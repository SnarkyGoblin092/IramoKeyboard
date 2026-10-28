# HunKeys

A multilingual iPhone keyboard (English + Hungarian) that you build in the cloud with GitHub
Actions - no Mac needed.

## Features

| Feature | How it works |
|---|---|
| English + Hungarian | English is QWERTY, Hungarian is QWERTZ. Tap the **globe** key to switch. |
| Accents only for the active language | Hold a letter. Hungarian offers `á é í ó ö ő ú ü ű`; English offers none. |
| Swipe typing | Slide across the letters. The best 3 readings appear in the bar (tap one to swap). Backspace right after a swipe deletes the whole word. |
| Word + emoji suggestions | Suggestion bar: typed word, completions, and emoji that match the word (`smile` -> 😀, `szív` -> ❤️). Learns new words locally. |
| All emoji | The emoji list is downloaded from the newest Unicode data on every build, and the keyboard hides any emoji your phone cannot draw yet. Long-press an emoji for skin tones. |
| Hold delay setting | Gear button (top-left of the keyboard) -> **Hold delay** (0.10 - 1.00 s). Also controls when backspace starts repeating. |
| Vibration strength | Gear button -> **Vibration strength** (Off - 100 %). Needs "Allow Full Access" (iOS rule). |
| Other options | Swipe typing on/off, word suggestions, emoji suggestions, auto-capitalize, forget learned words. |

Extras: double-space gives ". ", auto-capitalisation, dark mode, return key label follows the app (Go/Search/Send...).

## Build it (about 10 minutes, first time)

1. **Create a GitHub repository** (private is fine) at https://github.com/new.
2. **Upload this folder's contents** to it. Easiest with git:
   ```
   cd HunKeys
   git init -b main
   git add .
   git commit -m "HunKeys"
   git remote add origin https://github.com/<you>/<repo>.git
   git push -u origin main
   ```
   Or use the web page (Add file -> Upload files) and drag everything in, **including the hidden
   `.github` folder**. If your browser skips it, create the file `.github/workflows/build-ipa.yml`
   with *Add file -> Create new file* and paste the contents of the one in this folder.
3. Open the repository's **Actions** tab. The workflow **Build HunKeys IPA** starts by itself
   (or press *Run workflow*). It takes roughly 5-10 minutes.
4. When it is green, open the run and download the artifact **HunKeys-unsigned-ipa**
   (a zip containing `HunKeys.ipa`).

### If the build fails
Open the failed run. The step **Show compiler errors** prints every `error:` line, and the
artifact **build-log** has the full log. Send those lines to Claude and they can be fixed quickly.
(The code was written without access to a Swift compiler, so a typo or two on the first run
would not be surprising.)

## Install on your iPhone

The IPA from GitHub is **unsigned**. A tool has to sign it with your Apple ID before iOS will run it:

- **Sideloadly** (Windows or macOS) or **AltStore**: plug in the iPhone, drag `HunKeys.ipa` in,
  sign in with your Apple ID. These tools also re-sign the keyboard extension inside the app.
- A free Apple ID works, but the install **expires after 7 days** - just reinstall the same IPA.
  A paid Apple Developer account ($99/year) lasts a year.
- iOS 16+ needs **Developer Mode**: Settings -> Privacy & Security -> Developer Mode.
- After installing, trust the profile: Settings -> General -> VPN & Device Management.
- If signing says the bundle ID is not available, change the two `PRODUCT_BUNDLE_IDENTIFIER`
  lines in `project.yml` (keep the keyboard's ID starting with the app's ID) and rebuild, or change
  the ID in Sideloadly's *Advanced options*.

### Turn the keyboard on
1. Settings -> General -> Keyboard -> Keyboards -> **Add New Keyboard** -> **HunKeys**
2. Tap **HunKeys** in that list and switch on **Allow Full Access** (needed for vibration).
   HunKeys contains no networking code; it never sends what you type anywhere.
3. In any text field, hold the system globe/emoji key and pick HunKeys.

## How the pieces fit together

```
project.yml                    XcodeGen recipe -> HunKeys.xcodeproj (generated on CI)
.github/workflows/build-ipa.yml   download data, generate project, xcodebuild, zip IPA
scripts/build_data.py          downloads Unicode emoji, CLDR keywords, word-frequency lists
scripts/make_icon.py           draws the app icon

App/                           tiny SwiftUI app: setup instructions + a test text field
Keyboard/                      the keyboard extension
  KeyboardViewController.swift   talks to the text field (textDocumentProxy), owns state
  KeyboardView.swift             draws keys, ALL touch handling (multi-touch, long-press, swipe)
  KeyView.swift, Popups.swift    one key; preview bubble; accent strip
  Layouts.swift                  languages, accents, key rows for letters / numbers / symbols
  SwipeDecoder.swift             path -> words (resample + compare + frequency)
  WordStore.swift                sorted dictionary, prefix search, learned words
  SuggestionBar.swift            gear + 4 suggestion slots
  EmojiStore.swift               emoji data, "can this iPhone draw it?" check, keyword lookup
  EmojiPanel.swift               emoji picker UI
  SettingsPanel.swift            in-keyboard settings
  Settings.swift, Haptics.swift  stored options; vibration with adjustable intensity
```

Why settings live inside the keyboard: sharing settings between the app and the keyboard needs an
*App Group*, which is awkward with free Apple IDs and re-signing tools. Keeping them inside the
keyboard (its own `UserDefaults`) avoids that and lets you feel the vibration while you adjust it.

### Swipe typing in one paragraph
For each swipe, only words that start/end near where the finger started/ended are considered.
Each candidate is turned into an ideal path through its letters' key centres; both paths are
resampled to 32 points and compared point by point (distance measured in key widths). That
distance is combined with how common the word is. Words are compared without accents, so
`szep` can produce `szép`; frequency picks the accented spelling.

### Emoji in one paragraph
`build_data.py` reads Unicode's `emoji-test.txt` (always the latest release) and groups every
fully-qualified emoji, folding skin-tone variants under their base emoji. On the phone,
`EmojiSupport` asks the system emoji font whether each emoji can be drawn and hides the ones it
cannot. I could not verify which Emoji version iOS 27.2 ships, so the keyboard adapts to the phone
rather than assuming. Keywords for suggestions come from CLDR annotations in English and Hungarian.

## Known limits
- No autocorrect (only suggestions), no next-word prediction, no voice input.
- Swipe typing works on the letters page only.
- Two languages are built in; adding one means a layout in `Layouts.swift`, a word list entry in
  `build_data.py`, and a case in `Language`.
- Unsigned IPA + free Apple ID = reinstall every 7 days.

## Data & licences
- Word frequencies: [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords)
  (OpenSubtitles-based, CC BY-SA 4.0).
- Emoji data and keywords: Unicode Consortium (`emoji-test.txt`) and CLDR annotations, under the
  Unicode licence. These files are downloaded at build time and are not stored in this repository.
