import SwiftUI

/// Swipe typing and the other gestures on the keys, by the key they start on.
struct GesturesView: View {
    @AppStorage(SettingKey.swipe, store: SharedStore.defaults) private var swipe = SettingDefault.swipe
    @AppStorage(SettingKey.twoThumbSwipe, store: SharedStore.defaults) private var twoThumbs = SettingDefault.twoThumbSwipe
    @AppStorage(SettingKey.spaceCommits, store: SharedStore.defaults) private var spaceCommits = SettingDefault.spaceCommits
    @AppStorage(SettingKey.multiWordSwipe, store: SharedStore.defaults) private var multiWord = SettingDefault.multiWordSwipe
    @AppStorage(SettingKey.deleteSwipedWord, store: SharedStore.defaults) private var deleteSwiped = SettingDefault.deleteSwipedWord
    @AppStorage(SettingKey.deleteSwipe, store: SharedStore.defaults) private var deleteWords = SettingDefault.deleteSwipe
    @AppStorage(SettingKey.cursorControl, store: SharedStore.defaults) private var cursor = SettingDefault.cursorControl
    @AppStorage(SettingKey.flickUpCapital, store: SharedStore.defaults) private var flickUp = SettingDefault.flickUpCapital
    @AppStorage(SettingKey.flickDownAccent, store: SharedStore.defaults) private var flickDown = SettingDefault.flickDownAccent

    var body: some View {
        List {
            Section {
                GlassToggle(title: "Swipe typing",
                            subtitle: "Slide across the letters to write a word; the bar offers the other readings.",
                            isOn: $swipe)
                Group {
                    GlassToggle(title: "Thumb handoff",
                                subtitle: "Touch a letter with your other thumb while gliding, or just after lifting, and the same word goes on.",
                                isOn: $twoThumbs)
                    GlassToggle(title: "Glide through space",
                                subtitle: "Slide onto the space bar to finish a word, then back onto the letters for the next one.",
                                isOn: $spaceCommits)
                    GlassToggle(title: "Phrase glide",
                                subtitle: "One glide may read as two or three words (\u{201C}do it\u{201D}); the single word stays in the bar.",
                                isOn: $multiWord)
                    GlassToggle(title: "Undo a swipe with one delete",
                                subtitle: "Delete right after a swipe removes the whole word. Off: one letter at a time.",
                                isOn: $deleteSwiped)
                }
                .disabled(!swipe)
            } header: {
                SectionHeader("Letters", symbol: "hand.draw.fill", color: .blue)
            }
            .glassRows()

            Section {
                SettingSlider("Hold delay",
                              key: SettingKey.holdDelay,
                              defaultValue: SettingDefault.holdDelay,
                              range: Settings.holdDelayRange,
                              step: 0.05,
                              subtitle: "How long to hold a key before its accents appear") { String(format: "%.2f s", $0) }
                GlassToggle(title: "Flick up for a capital",
                            subtitle: "A short flick up on a letter types it as a capital.",
                            isOn: $flickUp)
                GlassToggle(title: "Flick down for an accent",
                            subtitle: "A short flick straight down types the key's first accent.",
                            isOn: $flickDown)
            } header: {
                SectionHeader("Accents and capitals", symbol: "textformat.abc.dottedunderline", color: .orange)
            } footer: {
                Text("Flicks are short and straight; a longer slide is still swipe typing.")
            }
            .glassRows()

            Section {
                GlassToggle(title: "Move the cursor",
                            subtitle: "Hold the space bar until the letters fade, then slide left or right.",
                            isOn: $cursor)
            } header: {
                SectionHeader("Space bar", symbol: "space", color: .teal)
            } footer: {
                Text("A quick sideways swipe on the space bar switches the language instead.")
            }
            .glassRows()

            Section {
                GlassToggle(title: "Delete whole words",
                            subtitle: "Slide left from the delete key: each step removes one more word.",
                            isOn: $deleteWords)
            } header: {
                SectionHeader("Delete key", symbol: "delete.left.fill", color: .red)
            } footer: {
                Text("Holding delete repeats it, letter by letter.")
            }
            .glassRows()
        }
        .listStyle(.insetGrouped)
        .glassScreen()
        .navigationTitle("Gestures")
        .navigationBarTitleDisplayMode(.inline)
    }
}
