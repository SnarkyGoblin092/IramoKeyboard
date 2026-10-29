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

import baseline
from keyboard import key as match_key, normalize_apostrophes
from lm import LanguageModel, Mixture, COMMA, UNKNOWN

# Tuned with tune.py on the tuning sentences.
SLIP = 3.5              # log10 cost of one typing mistake (a neighbouring key costs half)
FIRST_LETTER = 0.6      # extra cost when the first letter is wrong (people rarely miss it)
UNKNOWN_WORD = -10.0    # log10 probability of a word no dictionary has (a name, slang)
CORRECT_MARGIN = 1.0    # log10 margin a correction needs over the text as typed
CANDIDATES = 30


def typing_cost(typed, word, near):
    """(prefix cost, whole cost) of typing `typed` for `word` (both match keys)."""
    n, m = len(typed), len(word)
    previous2 = None
    previous = list(map(float, range(n + 1)))
    best_prefix = previous[n]
    for i in range(1, m + 1):
        ch = word[i - 1]
        row = [float(i)] + [0.0] * n
        for j in range(1, n + 1):
            t = typed[j - 1]
            sub = 0.0 if t == ch else (0.5 if ch in near[j - 1] else 1.0)
            value = min(previous[j - 1] + sub, previous[j] + 1, row[j - 1] + 1)
            if i > 1 and j > 1 and t == word[i - 2] and typed[j - 2] == ch:
                value = min(value, previous2[j - 2] + 0.8)
            row[j] = value
        best_prefix = min(best_prefix, row[n])
        previous2, previous = previous, row
    return best_prefix, previous[n]


class Engine(baseline.Engine):
    name = "decoder"

    def __init__(self, data_dir, enabled, active):
        super().__init__(data_dir, enabled, active)
        self.models = {lang: LanguageModel(lang, data_dir) for lang in self.ordered}
        self.mixture = Mixture(self.models, active)
        self.near = self.stores[active].layout.neighbors
        self.lm_keys = {lang: [match_key(w) for w in model.words] for lang, model in self.models.items()}

    # -- shared ---------------------------------------------------------------------------------------------------

    def _context(self, before):
        """Per language: (weight, history ids) for the text before the word being typed."""
        weights = self.mixture.language_weights(before)
        return {lang: (weights[lang], model.context(before)) for lang, model in self.models.items()}

    def _lm(self, word, context):
        """log10 P(word | context) mixed over the languages (UNKNOWN_WORD when none knows it)."""
        total = 0.0
        for lang, (weight, history) in context.items():
            model = self.models[lang]
            w = model.ids.get(word)
            if w is None or weight < 1e-6:
                continue
            v = history[-1]
            u = history[-2] if len(history) >= 2 else None
            total += weight * 10 ** model.logp(w, v, u)
        return math.log10(total) if total > 0 else -99.0

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
            if weight >= 0.05 and key:
                starts = {key[0]} | self.near.get(key[0], set()) | ({key[1]} if len(key) >= 2 else set())
                for w in model.candidates(history):
                    if w > COMMA and keys[w][:1] in starts:
                        words.add(model.words[w])
        return words

    def _variants(self, key):
        result = {key}
        for i, ch in enumerate(key):
            for other in self.near.get(ch, ()):
                result.add(key[:i] + other + key[i + 1:])
        return result

    def features(self, before, typed):
        """(word, log10 P(word | context), prefix cost, whole cost, wrong first letter) for every candidate, plus the
        typed text's own probability. Everything the settings act on, so tune.py can try settings quickly."""
        lower = normalize_apostrophes(typed).lower()
        key = match_key(lower)
        head = before[:-len(typed)] if typed and before.endswith(typed) else before
        context = self._context(head)
        near = [self.near.get(c, set()) for c in key]
        rows = []
        for word in self._candidates(key, lower, context):
            word_key = match_key(word)
            if not word_key:
                continue
            prefix_cost, whole_cost = typing_cost(key, word_key, near)
            if prefix_cost > 2.0:
                continue
            rows.append((word, self._lm(word, context), prefix_cost, whole_cost, word_key[0] != key[0]))
        return rows, lower, self._lm(lower, context)

    # -- the keyboard's questions ---------------------------------------------------------------------------------

    params = {"slip": SLIP, "first": FIRST_LETTER, "unknown": UNKNOWN_WORD, "margin": CORRECT_MARGIN}

    def suggest(self, before, typed, limit=4):
        rows, lower, _ = self.features(before, typed)
        return suggestions(rows, lower, self.params, limit)

    def on_space(self, before, typed):
        rows, lower, typed_lm = self.features(before, typed)
        return correction(rows, lower, typed_lm, self.params)

    def next_words(self, before, limit=3):
        return self.mixture.next_words(before, limit)


def rank(rows, lower, params, whole):
    """Candidates best first: log10 P(word | context) minus the cost of the typing slips."""
    scored = []
    for word, lm, prefix_cost, whole_cost, first_wrong in rows:
        cost = whole_cost if whole else prefix_cost
        if cost > 2.0:
            continue
        scored.append((lm - params["slip"] * cost - (params["first"] if first_wrong else 0.0), word))
    scored.sort(reverse=True)
    return scored


def suggestions(rows, lower, params, limit=4):
    return [w for _, w in rank(rows, lower, params, whole=False) if w != lower][:limit]


def correction(rows, lower, typed_lm, params):
    """What space leaves in the text: the best word, if it beats the text as typed by the margin."""
    scored = rank(rows, lower, params, whole=True)
    if not scored:
        return lower
    typed_score = max(typed_lm, params["unknown"])
    best_score, best = scored[0]
    if best != lower and best_score >= typed_score + params["margin"]:
        return best
    return lower

