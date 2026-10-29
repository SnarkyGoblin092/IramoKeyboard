"""Reads lm_<lang>.bin (see scripts/language_model.py) and answers the questions the keyboard asks it."""

import math
import re
import struct
from pathlib import Path

from keyboard import normalize_apostrophes

START, UNKNOWN, COMMA, FIRST_WORD = 0, 1, 2, 3
TOKENS = re.compile(r"[^\W\d_]+(?:['’][^\W\d_]+)*|[.!?…]+|,|\S")
LN10 = math.log(10)


def _ids24(raw):
    return [raw[i] | (raw[i + 1] << 8) | (raw[i + 2] << 16) for i in range(0, len(raw), 3)]


class LanguageModel:
    def __init__(self, lang, data_dir: Path):
        self.lang = lang
        self.words = ["<s>", "<unk>", ","]
        with open(data_dir / f"words_{lang}.tsv", encoding="utf-8") as handle:
            for line in handle:
                self.words.append(normalize_apostrophes(line.split("\t", 1)[0]))
        self.ids = {w: i for i, w in enumerate(self.words) if i >= COMMA}
        raw = (data_dir / f"lm_{lang}.bin").read_bytes()
        assert raw[:4] == b"HKLM"
        _, vocabulary, nb, nt = struct.unpack_from("<4I", raw, 4)
        p_min, p_step, b_min, b_step = struct.unpack_from("<4f", raw, 20)
        offset = 36

        def take(n):
            nonlocal offset
            chunk = raw[offset:offset + n]
            offset += n
            return chunk

        def logs(chunk, low, step):
            return [low + c * step for c in chunk]

        self.p1 = logs(take(vocabulary), p_min, p_step)
        self.bo1 = logs(take(vocabulary), b_min, b_step)
        self.start = list(struct.unpack(f"<{vocabulary + 1}I", take(4 * (vocabulary + 1))))
        self.next2 = _ids24(take(3 * nb))
        self.p2 = logs(take(nb), p_min, p_step)
        self.bo2 = logs(take(nb), b_min, b_step)
        context = struct.unpack(f"<{nt}I", take(4 * nt))
        self.next3 = _ids24(take(3 * nt))
        self.p3 = logs(take(nt), p_min, p_step)
        assert len(self.words) == vocabulary, (len(self.words), vocabulary)
        # bigram entry -> (first, end) of its trigrams
        self.tri_range = {}
        for i, c in enumerate(context):
            first, _ = self.tri_range.get(c, (i, i))
            self.tri_range[c] = (first, i + 1)
        self.bigram_index = {}
        for v in range(vocabulary):
            for i in range(self.start[v], self.start[v + 1]):
                self.bigram_index[(v, self.next2[i])] = i
        self.by_unigram = sorted(range(FIRST_WORD, vocabulary), key=lambda i: -self.p1[i])[:2000]

    # -- context ----------------------------------------------------------------------------------------------

    def lower(self, text):
        if self.lang == "tr":
            text = text.replace("I", "ı").replace("İ", "i")
        return text.lower()

    def context(self, before):
        """The ids of the text's current sentence, START first."""
        ids = [START]
        for token in TOKENS.findall(self.lower(before[-300:])):
            if token == ",":
                if ids[-1] != COMMA and len(ids) > 1:
                    ids.append(COMMA)
            elif re.match(r"^[.!?…]+$", token):
                ids = [START]
            elif token[0].isalpha():
                ids.append(self.ids.get(normalize_apostrophes(token), UNKNOWN))
        return ids

    # -- probabilities (log10) --------------------------------------------------------------------------------

    def logp(self, w, v, u=None):
        """log10 P(w | u v); u None = bigram context only."""
        b = self.bigram_index.get((v, w))
        if u is not None:
            uv = self.bigram_index.get((u, v))
            if uv is not None:
                rng = self.tri_range.get(uv)
                if rng is not None:
                    for i in range(rng[0], rng[1]):
                        if self.next3[i] == w:
                            return self.p3[i]
                bo = self.bo2[uv]
            else:
                bo = 0.0
            return bo + (self.p2[b] if b is not None else self.bo1[v] + self.p1[w])
        return self.p2[b] if b is not None else self.bo1[v] + self.p1[w]

    def word_logp(self, word, history):
        """log10 P(word | history ids); unknown words get <unk>'s tiny probability."""
        w = self.ids.get(word, UNKNOWN)
        v = history[-1]
        u = history[-2] if len(history) >= 2 else None
        return self.logp(w, v, u)

    def candidates(self, history):
        """Word ids worth scoring as the next word: stored continuations plus the most common words."""
        v = history[-1]
        u = history[-2] if len(history) >= 2 else None
        result = set(self.next2[self.start[v]:self.start[v + 1]])
        if u is not None:
            uv = self.bigram_index.get((u, v))
            if uv is not None and uv in self.tri_range:
                first, end = self.tri_range[uv]
                result.update(self.next3[first:end])
        result.update(self.by_unigram[:200])
        result.discard(START)
        result.discard(UNKNOWN)
        return result

    def next_words(self, history, limit):
        v = history[-1]
        u = history[-2] if len(history) >= 2 else None
        scored = [(self.logp(w, v, u), w) for w in self.candidates(history) if w != COMMA]
        scored.sort(reverse=True)
        return [(self.words[w], p) for p, w in scored[:limit]]


class Mixture:
    """Several languages' models; the language of the text is inferred from how well each model explains it."""

    def __init__(self, models, active):
        self.models = models
        self.active = active

    def language_weights(self, before):
        """P(language | recent words): each model's likelihood of the last few words, a small prior for the layout."""
        scores = {}
        for lang, model in self.models.items():
            ids = model.context(before)
            history = [START]
            total = math.log10(1.5) if lang == self.active else 0.0
            for w in ids[1:][-8:]:
                total += model.logp(w, history[-1], history[-2] if len(history) >= 2 else None)
                history.append(w)
            scores[lang] = total
        top = max(scores.values())
        weights = {lang: 10 ** (s - top) for lang, s in scores.items()}
        norm = sum(weights.values())
        return {lang: w / norm for lang, w in weights.items()}

    def next_words(self, before, limit):
        weights = self.language_weights(before)
        combined = {}
        for lang, model in self.models.items():
            history = model.context(before)
            for word, logp in model.next_words(history, limit * 4):
                combined[word] = combined.get(word, 0.0) + weights[lang] * 10 ** logp
        ranked = sorted(combined.items(), key=lambda kv: -kv[1])
        return [w for w, _ in ranked[:limit]]
