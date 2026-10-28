# HunKeys

A Gboard-style iPhone keyboard: Hungarian + English, swipe typing, word/emoji suggestions, an iOS-style
emoji picker (with Recently Used and search), space-bar cursor control, and a Liquid Glass look.
All settings live in the **HunKeys app**; the keyboard itself only has a quick tool strip.

## Build (no Mac needed)
1. Push this repo to GitHub. The **Build IPA** workflow runs on a `macos-26` runner.
2. Download the `HunKeys-ipa` artifact. It contains two files:
   - `HunKeys-AppGroup.ipa` - **try this first.** Lets the app's settings reach the keyboard.
   - `HunKeys.ipa` - plain build, use it if the App Group build fails to install or the keyboard disappears.
3. Install with Sideloadly/AltStore, then add the keyboard in Settings > General > Keyboard > Keyboards,
   and turn on **Allow Full Access** (needed for vibration and paste).

### How settings reach the keyboard
The app and the keyboard are separate processes, so the app sends settings over every channel that works:
1. App Group storage, 2. a shared Keychain group (named after your Team ID, found at runtime), 3. manual:
"Copy settings for the keyboard" in the app, then the keyboard's paste tool (arrow at the left of the
suggestion bar, then the clipboard icon) imports them.
**Allow Full Access must be on** - iOS only lets a keyboard use shared storage with it.
The app's Status section shows the active channel and a **Test sync** button. A free Apple ID signed via
Sideloadly often removes App Group/Keychain sharing; in that case use the manual channel (or AltStore/SideStore,
which re-create App Groups for free accounts).

## Features
- Hungarian/English; accents shown only for the active language (hold a key)
- Adjustable hold delay and vibration strength, optional click sound
- Swipe typing; word and emoji suggestions; learned words; text shortcuts
- Emoji picker: iOS layout, Recently Used tab, search (English + Hungarian), skin tones, latest Unicode data
- Hold + slide on the space bar to move the cursor; slide left from delete to delete words
- Number row, key hints, one-handed mode, paste, adjustable height, accent colours
- Liquid Glass suggestion bar, pop-ups and emoji picker; keys use a light glass style
  ("Glass keys" turns on real glass per key - experimental)

## Limits
No autocorrect or next-word prediction, no voice typing, cursor control is horizontal only.
This code has not been compiled by its author: the first CI run may need small fixes.
