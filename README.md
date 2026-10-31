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

## Build it yourself

### On GitHub
1. **Fork** this repo.
2. In your fork, open the **Actions** tab and enable workflows (GitHub turns them off in new forks).
3. Start a build: **Actions > Build TempoKeyboard IPA > Run workflow**. Every push to the fork builds too.
4. When the run is green, download **TempoKeyboard.ipa** from the run's Artifacts (it is not zipped).

The build has two jobs. The **data** job runs on Linux: it downloads about 400 MB of word lists and sentences
and turns them into dictionaries (`scripts/build_data.py`), which takes 15-20 minutes the first time; the
result is cached for a week. The **build** job then compiles the app on macOS in about 3 minutes. Pushes that
only change Markdown files or the licence don't start a build.

Actions minutes are free for public repos. A private repo spends the account's monthly minutes (2,000 on
GitHub Free), and macOS minutes count ten times, which is why only the compile step runs on macOS: that leaves
roughly 60 builds a month.

### Install the IPA
The IPA is unsigned. Sign and install it with your own Apple ID using a sideloading tool such as
[iloader](https://github.com/nab138/iloader), [AltStore](https://altstore.io) or
[SideStore](https://sidestore.io). The App Group entitlement is already in the IPA and these tools keep it, so
the app's settings reach the keyboard. With a free Apple ID the app has to be refreshed every 7 days.

Then: **Settings > General > Keyboard > Keyboards > Add New Keyboard > Tempo**, and turn on
**Allow Full Access** (needed for vibration, recent emoji and learned words; the keyboard works without it).

## Prediction tests
`python3 scripts/predict_eval/run.py` scores prediction on held-out sentences with simulated sloppy typing and
swiping; see the script for options.

## Limits
No voice typing; cursor control is horizontal only.

## License
Copyright (C) 2026 Orsós Emil. TempoKeyboard is free software under the
[GNU General Public License v3.0](LICENSE): you may use, change and share it, and anything you distribute that is
based on it must be released under the same licence with its source code.

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
