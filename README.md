# Iramo

A custom keyboard for iPhone and iPad. All settings live in the **Iramo app**.

## Features

### Languages
- 15 languages: English, Hungarian, Spanish, French, German, Italian, Portuguese, Dutch, Polish, Czech, Romanian,
  Turkish, Russian, Ukrainian and Swedish.
- Each with its own layout: QWERTY, QWERTZ, AZERTY, Turkish, and Cyrillic for Russian and Ukrainian, plus the
  language's extra letters (ñ, ç, ü ö ä, å, ğ ş ı...).
- Swipe the space bar left or right to switch; the space bar shows the language's name.
- Several languages at once: words from any enabled language are suggested and corrected, and the keyboard
  learns which ones you write in most.
- The return key is labelled in the keyboard's language, to match the field (Go, Search, Send, Done, Next).

### Prediction and correction
- Word suggestions as you type, from a word trigram language model per language.
- Next-word suggestions before you start the next word.
- Auto-correction when you press space: typos ("vsgyok" -> "vagyok"), missing accents ("koszonom" -> "köszönöm"),
  missing spaces ("nemakarom" -> "nem akarom"), apostrophes and capitals ("im" -> "I'm").
- The word space will write is shown highlighted in the middle of the bar.
- Backspace right after an auto-correction undoes it.
- Learns new words: tap the word as you typed it in the bar to keep it; words you retype after deleting a typo
  teach the keyboard that typo; words you use often rank higher.
- No correction in password, email and web address fields, or where the app asks for none.

### Typing
- Swipe typing: slide across the letters to write a word; the bar offers the other readings.
- Hold a key for its accents and variants; hold the comma or the full stop for more punctuation.
- Auto-capitalization at the start of sentences, double-tap shift for caps lock.
- Double-tap the space bar for a full stop.
- Hold the space bar and slide to move the cursor.
- Slide left from the delete key to delete whole words.
- Text shortcuts: type a trigger and press space to expand it.
- Numbers and symbols pages, and an optional number row.
- Key pop-ups, key clicks and adjustable vibration.

### Emoji
- An emoji picker like the iOS one: recently used emoji, categories with tabs, skin tones, and search in your
  language.
- Emoji suggestions in the bar for the word you typed; tapping one replaces the word.
- Emoticons turn into emoji: type ":)", "<3", "xD", "(y)" and the bar offers 🙂, ❤️, 😆, 👍.

### Look
- 75 themes: Native, Transparent, Liquid Glass and 72 colour themes, which are a lighter shade in light mode.
- Follows light and dark mode; with the phone in dark mode, the keys stay dark even in apps that stay light.
- Accent colour, key roundness, keyboard height, key borders and accent hints on the keys.
- Theme previews in the app that look like the real keyboard, in light and dark mode.
- Works on iPhone and iPad, in portrait and landscape.

### Privacy
- Everything the keyboard learns stays on the device; the keyboard makes no network connections.
- Full Access is only needed for vibration and for saving recent emoji and learned words; the keyboard works
  without it.
- Clear recent emoji, forget learned words or reset all settings from the app.

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
