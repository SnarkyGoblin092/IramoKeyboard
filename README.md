# TempoKeyboard

A custom keyboard for iPhone and iPad. All settings live in the **Tempo app**.

- **Languages:** English, Hungarian and 13 other European languages; swipe the space bar to switch.
- **Prediction:** a word trigram model per language with typo, accent and missing-space correction
  ("vsgyok" -> "vagyok", "koszonom" -> "köszönöm", "nemakarom" -> "nem akarom"), capitalisation ("im" -> "I'm"),
  next-word suggestions, and learning of your own words and typos (view or remove them under Learned words).
  Backspace right after an auto-correction undoes it, and auto-correction can be turned off.
- **Typing:** swipe typing, space-bar cursor control, delete-by-word, text shortcuts, double-space full stop.
- **Emoji:** an iOS-style picker with recents, search and skin tones, plus emoji suggestions in the bar.
- **Look:** 75 themes (native, transparent, Liquid Glass and key-colour themes), accent colours, key roundness,
  height, borders and a number row; the previews follow light and dark mode.

## Build and install (no Mac needed)
1. Push this repo to GitHub. The **Build TempoKeyboard IPA** workflow runs on a `macos-26` runner.
2. Download the `TempoKeyboard.ipa` artifact (not zipped).
3. Install it with **iloader** (the App Group entitlement is already in the IPA so settings reach the keyboard).
4. Settings > General > Keyboard > Keyboards > Add New Keyboard > Tempo, then turn on **Allow Full Access**
   (needed for vibration, recent emoji and learned words).

## Prediction tests
`python3 scripts/predict_eval/run.py` scores prediction on held-out sentences with simulated sloppy typing and
swiping; see the script for options.

## Limits
No voice typing; cursor control is horizontal only.

## Credits
Emoji tab icons via Iconify: Codicons (Microsoft, CC BY 4.0), Basil (Craftwork, CC BY 4.0), Font Awesome 4
(OFL 1.1), Akar Icons, Famicons, Flowbite Icons, Fluent UI System Icons and Boxicons (MIT).
