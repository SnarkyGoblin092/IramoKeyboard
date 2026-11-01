# Iramo

A custom keyboard for iPhone and iPad. All settings live in the **Iramo app**.

## Features

### Languages
- 37 languages: English, Hungarian, Spanish, French, German, Italian, Portuguese, Dutch, Polish, Czech, Romanian,
  Turkish, Russian, Ukrainian, Swedish, Lithuanian, Latvian, Arabic, Danish, Norwegian, Finnish, Greek, Hebrew, Persian,
  Indonesian, Malay, Vietnamese, Slovak, Croatian, Bulgarian, Catalan, Korean, Hindi, Thai, Japanese, Cantonese
  and Mandarin.
- Each with its own layout: QWERTY, QWERTZ, AZERTY, Turkish, Nordic (å æ ø / å ä ö), Croatian (š đ č ć ž),
  Cyrillic for Russian, Ukrainian and Bulgarian (phonetic), Greek, Hebrew, Persian and Arabic, plus the language's
  extra letters on long-press (ñ, ç, ü ö ä, ğ ş ı, ą č ę ė į š ų ū ž, ā ē ģ ī ķ ļ ņ, ά έ ή ί ό ύ ώ, ľ ĺ ô ŕ, l·l...).
- Vietnamese: type without the marks and pick the word from the bar (tieng → tiếng), or long-press a vowel for
  its tones and ă â ê ô ơ ư, and d for đ.
- Hebrew and Persian are written right to left like Arabic; Persian has its own letters (پ چ ژ ک گ ی), Persian
  digits (۱۲۳) and the Arabic comma, question mark and semicolon.
- Arabic: right to left (the cursor slides the right way), no shift key, its own comma, question mark and
  semicolon (، ؟ ؛), Arabic-Indic digits (the Western ones on long-press), hamza forms on long-press, and words
  matched with or without hamza and vowel marks.
- Japanese (日本語), typed in romaji: the letters turn into hiragana as you type (konnichiha → こんにちは) and the
  bar offers kanji words for them (gakusei → 学生, nihongo → 日本語), with the hiragana and katakana right after
  the best word (ko-hi- → コーヒー; ー is on the comma's long-press). Space or a tap writes a word, letters left over
  become the next one, and return keeps the kana. Japanese punctuation: 、。？！ and 「」.
- Korean (한국어) on the 2-beolsik layout: jamo build syllables as you type (ㅎ ㅏ ㄴ → 한, 각 + ㅏ → 가가), backspace
  takes back one jamo at a time, and ㄲ ㄸ ㅃ ㅆ ㅉ ㅒ ㅖ are on long-press. Suggestions work on the syllables
  typed so far; auto-correction and swiping are off.
- Hindi (हिन्दी) on a Devanagari layout with the vowel signs on keys: a vowel sign typed where it has no consonant
  (at the start of a word) becomes the full vowel (ा → आ, े → ए, ् → अ); aspirated consonants (ख घ थ ध फ भ...),
  ञ ण ष and conjuncts (क्ष ज्ञ त्र श्र) are on long-press, and the full stop is the danda (।).
- Thai (ไทย) on the Kedmanee layout with its four rows of letters (the keyboard grows a row for it); the shifted
  letters, tone marks and ฯ are on long-press. Auto-correction is off, as Thai has no spaces between words.
- Mandarin (普通话, simplified characters), typed in Pinyin the same way as Cantonese below: nihao → 你好,
  women → 我们, duibuqi → 对不起; type ü as v (lv → 绿).
- Cantonese (粵語), typed in Jyutping: the letters show underlined in the field while the suggestion bar offers
  traditional characters and words for them (neihou → 你好, hoenggong → 香港, even whole phrases); space or a tap
  writes one, and letters left over turn into the next word. Return keeps the letters as typed. Tones are not
  needed, words you pick rank higher next time, and the comma, full stop, question and exclamation marks are
  full-width (，。？！), with 、「」『』 on long-press. Swiping and auto-correction are off for it.
- Swipe the space bar left or right to switch; the space bar shows the language's name.
- Several languages at once: words from any enabled language are suggested and corrected, and the keyboard
  learns which ones you write in most.
- Features a language can't use are left out while typing in it: swipe typing, adaptive keys and the hit map
  (Korean, Hindi, Thai, Chinese, Japanese), auto-correction (Korean, Thai, Chinese, Japanese), capitals and
  auto-capitalization (scripts without capitals), and the double-space full stop (Thai, Chinese, Japanese; Hindi
  gets the danda "। "). In the app those settings name the enabled languages they're off in, and are greyed out
  when none of the enabled languages can use them.
- The return key is labelled in the keyboard's language, to match the field (Go, Search, Send, Done, Next).

### Prediction and correction
- Word suggestions as you type, from a word trigram language model per language.
- Next-word suggestions before you start the next word.
- Auto-correction when you press space: typos ("vsgyok" -> "vagyok"), missing accents ("koszonom" -> "köszönöm"),
  missing spaces ("nemakarom" -> "nem akarom"), apostrophes and capitals ("im" -> "I'm"); an unfinished word
  is completed rather than swapped for a short one ("appl" -> "apple", not "all").
- The word space will write sits on an accent-coloured pill in the middle of the bar.
- The bar can size each suggestion to its word so more fit, or scroll sideways through up to ten; separators
  (solid, dashed, dotted or none) or key-like segments, in the theme's colours or neutral ones, at any height.
  With only one or two words they sit centred, with no empty places and separators only between them.
- Update speed: Very slow, Slow, Normal, Fast or Very fast (500, 300, 150, 100 or 50 ms), or any wait from 50 to
  500 ms: how long the bar waits for a pause in typing, or in a swipe, before showing new words.
- Switching: how new words replace the old ones — Instant, Fade, Rise, Slide (along the reading direction, so
  right to left in Arabic) or Pop, taking 0.10 to 0.50 s; the settings preview keeps changing its words to show
  it, at the same speed as the keyboard.
- Backspace right after an auto-correction undoes it.
- Learns new words: tap the word as you typed it in the bar to keep it, or type a new word twice; words you
  retype after deleting a typo teach the keyboard that typo; words you use often, and the words you put after
  each other, rank higher. Learned words are shared by every language: a name or slang word learned while typing
  in one language is suggested, kept and swiped in all of them (one list in the app, searchable).
- Knows your contacts' names (suggested, never corrected) and uses your iOS text replacements.
- No correction in password, email and web address fields, or where the app asks for none.

### Typing
- Swipe typing: slide across the letters to write a word; the bar offers the other readings.
- Thumb handoff: pass a word to the other thumb mid-glide (or right after lifting) and it goes on.
- Glide onto the space bar to finish a word and carry on with the next one without lifting ("hello you"); the
  trips to and from the bar are left out of the words.
- The swipe line fades out behind the finger, over a Trail length you set (60 to 600 pt).
- Optional phrase glides: one glide can read as two or three words ("do it", "in the morning").
- Delete right after a swipe removes the whole word (can be turned off).
- Optional flicks: up on a letter for a capital, down for its first accent. A flick that keeps going (over about 1.3 key heights) becomes a swiped word instead (one that dips onto the space bar commits nothing there until it reaches another letter).
- Hold a key for its accents and variants; hold the comma or the full stop for more punctuation.
- Auto-capitalization at the start of sentences, double-tap shift for caps lock.
- Double-tap the space bar for a full stop.
- Hold the space bar and slide to move the cursor.
- Slide left from the delete key to delete whole words.
- Hold the emoji key to open the Iramo app.
- Text shortcuts: type a trigger and press space to expand it.
- Numbers and symbols pages, and an optional number row.
- A hide-keyboard button at the right end of the suggestion bar (no background: the icon just dims while held).
- Key pop-ups and key clicks.
- Vibration with an adjustable strength and feel (Soft, Light, Medium, Firm or Crisp, or any sharpness),
  and optional ticks when the cursor mode starts and for each character it moves.

### Hitboxes
- Letter room: Strict, Normal or Generous next to shift, delete and space, or any amount in between.
- Adaptive keys: the letters likely to come next get more room, the unlikely ones less (Gentle, Normal or
  Strong, with fine-tuning), also before the first letter.
- Hit map: learns where you really tap each key and moves its touch area there; the app shows the map per
  language and can reset it.

### Emoji
- An emoji picker like the iOS one: recently used emoji, categories with tabs, skin tones, and search in your
  language; the search bar takes the theme's key colours.
- Emoji suggestions in the bar for the word you typed; tapping one replaces the word.
- Emoticons turn into emoji: type ":)", "<3", "xD", "(y)" and the bar offers 🙂, ❤️, 😆, 👍.

### Look
- 75 themes: Native, Transparent, Liquid Glass and 72 colour themes, which are a lighter shade in light mode.
- Follows light and dark mode; with the phone in dark mode, the keys stay dark even in apps that stay light.
- Accent colour (a preset, or any colour from the colour picker in the last place), and a key style: surface (flat, a soft sheen, or raised with a shadow under each key), border (none,
  thin, bold or in the accent colour) and an accent glow (soft or strong); by default colour themes have raised
  keys and every theme but Native a thin outline. Settings a theme has no use for are greyed out (the key style
  with Liquid Glass, whose keys are real glass).
- Keys: Small, Standard or Large, or set one by one: key height (with its own landscape size), keyboard
  width, corners (square to round), the gaps between keys and rows, a font for the keys and the bar (the system
  font, its rounded, serif and monospaced designs, or one of 11 built-in fonts), letter size, capitals that follow shift or
  always show, accent hints in any corner (or off) at any size, and the space bar's text (the language's name or
  its code) and size.
- Highlights follow the theme's accent: the auto-correction pill, pressed suggestions (a tapped word gets exactly
  the auto-correction's pill, in every theme), the hide-keyboard icon
  and the emoji category tabs; in the Liquid Glass theme the pill, a pressed word, the bar's tiles and the emoji
  tab highlight are glass too.
- Works on iPhone and iPad, in portrait and landscape.
- Split keyboard on iPad: every row in two halves with a gap between them (the space bar cut in two), for every
  language and page.
- One-handed mode for left or right hand, on iPhone and iPad: a narrower keyboard (80% wide) against that side;
  the arrow in the empty side moves it over. The split keyboard takes precedence on iPad.

### The Iramo app
- A Liquid Glass design: every list (settings, languages, learned words, shortcuts) has real glass rows over a
  backdrop tinted with your accent colour (frosted glass before iOS 26).
- Laid out like the system Settings app: coloured icons, and each row showing what it is set to.
- Screens that change the keyboard keep a live preview pinned at the top while their settings scroll below it
  (on Themes, drag the bar under it to make it smaller): the keyboard itself (Keys, Themes), the suggestion bar, a
  swipe being drawn, the keys' touch areas, the vibration's feel (tap to play it) and a text shortcut, all drawn
  in the chosen theme with its key style. The keyboard previews show it as it opens (number row, shift, sizes,
  font) and follow sliders while they are dragged.
- Shows what still needs setting up (adding the keyboard, Full Access) with a button to Settings, and a field
  to try the keyboard.
- Themes with previews that look like the real keyboard, in light and dark mode (the Liquid Glass theme with real
  glass keys over a colourful backdrop, sharing one glass container as on the keyboard so the accent keys' colour
  reflects in the keys around them), down to the auto-correction pill in the bar.
- Haptics throughout, with a feel for each kind of action: a light click for switches and sliders, a soft tap
  for opening screens, a fuller knock for choosing a theme or preset, a success pattern for adding, a sharp tap
  for deleting, and for Reset all settings a half-second strong buzz before it asks and a warning buzz when it
  is done.
- Languages, text shortcuts and learned words, each swiped left to remove an entry.
- On the main screen: the theme's name (its preview is on the Themes screen), the number row right under it,
  then Keys and Haptics.
- Keys, Haptics, Suggestion bar, Gestures (swipe, delete, cursor, accents and flicks) and Hitboxes (size,
  adaptive keys, hit map), each with presets and fine-tuning; the keyboard preview follows every change.
- Credits and licences for the word, emoji and icon data.

### Privacy
- Everything the keyboard learns stays on the device; the keyboard makes no network connections.
- Full Access is only needed for vibration and for saving recent emoji and learned words; the keyboard works
  without it.
- Search and remove single learned words, clear recent emoji, forget all learned words or reset all settings from the
  app (each asks first; the removing ones are marked in orange, resetting in red).

## License
Copyright (C) 2026 Orsós Emil. All rights reserved. The code and the app may not be used, copied, changed or
distributed without written permission; see [LICENSE](LICENSE).

The third-party material below keeps its own licences; the dictionaries the build produces are CC BY-SA 4.0.

## Credits
The full notices are in the app under Licences (App/LicensesView.swift).

- Dictionaries: adapted from [FrequencyWords](https://github.com/hermitdave/FrequencyWords) by Hermit Dave
  (OpenSubtitles 2018 word counts), CC BY-SA 4.0; the built dictionaries are shared under the same licence.
- Word pairs: [Tatoeba](https://tatoeba.org) example sentences, CC BY 2.0 FR.
- Cantonese words and Jyutping: [rime-cantonese](https://github.com/rime/rime-cantonese) by CanCLID, CC BY 4.0.
- Mandarin words and Pinyin: [CC-CEDICT](https://www.mdbg.net/chinese/dictionary?page=cc-cedict), CC BY-SA 4.0.
- Japanese words and readings: [JMdict](https://www.edrdg.org/jmdict/j_jmdict.html) by the EDRDG, CC BY-SA 4.0.
- Next-word statistics: counted from the OPUS OpenSubtitles 2018 corpus (Lison & Tiedemann, 2016), compiled from
  opensubtitles.org; no subtitle text ships with the app.
- Emoji list and names: Unicode emoji data and CLDR annotations, Unicode License V3.
- Emoji tab icons via Iconify: Codicons (Microsoft, CC BY 4.0), Basil (Craftwork, CC BY 4.0), Font Awesome 4
  (Dave Gandy, OFL 1.1), and Akar Icons, Famicons, Flowbite Icons, Fluent UI System Icons and Boxicons (MIT).
