"""The keyboard's current prediction, ported line by line from Keyboard/WordStore.swift, Predictor.swift,
SwipeDecoder.swift and the parts of KeyboardViewController.swift that call them.

It exists so the test harness can score the current behaviour; nothing the user has learned is modelled
(no learned words, pairs or word use), which is how a fresh install behaves.
"""

import bisect
import math
from pathlib import Path

from keyboard import Layout, fold, key as match_key, normalize_apostrophes, APOSTROPHES

INF = float("inf")


class Entry:
    __slots__ = ("word", "folded", "freq", "norm", "length")

    def __init__(self, word, folded, freq, norm):
        self.word, self.folded, self.freq, self.norm = word, folded, freq, norm
        self.length = len(folded)


def insert(candidate, top, limit):
    """WordStore.insert: keeps `top` best first, at most `limit` long, one entry per word."""
    word, score = candidate
    if len(top) == limit and score <= top[-1][1]:
        return
    if any(w == word for w, _ in top):
        return
    position = len(top)
    while position > 0 and top[position - 1][1] < score:
        position -= 1
    top.insert(position, candidate)
    if len(top) > limit:
        top.pop()


STARTERS = {
    "en": ["i", "the", "thanks", "hey", "hi", "what", "do", "can", "we", "it's"],
    "hu": ["szia", "köszi", "én", "nem", "hogy", "mi", "jó", "igen", "ma", "nagyon"],
    "de": ["ich", "hallo", "danke", "das", "wir", "was", "ja", "nein", "es", "hast"],
    "fr": ["je", "salut", "merci", "bonjour", "on", "c'est", "oui", "non", "tu", "il"],
    "es": ["hola", "gracias", "yo", "no", "sí", "qué", "me", "es", "buenos", "te"],
    "it": ["ciao", "grazie", "io", "non", "sì", "che", "come", "è", "ho", "buongiorno"],
    "pt": ["olá", "obrigado", "eu", "não", "sim", "o", "que", "bom", "tudo", "oi"],
    "nl": ["hoi", "dank", "ik", "het", "wat", "ja", "nee", "we", "je", "goed"],
}

COMMON_PAIRS = {
    "en": {
        "i": ["am", "have", "think", "will"], "i'm": ["not", "going", "sure"], "i'll": ["be", "do", "see"],
        "i've": ["been", "got", "never"], "thank": ["you"], "thanks": ["for", "so"], "how": ["are", "do", "to"],
        "what": ["is", "are", "do"], "see": ["you"], "let's": ["go", "see", "do"], "do": ["you", "not", "it"],
        "you": ["are", "can", "have"], "it's": ["a", "not", "the"], "we": ["are", "can", "have"],
        "good": ["morning", "night", "luck"], "i'd": ["like", "love", "be"], "can": ["you", "i", "we"],
        "don't": ["know", "worry", "forget"], "see you": ["soon", "later", "tomorrow"], "looking": ["forward"],
        "talk": ["to", "soon", "later"], "have": ["a", "you", "to"], "is": ["it", "this", "there"],
        "of": ["course", "the", "my"], "on": ["my", "the", "it"], "in": ["the", "a", "my"],
        "happy": ["birthday", "new", "to"], "no": ["problem", "worries", "way"], "sounds": ["good", "great"],
    },
    "hu": {
        "jó": ["reggelt", "estét", "napot"], "nagyon": ["szépen", "jó", "köszönöm"], "hogy": ["vagy", "van", "lehet"],
        "köszönöm": ["szépen", "a", "nagyon"], "szia": ["hogy", "mizu"], "mi": ["újság", "van", "a"],
        "viszlát": ["holnap", "később"], "kérlek": ["szépen", "hívj"], "szeretlek": ["téged"],
        "boldog": ["születésnapot", "karácsonyt", "új"], "sajnálom": ["hogy", "nagyon"],
    },
}


class WordStore:
    def __init__(self, lang: str, data_dir: Path, limit=None):
        self.lang = lang
        self.layout = Layout(lang)
        entries = []
        max_log = 1.0
        with open(data_dir / f"words_{lang}.tsv", encoding="utf-8") as handle:
            for line in handle:
                parts = line.rstrip("\n").split("\t")
                if len(parts) < 3 or not parts[2].isdigit():
                    continue
                freq = int(parts[2])
                if not entries:
                    max_log = max(math.log(freq + 1), 1)
                word = normalize_apostrophes(parts[0])
                folded = parts[1] or match_key(word)
                if not folded:
                    continue
                entries.append(Entry(word, folded, freq, min(1, math.log(freq + 1) / max_log)))
                if limit is not None and len(entries) >= limit:
                    break
        entries.sort(key=lambda e: e.folded)
        self.entries = entries
        self.keys = [e.folded for e in entries]
        self.pairs = {}
        path = data_dir / f"pairs_{lang}.tsv"
        if path.exists():
            with open(path, encoding="utf-8") as handle:
                for line in handle:
                    parts = line.rstrip("\n").split("\t", 1)
                    if len(parts) == 2:
                        self.pairs[parts[0]] = parts[1]
        # Swipe index: first + last key letter -> entry indices.
        self.edges = {}
        for index, entry in enumerate(entries):
            letters = [k for k in (self.layout.key_letter(c) for c in entry.word) if k is not None]
            if len(letters) >= 2:
                self.edges.setdefault(letters[0] + letters[-1], []).append(index)
        self.prefix_cache = {}
        self.frequency_order = None

    def lower_bound(self, key):
        return bisect.bisect_left(self.keys, key)

    def top_indices(self, prefix):
        cached = self.prefix_cache.get(prefix)
        if cached is not None:
            return cached
        index = self.lower_bound(prefix)
        matches = []
        while index < len(self.entries) and self.keys[index].startswith(prefix):
            matches.append(index)
            index += 1
        matches.sort(key=lambda i: -self.entries[i].freq)
        top = matches[:100]
        self.prefix_cache[prefix] = top
        return top

    def contains(self, key):
        index = self.lower_bound(key)
        return index < len(self.keys) and self.keys[index] == key

    def frequency_of_key(self, key):
        index = self.lower_bound(key)
        best = 0.0
        while index < len(self.keys) and self.keys[index] == key:
            best = max(best, self.entries[index].norm)
            index += 1
        return best

    def spelling_check(self, typed):
        lower = normalize_apostrophes(typed).lower()
        key = match_key(lower)
        if not key:
            return ("unknown",)
        typed_freq, typed_norm, best, runner_up = 0, 0.0, None, 0
        index = self.lower_bound(key)
        while index < len(self.keys) and self.keys[index] == key:
            entry = self.entries[index]
            index += 1
            if entry.word == lower:
                typed_freq, typed_norm = entry.freq, entry.norm
            elif entry.freq > (best.freq if best else 0):
                runner_up = best.freq if best else 0
                best = entry
            else:
                runner_up = max(runner_up, entry.freq)
        if best is None:
            return ("keep",) if typed_freq > 0 else ("unknown",)
        if best.freq >= 50 * typed_freq and typed_norm < 0.65 and best.freq >= 3 * runner_up and best.norm >= 0.15:
            return ("fix", best.word, best.norm)
        return ("keep",) if typed_freq > 0 else ("unknown",)

    def completion_candidates(self, key, typed_lower, limit, contractions_only=False):
        if not key or limit <= 0:
            return []
        top = []

        def entry_score(entry):
            score = entry.norm
            if entry.word.startswith(typed_lower):
                score += 0.12
            if entry.folded == key and entry.word != typed_lower:
                score += 0.15
            extra = entry.length - len(key)
            if extra > 0:
                score -= min(0.10, 0.012 * extra)
            return score

        if len(key) <= 3 and not contractions_only:
            for index in self.top_indices(key):
                entry = self.entries[index]
                insert((entry.word, entry_score(entry)), top, limit)
        else:
            index = self.lower_bound(key)
            scanned = 0
            while index < len(self.entries) and scanned < 40000 and self.keys[index].startswith(key):
                entry = self.entries[index]
                index += 1
                scanned += 1
                if contractions_only and "'" not in entry.word:
                    continue
                insert((entry.word, entry_score(entry)), top, limit)
        return top

    def fuzzy_scan(self, typed, max_cost, visit):
        """Weighted Damerau-Levenshtein over words sharing rows (see WordStore.fuzzyScan). Words that share a
        beginning that already failed are skipped in one jump: their rows, and so their result, are identical."""
        n = len(typed)
        if n == 0:
            return
        width, depth = n + 1, n + 2
        near = [self.layout.neighbors.get(t, set()) for t in typed]
        table = [0.0] * ((depth + 1) * width)
        for j in range(n + 1):
            table[j] = float(j)
        row_min = [0.0] * (depth + 1)
        letters = [" "] * depth
        starts = {typed[0]} | near[0]
        if n >= 2:
            starts.add(typed[1])
        entries, keys = self.entries, self.keys
        for start in starts:
            index = self.lower_bound(start)
            known = 0
            while index < len(entries) and keys[index][:1] == start:
                entry = entries[index]
                index += 1
                row = 0
                shared = True
                complete = True
                over = False
                prefix_cost = INF
                for ch in entry.folded:
                    if row == depth:
                        complete = False
                        break
                    if not (shared and row < known and letters[row] == ch):
                        shared = False
                        letters[row] = ch
                        r = row + 1
                        base = r * width
                        up = base - width
                        table[base] = float(r)
                        minimum = table[base]
                        for j in range(1, n + 1):
                            t = typed[j - 1]
                            sub = 0.0 if t == ch else (0.5 if ch in near[j - 1] else 1.0)
                            value = min(table[up + j - 1] + sub, table[up + j] + 1, table[base + j - 1] + 1)
                            if r > 1 and j > 1 and t == letters[r - 2] and typed[j - 2] == ch:
                                value = min(value, table[up - width + j - 2] + 0.8)
                            table[base + j] = value
                            if value < minimum:
                                minimum = value
                        row_min[r] = minimum
                    row += 1
                    cost = table[row * width + n]
                    if cost < prefix_cost:
                        prefix_cost = cost
                    if row_min[row] > max_cost and row_min[row - 1] > max_cost:
                        complete = False
                        over = True
                        break
                known = row
                if prefix_cost > max_cost:
                    if over:
                        index = bisect.bisect_left(keys, "".join(letters[:row]) + "\U0010ffff", index)
                    continue
                visit(entry, prefix_cost, table[row * width + n] if complete else None)

    def fuzzy_candidates(self, key, limit):
        typed = list(key)
        if len(typed) < 3 or limit <= 0:
            return []
        top = []
        max_cost = 1.6 if len(typed) >= 6 else 1.1

        def visit(entry, _prefix_cost, whole_cost):
            if whole_cost is None or whole_cost > max_cost or entry.folded == key or abs(entry.length - len(typed)) > 2:
                return
            insert((entry.word, entry.norm * 0.75 + (max_cost - whole_cost) * 0.30), top, limit)

        self.fuzzy_scan(typed, max_cost, visit)
        return top

    def fuzzy_completion_candidates(self, key, limit):
        typed = list(key)
        if len(typed) < 3 or limit <= 0:
            return []
        max_cost = 1.5 if len(typed) >= 7 else (1.0 if len(typed) >= 4 else 0.5)
        top = []

        def visit(entry, prefix_cost, _whole):
            if prefix_cost <= 0:
                return
            score = entry.norm - 0.10 - 0.40 * prefix_cost
            if entry.folded[:1] != typed[0]:
                score -= 0.20
            extra = entry.length - len(typed)
            if extra > 0:
                score -= min(0.10, 0.012 * extra)
            insert((entry.word, score), top, limit)

        self.fuzzy_scan(typed, max_cost, visit)
        return top

    def frequent_words(self, letters, limit):
        if self.frequency_order is None:
            order = sorted(range(len(self.entries)), key=lambda i: -self.entries[i].freq)
            self.frequency_order = order[:min(len(order), 6000)]
        result = []
        for index in self.frequency_order:
            entry = self.entries[index]
            first = entry.folded[:1]
            ok = (first in letters) if letters is not None else first.isalpha()
            if not first or not ok or "'" in entry.word or entry.length < 2:
                continue
            result.append((entry.word, entry.norm))
            if len(result) >= limit:
                break
        return result

    def built_in_followers(self, prev):
        result = list(COMMON_PAIRS.get(self.lang, {}).get(prev, []))
        line = self.pairs.get(prev)
        if line:
            for word in line.split(" "):
                if word not in result:
                    result.append(word)
        return result

    def bigram_bonus(self, previous, nxt, before2=None):
        prev = normalize_apostrophes(previous).lower()
        following = normalize_apostrophes(nxt).lower()
        if not prev or not following:
            return 0.0
        followers = self.built_in_followers(prev)
        if following in followers:
            return 0.35 - 0.05 * followers.index(following)
        return 0.0

    def context_bonuses(self, previous, before2=None):
        prev = normalize_apostrophes(previous).lower()
        if not prev:
            return {}
        result = {}
        for position, word in enumerate(self.built_in_followers(prev)):
            result.setdefault(word, 0.35 - 0.05 * position)
        return result

    def next_words(self, previous, before2, limit):
        prev = normalize_apostrophes(previous).lower()
        if not prev or limit <= 0:
            return []
        scored = {w: b for w, b in self.context_bonuses(prev, before2).items() if w != prev}
        result = [w for w, _ in sorted(scored.items(), key=lambda kv: -kv[1])][:limit]
        if len(result) < limit:
            for word in self.built_in_followers(prev):
                if word not in result and word != prev:
                    result.append(word)
                    if len(result) >= limit:
                        break
        return result

    def sentence_starters(self, limit):
        result = []
        for word in STARTERS.get(self.lang, []) + self.built_in_followers("."):
            if len(result) < limit and word not in result:
                result.append(word)
        if len(result) < limit:
            blocked = {"the", "a", "an", "of", "to", "and"}
            for word, _ in self.frequent_words(None, 40):
                if len(result) < limit and word not in result and len(word) >= 2 and word not in blocked:
                    result.append(word)
        return result


# ---------------------------------------------------------------------------------------------------------------
# Predictor
# ---------------------------------------------------------------------------------------------------------------

def is_word_char(ch):
    return ch.isalpha() or ch in APOSTROPHES


def clean(token):
    text = normalize_apostrophes(token).lower()
    return text.strip("'")


def last_words(text, count):
    words, current = [], []
    for ch in reversed(text[-120:]):
        if is_word_char(ch):
            current.append(ch)
        elif current:
            words.append(clean("".join(reversed(current))))
            current = []
            if len(words) >= count:
                break
    if current and len(words) < count:
        words.append(clean("".join(reversed(current))))
    return list(reversed([w for w in words if w]))


def tokens(text):
    result, current = [], ""
    for ch in text:
        if is_word_char(ch):
            current += ch
        elif current:
            token = clean(current)
            if len(token) >= 2:
                result.append(token)
            current = ""
    if current:
        token = clean(current)
        if len(token) >= 2:
            result.append(token)
    return result


def is_sentence_start(text):
    trimmed = text.rstrip(" \n")
    return not trimmed or trimmed[-1] in ".!?…"


class FieldContext:
    def __init__(self, before, after=""):
        head = before[-2000:]
        while head and is_word_char(head[-1]):
            head = head[:-1]
        self.next_word = None
        all_tokens = tokens(head)[-300:]
        self.counts, self.recency = {}, {}
        count = len(all_tokens)
        for index, token in enumerate(all_tokens):
            self.counts[token] = self.counts.get(token, 0) + 1
            self.recency[token] = index / (count - 1) if count > 1 else 1
        self._dominant = None
        self._dominant_key = None

    def bonus(self, word):
        key = clean(word)
        count = self.counts.get(key)
        if count is None:
            return 0.0
        base = min(0.35, 0.10 + 0.05 * min(count, 5))
        return base * (0.6 + 0.4 * self.recency.get(key, 0))

    def uses(self, word, at_least=1):
        return self.counts.get(clean(word), 0) >= at_least

    def dominant(self, active, stores):
        memo = (active, len(stores))
        if memo == self._dominant_key:
            return self._dominant
        self._dominant_key = memo
        self._dominant = None
        sample = [w for w, _ in sorted(self.recency.items(), key=lambda kv: kv[1])][-60:]
        sample = [w for w in sample if len(match_key(w)) >= 3]
        if len(sample) < 3 or not stores:
            return None
        hits = {}
        for word in sample:
            for lang in owners(word, stores):
                hits[lang] = hits.get(lang, 0) + 1
        winner, winner_hits = active, hits.get(active, 0)
        for lang, n in hits.items():
            if n > winner_hits:
                winner, winner_hits = lang, n
        if winner_hits >= 0.4 * len(sample):
            self._dominant = winner
        return self._dominant


def owners(word, stores):
    key = match_key(word)
    freqs = {}
    for lang, store in stores.items():
        value = store.frequency_of_key(key)
        if value > 0:
            freqs[lang] = value
    if not freqs:
        return []
    top = max(freqs.values())
    return [lang for lang, v in freqs.items() if v >= top - 0.08]


def context_weights(before, current_prefix, stores):
    text = before
    if current_prefix and text.endswith(current_prefix):
        text = text[:-len(current_prefix)]
    words = [w for w in last_words(text, 4) if len(match_key(w)) >= 3]
    if not words:
        return {}
    hits = {}
    for word in words:
        for lang in owners(word, stores):
            hits[lang] = hits.get(lang, 0) + 1
    return {lang: n / len(words) for lang, n in hits.items()}


ELISION_HEADS = {
    "fr": {"l", "d", "j", "m", "n", "s", "t", "c", "qu", "jusqu", "lorsqu", "puisqu", "quoiqu"},
    "it": {"l", "un", "dell", "all", "dall", "nell", "sull", "quest", "quell", "c", "d", "m", "t", "s", "v",
           "nessun", "buon", "sant", "bell", "tutt", "com", "dov", "cos"},
}


def split_elision(token, lang):
    heads = ELISION_HEADS.get(lang)
    if not heads or "'" not in token:
        return None
    head, tail = token.split("'", 1)
    return (head, tail) if head in heads else None


ENGLISH_APOSTROPHES = {
    "dont": "don't", "cant": "can't", "doesnt": "doesn't", "didnt": "didn't", "isnt": "isn't",
    "arent": "aren't", "wasnt": "wasn't", "werent": "weren't", "hasnt": "hasn't", "havent": "haven't",
    "hadnt": "hadn't", "couldnt": "couldn't", "wouldnt": "wouldn't", "shouldnt": "shouldn't",
    "mustnt": "mustn't", "im": "i'm", "ive": "i've", "youre": "you're", "theyre": "they're",
    "thats": "that's", "whats": "what's", "theres": "there's", "youve": "you've", "theyve": "they've",
    "youll": "you'll", "theyll": "they'll", "itll": "it'll", "couldve": "could've", "wouldve": "would've",
    "shouldve": "should've", "mightve": "might've", "mustve": "must've", "whos": "who's",
    "heres": "here's", "hows": "how's", "wheres": "where's",
}


class Engine:
    """The current keyboard, as the harness drives it."""

    name = "current"

    def __init__(self, data_dir: Path, enabled, active):
        self.active = active
        self.enabled = list(enabled)
        others = [lang for lang in self.enabled if lang != active][:4]
        share = max(20000, 160000 // max(1, len(others)))
        self.stores = {active: WordStore(active, data_dir)}
        for lang in others:
            self.stores[lang] = WordStore(lang, data_dir, limit=share)
        self.ordered = [active] + others

    # -- typing -------------------------------------------------------------------------------------------------

    def suggest(self, before, typed, limit=4):
        """Predictor.suggest; `before` includes `typed`."""
        field = FieldContext(before)
        stores = self.stores
        token = normalize_apostrophes(typed)
        lower = token.lower()
        key = match_key(token)
        if not key:
            return []
        ends_with_apostrophe = lower.endswith("'")
        weights = context_weights(before, typed, stores)
        dominant = field.dominant(self.active, stores)
        foreign = dominant if dominant is not None and dominant != self.active else None

        def language_bonus(lang):
            bonus = 0.5 * weights.get(lang, 0)
            if lang == self.active:
                bonus += 0.08 if foreign is None else 0.03
            if lang == foreign:
                bonus += 0.30
            return bonus

        previous = before2 = None
        head = before[:-len(typed)] if typed and before.endswith(typed) else before
        if head.endswith(" ") and not is_sentence_start(head):
            words = last_words(head, 2)
            previous = words[-1] if words else None
            if len(words) == 2:
                before2 = words[0]

        best = {}

        def add(candidates, bonus, lang, prefix=""):
            store = stores[lang]
            for word, score in candidates:
                word = prefix + word
                if word == lower:
                    continue
                score += bonus
                if previous is not None:
                    score += store.bigram_bonus(previous, word, before2)
                score += field.bonus(word)
                if score > best.get(word, -1):
                    best[word] = score

        for lang in self.ordered:
            store = stores[lang]
            bonus = language_bonus(lang)
            add(store.completion_candidates(key, lower, 8, ends_with_apostrophe), bonus, lang)
            split = split_elision(lower, lang)
            if split:
                elision_head, tail = split
                if not tail:
                    letters = set("aeiouyhàâéèêîôû") if lang == "fr" else set("aeiouhàèéìòù")
                    add(store.frequent_words(letters, 6), bonus, lang, elision_head + "'")
                else:
                    add(store.completion_candidates(match_key(tail), tail, 6), bonus, lang, elision_head + "'")

        if not ends_with_apostrophe and len(key) >= 3:
            for lang in self.ordered:
                add(stores[lang].fuzzy_completion_candidates(key, 4), language_bonus(lang), lang)

        if not ends_with_apostrophe:
            for word in field.counts:
                if word != lower and len(word) > len(lower):
                    word_key = match_key(word)
                    if word_key and word_key.startswith(key):
                        score = 0.40 + field.bonus(word)
                        if score > best.get(word, -1):
                            best[word] = score

        if not ends_with_apostrophe and len(key) >= 3:
            known = any(stores[lang].contains(key) for lang in self.ordered) or field.uses(lower)
            if not known:
                for lang in self.ordered:
                    add(stores[lang].fuzzy_candidates(key, 4), language_bonus(lang), lang)

        ranked = sorted(best.items(), key=lambda kv: (-kv[1], kv[0]))
        return [w for w, _ in ranked[:limit]]

    def on_space(self, before, typed):
        """What ends up in the text when the word is finished with space: Predictor.autoFix, else as typed."""
        field = FieldContext(before)
        lower = normalize_apostrophes(typed).lower()
        if len(lower) < 2 or field.uses(lower, 2):
            return lower
        weights = context_weights(before, typed, self.stores)
        best = None
        for lang in self.ordered:
            store = self.stores[lang]
            fix = None
            if lang == "en" and lower in ENGLISH_APOSTROPHES:
                fix = (ENGLISH_APOSTROPHES[lower], 0.8)
            else:
                check = store.spelling_check(lower)
                if check[0] == "keep":
                    return lower
                if check[0] == "fix":
                    fix = (check[1], check[2])
            if fix is None:
                continue
            score = fix[1] + 0.5 * weights.get(lang, 0) + (0.08 if lang == self.active else 0)
            if best is None or score > best[1]:
                best = (fix[0], score)
        return best[0] if best else lower

    def next_words(self, before, limit=3):
        """Predictor.nextWords; `before` ends with a space."""
        if not before.endswith(" "):
            return []
        field = FieldContext(before)
        stores = self.stores
        wide = limit * 2
        weights = context_weights(before, "", stores)
        languages = [self.active]
        foreign = [kv for kv in weights.items() if kv[0] != self.active and kv[1] >= 0.5]
        if foreign:
            languages.insert(0, max(foreign, key=lambda kv: kv[1])[0])
        dominant = field.dominant(self.active, stores)
        if dominant is not None and dominant != self.active and dominant not in languages:
            languages.insert(0, dominant)

        result = []
        if is_sentence_start(before):
            for lang in languages:
                for word in stores[lang].sentence_starters(limit):
                    if word not in result:
                        result.append(word)
            return result[:limit]

        trimmed = before.rstrip(" ")
        if not trimmed or not is_word_char(trimmed[-1]):
            return []
        words = last_words(trimmed, 2)
        if not words:
            return []
        previous = words[-1]
        before_previous = words[0] if len(words) == 2 else None
        previous_owners = owners(previous, stores)
        if self.active not in previous_owners:
            for lang in self.enabled:
                if lang in previous_owners and lang not in languages and lang in stores:
                    languages.insert(0, lang)
        for lang in languages:
            for word in stores[lang].next_words(previous, before_previous, wide):
                if word != previous and word not in result:
                    result.append(word)
        if len(result) < wide:
            for word, _ in stores[self.active].frequent_words(None, 12):
                if len(result) < wide and word != previous and len(word) >= 2 and word not in result:
                    result.append(word)

        scored = []
        for index, word in enumerate(result):
            scored.append((word, 1.0 - 0.06 * index + 1.2 * field.bonus(word)))
        for word, n in field.counts.items():
            if n >= 2 and len(word) >= 3 and word != previous and word not in result:
                scored.append((word, 0.35 + field.bonus(word)))
        order = {w: i for i, (w, _) in enumerate(scored)}
        scored.sort(key=lambda ws: (-ws[1], order[ws[0]]))
        return [w for w, _ in scored[:limit]]

    # -- swiping ------------------------------------------------------------------------------------------------

    def swipe(self, before, path, limit=4):
        """KeyboardViewController.makeSwipeContext + SwipeDecoder.decode."""
        stores = self.stores
        previous = None
        if not before or before[-1] in " \n":
            found = last_words(before, 1)
            previous = found[0] if found else None
        before2 = last_words(before, 2)
        field = FieldContext(before)
        weights = context_weights(before, "", stores)
        dominant = field.dominant(self.active, stores)
        foreign = dominant if dominant is not None and dominant != self.active else None
        field_bonuses = {w: field.bonus(w) for w in field.counts}

        def likelihood(lang):
            value = 0.5 * weights.get(lang, 0)
            if lang == self.active:
                value += 0.12 if foreign is None else 0.04
            if lang == foreign:
                value += 0.40
            return value

        best = max(likelihood(lang) for lang in self.ordered)
        sources = []
        for lang in self.ordered:
            store = stores[lang]
            bonuses = {}
            if previous is not None:
                bonuses = store.context_bonuses(previous, before2[0] if lang == self.active and len(before2) > 1 else None)
            sources.append((store, min(0.7, 1.1 * (best - likelihood(lang))), bonuses, field_bonuses))
        layout = stores[self.active].layout
        return decode_swipe(path, layout.centers, layout.key_width, sources, limit)


# ---------------------------------------------------------------------------------------------------------------
# SwipeDecoder
# ---------------------------------------------------------------------------------------------------------------

SAMPLES = 32


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def path_length(points):
    return sum(dist(points[i - 1], points[i]) for i in range(1, len(points)))


def thinned(points, step):
    last = points[0]
    result = [last]
    for p in points[1:]:
        if dist(p, last) >= step:
            result.append(p)
            last = p
    if dist(points[-1], result[-1]) > 0:
        result.append(points[-1])
    return result


def resample(points, n):
    total = path_length(points)
    if len(points) < 2 or total <= 0:
        return [points[0]] * n
    step = total / (n - 1)
    result = [points[0]]
    working = list(points)
    accumulated = 0.0
    i = 1
    while i < len(working):
        a, b = working[i - 1], working[i]
        segment = dist(a, b)
        if segment > 0 and accumulated + segment >= step:
            t = (step - accumulated) / segment
            q = (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]))
            result.append(q)
            working.insert(i, q)
            accumulated = 0.0
        else:
            accumulated += segment
        i += 1
    while len(result) < n:
        result.append(points[-1])
    return result[:n]


def distance_to_polyline(p, line):
    best = INF
    for i in range(1, len(line)):
        a, b = line[i - 1], line[i]
        dx, dy = b[0] - a[0], b[1] - a[1]
        length_sq = dx * dx + dy * dy
        t = 0.0
        if length_sq > 0:
            t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / length_sq))
        best = min(best, math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy)))
    return best


def nearest_keys(point, centers, within, count):
    ranked = sorted(((dist(point, c), k) for k, c in centers.items()), key=lambda dk: dk[0])
    return [k for d, k in ranked if d <= within][:count]


def decode_swipe(raw_path, centers, key_width, sources, limit):
    path = thinned(raw_path, 2)
    if len(path) < 2:
        return []
    start, end = path[0], path[-1]
    start_keys = nearest_keys(start, centers, key_width * 1.9, 5)
    end_keys = nearest_keys(end, centers, key_width * 1.9, 5)
    if not start_keys or not end_keys:
        return []
    total = path_length(path)
    sampled = resample(path, SAMPLES)
    near_keys = {k for k, c in centers.items() if any(dist(p, c) <= key_width * 1.9 for p in sampled)}

    scored = []
    seen = set()
    for store, penalty, context, field_bonuses in sources:
        layout = store.layout
        # The source's own layout maps letters to keys; positions come from the keyboard on screen.
        for f in start_keys:
            for l in end_keys:
                for index in store.edges.get(f + l, ()):
                    entry = store.entries[index]
                    if entry.word in seen:
                        continue
                    template = []
                    previous = None
                    ok = True
                    for ch in entry.word:
                        if not ch.isalpha():
                            continue
                        k = layout.key_letter(ch)
                        if k is None or k not in near_keys:
                            ok = False
                            break
                        if k == previous:
                            continue
                        previous = k
                        center = centers.get(k)
                        if center is None:
                            ok = False
                            break
                        template.append(center)
                    if not ok or len(template) < 2:
                        continue
                    start_miss = dist(start, template[0]) / key_width
                    end_miss = dist(end, template[-1]) / key_width
                    if start_miss > 1.9 or end_miss > 1.9:
                        continue
                    template_length = path_length(template)
                    if template_length <= key_width * 0.5:
                        continue
                    ratio = total / template_length
                    if ratio < 0.45 or ratio > 2.8:
                        continue
                    sampled_template = resample(template, SAMPLES)
                    shape = sum(min(dist(sampled[i], sampled_template[i]), key_width * 2.5) for i in range(SAMPLES))
                    shape /= SAMPLES * key_width
                    if shape > 1.8:
                        continue
                    coverage = 0.0
                    worst = 0.0
                    for center in template:
                        miss = min(dist(p, center) for p in sampled) / key_width
                        coverage += min(miss, 2)
                        worst = max(worst, miss)
                    coverage /= len(template)
                    if worst > 1.9:
                        continue
                    excess = sum(min(distance_to_polyline(p, template), key_width * 2.5) for p in sampled)
                    excess /= SAMPLES * key_width
                    cost = (0.45 * shape + 0.40 * coverage + 0.35 * excess + 0.50 * (start_miss + end_miss)
                            + 0.35 * max(0, worst - 0.9) + penalty)
                    score = cost - 0.55 * entry.norm - 0.8 * context.get(entry.word, 0) - 0.9 * field_bonuses.get(entry.word, 0)
                    seen.add(entry.word)
                    scored.append((score, entry.word))
    scored.sort(key=lambda sw: sw[0])
    return [w for _, w in scored[:limit]]
