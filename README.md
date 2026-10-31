# TempoKeyboard

A custom keyboard for iPhone and iPad. All settings live in the **Tempo app**.

- **Languages:** English, Hungarian and 13 other European languages; swipe the space bar to switch.
- **Prediction:** a word trigram model per language with typo, accent and missing-space correction
  ("vsgyok" -> "vagyok", "koszonom" -> "köszönöm", "nemakarom" -> "nem akarom"), capitalisation ("im" -> "I'm"),
  next-word suggestions, and learning of your own words and typos (tap a word as you typed it in the suggestion bar to keep it).
  Backspace right after an auto-correction undoes it, and auto-correction can be turned off.
- **Typing:** swipe typing, space-bar cursor control, delete-by-word, text shortcuts, double-space full stop.
- **Emoji:** an iOS-style picker with recents, search and skin tones, plus emoji suggestions in the bar.
- **Look:** 75 themes (native, transparent, Liquid Glass and key-colour themes), accent colours, key roundness,
  height, borders and a number row; the previews follow light and dark mode.

## Prediction tests
`python3 scripts/predict_eval/run.py` scores prediction on held-out sentences with simulated sloppy typing and
swiping; see the script for options.

## Limits
No voice typing; cursor control is horizontal only.

## License
Copyright (C) 2026 Orsós Emil. All rights reserved. The code and the app may not be used, copied, changed or
distributed without written permission; see [LICENSE](LICENSE).

The third-party material below keeps its own licences; the dictionaries the build produces are CC BY-SA 4.0.

## Credits
The full notices are in the app under Licences (App/LicensesView.swift).

- Dictionaries: adapted from [FrequencyWords](https://github.com/hermitdave/FrequencyWords) by Hermit Dave
  (OpenSubtitles 2018 word counts), CC BY-SA 4.0; the built dictionaries are shared under the same licence.
- Word pairs: [Tatoeba](https://tatoeba.org) example sentences, CC BY 2.0 FR.
- Next-word statistics: counted from the OPUS OpenSubtitles 2018 corpus (Lison & Tiedemann, 2016), compiled from
  opensubtitles.org; no subtitle text ships with the app.
- Emoji list and names: Unicode emoji data and CLDR annotations, Unicode License V3.
- Emoji tab icons via Iconify: Codicons (Microsoft, CC BY 4.0), Basil (Craftwork, CC BY 4.0), Font Awesome 4
  (Dave Gandy, OFL 1.1), and Akar Icons, Famicons, Flowbite Icons, Fluent UI System Icons and Boxicons (MIT).
