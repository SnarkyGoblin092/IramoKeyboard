"""Restores accents on words the dictionary does not have ("unokadbol" -> "unokádból").

For every letter that can carry an accent the keyboard has no key for (Hungarian a/á, o/ó/ö/ő, u/ú/ü/ű ...), the
letters around it decide which form is right. The model is learned from the language's full word list (every form
seen at least three times in subtitles, far more than the dictionary keeps): for a window of the accent-free word
around the letter, the most common accented form. Lookups back off from the widest window (3 letters each side) to
narrower ones; a window is stored only when it decides differently from the narrower one, so the file stays small.

accents_<lang>.bin (little-endian), read by Keyboard/AccentModel.swift:
    "HKAC", u32 version, u32 windows N, u32 text bytes B
    N records of 12 bytes, sorted by window (UTF-8 byte order): u32 offset, u32 length, u32 letter (Unicode scalar)
    B bytes of UTF-8: the windows, "<left>|<letter>|<right>" of the accent-free word, "^" / "$" marking its ends
"""

import collections
import math
import struct
import unicodedata

RADII = (3, 2, 1, 0)
CONFIDENCE = 0.75      # a window restores an accent only when that form has this share of its occurrences


# Letters that do not decompose into a base letter and an accent (TextFolding.special in Swift).
SPECIAL = {"ł": "l", "ø": "o", "đ": "d"}


def fold_letter(ch):
    if ch in SPECIAL:
        return SPECIAL[ch]
    decomposed = unicodedata.normalize("NFD", ch)
    base = "".join(c for c in decomposed if unicodedata.category(c) != "Mn")
    return base if len(base) == 1 else None


def accented_letters(alphabet_letters, key_letters):
    """folded letter -> its forms the user cannot type directly (the folded letter itself included)."""
    groups = collections.defaultdict(set)
    for letter in alphabet_letters:
        base = fold_letter(letter)
        if base is None or base == letter or letter in key_letters:
            continue
        groups[base].update({base, letter})
    return {base: forms for base, forms in groups.items() if len(forms) > 1}


def window(folded, i, radius):
    padded_left = ("^" + folded[:i])[-radius:] if radius else ""
    padded_right = (folded[i + 1:] + "$")[:radius] if radius else ""
    return f"{padded_left}|{folded[i]}|{padded_right}"


class AccentModel:
    def __init__(self, table, groups):
        self.table = table          # window -> letter
        self.groups = groups

    def restore(self, folded):
        """The accented form of an accent-free word (unchanged letters where nothing is known)."""
        out = []
        for i, ch in enumerate(folded):
            if self.groups is not None and ch not in self.groups:
                out.append(ch)
                continue
            choice = ch
            for radius in RADII:
                found = self.table.get(window(folded, i, radius))
                if found is not None:
                    choice = found
                    break
            out.append(choice)
        return "".join(out)


def train(counts, groups, confidence=CONFIDENCE):
    """counts: word -> count (lower case, accented). Returns the pruned window table: window -> the letter to
    write there (the accent-free letter itself where the window is not sure enough, so narrower windows do not
    overrule it)."""
    stats = {radius: collections.defaultdict(collections.Counter) for radius in RADII}
    for word, count in counts.items():
        folded_letters = []
        for ch in word:
            base = fold_letter(ch)
            folded_letters.append(base if base is not None and base in groups and ch in groups[base] else ch)
        folded = "".join(folded_letters)
        if folded == word and not any(c in groups for c in word):
            continue
        weight = math.log(1 + count)
        for i, ch in enumerate(word):
            base = folded[i]
            if base not in groups:
                continue
            for radius in RADII:
                stats[radius][window(folded, i, radius)][ch] += weight

    table = {}
    # Narrowest first, so a wider window is kept only when it changes the decision.
    for radius in reversed(RADII):
        for key, forms in stats[radius].items():
            best, weight = forms.most_common(1)[0]
            left, middle, right = key.split("|")
            if weight < confidence * sum(forms.values()):
                best = middle
            # What the narrower windows would decide for this position.
            decided = middle
            for r in RADII:
                if r >= radius:
                    continue
                narrower_key = f"{left[-r:] if r else ''}|{middle}|{right[:r] if r else ''}"
                if narrower_key in table:
                    decided = table[narrower_key]
                    break
            if best != decided:
                table[key] = best
    return table


def write(path, table):
    keys = sorted(table, key=lambda k: k.encode("utf-8"))
    text = bytearray()
    records = bytearray()
    for key in keys:
        encoded = key.encode("utf-8")
        records += struct.pack("<III", len(text), len(encoded), ord(table[key]))
        text += encoded
    with open(path, "wb") as out:
        out.write(b"HKAC")
        out.write(struct.pack("<3I", 1, len(keys), len(text)))
        out.write(records)
        out.write(bytes(text))


def read(path):
    """The model written by `write` (every letter is looked up, as in the keyboard)."""
    raw = open(path, "rb").read()
    assert raw[:4] == b"HKAC"
    _, n, size = struct.unpack_from("<3I", raw, 4)
    text = raw[16 + 12 * n:]
    table = {}
    for i in range(n):
        offset, length, letter = struct.unpack_from("<3I", raw, 16 + 12 * i)
        table[text[offset:offset + length].decode("utf-8")] = chr(letter)
    return AccentModel(table, None)
