"""Word trigram language model for the keyboard: counts, smoothing, pruning and the binary file it ships as.

Trained on the start of each language's OpenSubtitles text (conversational, like the word lists) plus the
Tatoeba sentences not held out for testing. Word ids are line numbers in words_<lang>.tsv (most common first),
so the model and the dictionary always agree. A comma is a word of its own ("..., hogy" is very likely);
sentence ends reset the context to <s>.

Smoothing is interpolated absolute discounting (Kneser-Ney without continuation counts, which lossy counting
would distort), written in backoff form like an ARPA file, so the keyboard needs no more than:

    P(w | u v) = p3(u v w)              if stored
               = bo2(u v) * P(w | v)    otherwise
    P(w | v)   = p2(v w)                if stored
               = bo1(v) * p1(w)         otherwise

File layout (little-endian), lm_<lang>.bin:
    "HKLM", u32 version, u32 V, u32 bigrams, u32 trigrams
    f32 probability min, f32 step, f32 backoff min, f32 step        (log10 values, 8-bit codes)
    u8  p1[V]           unigram log10 probability codes
    u8  bo1[V]          unigram-context backoff codes
    u32 start[V + 1]    bigrams of context v are entries start[v] ..< start[v + 1]
    u8  next[3 * B]     24-bit word ids, sorted within each context
    u8  p2[B], bo2[B]
    u32 context[T]      bigram entry index of each trigram (sorted)
    u8  next3[3 * T]    24-bit word ids, sorted within each context
    u8  p3[T]
"""

import collections
import gzip
import math
import os
import re
import struct

START, UNKNOWN, COMMA = 0, 1, 2
FIRST_WORD = 3
SHIFT = 18                       # ids are below 2^18 (the largest dictionary has 160k words)
MASK = (1 << SHIFT) - 1

# A letter, or a mark that combines with the letter before it (Python's \w has no marks, which would cut "नहीं"
# into "नह", "ी", "ं"): accents, Hebrew points, Arabic vowel marks, Devanagari vowel signs, Thai vowels and tones.
MARKS = "̀-֑ͯ-ׇؐ-ًؚ-ٰٟۖ-ۭऀ-ःऺ-ॏ" \
        "॑-ॗॢॣัิ-ฺ็-๎"
WORD = rf"[^\W\d_](?:[^\W\d_]|[{MARKS}])*"
# Sentence ends include the Devanagari dandas (। ॥) and the Arabic question mark (؟).
TOKENS = re.compile(rf"{WORD}(?:['’]{WORD})*|[.!?…।॥؟]+|,|\S")
SENTENCE_END = re.compile(r"^[.!?…।॥؟]+$")

# How much text and how big the model may get (the app ships every language).
SUBTITLE_BYTES = int(os.environ.get("HUNKEYS_SUBTITLE_BYTES", 60_000_000))   # compressed bytes read from the start of the subtitles file (~25M words)
MAX_BIGRAMS = int(os.environ.get("HUNKEYS_MAX_BIGRAMS", 700_000))
MAX_TRIGRAMS = int(os.environ.get("HUNKEYS_MAX_TRIGRAMS", 350_000))
MIN_COUNT = 2
DISCOUNT2 = 0.75
DISCOUNT3 = 0.80
PRUNE_AT = 8_000_000             # trigram table size that triggers dropping rare entries while counting

P_MIN, P_STEP = -9.0, 9.0 / 255
B_MIN, B_STEP = -4.0, 5.0 / 255


class Counts:
    def __init__(self):
        self.bigrams = collections.Counter()
        self.trigrams = collections.Counter()
        self.tokens = 0
        self.floor = 0           # counts below this may have been dropped (lossy counting)

    def add_sentences(self, sentences):
        """Each sentence is a list of ids starting with START."""
        pairs = []
        triples = []
        for ids in sentences:
            if len(ids) < 2:
                continue
            self.tokens += len(ids) - 1
            pairs += [(a << SHIFT) | b for a, b in zip(ids, ids[1:])]
            if len(ids) >= 3:
                triples += [(a << (2 * SHIFT)) | (b << SHIFT) | c for a, b, c in zip(ids, ids[1:], ids[2:])]
        self.bigrams.update(pairs)
        self.trigrams.update(triples)
        if len(self.trigrams) > PRUNE_AT:
            self.floor += 1
            self.trigrams = collections.Counter({k: v for k, v in self.trigrams.items() if v > self.floor})


END = -1        # token class: ends the sentence
SKIP = -2       # token class: ignored (quotes, dashes, brackets)


LOWER, TITLE, UPPER = 0, 1, 2     # how a word is written


class Tokenizer:
    """Turns text into word ids, and counts how each word is capitalised where nothing else (a sentence or line
    start, a quote) would capitalise it: words written capitalised there nearly always are names, German nouns,
    English "I"... (see `capitals`)."""

    def __init__(self, vocabulary, lang, lower, repair):
        self.ids = vocabulary
        self.lang = lang
        self.lower = lower
        self.repair = repair
        self.memo = {",": (COMMA, LOWER)}
        self.case_counts = collections.Counter()    # (id, case) -> mid-sentence occurrences

    def classify(self, token):
        """(word id / COMMA / END / SKIP, case) for a token as written (remembered: most tokens repeat)."""
        case = LOWER
        if SENTENCE_END.match(token):
            kind = END
        elif token[0].isalpha():
            lowered = self.lower(token, self.lang)
            kind = self.ids.get(self.repair(lowered.replace("’", "'"), self.lang), UNKNOWN)
            letters = [c for c in token if c.isalpha()]
            if len(letters) >= 2 and all(c.isupper() for c in letters):
                case = UPPER
            elif token[0].isupper():
                case = TITLE
        else:
            kind = SKIP
        self.memo[token] = (kind, case)
        return kind, case

    def sentences(self, text, continued):
        """Splits a line into sentences of ids. `continued` is the open sentence from the line before (subtitles
        break sentences over lines); returns (finished sentences, open sentence)."""
        finished = []
        current = continued if continued is not None else [START]
        stripped = text.strip()
        if stripped.startswith("-") and len(current) > 1:    # a new speaker
            finished.append(current)
            current = [START]
        memo = self.memo
        cases = self.case_counts
        initial = True      # the line's first word, or the first after a sentence end or a quote / dash
        for token in TOKENS.findall(stripped):
            found = memo.get(token)
            kind, case = found if found is not None else self.classify(token)
            if kind >= FIRST_WORD or kind == UNKNOWN:
                if not initial and kind >= FIRST_WORD:
                    cases[(kind, case)] += 1
                initial = False
                current.append(kind)
            elif kind == COMMA:
                if current[-1] != COMMA and len(current) > 1:
                    current.append(COMMA)
            elif kind == END:
                finished.append(current)
                current = [START]
                initial = True
            else:
                initial = True
        return finished, current

    def capitals(self, words, min_count=4, share=0.8):
        """word -> "T" (Title) or "U" (ALLCAPS) for the words written that way at least `share` of the time in the
        middle of sentences (seen at least `min_count` times there)."""
        totals = collections.Counter()
        for (kind, _), n in self.case_counts.items():
            totals[kind] += n
        result = {}
        for kind, total in totals.items():
            if total < min_count:
                continue
            title = self.case_counts[(kind, TITLE)]
            upper = self.case_counts[(kind, UPPER)]
            if title + upper >= share * total:
                result[words[kind - FIRST_WORD]] = "U" if upper >= share * total else "T"
        return result


def count_text(counts, tokenizer, lines, fresh_lines=False):
    """Counts the n-grams of `lines`; `fresh_lines`: every line is a sentence of its own."""
    current = None
    batch = []
    for line in lines:
        finished, current = tokenizer.sentences(line, None if fresh_lines else current)
        batch += finished
        if fresh_lines:
            batch.append(current)
            current = None
        if len(batch) >= 50_000:
            counts.add_sentences(batch)
            batch = []
    if current is not None:
        batch.append(current)
    counts.add_sentences(batch)


def subtitle_lines(path):
    """Lines of a (possibly truncated) gzip file."""
    try:
        with gzip.open(path, "rt", encoding="utf-8", errors="ignore") as handle:
            for line in handle:
                yield line
    except (EOFError, OSError):
        return


def quantize(value, low, step):
    return max(0, min(255, int(round((value - low) / step))))


def build(counts, unigram_counts, path):
    """Smooths, prunes and writes the model. `unigram_counts[i]` is word id i's count in the full word list."""
    vocabulary_size = len(unigram_counts)

    # Unigrams from the full word lists (far more text than the sample); <s> and <unk> are never predicted.
    total = sum(unigram_counts) or 1
    p1 = [max(c, 0.5) / total for c in unigram_counts]
    p1[START] = p1[UNKNOWN] = 1e-9
    comma = sum(v for k, v in counts.bigrams.items() if k & MASK == COMMA)
    p1[COMMA] = max(comma, 1) / max(counts.tokens, 1)

    # Context totals and the number of distinct followers, from every counted n-gram.
    context1 = collections.Counter()
    followers1 = collections.Counter()
    for key, c in counts.bigrams.items():
        context1[key >> SHIFT] += c
        followers1[key >> SHIFT] += 1
    followers2 = collections.Counter()
    for key in counts.trigrams:
        followers2[key >> SHIFT] += 1

    def p2_interpolated(v, w, c):
        total_v = context1[v]
        if total_v == 0:
            return p1[w]
        return max(c - DISCOUNT2, 0) / total_v + DISCOUNT2 * followers1[v] / total_v * p1[w]

    # Keep the most frequent n-grams that fit the budget (and never predict <s> / <unk>).
    def kept(table, limit, ok):
        items = [(k, c) for k, c in table.items() if c >= max(MIN_COUNT, counts.floor + 1) and ok(k)]
        items.sort(key=lambda kc: -kc[1])
        return dict(items[:limit])

    bigrams = kept(counts.bigrams, MAX_BIGRAMS, lambda k: (k & MASK) >= COMMA and (k >> SHIFT) != UNKNOWN)
    trigrams = kept(counts.trigrams, MAX_TRIGRAMS,
                    lambda k: (k & MASK) >= COMMA and (k >> SHIFT) in bigrams)

    # Bigram probabilities and unigram-context backoffs.
    p2 = {k: p2_interpolated(k >> SHIFT, k & MASK, c) for k, c in bigrams.items()}
    kept_mass = collections.Counter()
    kept_lower = collections.Counter()
    for k, p in p2.items():
        kept_mass[k >> SHIFT] += p
        kept_lower[k >> SHIFT] += p1[k & MASK]
    bo1 = [1.0] * vocabulary_size
    for v in kept_mass:
        bo1[v] = max(1e-6, 1 - kept_mass[v]) / max(1e-6, 1 - kept_lower[v])

    def p2_backoff(v, w):
        p = p2.get((v << SHIFT) | w)
        return p if p is not None else bo1[v] * p1[w]

    # Trigram probabilities and bigram-context backoffs.
    p3 = {}
    mass3 = collections.Counter()
    lower3 = collections.Counter()
    for k, c in trigrams.items():
        uv, w = k >> SHIFT, k & MASK
        total_uv = counts.bigrams[uv]
        lower = p2_backoff(uv & MASK, w)
        p = max(c - DISCOUNT3, 0) / total_uv + DISCOUNT3 * followers2[uv] / total_uv * lower if total_uv else lower
        p3[k] = p
        mass3[uv] += p
        lower3[uv] += lower
    bo2 = {uv: max(1e-6, 1 - mass3[uv]) / max(1e-6, 1 - lower3[uv]) for uv in mass3}

    # Write.
    bigram_keys = sorted(p2)
    index_of = {k: i for i, k in enumerate(bigram_keys)}
    start = [0] * (vocabulary_size + 1)
    for k in bigram_keys:
        start[(k >> SHIFT) + 1] += 1
    for i in range(vocabulary_size):
        start[i + 1] += start[i]
    trigram_keys = sorted(p3, key=lambda k: (index_of[k >> SHIFT], k & MASK))

    def log10(x):
        return math.log10(max(x, 1e-12))

    def ids24(values):
        out = bytearray()
        for v in values:
            out += v.to_bytes(3, "little")
        return bytes(out)

    with open(path, "wb") as out:
        out.write(b"HKLM")
        out.write(struct.pack("<4I", 1, vocabulary_size, len(bigram_keys), len(trigram_keys)))
        out.write(struct.pack("<4f", P_MIN, P_STEP, B_MIN, B_STEP))
        out.write(bytes(quantize(log10(p), P_MIN, P_STEP) for p in p1))
        out.write(bytes(quantize(log10(b), B_MIN, B_STEP) for b in bo1))
        out.write(struct.pack(f"<{vocabulary_size + 1}I", *start))
        out.write(ids24(k & MASK for k in bigram_keys))
        out.write(bytes(quantize(log10(p2[k]), P_MIN, P_STEP) for k in bigram_keys))
        out.write(bytes(quantize(log10(bo2.get(k, 1.0)), B_MIN, B_STEP) for k in bigram_keys))
        out.write(struct.pack(f"<{len(trigram_keys)}I", *(index_of[k >> SHIFT] for k in trigram_keys)))
        out.write(ids24(k & MASK for k in trigram_keys))
        out.write(bytes(quantize(log10(p3[k]), P_MIN, P_STEP) for k in trigram_keys))
    return len(bigram_keys), len(trigram_keys)
