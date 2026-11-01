import SwiftUI

/// The emoji picker's settings, in five tabs: General (recent emoji), Layout (the grid), Panel (the search field,
/// the category tabs and the keys beside them), Categories (their order) and Skin tones. The keyboard reads them
/// each time the picker opens (Prefs, EmojiPanel).
struct EmojiView: View {
    enum Tab: Int, CaseIterable {
        case general, layout, panel, categories, skinTones

        var title: String {
            switch self {
            case .general: return "General"
            case .layout: return "Layout"
            case .panel: return "Panel"
            case .categories: return "Categories"
            case .skinTones: return "Skin tones"
            }
        }

        var symbol: String {
            switch self {
            case .general: return "face.smiling"
            case .layout: return "square.grid.3x3"
            case .panel: return "rectangle.topthird.inset.filled"
            case .categories: return "square.stack"
            case .skinTones: return "hand.raised.fill"
            }
        }
    }

    @State private var tab: Tab = .general

    var body: some View {
        GlassList {
            Section {
                EmojiTabBar(selected: $tab)
                    .glassOutsideCard()
            }
            switch tab {
            case .general: EmojiGeneralTab()
            case .layout: EmojiLayoutTab()
            case .panel: EmojiPanelTab()
            case .categories: EmojiCategoriesTab()
            case .skinTones: EmojiSkinToneTab()
            }
        }
        .glassScreen()
        .navigationTitle("Emoji")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The five tabs as tiles: an icon over the name, the chosen one filled with the accent.
private struct EmojiTabBar: View {
    @Binding var selected: EmojiView.Tab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(EmojiView.Tab.allCases, id: \.self) { tab in
                let isOn = tab == selected
                Button {
                    guard tab != selected else { return }
                    Feedback.choose()
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol).font(.system(size: 18, weight: .medium))
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundColor(isOn ? .white : .primary)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.tertiarySystemFill))))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

// MARK: - Option cards

/// One choice drawn as a card: a small picture of what it does over its name, outlined in the accent when chosen.
struct OptionCard<Picture: View>: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    @ViewBuilder let picture: () -> Picture

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                picture()
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.tertiarySystemFill)))
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary.opacity(0.2)), lineWidth: isOn ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A titled row of option cards for a stored text setting.
private struct OptionRow: View {
    let title: String
    let options: [(value: String, title: String, symbol: String)]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            HStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { index in
                    let option = options[index]
                    OptionCard(title: option.title, isOn: selection == option.value) {
                        guard selection != option.value else { return }
                        Feedback.choose()
                        selection = option.value
                    } picture: {
                        Image(systemName: option.symbol).font(.system(size: 22)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - General

private struct EmojiGeneralTab: View {
    @AppStorage(SettingKey.emojiShowRecents, store: SharedStore.defaults) private var showRecents = SettingDefault.emojiShowRecents
    @AppStorage(SettingKey.emojiRecentOrder, store: SharedStore.defaults) private var order = SettingDefault.emojiRecentOrder
    @AppStorage(SettingKey.emojiRecentLimit, store: SharedStore.defaults) private var limit = SettingDefault.emojiRecentLimit
    @AppStorage(SettingKey.emojiSpaceAfter, store: SharedStore.defaults) private var spaceAfter = SettingDefault.emojiSpaceAfter
    @State private var recents: [String] = []

    var body: some View {
        Section {
            GlassToggle(title: "Show recent emoji",
                        subtitle: "A tab of the emoji you used lately. Move it anywhere on the Categories tab.",
                        isOn: $showRecents)
            HStack(spacing: 6) {
                if recents.isEmpty {
                    Text("No recent emoji yet").foregroundColor(.secondary)
                } else {
                    ForEach(recents.prefix(6), id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 26))
                            .frame(width: 40, height: 40)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.tertiarySystemFill)))
                    }
                }
                Spacer(minLength: 8)
                Button("Clear") {
                    Settings.shared.clearRecentEmoji()
                    Feedback.delete()
                    withAnimation(.easeOut(duration: 0.2)) { recents = [] }
                }
                .disabled(recents.isEmpty)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Order").font(.subheadline).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    OptionCard(title: "Most recent", isOn: order == "recent") { choose("recent") } picture: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock").foregroundStyle(.tint)
                            Text("😇😉😁")
                        }
                    }
                    OptionCard(title: "Most used", isOn: order == "used") { choose("used") } picture: {
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(0..<3, id: \.self) { index in
                                VStack(spacing: 3) {
                                    Text(["😇", "😉", "😁"][index])
                                    Capsule().fill(.tint).frame(width: 18, height: CGFloat(9 - index * 3))
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .disabled(!showRecents)
            .opacity(showRecents ? 1 : 0.45)
            GlassSlider(title: "How many to keep", symbol: "clock.arrow.circlepath", value: $limit,
                        range: Settings.emojiRecentLimitRange, step: 1) { "\(Int($0.rounded()))" }
                .disabled(!showRecents)
                .opacity(showRecents ? 1 : 0.45)
        } header: {
            SectionHeader("Recent emoji", symbol: "clock.fill", color: .orange)
        }
        .glassRows()
        .onAppear { recents = Settings.shared.orderedRecentEmoji() }
        .onChange(of: order) { _ in recents = Settings.shared.orderedRecentEmoji() }

        Section {
            GlassToggle(title: "Add a space after",
                        subtitle: "A space follows each emoji picked, so a run of them doesn't come out as one block.",
                        isOn: $spaceAfter)
        } header: {
            SectionHeader("Typing", symbol: "character.cursor.ibeam", color: .blue)
        }
        .glassRows()
    }

    private func choose(_ value: String) {
        guard order != value else { return }
        Feedback.choose()
        order = value
    }
}

// MARK: - Layout

private struct EmojiLayoutTab: View {
    @AppStorage(SettingKey.emojiScroll, store: SharedStore.defaults) private var scroll = SettingDefault.emojiScroll
    @AppStorage(SettingKey.emojiSwipeTabs, store: SharedStore.defaults) private var swipeTabs = SettingDefault.emojiSwipeTabs
    @AppStorage(SettingKey.emojiRows, store: SharedStore.defaults) private var rows = SettingDefault.emojiRows
    @AppStorage(SettingKey.emojiSize, store: SharedStore.defaults) private var size = SettingDefault.emojiSize
    @AppStorage(SettingKey.emojiSpacing, store: SharedStore.defaults) private var spacing = SettingDefault.emojiSpacing
    @AppStorage(SettingKey.emojiSearchPosition, store: SharedStore.defaults) private var search = SettingDefault.emojiSearchPosition
    @AppStorage(SettingKey.emojiTabsPosition, store: SharedStore.defaults) private var tabs = SettingDefault.emojiTabsPosition

    private struct Setup {
        let title: String
        let symbol: String
        let rows: Double
        let size: Double
        let spacing: Double
        let search: String
        let tabs: String
    }

    private let setups = [
        Setup(title: "Familiar", symbol: "square.grid.3x3", rows: 4, size: 0.79, spacing: 0, search: "top", tabs: "bottom"),
        Setup(title: "Roomy", symbol: "square.grid.2x2", rows: 3, size: 0.85, spacing: 4, search: "top", tabs: "bottom"),
        Setup(title: "Dense", symbol: "square.grid.4x3.fill", rows: 6, size: 0.80, spacing: 0, search: "top", tabs: "bottom"),
        Setup(title: "Grid only", symbol: "circle.grid.3x3", rows: 5, size: 0.79, spacing: 0, search: "hidden", tabs: "hidden")
    ]

    private func same(_ a: Double, _ b: Double) -> Bool { return abs(a - b) < 0.001 }

    private func matches(_ setup: Setup) -> Bool {
        return same(rows, setup.rows) && same(size, setup.size) && same(spacing, setup.spacing)
            && search == setup.search && tabs == setup.tabs
    }

    var body: some View {
        Section {
            HStack(spacing: 8) {
                ForEach(setups, id: \.title) { setup in
                    OptionCard(title: setup.title, isOn: matches(setup)) {
                        guard !matches(setup) else { return }
                        Feedback.choose()
                        rows = setup.rows
                        size = setup.size
                        spacing = setup.spacing
                        search = setup.search
                        tabs = setup.tabs
                    } picture: {
                        Image(systemName: setup.symbol).font(.system(size: 22)).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            SectionHeader("Quick setups", symbol: "wand.and.stars", color: .purple)
        } footer: {
            Text("Grid only hides the search field and the category tabs; ABC and delete stay.")
        }
        .glassRows()

        Section {
            OptionRow(title: "Scroll direction",
                      options: [("vertical", "Vertical", "arrow.down"), ("horizontal", "Horizontal", "arrow.right")],
                      selection: $scroll)
            GlassToggle(title: "Swipe to switch tabs",
                        subtitle: "Swipe across the scroll direction for the next or the previous category.",
                        isOn: $swipeTabs)
            GlassSlider(title: "Rows", symbol: "rectangle.split.1x2", value: $rows,
                        range: Settings.emojiRowsRange, step: 1) { "\(Int($0.rounded()))" }
            GlassSlider(title: "Emoji size", symbol: "textformat.size", value: $size,
                        range: Settings.emojiSizeRange, step: 0.01) { "\(Int(($0 * 100).rounded()))%" }
            GlassSlider(title: "Cell spacing", symbol: "arrow.left.and.right", value: $spacing,
                        range: Settings.emojiSpacingRange, step: 1) { "\(Int($0.rounded())) pt" }
        } header: {
            SectionHeader("Grid", symbol: "square.grid.3x3.fill", color: .blue)
        }
        .glassRows()
    }
}

// MARK: - Panel

private struct EmojiPanelTab: View {
    @AppStorage(SettingKey.emojiSearchPosition, store: SharedStore.defaults) private var search = SettingDefault.emojiSearchPosition
    @AppStorage(SettingKey.emojiTabsPosition, store: SharedStore.defaults) private var tabs = SettingDefault.emojiTabsPosition
    @AppStorage(SettingKey.emojiTabStyle, store: SharedStore.defaults) private var tabStyle = SettingDefault.emojiTabStyle
    @AppStorage(SettingKey.emojiBackspaceKey, store: SharedStore.defaults) private var backspace = SettingDefault.emojiBackspaceKey

    var body: some View {
        Section {
            OptionRow(title: "Search field",
                      options: [("top", "Top", "rectangle.topthird.inset.filled"),
                                ("bottom", "Bottom", "rectangle.bottomthird.inset.filled"),
                                ("hidden", "Hidden", "eye.slash")],
                      selection: $search)
            OptionRow(title: "Category tabs",
                      options: [("top", "Top", "rectangle.topthird.inset.filled"),
                                ("bottom", "Bottom", "rectangle.bottomthird.inset.filled"),
                                ("hidden", "Hidden", "eye.slash")],
                      selection: $tabs)
            VStack(alignment: .leading, spacing: 8) {
                Text("Tab style").font(.subheadline).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    OptionCard(title: "Symbols", isOn: tabStyle == "symbols") { chooseStyle("symbols") } picture: {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                            Image(systemName: "face.smiling")
                            Image(systemName: "pawprint")
                        }
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                    }
                    OptionCard(title: "Emoji", isOn: tabStyle == "emoji") { chooseStyle("emoji") } picture: {
                        Text("🕘 😀 🐶").font(.system(size: 18))
                    }
                }
            }
            .padding(.vertical, 4)
            .disabled(tabs == "hidden")
            .opacity(tabs == "hidden" ? 0.45 : 1)
            GlassToggle(title: "Delete key",
                        subtitle: "Delete beside the tabs. ABC always stays, so there is a way back to the letters.",
                        isOn: $backspace)
        } header: {
            SectionHeader("Panel", symbol: "rectangle.3.group", color: .teal)
        }
        .glassRows()
    }

    private func chooseStyle(_ value: String) {
        guard tabStyle != value else { return }
        Feedback.choose()
        tabStyle = value
    }
}

// MARK: - Categories

/// The tabs in the order the picker shows them; each moves up or down and shows or hides.
private struct EmojiCategoriesTab: View {
    @AppStorage(SettingKey.emojiShowRecents, store: SharedStore.defaults) private var showRecents = SettingDefault.emojiShowRecents
    @State private var order: [String] = []
    @State private var hidden: Set<String> = []

    /// The system emoji keyboard's order (EmojiCategory.layout in the keyboard), Recently Used first.
    static let standard: [(key: String, title: String, emoji: String)] = [
        ("recent", "Recently used", "🕘"),
        ("smileys", "Smileys & people", "😀"),
        ("animals", "Animals & nature", "🐶"),
        ("food", "Food & drink", "🍎"),
        ("activity", "Activity", "⚽"),
        ("travel", "Travel & places", "🚗"),
        ("objects", "Objects", "💡"),
        ("symbols", "Symbols", "❤️"),
        ("flags", "Flags", "🏁")
    ]

    private func info(_ key: String) -> (key: String, title: String, emoji: String) {
        return EmojiCategoriesTab.standard.first { $0.key == key } ?? (key, key, "")
    }

    private func isShown(_ key: String) -> Bool {
        return key == "recent" ? showRecents : !hidden.contains(key)
    }

    var body: some View {
        Section {
            ForEach(order, id: \.self) { key in
                let index = order.firstIndex(of: key) ?? 0
                let category = info(key)
                HStack(spacing: 10) {
                    Text(category.emoji).font(.system(size: 22)).frame(width: 30)
                    Toggle(category.title, isOn: Binding(get: { isShown(key) }, set: { show($0, key) }))
                    VStack(spacing: 2) {
                        arrow("chevron.up", enabled: index > 0) { move(index, by: -1) }
                        arrow("chevron.down", enabled: index < order.count - 1) { move(index, by: 1) }
                    }
                }
            }
            Button("Restore the standard order") {
                Feedback.choose()
                withAnimation(.easeOut(duration: 0.2)) { order = EmojiCategoriesTab.standard.map { $0.key } }
                SharedStore.defaults.set([String](), forKey: SettingKey.emojiCategoryOrder)
            }
            .disabled(order == EmojiCategoriesTab.standard.map { $0.key })
        } header: {
            SectionHeader("Categories", symbol: "square.stack.fill", color: .indigo)
        } footer: {
            Text("The picker's tabs, top to bottom here and left to right on the keyboard. At least one category stays shown.")
        }
        .glassRows()
        .onAppear(perform: load)
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .frame(width: 30, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .accessibilityLabel(symbol == "chevron.up" ? "Move up" : "Move down")
    }

    private func load() {
        let standard = EmojiCategoriesTab.standard.map { $0.key }
        let stored = (SharedStore.defaults.stringArray(forKey: SettingKey.emojiCategoryOrder) ?? []).filter { standard.contains($0) }
        order = stored + standard.filter { !stored.contains($0) }
        hidden = Set(SharedStore.defaults.stringArray(forKey: SettingKey.emojiHiddenCategories) ?? [])
    }

    private func move(_ index: Int, by step: Int) {
        let target = index + step
        guard target >= 0, target < order.count else { return }
        Feedback.tick()
        withAnimation(.easeOut(duration: 0.2)) { order.swapAt(index, target) }
        SharedStore.defaults.set(order, forKey: SettingKey.emojiCategoryOrder)
    }

    private func show(_ on: Bool, _ key: String) {
        Feedback.tick()
        if key == "recent" {
            showRecents = on
            return
        }
        if on {
            hidden.remove(key)
        } else {
            // Never every category hidden.
            let shownCategories = order.filter { $0 != "recent" && !hidden.contains($0) }
            guard shownCategories.count > 1 else { return }
            hidden.insert(key)
        }
        SharedStore.defaults.set(Array(hidden).sorted(), forKey: SettingKey.emojiHiddenCategories)
    }
}

// MARK: - Skin tones

private struct EmojiSkinToneTab: View {
    @AppStorage(SettingKey.emojiSkinTone, store: SharedStore.defaults) private var tone = SettingDefault.emojiSkinTone
    @AppStorage(SettingKey.emojiHoldDelay, store: SharedStore.defaults) private var holdDelay = SettingDefault.emojiHoldDelay

    private static let names = ["Default", "Light", "Medium-light", "Medium", "Medium-dark", "Dark"]
    private static let waves = ["👋", "👋🏻", "👋🏼", "👋🏽", "👋🏾", "👋🏿"]

    private var current: Int { return min(max(Int(tone.rounded()), 0), 5) }

    var body: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    OptionCard(title: EmojiSkinToneTab.names[index], isOn: current == index) {
                        guard current != index else { return }
                        Feedback.choose()
                        tone = Double(index)
                    } picture: {
                        Text(EmojiSkinToneTab.waves[index]).font(.system(size: 30))
                    }
                }
            }
            .padding(.vertical, 4)
            HStack(spacing: 12) {
                Text(EmojiSkinToneTab.waves[current])
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(.tertiarySystemFill)))
                GlassSlider(title: "Hold to pick a tone", symbol: "hand.tap", value: $holdDelay,
                            range: Settings.emojiHoldDelayRange, step: 0.01) { "\(Int(($0 * 1000).rounded())) ms" }
            }
        } header: {
            SectionHeader("Default skin tone", symbol: "hand.raised.fill", color: .orange)
        } footer: {
            Text("Emoji with skin tones show in this one. Hold an emoji for the others.")
        }
        .glassRows()
    }
}
