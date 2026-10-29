"""The keyboard's dictionary as one memory-mapped file, dict_<lang>.bin (read by Keyboard/Lexicon.swift).

Memory-mapped pages are not the keyboard's own memory, so the dictionaries can be large (and every enabled language
loaded in full) without the extension running into iOS's memory limit.

Layout (little-endian):
    "HKDX", u32 version, u32 words N, u32 edge keys E, u32 text bytes B, u32 edge entries L, f64 total count
    N records of 20 bytes, sorted by match key (code point order) then by count, most common first:
        u32 word offset, u32 key offset (into the text), u32 count, u32 rank (line in words_<lang>.tsv, which is
        the language model's word id - 3), u8 word bytes, u8 key bytes, u8 capitals (0 / 1 Title / 2 ALLCAPS),
        u8 key length in characters
    u32 by_rank[N]              record index of each rank
    E edge keys of 12 bytes:    u32 first key letter, u32 last key letter (Unicode scalars), u32 start
    u32 edge_entries[L + 1]     record indices, grouped by edge key (start[e] ..< start[e + 1]; a final end)
    B bytes of UTF-8 text
"""

import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "predict_eval"))
from keyboard import Layout  # noqa: E402

CAPITALS = {"": 0, "T": 1, "U": 2}


def write(path, lang, words, capitals):
    """`words`: [(word, key, count)] in frequency order (rank = position)."""
    layout = Layout(lang)
    order = sorted(range(len(words)), key=lambda i: (words[i][1], -words[i][2]))
    text = bytearray()
    offsets = {}

    def place(s):
        if s not in offsets:
            offsets[s] = len(text)
            text.extend(s.encode("utf-8"))
        return offsets[s]

    records = bytearray()
    by_rank = [0] * len(words)
    edges = {}
    for index, rank in enumerate(order):
        word, key, count = words[rank]
        word_bytes, key_bytes = word.encode("utf-8"), key.encode("utf-8")
        if len(word_bytes) > 255 or len(key_bytes) > 255:
            raise ValueError(f"word too long: {word}")
        records += struct.pack("<IIIIBBBB", place(word), place(key), min(count, 0xFFFFFFFF), rank,
                               len(word_bytes), len(key_bytes), CAPITALS[capitals.get(word, "")], min(len(key), 255))
        by_rank[rank] = index
        letters = [k for k in (layout.key_letter(c) for c in word) if k is not None]
        if len(letters) >= 2:
            edges.setdefault((ord(letters[0]), ord(letters[-1])), []).append(index)

    edge_keys = sorted(edges)
    starts, entries = [], []
    for edge in edge_keys:
        starts.append(len(entries))
        entries += edges[edge]
    total = float(sum(count for _, _, count in words))
    with open(path, "wb") as out:
        out.write(b"HKDX")
        out.write(struct.pack("<5I", 1, len(words), len(edge_keys), len(text), len(entries)))
        out.write(struct.pack("<d", total))
        out.write(records)
        out.write(struct.pack(f"<{len(words)}I", *by_rank))
        for (first, last), start in zip(edge_keys, starts):
            out.write(struct.pack("<3I", first, last, start))
        out.write(struct.pack(f"<{len(entries) + 1}I", *entries, len(entries)))
        out.write(bytes(text))
