"""The new typing decoder (step 3): one probability for every suggestion, auto-correction and next word.

    score(word) = log10 P(word | previous words, language mix) - SLIP * typing cost(typed letters, word)

The language model (lm.py) gives P(word | context) for each enabled language, weighted by how well each language
explains the recent text. The typing cost is the weighted Damerau-Levenshtein distance between the keys typed and
the word's letters (a neighbouring key 0.5, a swap 0.8, anything else 1; accents and apostrophes are free, as the
keys have none). While typing, the cost compares the typed keys with the word's best-fitting beginning, so the
word can be completed; on space, with the whole word, and the typed text is replaced only when a word scores
clearly better than the text as typed.

Candidates come from the dictionaries (exact and slipped prefixes, see baseline.WordStore) and the language model's
known continuations of the context; the probability decides among them.
"""

import math
import os

import accents
import baseline
from keyboard import ROW_PITCH, fold, key as match_key, normalize_apostrophes
from lm import LanguageModel, Mixture, COMMA, UNKNOWN

# Tuned with tune.py on the tuning sentences.
SLIP = 3.5              # log10 cost of one typing mistake (a neighbouring key costs half)
FIRST_LETTER = 0.6      # extra cost when the first letter is wrong (people rarely miss it)
UNKNOWN_WORD = -10.0    # log10 probability of a word no dictionary has (a name, slang)
CORRECT_MARGIN = 1.0    # log10 margin a correction needs over the text as typed
# Personal learning (WordStore.learnedLogProb / personalLogBonus in Swift).
LEARNED_BASE = -5.5     # log10 probability of a word the user taught the keyboard, used once...
LEARNED_SLOPE = 0.6     # ... plus this times ln(1 + uses), at most LEARNED_CAP
LEARNED_CAP = 2.0
LEARN_AFTER = 2         # an unknown word counts as the user's own after this many uses (one slip is not a word)
USED_SLOPE, USED_CAP = 0.25, 0.8        # dictionary words the user writes
PAIR_SLOPE, PAIR_CAP = 0.5, 1.2         # words the user put after the previous word
RESTORED = -8.5         # log10 probability of an unknown word with its accents restored (see accents.py)
SPLIT = float(os.environ.get("HUNKEYS_SPLIT", 1.0))  # log10 cost of a missing space ("nemakarom" -> "nem akarom")
SPLIT_WORD_FLOOR = -5.5  # a dictionary "word" rarer than this may be two words run together ("tothe")
SPATIAL = 0.5           # tap positions: cost per squared key-width of extra distance to the intended key
SHAPE = 10.0            # log10 cost of one unit of swipe shape mismatch (see baseline.decode_swipe)
CANDIDATES = 30


UNFINISHED_LETTER = 0.35   # Decoder.unfinishedLetter
OTHER_KEY = 0.5            # Decoder.otherKey: "o" typed for "ö" where the layout has both keys
TWIN, TWIN_ACROSS = 2, 1   # a row's last field (see Engine.features)


CLITIC_WORDS = 3        # a head ("l'", "j'") or ending ("'s", "'ll") counts when this many dictionary words have it


def clitic_parts(store):
    """(elided heads, clitic endings) of a dictionary: the parts before / after an apostrophe that join this many
    dictionary words to others ("l" from "l'amour", "s" from "it's"). WordStore.clitics in Swift."""
    words = {entry.word for entry in store.entries}
    heads, endings = {}, {}
    for word in words:
        if word.count("'") != 1:
            continue
        left, right = word.split("'")
        if left and right:
            if right in words:
                heads[left] = heads.get(left, 0) + 1
            if left in words:
                endings[right] = endings.get(right, 0) + 1
    return ({h for h, n in heads.items() if n >= CLITIC_WORDS}, {e for e, n in endings.items() if n >= CLITIC_WORDS})


def typing_cost(typed, word, costs):
    """(prefix cost, whole cost) of typing `typed` for `word` (both match keys). `costs[j]` maps a letter to the
    cost of the j-th typed key standing for it (see Engine.substitution_costs; missing letters cost 1)."""
    n, m = len(typed), len(word)
    previous2 = None
    previous = list(map(float, range(n + 1)))
    best_prefix = previous[n]
    for i in range(1, m + 1):
        ch = word[i - 1]
        row = [float(i)] + [0.0] * n
        for j in range(1, n + 1):
            t = typed[j - 1]
            sub = costs[j - 1].get(ch, 1.0)
            value = min(previous[j - 1] + sub, previous[j] + 1, row[j - 1] + 1)
            if i > 1 and j > 1 and t == word[i - 2] and typed[j - 2] == ch:
                value = min(value, previous2[j - 2] + 0.8)
            row[j] = value
        best_prefix = min(best_prefix, row[n])
        previous2, previous = previous, row
    return best_prefix, previous[n]


class Personal:
    """What the keyboard learns from one user (WordStore's learned / used words and pairs)."""

    def __init__(self):
        self.learned = {}
        self.used = {}
        self.usage = {}         # language -> recency-weighted words written in it
        self.pairs = {}
        self.triples = {}

    def is_learned(self, word, params):
        return self.learned.get(word, 0) >= params["learn_after"]

    def learned_logp(self, word, params):
        count = self.learned.get(word, 0)
        if count < params["learn_after"]:
            return None
        return params["learned_base"] + min(LEARNED_CAP, params["learned_slope"] * math.log(1 + count))

    def bonus(self, word, previous, before2):
        value = 0.0
        if word in self.used:
            value += min(USED_CAP, USED_SLOPE * math.log(1 + self.used[word]))
        if previous is not None:
            pair = (previous, word)
            if pair in self.pairs:
                value += min(PAIR_CAP, PAIR_SLOPE * math.log(1 + self.pairs[pair]))
            if before2 is not None and (before2,) + pair in self.triples:
                value += min(0.6, 0.3 * math.log(1 + self.triples[(before2,) + pair]))
        return value


class Engine(baseline.Engine):
    name = "decoder"

    def __init__(self, data_dir, enabled, active):
        super().__init__(data_dir, enabled, active)
        self.models = {lang: LanguageModel(lang, data_dir) for lang in self.ordered}
        self.mixture = Mixture(self.models, active)
        self.near = self.stores[active].layout.neighbors
        self.lm_keys = {lang: [match_key(w) for w in model.words] for lang, model in self.models.items()}
        self.personal = Personal()
        self.params = dict(Engine.params)
        self.accent_models = {}
        for lang in self.ordered:
            path = data_dir / f"accents_{lang}.bin"
            if path.exists():
                self.accent_models[lang] = accents.read(path)
        if os.environ.get("HUNKEYS_RESTORED"):
            self.params["restored"] = float(os.environ["HUNKEYS_RESTORED"])
        if os.environ.get("HUNKEYS_SPATIAL"):
            self.params["spatial"] = float(os.environ["HUNKEYS_SPATIAL"])
        self.clitics = {lang: clitic_parts(store) for lang, store in self.stores.items()}
        # Key centres by folded letter ("o" is the o key, not German's "ö" key).
        self.folded_centers = {}
        layout_centers = self.stores[active].layout.centers
        for letter in sorted(layout_centers, key=lambda letter: letter != fold(letter)):
            self.folded_centers.setdefault(fold(letter)[:1], layout_centers[letter])

    # -- learning (KeyboardViewController.learnWord / noteWordUse / recordBigram) --------------------------------

    def learn(self, before, word, explicit=False):
        """The user finished `word` after `before`. `explicit`: they took back an auto-correction to keep it."""
        word = normalize_apostrophes(word).lower()
        if len(word) < 2 or not all(baseline.is_word_char(c) for c in word):
            return
        personal = self.personal
        # Which languages the user writes in (Decoder.noteLanguage).
        self.mixture.usage = personal.usage
        weights = self.mixture.language_weights(before + word + " ")
        for lang in personal.usage:
            personal.usage[lang] *= 0.995
        for lang, weight in weights.items():
            personal.usage[lang] = personal.usage.get(lang, 0.0) + weight
        if explicit:
            personal.learned[word] = personal.learned.get(word, 0) + self.params["learn_after"]
        elif any(store.entry_exact(word) for store in self.stores.values()):
            personal.used[word] = personal.used.get(word, 0) + 1
        elif len(word) >= 3 and not any(store.contains(match_key(word)) for store in self.stores.values()):
            personal.learned[word] = personal.learned.get(word, 0) + 1
        text = before
        if text.endswith(" "):
            if baseline.is_sentence_start(text):
                personal.pairs[(".", word)] = personal.pairs.get((".", word), 0) + 1
            else:
                words = baseline.last_words(text, 2)
                if words:
                    personal.pairs[(words[-1], word)] = personal.pairs.get((words[-1], word), 0) + 1
                    if len(words) == 2:
                        key = (words[0], words[-1], word)
                        personal.triples[key] = personal.triples.get(key, 0) + 1

    # -- shared ---------------------------------------------------------------------------------------------------

    def _context(self, before):
        """Per language: (weight, history ids) for the text before the word being typed; "_words": the last two
        words of the sentence, for the user's own word pairs."""
        self.mixture.usage = self.personal.usage
        weights = self.mixture.language_weights(before)
        context = {lang: (weights[lang], model.context(before)) for lang, model in self.models.items()}
        sentence = [] if baseline.is_sentence_start(before) else baseline.last_words(before, 2)
        context["_words"] = (sentence[-1] if sentence else ".", sentence[-2] if len(sentence) == 2 else None)
        return context

    def _lm(self, word, context):
        """log10 P(word | context) mixed over the languages (UNKNOWN_WORD when none knows it)."""
        total = 0.0
        for lang, (weight, history) in context.items():
            if lang == "_words":
                continue
            model = self.models[lang]
            w = model.ids.get(word)
            if w is None or weight < 1e-6:
                continue
            v = history[-1]
            u = history[-2] if len(history) >= 2 else None
            total += weight * 10 ** model.logp(w, v, u)
        learned = self.personal.learned_logp(word, self.params)
        if learned is not None:
            total += 10 ** learned
        value = math.log10(total) if total > 0 else -99.0
        previous, before2 = context["_words"]
        return value + self.personal.bonus(word, previous, before2)

    def _candidates(self, key, lower, context):
        words = set()
        for lang in self.ordered:
            store = self.stores[lang]
            words.update(w for w, _ in store.completion_candidates(key, lower, CANDIDATES))
            if len(key) >= 3:
                words.update(w for w, _ in store.fuzzy_completion_candidates(key, CANDIDATES))
                words.update(w for w, _ in store.fuzzy_candidates(key, CANDIDATES))
            else:
                # One or two letters: every slip to a neighbouring key, looked up directly.
                for variant in self._variants(key):
                    words.update(w for w, _ in store.completion_candidates(variant, variant, 8))
            # What the language model expects here, if it starts like the typed word.
            model = self.models[lang]
            keys = self.lm_keys[lang]
            weight, history = context[lang]
            words.update(self._learned_candidates(key))
            if weight >= 0.05 and key:
                starts = {key[0]} | self.near.get(key[0], set()) | ({key[1]} if len(key) >= 2 else set())
                for w in model.candidates(history):
                    if w > COMMA and keys[w][:1] in starts:
                        words.add(model.words[w])
        return words

    def _learned_candidates(self, key):
        return [w for w in self.personal.learned if self.personal.is_learned(w, self.params) and match_key(w).startswith(key)]

    def _variants(self, key):
        result = {key}
        for i, ch in enumerate(key):
            for other in self.near.get(ch, ()):
                result.add(key[:i] + other + key[i + 1:])
        return result

    uses_taps = True

    def substitution_costs(self, lower, key, taps):
        """Per letter of `key`: letter -> cost of that typed key standing for it. With the tap's position (run.py
        passes them; the keyboard records them), a key the finger nearly hit costs almost nothing and one it was
        far from costs up to 1; without it, the typed key costs 0, its neighbours 0.5."""
        aligned = []
        if taps is not None and len(taps) == len(lower):
            for ch, tap in zip(lower, taps):
                aligned += [tap] * len(match_key(ch))
        if len(aligned) != len(key):
            aligned = [None] * len(key)
        layout = self.stores[self.active].layout
        centers = self.folded_centers
        spatial = self.params["spatial"]
        costs = []
        for t, tap in zip(key, aligned):
            if tap is None or t not in centers:
                table = {c: 0.5 for c in self.near.get(t, ())}
            else:
                def d2(center):
                    return ((tap[0] - center[0]) / layout.key_width) ** 2 + ((tap[1] - center[1]) / ROW_PITCH) ** 2
                own = d2(centers[t])
                table = {c: min(1.0, max(0.0, spatial * (d2(center) - own))) for c, center in centers.items()}
            table[t] = 0.0
            costs.append(table)
        return costs

    def features(self, before, typed, taps=None):
        """(word, log10 P(word | context), prefix cost, whole cost, wrong first letter, typed but for accents the
        layout has no key for) for every candidate, plus the typed text's own probability. Everything the settings act on, so tune.py can try settings quickly."""
        lower = normalize_apostrophes(typed).lower()
        key = match_key(lower)
        head = before[:-len(typed)] if typed and before.endswith(typed) else before
        context = self._context(head)
        near = self.substitution_costs(lower, key, taps)
        layout = self.stores[self.active].layout
        typed_in = [store for store in self.stores.values() if store.entry_exact(lower)]
        rows = []
        for word in self._candidates(key, lower, context):
            word_key = match_key(word)
            if not word_key:
                continue
            prefix_cost, whole_cost = typing_cost(key, word_key, near)
            if prefix_cost > 2.0:
                continue
            # The last one or two letters left off ("appl" -> "apple") cost far less than a wrong key
            # (Decoder.unfinishedLetter).
            missing = len(word_key) - len(key)
            if prefix_cost < 0.001 and 1 <= missing <= 2:
                whole_cost = min(whole_cost, UNFINISHED_LETTER * missing)
            other = layout.other_keys(lower, word)
            if other:
                prefix_cost += OTHER_KEY * other
                whole_cost += OTHER_KEY * other
            # The typed text with only the accents (or apostrophe) the layout has no key for left off: TWIN when a
            # language has both spellings (or the typed one is no word), TWIN_ACROSS when only another language has it
            # (English "he", Hungarian "hé").
            twin = 0
            if word_key == key and word != lower and layout.typed_form(word) == lower:
                twin = TWIN if not typed_in or any(store.entry_exact(word) for store in typed_in) else TWIN_ACROSS
            rows.append((word, self._lm(word, context), prefix_cost, whole_cost, word_key[0] != key[0], twin))
        # A word no dictionary has, typed without accents: its accents restored, in the languages of the text.
        if key and key == lower and not any(store.contains(key) for store in self.stores.values()):
            for lang, model in self.accent_models.items():
                weight = context[lang][0]
                restored = model.restore(key) if weight >= 0.1 else key
                if restored != key:
                    rows.append((restored, self.params["restored"] + math.log10(weight), 0.0, 0.0, False, 0))
        rows.extend(self._splits(key, lower, head, context))
        rows.extend(self._clitic_rows(lower, head, taps))
        return rows, lower, self._lm(lower, context)

    def _clitic_rows(self, lower, head, taps):
        """A word with an elided head or a clitic ending that the dictionary lacks as a whole ("l'oceab" ->
        "l'océan", "j'ecris" -> "j'écris", "tom's"): the part that is a word of its own is decoded like any word,
        and the clitic is kept as typed. The text as typed is a row too when that part is a word."""
        if lower.count("'") != 1 or any(store.entry_exact(lower) for store in self.stores.values()):
            return []
        i = lower.index("'")
        left, right = lower[:i], lower[i + 1:]
        if not left or not right:
            return []
        rows = []
        for part, start, clitic, kind in ((right, i + 1, left, 0), (left, 0, right, 1)):
            if not any(clitic in self.clitics[lang][kind] for lang in self.ordered):
                continue
            part_taps = taps[start:start + len(part)] if taps is not None and len(taps) == len(lower) else None
            found, _, part_lm = self.features(head + part, part, part_taps)
            for word, lm, prefix_cost, whole_cost, first_wrong, twin in found:
                if " " not in word and "'" not in word:
                    whole = left + "'" + word if kind == 0 else word + "'" + right
                    rows.append((whole, lm, prefix_cost, whole_cost, first_wrong, twin))
            if part_lm > -98:
                rows.append((lower, part_lm, 0.0, 0.0, False, 0))
        return rows

    def _exact(self, part):
        """Dictionary words whose key is exactly `part`."""
        found = set()
        for store in self.stores.values():
            found.update(w for w, _ in store.completion_candidates(part, part, 30) if match_key(w) == part)
        return found

    def _splits(self, key, lower, head, context):
        """Two words typed without the space between them ("nemakarom" -> "nem akarom"): every place the typed
        letters split into a dictionary word and a word (or the start of one), scored as both words in a row. Not
        when the typed letters are a real word; a rare one that is really a slip ("tothe") still splits."""
        if len(key) < 3:
            return []
        floor = -math.inf   # a typed dictionary word: split only when rare, into words more likely than it
        if any(store.contains(key) for store in self.stores.values()):
            floor = self._lm(lower, context)
            if floor >= SPLIT_WORD_FLOOR:
                return []
        rows = []
        for i in range(1, len(key)):
            left, right = key[:i], key[i:]
            firsts = self._exact(left)
            if not firsts:
                continue
            seconds = self._exact(right)
            for store in self.stores.values():
                seconds.update(w for w, _ in store.completion_candidates(right, right, 8))
            if not seconds:
                continue
            for first in firsts:
                p1 = self._lm(first, context)
                if p1 < -6:
                    continue
                after = self._context(head + first + " ")
                for second in seconds:
                    exact = match_key(second) == right
                    lm = p1 + self._lm(second, after) - self.params["split"]
                    if lm <= floor:
                        continue
                    rows.append((first + " " + second, lm, 0.0, 0.0 if exact else 9.0, False, 0))
        return rows

    # -- the keyboard's questions ---------------------------------------------------------------------------------

    params = {"slip": SLIP, "first": FIRST_LETTER, "unknown": UNKNOWN_WORD, "margin": CORRECT_MARGIN, "shape": SHAPE,
              "learn_after": LEARN_AFTER, "learned_base": LEARNED_BASE, "learned_slope": LEARNED_SLOPE,
              "spatial": SPATIAL, "restored": RESTORED, "split": SPLIT}

    def swipe_features(self, before, path):
        """(word, shape cost, log10 P(word | context)) for every word the swipe could be."""
        context = self._context(before)
        layout = self.stores[self.active].layout
        shapes = {}

        def collect(_store, entry, geometry):
            if geometry < shapes.get(entry.word, float("inf")):
                shapes[entry.word] = geometry

        for lang in self.ordered:
            baseline.decode_swipe(path, layout.centers, layout.key_width, [(self.stores[lang], 0, {}, {})], 0, collect)
        return [(word, shape, self._lm(word, context)) for word, shape in shapes.items()]

    def swipe(self, before, path, limit=4):
        return swipe_ranking(self.swipe_features(before, path), self.params)[:limit]

    def suggest(self, before, typed, limit=4, taps=None):
        if normalize_apostrophes(typed).endswith("'"):
            # "j'", "we'": the dictionary's elisions and contractions (Predictor.suggest).
            return baseline.Engine.suggest(self, before, typed, limit)
        rows, lower, _ = self.features(before, typed, taps)
        active = self.stores.get(self.active)
        return suggestions(rows, lower, self.params, limit,
                           is_active=(lambda w: " " not in w and active.contains(match_key(w))) if active else None)

    def on_space(self, before, typed, taps=None):
        lower = normalize_apostrophes(typed).lower()
        if self.personal.is_learned(lower, self.params):
            return lower
        rows, lower, typed_lm = self.features(before, typed, taps)
        return correction(rows, lower, typed_lm, self.params)

    def next_words(self, before, limit=3):
        """Decoder.nextWords: the models' likeliest next words, plus words the user put after the previous one."""
        context = self._context(before)
        combined = {}
        for lang, model in self.models.items():
            weight, history = context[lang]
            if weight < 0.02:
                continue
            for word, logp in model.next_words(history, limit * 4):
                combined[word] = combined.get(word, 0.0) + weight * 10 ** logp
        previous, _ = context["_words"]
        for (first, word), count in self.personal.pairs.items():
            if first == previous:
                strength = min(PAIR_CAP, PAIR_SLOPE * math.log(1 + count))
                combined[word] = max(combined.get(word, 0.0), 1e-4) * 10 ** strength
        combined.pop(previous, None)
        ranked = sorted(combined.items(), key=lambda kv: (-kv[1], kv[0]))
        return [w for w, _ in ranked[:limit]]


def rank(rows, lower, params, whole):
    """Candidates best first: log10 P(word | context) minus the cost of the typing slips."""
    scored = []
    for word, lm, prefix_cost, whole_cost, first_wrong, _ in rows:
        cost = whole_cost if whole else prefix_cost
        if cost > 2.0:
            continue
        scored.append((lm - params["slip"] * cost - (params["first"] if first_wrong else 0.0), word))
    scored.sort(reverse=True)
    return scored


ACTIVE_KEEP = 2.0  # Decoder.activeKeep


def suggestions(rows, lower, params, limit=4, is_active=None):
    """Best first; a word of the layout's language that nearly made it keeps the last place (Decoder.shown)."""
    ranked = [(s, w) for s, w in rank(rows, lower, params, whole=False) if w != lower]
    top = ranked[:limit]
    if is_active and limit >= 2 and len(top) == limit and not any(is_active(w) for _, w in top):
        keep = next(((s, w) for s, w in ranked[limit:] if is_active(w)), None)
        if keep and keep[0] >= top[-1][0] - ACTIVE_KEEP:
            top[-1] = keep
    return [w for _, w in top]


def correction(rows, lower, typed_lm, params):
    """What space leaves in the text: the best word, if it beats the text as typed by the margin. A dictionary word
    the typed letters spell but for accents (or an apostrophe) the layout has no key for ("kozotti" -> "közötti",
    "que" -> "qué", "were" -> "we're") is what the writer typed whenever it is likelier (by the margin when only
    another language has it); any other word must then beat it by the margin ("közötti" stays, not "között")."""
    scored = rank(rows, lower, params, whole=True)
    if not scored:
        return lower
    base_score, base = max(typed_lm, params["unknown"]), lower
    own = next((s for s, w in scored if w == lower), None)
    if own is not None and own > base_score:
        base_score = own     # a clitic on a known word ("tom's")
    twins = {row[0]: row[5] for row in rows if row[5]}
    twin = next(((s, w) for s, w in scored if w in twins), None)
    if twin is not None and twin[0] > base_score + (0.0 if twins[twin[1]] == TWIN else params["margin"]):
        base_score, base = twin
    best_score, best = scored[0]
    if best != base and best_score >= base_score + params["margin"]:
        return best
    return base


def swipe_ranking(rows, params):
    """Swiped words best first: log10 P(word | context) minus the cost of the path's mismatch with the word."""
    scored = sorted(((lm - params["shape"] * shape, word) for word, shape, lm in rows), reverse=True)
    return [w for _, w in scored]
