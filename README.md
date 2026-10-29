# Tempo

A custom iPhone keyboard: multiple languages (English and Hungarian plus popular European ones), swipe typing,
word and emoji suggestions, an iOS-style emoji picker with history and search, space-bar cursor control,
and a theme picker (native, transparent, Liquid Glass and gradient themes). All settings live in the **Tempo app**.

## Build and install (no Mac needed)
1. Push this repo to GitHub. The **Build HunKeys IPA** workflow runs on a `macos-26` runner.
2. Download the `HunKeys-ipa` artifact (`HunKeys.ipa`).
3. Install it with **iloader** (the App Group entitlement is already in the IPA so settings reach the keyboard).
4. Settings > General > Keyboard > Keyboards > Add New Keyboard > Tempo, then turn on **Allow Full Access**
   (needed for vibration, recent emoji and learned words).

## Limits
Auto-fix only restores missing accents and apostrophes ("koszonom" -> "köszönöm", "dont" -> "don't"; backspace
right after undoes it), it does not correct other typos. No voice typing, cursor control is horizontal only.

- Adjustable key roundness (Appearance), larger touch targets, and a Liquid Glass theme alongside the gradient themes.
- 12 accent presets plus a colour picker, key-colour themes (they only recolour the keys, never the background), and optional adaptive key areas that learn where you tap (reset in Data).
