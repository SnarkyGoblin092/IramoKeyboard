# HunKeys

A Gboard-style iPhone keyboard: Hungarian + English, swipe typing, word/emoji suggestions, an iOS-style
emoji picker (with Recently Used and search), space-bar cursor control, and a Liquid Glass look.
All settings live in the **HunKeys app**; the keyboard itself only has a quick tool strip.

## Build (no Mac needed)
1. Push this repo to GitHub. The **Build IPA** workflow runs on a `macos-26` runner.
2. Download the `HunKeys-ipa` artifact. It contains two files:
   - `HunKeys.ipa` - no entitlements. **Use this with Sideloadly and a free Apple ID.**
   - `HunKeys-AppGroup.ipa` - the App Group entitlement is in the signature of the app and the keyboard.
     **Use this with AltStore / SideStore** (or a signer with a paid developer account).
3. Add the keyboard in Settings > General > Keyboard > Keyboards and turn on **Allow Full Access**
   (needed for vibration, paste, saving recents, and the clipboard sync below).

## How settings reach the keyboard
The app and the keyboard are separate processes, so they need a shared place. By installer:

| Installer | What happens |
|---|---|
| **AltStore / SideStore** (free Apple ID) | Use `HunKeys-AppGroup.ipa`. They read the entitlement, register `group.com.hunkeys.k9x4.shared.<TeamID>` and write `ALTAppGroups` into both Info.plists; HunKeys finds the group at runtime. Settings sync automatically. |
| **Sideloadly + free Apple ID** | Use `HunKeys.ipa`. Free accounts can't be granted App Groups, and Sideloadly's custom-entitlement feature is for paid accounts only, so there is no App Group. A shared Keychain is tried (it may or may not be granted - the app's Status > Sync details says), otherwise use **Send settings to keyboard** in the app: it copies the settings, and the keyboard imports them by itself the next time it appears (clipboard is cleared afterwards). Fallback: arrow at the left of the suggestion bar > clipboard icon. |
| **Paid developer account** | `HunKeys-AppGroup.ipa`; the group should work (not verified here). |

Reading shared storage is allowed without Full Access, but writing (recents, status) and clipboard access need it.
Status in the app shows the active channel, a **Test sync** button and a **Sync details** list explaining
why each channel did or didn't work.

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
