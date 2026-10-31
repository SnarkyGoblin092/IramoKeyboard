"""Keyboard geometry, text folding and simulated typing / swiping for the prediction tests.

Mirrors the Swift side: `letterRows` in Keyboard/Layouts.swift, `TextFolding` and `WordStore.keyLetter` in
Keyboard/WordStore.swift. Positions are in points of a 390 pt wide iPhone keyboard.
"""

import math
import random
import unicodedata

LETTER_ROWS = {
    "en": ["qwertyuiop", "asdfghjkl", "zxcvbnm"],
    "it": ["qwertyuiop", "asdfghjkl", "zxcvbnm"],
    "hu": ["qwertzuiop", "asdfghjkl", "yxcvbnm"],
    "cs": ["qwertzuiop", "asdfghjkl", "yxcvbnm"],
    "es": ["qwertyuiop", "asdfghjklñ", "zxcvbnm"],
    "fr": ["azertyuiop", "qsdfghjklm", "wxcvbn"],
    "de": ["qwertzuiopü", "asdfghjklöä", "yxcvbnm"],
    "pt": ["qwertyuiop", "asdfghjklç", "zxcvbnm"],
    "nl": ["qwertyuiop", "asdfghjkl", "zxcvbnm"],
    "pl": ["qwertyuiop", "asdfghjkl", "zxcvbnm"],
    "ro": ["qwertyuiop", "asdfghjkl", "zxcvbnm"],
    "tr": ["qwertyuıopğü", "asdfghjklşi", "zxcvbnmöç"],
    "ru": ["йцукенгшщзхъ", "фывапролджэ", "ячсмитьбю"],
    "uk": ["йцукенгшщзхї", "фівапролджє", "ячсмитьбюґ"],
    "sv": ["qwertyuiopå", "asdfghjklöä", "zxcvbnm"],
    "lt": ["qwertyuiop", "asdfghjkl", "zxcvbnm"],
    "ar": ["ضصثقفغعهخحجد", "شسيبلاتنمكط", "ذئءؤرىةوزظ"],
}

KEYBOARD_WIDTH = 390.0
ROW_PITCH = 54.0     # key height plus the gap between rows

SPECIAL_FOLDS = {"ł": "l", "đ": "d", "ø": "o", "ß": "ss", "æ": "ae", "œ": "oe", "ı": "i", "ð": "d", "þ": "th"}
APOSTROPHES = "'’ʼ‘"


def fold(text: str) -> str:
    """Lower-case and strip accents ("Szép" -> "szep"). Same as TextFolding.fold."""
    decomposed = unicodedata.normalize("NFD", text.lower())
    return "".join(SPECIAL_FOLDS.get(c, c) for c in decomposed if unicodedata.category(c) != "Mn")


def key(text: str) -> str:
    """The match key: folded, without apostrophes. Same as TextFolding.key."""
    return "".join(c for c in fold(text) if c not in APOSTROPHES)


def normalize_apostrophes(text: str) -> str:
    return "".join("'" if c in APOSTROPHES else c for c in text)


class Layout:
    def __init__(self, lang: str):
        self.lang = lang
        rows = LETTER_ROWS[lang]
        longest = max(len(row) for row in rows)
        self.key_width = KEYBOARD_WIDTH / longest
        self.key_size = (self.key_width, ROW_PITCH)
        self.centers = {}
        for r, row in enumerate(rows):
            left = (KEYBOARD_WIDTH - len(row) * self.key_width) / 2
            for c, letter in enumerate(row):
                self.centers[letter] = (left + (c + 0.5) * self.key_width, (r + 0.5) * ROW_PITCH)
        self.letters = set(self.centers)
        self._memo = {}
        # Keys next to each other (same as WordStore.neighborMap), on folded letters.
        folded_rows = [[fold(ch)[0] for ch in row] for row in rows]
        self.neighbors = {}
        for r, row in enumerate(folded_rows):
            for c, letter in enumerate(row):
                near = self.neighbors.setdefault(letter, set())
                if c > 0:
                    near.add(row[c - 1])
                if c + 1 < len(row):
                    near.add(row[c + 1])
                for other in (r - 1, r + 1):
                    if 0 <= other < len(folded_rows):
                        for d in (-1, 0, 1):
                            k = c + d
                            if 0 <= k < len(folded_rows[other]):
                                near.add(folded_rows[other][k])

    def key_letter(self, ch: str):
        """The key a character is typed on ("é" -> "e" in Hungarian, "ö" stays "ö" in German), or None."""
        if ch in self._memo:
            return self._memo[ch]
        result = None
        if ch in self.letters:
            result = ch
        else:
            folded = fold(ch)
            if folded and folded[0] in self.letters:
                result = folded[0]
        self._memo[ch] = result
        return result

    def nearest(self, x: float, y: float) -> str:
        best, best_d = None, float("inf")
        for letter, (cx, cy) in self.centers.items():
            d = (x - cx) ** 2 + (y - cy) ** 2
            if d < best_d:
                best, best_d = letter, d
        return best


def tap_word(word: str, layout: Layout, rng: random.Random, sigma: float) -> str:
    return tap_word_points(word, layout, rng, sigma)[0]


def tap_word_points(word: str, layout: Layout, rng: random.Random, sigma: float):
    """tap_word, plus where each tap landed (None for characters typed without a letter key)."""
    letters, points = [], []
    for ch in word:
        letter = layout.key_letter(ch)
        if letter is None:
            letters.append(ch)
            points.append(None)
            continue
        cx, cy = layout.centers[letter]
        x = cx + rng.gauss(0, sigma * layout.key_width)
        y = cy + rng.gauss(0, sigma * layout.key_width)
        letters.append(layout.nearest(x, y))
        points.append((x, y))
    return "".join(letters), points


def swipe_path(word: str, layout: Layout, rng: random.Random, sigma: float):
    """A finger path for `word`: through its letters' keys (each aimed with scatter), corners rounded off."""
    points = []
    previous = None
    for ch in word:
        letter = layout.key_letter(ch)
        if letter is None or letter == previous:
            continue
        previous = letter
        cx, cy = layout.centers[letter]
        points.append((cx + rng.gauss(0, sigma * layout.key_width), cy + rng.gauss(0, sigma * layout.key_width)))
    if len(points) < 2:
        return None
    # Dense polyline, then a moving average: a real finger cuts corners instead of stopping on each key.
    dense = []
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        steps = max(1, int(math.hypot(bx - ax, by - ay) / 3))
        for i in range(steps):
            t = i / steps
            dense.append((ax + t * (bx - ax), ay + t * (by - ay)))
    dense.append(points[-1])
    window = 4
    smooth = []
    for i in range(len(dense)):
        lo, hi = max(0, i - window), min(len(dense), i + window + 1)
        smooth.append((sum(p[0] for p in dense[lo:hi]) / (hi - lo), sum(p[1] for p in dense[lo:hi]) / (hi - lo)))
    smooth[0], smooth[-1] = points[0], points[-1]
    return smooth
