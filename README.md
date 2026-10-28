# HunKeys

A custom iPhone keyboard: multiple languages (English and Hungarian plus popular European ones), swipe typing,
word and emoji suggestions, an iOS-style emoji picker with history and search, space-bar cursor control,
and a native or transparent look. All settings live in the **HunKeys app**.

## Build and install (no Mac needed)
1. Push this repo to GitHub. The **Build HunKeys IPA** workflow runs on a `macos-26` runner.
2. Download the `HunKeys-ipa` artifact (`HunKeys.ipa`).
3. Install it with **iloader** (the App Group entitlement is already in the IPA so settings reach the keyboard).
4. Settings > General > Keyboard > Keyboards > Add New Keyboard > HunKeys, then turn on **Allow Full Access**
   (needed for vibration, recent emoji and learned words).

## Limits
No autocorrect or next-word prediction, no voice typing, cursor control is horizontal only.
