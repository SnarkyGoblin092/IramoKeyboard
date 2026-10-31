import SwiftUI

/// Swipe typing and the other gestures on the keys, by kind.
struct GesturesView: View {
    private enum Tab: Hashable { case swipe, delete, cursor, accents }

    @State private var tab: Tab = .swipe
    @AppStorage(SettingKey.swipe, store: SharedStore.defaults) private var swipe = SettingDefault.swipe
    @AppStorage(SettingKey.twoThumbSwipe, store: SharedStore.defaults) private var twoThumbs = SettingDefault.twoThumbSwipe
    @AppStorage(SettingKey.spaceCommits, store: SharedStore.defaults) private var spaceCommits = SettingDefault.spaceCommits
    @AppStorage(SettingKey.multiWordSwipe, store: SharedStore.defaults) private var multiWord = SettingDefault.multiWordSwipe
    @AppStorage(SettingKey.deleteSwipedWord, store: SharedStore.defaults) private var deleteSwiped = SettingDefault.deleteSwipedWord
    @AppStorage(SettingKey.deleteSwipe, store: SharedStore.defaults) private var deleteWords = SettingDefault.deleteSwipe
    @AppStorage(SettingKey.cursorControl, store: SharedStore.defaults) private var cursor = SettingDefault.cursorControl
    @AppStorage(SettingKey.flickUpCapital, store: SharedStore.defaults) private var flickUp = SettingDefault.flickUpCapital
    @AppStorage(SettingKey.flickDownAccent, store: SharedStore.defaults) private var flickDown = SettingDefault.flickDownAccent
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                VStack(alignment: .leading, spacing: 16) {
                    GlassTabs(tabs: [Tab.swipe, .delete, .cursor, .accents], selection: $tab,
                              title: { info(for: $0).tab },
                              symbol: { info(for: $0).symbol },
                              marked: { isOn($0) })
                    Divider()
                    switch tab {
                    case .swipe: swipeTab
                    case .delete: deleteTab
                    case .cursor: cursorTab
                    case .accents: accentsTab
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: GlassMetrics.cardRadius)
            }
            .padding(16)
        }
        .background(GlassBackdrop())
        .navigationTitle("Gestures")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private struct Info {
        let tab: String
        let title: String
        let symbol: String
        let text: String
    }

    private func info(for tab: Tab) -> Info {
        switch tab {
        case .swipe:
            return Info(tab: "Swipe", title: "Swipe typing", symbol: "hand.draw",
                        text: "Glide across the letters to write a word and lift at the end.")
        case .delete:
            return Info(tab: "Delete", title: "Delete words", symbol: "delete.left",
                        text: "Slide left from the delete key to remove whole words.")
        case .cursor:
            return Info(tab: "Cursor", title: "Move the cursor", symbol: "character.cursor.ibeam",
                        text: "Hold the space bar, then slide to move the cursor like on a trackpad.")
        case .accents:
            return Info(tab: "Accents", title: "Accents", symbol: "textformat.abc.dottedunderline",
                        text: "Hold a key for its accents and alternatives, or flick it.")
        }
    }

    private func isOn(_ tab: Tab) -> Bool {
        switch tab {
        case .swipe: return swipe
        case .delete: return deleteWords
        case .cursor: return cursor
        case .accents: return flickUp || flickDown
        }
    }

    private var hero: some View {
        let current = info(for: tab)
        return VStack(alignment: .leading, spacing: 14) {
            Label(isOn(tab) ? "On" : "Off", systemImage: current.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isOn(tab) ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(isOn(tab) ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.primary.opacity(0.08))))
            Image(systemName: current.symbol)
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .accessibilityHidden(true)
            Text(current.title).font(.largeTitle.weight(.bold))
            Text(current.text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: GlassMetrics.cardRadius, tint: Color.currentAccent(name: accentName, hex: accentHex))
        .animation(.easeOut(duration: 0.2), value: tab)
    }

    // MARK: Tabs

    private var swipeTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassToggle(title: "Swipe typing",
                        subtitle: "Slide across the letters to type a word; the bar offers the other readings.",
                        isOn: $swipe)
            Group {
                GlassToggle(title: "Two thumbs",
                            subtitle: "Hand a word from one thumb to the other: touch a letter with the other thumb while gliding, or right after lifting, and the same word goes on.",
                            isOn: $twoThumbs)
                GlassToggle(title: "Multi-word",
                            subtitle: "One glide can read as two or three words (\u{201C}do it\u{201D}, \u{201C}in the morning\u{201D}) without touching space. The single word stays in the bar.",
                            isOn: $multiWord)
                GlassToggle(title: "Space commits",
                            subtitle: "Glide onto the space bar to finish the word there, then back onto the letters for the next one, without lifting.",
                            isOn: $spaceCommits)
                GlassToggle(title: "Delete whole swiped word",
                            subtitle: "Delete right after a swipe removes the whole word. Off: one letter at a time.",
                            isOn: $deleteSwiped)
            }
            .disabled(!swipe)
            .opacity(swipe ? 1 : 0.45)
        }
    }

    private var deleteTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassToggle(title: "Delete whole words",
                        subtitle: "Slide left from the delete key: each step to the left removes one more word.",
                        isOn: $deleteWords)
            Text("Holding delete repeats it, letter by letter.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var cursorTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassToggle(title: "Move the cursor",
                        subtitle: "Hold the space bar until the letters fade, then slide left or right.",
                        isOn: $cursor)
            Text("A quick sideways swipe on the space bar switches the language instead.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accentsTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingSlider("Hold delay",
                          key: SettingKey.holdDelay,
                          defaultValue: SettingDefault.holdDelay,
                          range: Settings.holdDelayRange,
                          step: 0.05,
                          subtitle: "How long to hold a key before its accents appear") { String(format: "%.2f s", $0) }
            GlassToggle(title: "Swipe up to capitalize",
                        subtitle: "Flick a letter up to type it as a capital.",
                        isOn: $flickUp)
            GlassToggle(title: "Swipe down for accent",
                        subtitle: "Flick a letter straight down to type its first accent at once.",
                        isOn: $flickDown)
            Text("Flicks are short and straight; a longer slide is still swipe typing.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
