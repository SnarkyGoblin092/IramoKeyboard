"""Scores the keyboard's word prediction on held-out example sentences, with simulated sloppy typing and swiping.

    python3 scripts/predict_eval/run.py                          # every language on its own
    python3 scripts/predict_eval/run.py --mix hu,en              # Hungarian + English enabled, Hungarian layout
    python3 scripts/predict_eval/run.py --langs hu --sentences 50 --no-swipe
    python3 scripts/predict_eval/run.py --compare .eval/results/before.json

The dictionaries are rebuilt into .eval/data by scripts/build_data.py, which keeps one sentence in 20 out of the
word pairs (`is_held_out`); those sentences are the test set. Typing is simulated per letter: the finger lands
with Gaussian scatter (`--sigma`, in key widths) and the nearest key wins; accented letters are typed on their
base key. Set HUNKEYS_FIXTURES to a folder of already downloaded sources to work offline.

Metrics, per word of the test sentences:
  next      the word is among the 3 suggestions shown before typing it
  typed     after typing the whole word (with slips), it is in the bar (as typed, or one of the 2 suggestions)
  space     typing the whole word and pressing space leaves the right word (auto-correction / accents)
  clean     the same, only for words typed without a slip: never "correct" a right word into a wrong one
  slipped   the same, only for words typed with a slip: how many typos get repaired
  ksr       keystroke savings: share of taps saved by tapping a prediction as soon as it shows the word
  swipe1/3  a simulated swipe of the word gives it first / among the first 3
"""

import argparse
import hashlib
import importlib
import json
import multiprocessing
import os
import random
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(1, str(HERE))

from keyboard import Layout, normalize_apostrophes, swipe_path, tap_word_points, APOSTROPHES  # noqa: E402

EVAL_DIR = ROOT / ".eval"
DATA_DIR = EVAL_DIR / "data"
RESULTS_DIR = EVAL_DIR / "results"
ALL_LANGS = ["en", "hu", "es", "fr", "de", "it", "pt", "nl", "pl", "cs", "ro", "tr", "ru", "uk", "sv"]
TOKEN = re.compile(r"[^\W\d_]+(?:[" + APOSTROPHES + r"][^\W\d_]+)*")
METRICS = ["next", "typed", "space", "clean", "slipped", "ksr", "swipe1", "swipe3"]


# ---------------------------------------------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------------------------------------------

def prepare(langs):
    """Builds words_/pairs_<lang>.tsv into .eval/data, again whenever build_data.py changes."""
    os.environ["HUNKEYS_OUT"] = str(DATA_DIR)
    os.environ["HUNKEYS_TSV"] = "1"     # the engines read the text word lists
    import build_data
    build_data.OUT = DATA_DIR
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    stamp = hashlib.sha1(b"".join((ROOT / "scripts" / name).read_bytes()
                              for name in ("build_data.py", "language_model.py"))).hexdigest()
    stamp_file = DATA_DIR / "stamp"
    if not stamp_file.exists() or stamp_file.read_text() != stamp:
        for old in DATA_DIR.glob("*.tsv"):
            old.unlink()
        stamp_file.write_text(stamp)
    missing = [lang for lang in langs if not (DATA_DIR / f"words_{lang}.tsv").exists()]
    if not missing:
        return
    needed = sorted(set(missing) | {"en"} | ({"ru"} if "uk" in missing else set()))
    build_data.prefetch([f"{lang}_full.txt" for lang in needed] + [f"sentences_{lang}.tsv.bz2" for lang in needed]
                        + [f"subtitles_{lang}.txt.gz" for lang in needed])
    with multiprocessing.Pool(min(build_data.BUILD_PROCESSES, len(missing))) as pool:
        pool.map(_build_dictionary, missing, chunksize=1)


def _build_dictionary(lang):
    os.environ["HUNKEYS_OUT"] = str(DATA_DIR)
    import build_data
    build_data.OUT = DATA_DIR
    build_data.build_dictionary(lang)


def test_sentences(lang, count, tuning=False):
    """`count` held-out sentences of 3 to 20 words, the same ones on every run. `tuning`: a separate set, for
    choosing an engine's settings without fitting them to the test sentences."""
    import bz2
    import build_data
    path = build_data.fetch(f"sentences_{lang}.tsv.bz2")
    rows = []
    with bz2.open(path, "rt", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3 or not build_data.is_held_out(parts[0]):
                continue
            text = parts[2].strip()
            if any(ch.isdigit() for ch in text):
                continue
            words = TOKEN.findall(text)
            if 3 <= len(words) <= 20:
                rows.append((parts[0], text))
    random.Random(f"sentences-{lang}").shuffle(rows)
    return rows[-count:] if tuning else rows[:count]


# ---------------------------------------------------------------------------------------------------------------
# Scoring (runs in worker processes)
# ---------------------------------------------------------------------------------------------------------------

_engine = None
_layout = None
_options = None


def _init(engine_name, enabled, active, layout_lang, options):
    global _engine, _layout, _options
    module = importlib.import_module(engine_name)
    _engine = module.Engine(DATA_DIR, enabled, active)
    _layout = Layout(layout_lang)
    _options = options


def _target(token):
    return normalize_apostrophes(token).lower().strip("'")


def score_sentence(row):
    sentence_id, text = row
    engine, layout, sigma, swipe = _engine, _layout, _options["sigma"], _options["swipe"]
    totals = {m: [0, 0] for m in METRICS}
    keys_used = keys_full = 0
    misses = []
    for index, match in enumerate(TOKEN.finditer(text)):
        target = _target(match.group())
        if not target:
            continue
        before = text[:match.start()]
        rng = random.Random(f"{sentence_id}:{index}")
        typed, points = tap_word_points(target, layout, rng, sigma)
        # Engines that use where each tap landed get the positions (`--no-taps` hides them).
        give_taps = getattr(engine, "uses_taps", False) and not _options.get("no_taps")

        def taps(k=None):
            return {"taps": points[:k] if k is not None else points} if give_taps else {}
        slipped = typed != "".join(layout.key_letter(c) or c for c in target)
        exact = typed == target

        # Before typing: the next-word predictions.
        predicted = engine.next_words(before) if (not before or before.endswith(" ")) else []
        next_hit = target in predicted[:3]
        totals["next"][0] += next_hit
        totals["next"][1] += 1

        # While typing: the first prefix whose bar shows the word.
        shown_at = None
        if not next_hit:
            for k in range(1, len(typed)):
                if target in engine.suggest(before + typed[:k], typed[:k], **taps(k))[:2]:
                    shown_at = k
                    break

        # The whole word typed.
        bar = engine.suggest(before + typed, typed, **taps())[:2]
        in_bar = exact or target in bar
        totals["typed"][0] += in_bar
        totals["typed"][1] += 1
        committed = _target(engine.on_space(before + typed, typed, **taps()))
        right = committed == target
        if _options.get("learn"):
            # The keyboard learns what space committed; a wrong word is then fixed: an unwanted correction is
            # taken back with backspace (which teaches the typed spelling), anything else retyped.
            engine.learn(before, committed)
            if not right:
                engine.learn(before, target, explicit=(typed == target))
        totals["space"][0] += right
        totals["space"][1] += 1
        bucket = "slipped" if slipped else "clean"
        totals[bucket][0] += right
        totals[bucket][1] += 1

        # Keystrokes: a predicted word costs one tap (it adds the space), a typed one its letters plus space.
        full = len(target) + 1
        if next_hit:
            used = 1
        elif shown_at is not None:
            used = shown_at + 1
        else:
            used = len(typed) + 1
        keys_used += used
        keys_full += full

        if swipe and sum(1 for c in target if layout.key_letter(c)) >= 2:
            path = swipe_path(target, layout, rng, _options["swipe_sigma"])
            if path is not None:
                words = engine.swipe(before, path)
                totals["swipe1"][0] += bool(words) and words[0] == target
                totals["swipe1"][1] += 1
                totals["swipe3"][0] += target in words[:3]
                totals["swipe3"][1] += 1
                if not words or words[0] != target:
                    misses.append(("swipe", target, words[:3]))
        if not right:
            misses.append(("space", target, typed, committed))
    totals["ksr"] = [keys_full - keys_used, keys_full]
    return totals, misses


# ---------------------------------------------------------------------------------------------------------------
# Runs and reports
# ---------------------------------------------------------------------------------------------------------------

def score_block(block):
    """One simulated user typing `block` in order, the keyboard learning as they go."""
    _engine.personal = type(_engine.personal)()
    totals = {m: [0, 0] for m in METRICS}
    misses = []
    for row in block:
        part, missed = score_sentence(row)
        for m in METRICS:
            totals[m][0] += part[m][0]
            totals[m][1] += part[m][1]
        misses.extend(missed)
    return totals, misses


def run_config(engine_name, enabled, active, lang, args, workers):
    sentences = test_sentences(lang, args.sentences)
    options = {"sigma": args.sigma, "swipe": not args.no_swipe, "swipe_sigma": args.swipe_sigma,
               "learn": bool(args.learn), "no_taps": args.no_taps}
    started = time.time()
    with multiprocessing.Pool(workers, _init, (engine_name, enabled, active, active, options)) as pool:
        if args.learn:
            blocks = [sentences[i:i + args.learn] for i in range(0, len(sentences), args.learn)]
            results = pool.map(score_block, blocks, chunksize=1)
        else:
            results = pool.map(score_sentence, sentences, chunksize=1)
    totals = {m: [0, 0] for m in METRICS}
    misses = []
    for part, missed in results:
        for m in METRICS:
            totals[m][0] += part[m][0]
            totals[m][1] += part[m][1]
        misses.extend(missed)
    return {
        "lang": lang, "enabled": enabled, "active": active, "sentences": len(sentences),
        "words": totals["space"][1], "seconds": round(time.time() - started, 1),
        "scores": {m: (round(100 * a / b, 1) if b else None) for m, (a, b) in totals.items()},
        "misses": misses[:200],
    }


def print_table(rows, compare=None):
    previous = {}
    if compare:
        for row in json.loads(Path(compare).read_text(encoding="utf-8"))["runs"]:
            previous[(row["lang"], ",".join(row["enabled"]))] = row["scores"]
    header = f"{'test':<6}{'enabled':<10}{'words':>6}  " + "".join(f"{m:>9}" for m in METRICS)
    print(header)
    print("-" * len(header))
    for row in rows:
        old = previous.get((row["lang"], ",".join(row["enabled"])), {})
        cells = []
        for m in METRICS:
            value = row["scores"][m]
            if value is None:
                cells.append(f"{'-':>9}")
                continue
            delta = ""
            if m in old and old[m] is not None:
                change = value - old[m]
                delta = f"{change:+.0f}" if abs(change) >= 0.5 else ""
            cells.append(f"{value:>6.1f}{delta:>3}" if delta else f"{value:>9.1f}")
        print(f"{row['lang']:<6}{','.join(row['enabled']):<10}{row['words']:>6}  " + "".join(cells))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--engine", default="decoder", help="module in scripts/predict_eval with an Engine class (decoder: the keyboard's; baseline: the old one)")
    parser.add_argument("--langs", default=",".join(ALL_LANGS), help="languages to test, each on its own")
    parser.add_argument("--mix", help="enabled languages tested together, the first is the layout (e.g. hu,en)")
    parser.add_argument("--sentences", type=int, default=150, help="test sentences per language")
    parser.add_argument("--sigma", type=float, default=0.25, help="tap scatter in key widths")
    parser.add_argument("--swipe-sigma", type=float, default=0.30, help="swipe scatter in key widths")
    parser.add_argument("--no-swipe", action="store_true")
    parser.add_argument("--no-taps", action="store_true", help="don't give engines the tap positions")
    parser.add_argument("--learn", type=int, default=0,
                        help="simulate users who each type this many sentences in order while the keyboard learns")
    parser.add_argument("--workers", type=int, default=max(1, min(16, (os.cpu_count() or 2) - 2)))
    parser.add_argument("--out", help="results file (default .eval/results/<engine>-<time>.json)")
    parser.add_argument("--compare", help="earlier results file to show the change against")
    parser.add_argument("--misses", type=int, default=0, help="print this many wrong words per run")
    args = parser.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    configs = []
    if args.mix:
        enabled = args.mix.split(",")
        configs = [(enabled, enabled[0], lang) for lang in enabled]
    else:
        configs = [([lang], lang, lang) for lang in args.langs.split(",")]
    prepare(sorted({lang for enabled, _, _ in configs for lang in enabled}))

    rows = []
    for enabled, active, lang in configs:
        print(f"... {lang} (enabled {','.join(enabled)}, layout {active})", flush=True)
        row = run_config(args.engine, enabled, active, lang, args, args.workers)
        rows.append(row)
        for miss in row["misses"][:args.misses]:
            print("   ", miss)
    print()
    print_table(rows, args.compare)

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    out = Path(args.out) if args.out else RESULTS_DIR / f"{args.engine}-{time.strftime('%Y%m%d-%H%M%S')}.json"
    out.write_text(json.dumps({"engine": args.engine, "args": vars(args), "runs": rows}, ensure_ascii=False, indent=1),
                   encoding="utf-8")
    print(f"\nSaved {out}")


if __name__ == "__main__":
    main()
