# Iramo

A custom keyboard for iPhone and iPad. All settings live in the **Iramo app**.

## Features

### Languages
- 38 languages (English, Hungarian, Arabic, Hindi, Japanese and more), each with its own layout and long-press letters.
- Vietnamese: type without the marks and pick the word from the bar (tieng → tiếng); long-press vowels for tones.
- Arabic, Hebrew, Persian: right to left. Arabic has no shift key, and matching ignores hamza and vowel marks. Persian has its own letters and digits.
- Japanese: romaji turns into hiragana as you type (konnichiha → こんにちは), with kanji and katakana words in the bar.
- Korean (2-beolsik): jamo build syllables as you type. Hindi: Devanagari with vowel signs on keys. Thai: Kedmanee layout.
- Mandarin (simplified): Pinyin (nihao → 你好). Cantonese: Jyutping (neihou → 你好), traditional characters in the bar.
- Swipe the space bar to switch language; it shows the language's name.
- Several enabled languages at once: suggestions and corrections from all of them.
- Features a language can't use are left out there (such as swipe, auto-correction or capitals). The app greys out settings that no enabled language can use.
- The return key shows ⏎ in every language.

### Prediction and correction
- Word suggestions from a trigram model per language, and next-word suggestions before you start a word. The layout's language leads until the text shows another.
- Auto-correction on space: typos, missing accents and spaces, apostrophes and capitals ("im" → "I'm"). Unfinished words are completed, not shortened.
- Backspace right after an auto-correction undoes it.
- Bar: each suggestion sized to its word, or scrolling through up to ten; separators (solid, dashed, dotted, none) or key-like segments.
- Update speed: Very slow to Very fast (500 to 50 ms), or any wait from 50 to 500 ms.
- Word change animation: Instant, Fade, Rise, Slide or Pop.
- Learns words: tap the typed word in the bar to keep it, or type a new word twice. Learned words are shared by all languages and searchable in the app.
- Contact names are suggested, never corrected. iOS text replacements are used.
- No correction in password, email and web address fields.

### Typing
- Swipe typing with alternative readings in the bar; thumb handoff passes a glide to the other thumb.
- Glide onto the space bar to finish a word and carry on. Optional phrase glides ("do it").
- Swipe is off while word lists load and in password fields.
- Swipe trail fades over a length of 60 to 600 pt. Delete after a swipe removes the whole word (optional).
- Optional flicks: up for a capital, down for the first accent.
- Hold a key for accents; hold the comma or full stop for more punctuation.
- Auto-capitalization; double-tap shift for caps lock; double-tap space for a full stop.
- Hold space and slide to move the cursor. Slide left from delete to delete whole words.
- Hold the emoji key to open the Iramo app.
- Text shortcuts: type a trigger and press space to expand it.
- Number and symbol pages; optional number row; hide-keyboard button at the right end of the bar.
- Functions button (left end of the bar): a tools panel in place of the keys, with one-handed mode, clipboard, copy, cut, paste, split keyboard, next language and more. Its order and contents are set in the app.
- Clipboard (Functions panel): the last 20 copied texts; tap one to paste it. Needs Full Access.
- Key pop-ups and key clicks.
- Vibration with adjustable strength and feel, and optional ticks in cursor mode.

### Hitboxes
- Letter room: Strict, Normal or Generous next to shift, delete and space.
- Adaptive keys: likely next letters get more room (Gentle, Normal or Strong).
- Hit map: learns where you tap each key and moves its touch area. Viewable and resettable per language in the app.

### Emoji
- iOS-style picker: recently used, category tabs, skin tones, search in your language.
- Emoji suggestions in the bar for the word you typed.
- Emoticons turn into emoji: ":)", "<3", "xD" and "(y)" offer 🙂, ❤️, 😆 and 👍.
- Set up in the app's Emoji screen (General, Layout, Panel, Categories, Skin tones), with a live preview.

### Look
- 13 themes. Native, Transparent and Liquid Glass follow light and dark mode.
- 10 designed themes, each with its own backdrop, key shape and effects:
  - Synthwave: neon grid, pink glow
  - Terminal: green phosphor, scanlines
  - Keycap: mechanical caps
  - Frost: frosted glass keys
  - Candy: glossy pill keys
  - Paper: ink outlines on ruled paper
  - Brutalist: thick outlines, hard shadows
  - Gilded: gold-trimmed keys
  - Ember: dark keys glowing orange
  - Clay: soft, puffy keys
- Designed themes keep their own light or dark mode, accent, corners and key style.
- Theme editor: backdrop, key, label, accent and line colours; corners, outline, solidity, frost, sheen and depth; shadow, label glow and texture. Changes save per theme; Reset restores the design.
- System themes have their own editor. The accent colour is a preset or any colour. Liquid Glass keys are real glass, so their key style is fixed.
- Keys: Small, Standard or Large, or fine-tune height, width, gaps, font, letter size, capitals, accent hints and the space bar's label.
- The accent colour also highlights the auto-correction pill, pressed words, the hide-keyboard icon and the emoji tabs.
- iPhone and iPad, portrait and landscape.
- Split keyboard (iPad): every row in two halves, for every language and page.
- One-handed mode (iPhone and iPad): an 80%-wide keyboard against the left or right side. The split keyboard takes precedence on iPad.

### The Iramo app
- Liquid Glass design on iOS 26 and later: section cards over an aurora backdrop tinted with your accent. Frosted rows before iOS 26.
- Sliders and switches are the system's Liquid Glass controls in the accent colour (drawn glass before iOS 26).
- Sliders show values in real units for this phone; strengths read Faint ... Full.
- The real keyboard, suggestion bar included, pinned at the top of the Keys, Themes, Theme editor, Suggestions, Gestures, Hitboxes, Haptics and Effects screens: the keyboard's own code at its real size, shrunk to fit. Typed letters show in the bar; nothing is written into a field and the emoji key opens no picker. The Emoji and Text shortcuts screens keep their own previews.
- Setup status (keyboard added, Full Access) with a button to Settings, and a field to try the keyboard.
- Haptics with a feel for each kind of action. Swipe left to delete a language, text shortcut or learned word.
- Screens in order: Keyboard, Typing, Touch & gestures, Look & feel, Privacy & data, App language, Credits. The number row and key pop-up switches are on the Keys screen.
- Effects: 80 effects, each with its own switch and settings, plus a glowing swipe trail. Examples: glow, ripple, sparks, wave, shockwave, confetti, hearts, snow, lightning, glitch. 47 come from a catalog of space, nature, celebration, tech, playful and shape effects.
- Effect colours: accent, white, rainbow, warm, cool, pastel, neon, random or any colour. Direction (Auto, Up, Down, Left, Right, Random) and Position (Middle, Top, Bottom, Left, Right, Random) apply to all effects or per effect.
- Effect presets: 70, from Off, Glow and Neon to Showtime, all toned down so typing stays calm. Save your own mix under a name.
- Keys, Haptics, Suggestion bar, Gestures and Hitboxes each have presets and fine-tuning.
- App language: System or any of the 38 languages, in alphabetical order; the whole app switches at once. Translations are machine-made and not yet checked by native speakers. Licence texts and credits stay in English.

### Size
- Language data ships compressed. A language's files are unpacked only when it is enabled (by the app, or by the keyboard on first use), into storage the app and keyboard share, and removed when it is turned off.

### Privacy
- Everything the keyboard learns stays on the device. The keyboard makes no network connections.
- Full Access is only needed for vibration and for saving recent emoji and learned words.
- Learned words, recent emoji and all settings can be cleared from the app. Each asks first.

## License
Copyright (C) 2026 Orsós Emil. All rights reserved. The code and the app may not be used, copied, changed or distributed without written permission; see [LICENSE](LICENSE).

The third-party material below keeps its own licences; the dictionaries the build produces are CC BY-SA 4.0.

## Credits
The full notices are in the app under Licences (App/LicensesView.swift).

- Dictionaries: adapted from [FrequencyWords](https://github.com/hermitdave/FrequencyWords) by Hermit Dave (OpenSubtitles 2018 word counts), CC BY-SA 4.0; the built dictionaries are shared under the same licence.
- Word pairs: [Tatoeba](https://tatoeba.org) example sentences, CC BY 2.0 FR.
- Cantonese words and Jyutping: [rime-cantonese](https://github.com/rime/rime-cantonese) by CanCLID, CC BY 4.0.
- Mandarin words and Pinyin: [CC-CEDICT](https://www.mdbg.net/chinese/dictionary?page=cc-cedict), CC BY-SA 4.0.
- Japanese words and readings: [JMdict](https://www.edrdg.org/jmdict/j_jmdict.html) by the EDRDG, CC BY-SA 4.0.
- Next-word statistics: counted from the OPUS OpenSubtitles 2018 corpus (Lison & Tiedemann, 2016), compiled from opensubtitles.org; no subtitle text ships with the app.
- Emoji list and names: Unicode emoji data and CLDR annotations, Unicode License V3.
- Emoji tab icons via Iconify: Codicons (Microsoft, CC BY 4.0), Basil (Craftwork, CC BY 4.0), Font Awesome 4 (Dave Gandy, OFL 1.1), and Akar Icons, Famicons, Flowbite Icons, Fluent UI System Icons and Boxicons (MIT).
