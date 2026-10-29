"""Chooses the decoder's settings (decoder.Engine.params) on the tuning sentences, never the test sentences.

    python3 scripts/predict_eval/tune.py --langs hu,en,de,fr,pl,ru --mix hu,en

The candidates and their probabilities are collected once per word (the slow part); then each setting is tried
one at a time over a grid, twice round, keeping whichever scores best:

    objective = space-bar accuracy + 0.5 * keystroke savings - right words "corrected" into wrong ones (%)

The last term counts such a word twice: a wrong correction annoys more than a missed one.
"""

import argparse
import multiprocessing
import pickle
import random
import sys

import run
from decoder import correction, suggestions, swipe_ranking, Engine
from keyboard import Layout, swipe_path, tap_word

GRID = {
    "slip": [2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 7.0],
    "first": [0.0, 0.3, 0.6, 0.9, 1.2, 1.6, 2.0],
    "unknown": [-7.0, -8.0, -9.0, -10.0, -11.0, -12.0, -13.0, -14.0, -16.0, -99.0],
    "margin": [0.0, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0],
}
SWIPE_GRID = [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0, 6.0, 7.0, 8.0, 10.0, 12.0]

_engine = None
_layout = None
_swipe = False


def _init(enabled, active, swipe=False):
    global _engine, _layout, _swipe
    _swipe = swipe
    _engine = Engine(run.DATA_DIR, enabled, active)
    _layout = Layout(active)


def collect(row):
    sentence_id, text = row
    words = []
    for index, match in enumerate(run.TOKEN.finditer(text)):
        target = run._target(match.group())
        if not target:
            continue
        before = text[:match.start()]
        rng = random.Random(f"{sentence_id}:{index}")
        typed = tap_word(target, _layout, rng, 0.25)
        slipped = typed != "".join(_layout.key_letter(c) or c for c in target)
        if _swipe:
            if sum(1 for c in target if _layout.key_letter(c)) >= 2:
                path = swipe_path(target, _layout, rng, 0.30)
                if path is not None:
                    words.append({"target": target, "swipe": _engine.swipe_features(before, path)})
            continue
        predicted = _engine.next_words(before) if (not before or before.endswith(" ")) else []
        prefixes = []
        if target not in predicted[:3]:
            for k in range(1, len(typed)):
                rows, lower, _ = _engine.features(before + typed[:k], typed[:k])
                prefixes.append((rows, lower))
        rows, lower, typed_lm = _engine.features(before + typed, typed)
        words.append({"target": target, "typed": typed, "slipped": slipped, "next": target in predicted[:3],
                      "prefixes": prefixes, "full": (rows, lower, typed_lm)})
    return words


def evaluate(words, params, with_ksr=True):
    right = broken = saved = total_keys = 0
    for w in words:
        rows, lower, typed_lm = w["full"]
        committed = correction(rows, lower, typed_lm, params)
        ok = committed == w["target"]
        right += ok
        if not ok and not w["slipped"] and lower == w["target"]:
            broken += 1
        full = len(w["target"]) + 1
        total_keys += full
        if not with_ksr:
            continue
        used = len(w["typed"]) + 1
        if w["next"]:
            used = 1
        else:
            for k, (prefix_rows, prefix_lower) in enumerate(w["prefixes"], start=1):
                if w["target"] in suggestions(prefix_rows, prefix_lower, params, 2):
                    used = k + 1
                    break
        saved += full - used
    n = len(words)
    space = 100 * right / n
    ksr = 100 * saved / total_keys if with_ksr else 0.0
    return space, ksr, 100 * broken / n


def objective(sets, params):
    total = 0.0
    for words in sets.values():
        space, ksr, broken = evaluate(words, params)
        total += space + 0.5 * ksr - broken
    return total / len(sets)


def tune_swipe(sets):
    """Chooses the shape weight: swipe first-choice accuracy plus half the top-3 accuracy, averaged."""
    def scores(words, shape):
        first = top3 = n = 0
        for w in words:
            if w["swipe"] is None:
                continue
            ranked = swipe_ranking(w["swipe"], {"shape": shape})
            n += 1
            first += bool(ranked) and ranked[0] == w["target"]
            top3 += w["target"] in ranked[:3]
        return 100 * first / max(n, 1), 100 * top3 / max(n, 1)

    best = None
    for shape in SWIPE_GRID:
        total = sum(a + 0.5 * b for a, b in (scores(words, shape) for words in sets.values())) / len(sets)
        print(f"  shape {shape:<5} objective {total:.2f}")
        if best is None or total > best[0]:
            best = (total, shape)
    print("best shape", best[1])
    for key, words in sets.items():
        first, top3 = scores(words, best[1])
        print(f"  {key[0]:<4}{key[1]:<8} swipe1 {first:5.1f}  swipe3 {top3:5.1f}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--langs", default="hu,en,de,fr,pl,ru")
    parser.add_argument("--mix", default="hu,en")
    parser.add_argument("--sentences", type=int, default=80)
    parser.add_argument("--workers", type=int, default=16)
    parser.add_argument("--reuse", action="store_true", help="reuse the candidates collected by the last run")
    parser.add_argument("--swipe", action="store_true", help="tune only the swipe weight (collects swipes too)")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    configs = [([lang], lang, lang) for lang in args.langs.split(",")]
    if args.mix:
        enabled = args.mix.split(",")
        configs += [(enabled, enabled[0], lang) for lang in enabled]
    run.prepare(sorted({lang for enabled, _, _ in configs for lang in enabled}))

    cache = run.EVAL_DIR / ("tune_swipe.pkl" if args.swipe else "tune_sets.pkl")
    sets = pickle.loads(cache.read_bytes()) if args.reuse and cache.exists() else {}
    for enabled, active, lang in configs:
        if (lang, ",".join(enabled)) in sets:
            continue
        print(f"collecting {lang} (enabled {','.join(enabled)})", flush=True)
        rows = run.test_sentences(lang, args.sentences, tuning=True)
        with multiprocessing.Pool(args.workers, _init, (enabled, active, args.swipe)) as pool:
            sets[(lang, ",".join(enabled))] = [w for part in pool.map(collect, rows, chunksize=1) for w in part]
        cache.write_bytes(pickle.dumps(sets))

    if args.swipe:
        tune_swipe(sets)
        return

    params = dict(Engine.params)
    best = objective(sets, params)
    print("start", params, round(best, 2))
    for _ in range(3):
        for name, values in GRID.items():
            for value in values:
                trial = dict(params, **{name: value})
                score = objective(sets, trial)
                if score > best + 1e-9:
                    best, params = score, trial
            print(f"  {name:<8} -> {params[name]:<6} objective {best:.2f}", flush=True)
    print("best", params)
    for key, words in sets.items():
        space, ksr, broken = evaluate(words, params)
        print(f"  {key[0]:<4}{key[1]:<8} space {space:5.1f}  ksr {ksr:5.1f}  broken {broken:4.1f}")


if __name__ == "__main__":
    main()
