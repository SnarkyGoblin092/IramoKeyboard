import SwiftUI

/// The emoji picker's settings, in five tabs: General (recent emoji), Layout (the grid), Panel (the search field,
/// the category tabs and the keys beside them), Categories (their order) and Skin tones. The keyboard reads them
/// each time the picker opens (Prefs, EmojiPanel).
struct EmojiView: View {
    enum Tab: Int, CaseIterable {
        case general, layout, panel, categories, skinTones

        var title: String {
            switch self {
            case .general: return tr("General")
            case .layout: return tr("Layout")
            case .panel: return tr("Panel")
            case .categories: return tr("Categories")
            case .skinTones: return tr("Skin tones")
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

    // The picker as it will look stays pinned above the settings (PinnedPreview).
    var body: some View {
        PinnedPreview(id: "emoji", height: 230, fills: true) {
            EmojiPickerPreview()
        } content: {
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
        .scrollContentBackground(.hidden)
        }
        .navigationTitle(tr("Emoji"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

/// The picker's sizes on this phone, as EmojiPanel lays it out (the stock 440 x 337pt picker, scaled by the width).
enum EmojiPickerMetrics {
    static var scale: Double { return min(1, max(0.6, DeviceMetrics.portraitWidth / 440)) }

    /// The height of an emoji cell with `rows` rows (an emoji's size is a share of it).
    static func cell(rows: Int) -> Double {
        let gridHeight = 4 * 54.8 * scale
        if rows == 4 { return min(DeviceMetrics.portraitWidth * 54.8 / 440, gridHeight / 4) }
        return gridHeight / Double(max(rows, 1))
    }
}

/// The emoji picker drawn with the Emoji screen's settings: where the search field and the tabs sit, the tabs'
/// order and style, delete, the rows, the emoji's size and spacing, the scroll direction and the skin tone.
struct EmojiPickerPreview: View {
    @AppStorage(SettingKey.emojiScroll, store: SharedStore.defaults) private var scroll = SettingDefault.emojiScroll
    @AppStorage(SettingKey.emojiRows, store: SharedStore.defaults) private var rows = SettingDefault.emojiRows
    @AppStorage(SettingKey.emojiSize, store: SharedStore.defaults) private var size = SettingDefault.emojiSize
    @AppStorage(SettingKey.emojiSpacing, store: SharedStore.defaults) private var spacing = SettingDefault.emojiSpacing
    @AppStorage(SettingKey.emojiSearchPosition, store: SharedStore.defaults) private var search = SettingDefault.emojiSearchPosition
    @AppStorage(SettingKey.emojiTabsPosition, store: SharedStore.defaults) private var tabs = SettingDefault.emojiTabsPosition
    @AppStorage(SettingKey.emojiTabStyle, store: SharedStore.defaults) private var tabStyle = SettingDefault.emojiTabStyle
    @AppStorage(SettingKey.emojiBackspaceKey, store: SharedStore.defaults) private var backspace = SettingDefault.emojiBackspaceKey
    @AppStorage(SettingKey.emojiShowRecents, store: SharedStore.defaults) private var showRecents = SettingDefault.emojiShowRecents
    @AppStorage(SettingKey.emojiSkinTone, store: SharedStore.defaults) private var tone = SettingDefault.emojiSkinTone
    @Environment(\.colorScheme) private var scheme
    /// The tabs in the Categories tab's order, without the hidden ones (re-read whenever the settings change).
    @State private var tabKeys: [String] = []

    private static let icons: [String: (symbol: String, emoji: String)] = [
        "recent": ("clock", "🕘"), "smileys": ("face.smiling", "😀"), "animals": ("pawprint", "🐶"),
        "food": ("fork.knife", "🍎"), "activity": ("sportscourt", "⚽"), "travel": ("car", "🚗"),
        "objects": ("lightbulb", "💡"), "symbols": ("heart", "❤️"), "flags": ("flag", "🏁")
    ]
    private static let standardKeys = ["recent", "smileys", "animals", "food", "activity", "travel", "objects", "symbols", "flags"]
    private static let sample = Array("😀😃😄😁😆😅🤣😂🙂🙃😉😊😇🥰😍🤩😘😗😚😙😋😛😜🤪😝🤑🤗🤭🤫🤔🤐🤨😐😑😶😏😒🙄😬😮😯😲😳🥺😦😧😨😰😥😢😭😱😖😣😞😓😩😫🥱😤😡").map { String($0) }
    /// Emoji that take a skin tone, shown among the others in the chosen one.
    private static let hands = ["👋", "👍", "👏", "🙌", "🤞", "✌️"]

    private var toneMark: String {
        let marks = ["", "\u{1F3FB}", "\u{1F3FC}", "\u{1F3FD}", "\u{1F3FE}", "\u{1F3FF}"]
        return marks[min(max(Int(tone.rounded()), 0), 5)]
    }

    private var emoji: [String] {
        let hands = EmojiPickerPreview.hands.map { $0.replacingOccurrences(of: "\u{FE0F}", with: "") + toneMark }
        var list = EmojiPickerPreview.sample
        // Hands spread through the grid so they show whatever the layout.
        for (index, hand) in hands.enumerated() where index * 7 + 3 < list.count {
            list[index * 7 + 3] = hand
        }
        return list
    }

    private func loadTabs() {
        let defaults = SharedStore.defaults
        let stored = (defaults.stringArray(forKey: SettingKey.emojiCategoryOrder) ?? [])
            .filter { EmojiPickerPreview.standardKeys.contains($0) }
        let order = stored + EmojiPickerPreview.standardKeys.filter { !stored.contains($0) }
        let hidden = Set(defaults.stringArray(forKey: SettingKey.emojiHiddenCategories) ?? [])
        let keys = order.filter { $0 == "recent" ? showRecents : !hidden.contains($0) }
        if keys != tabKeys { tabKeys = keys }
    }

    var body: some View {
        GeometryReader { geometry in
            // The picker's own shape (440 x 337 on the stock phone), fitted into the pane.
            let fitWidth = min(geometry.size.width, geometry.size.height * 440 / 337)
            let height = fitWidth * 337 / 440
            // The first layout pass can be zero-sized; drawing the grid then divides by zero.
            if fitWidth > 1 {
                picker(width: fitWidth, height: height)
                    .frame(width: fitWidth, height: height)
                    .background(RoundedRectangle(cornerRadius: 14 * fitWidth / 440, style: .continuous)
                        .fill(scheme == .dark ? Color(white: 0.17) : Color(red: 0.82, green: 0.84, blue: 0.86)))
                    .clipShape(RoundedRectangle(cornerRadius: 14 * fitWidth / 440, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear(perform: loadTabs)
        .onChange(of: showRecents) { _ in loadTabs() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in loadTabs() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Preview of the emoji picker"))
    }

    private func picker(width: CGFloat, height: CGFloat) -> some View {
        let s = width / 440
        let pill = 44 * s
        let band = 46 * s
        var top = 5 * s
        var bottom = height
        var searchY: CGFloat?
        let barY: CGFloat
        if search == "top" {
            searchY = top
            top += pill + 3 * s
        }
        if tabs == "top" {
            barY = top
            top += band
        } else {
            barY = bottom - band
            bottom -= band
        }
        if search == "bottom" {
            searchY = bottom - pill - 4 * s
            bottom -= pill + 7 * s
        }
        let gridHeight = max(20, bottom - top)
        return ZStack(alignment: .topLeading) {
            if let y = searchY {
                searchField(width: width, height: pill, scale: s).offset(x: 6 * s, y: y)
            }
            grid(width: width, height: gridHeight, scale: s).offset(y: top)
            bar(width: width, height: band, scale: s).offset(y: barY)
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func searchField(width: CGFloat, height: CGFloat, scale s: CGFloat) -> some View {
        HStack(spacing: 6 * s) {
            Image(systemName: "magnifyingglass")
            Text(tr("Search Emoji"))
            Spacer(minLength: 0)
        }
        .font(.system(size: 18 * s))
        .foregroundColor(.secondary)
        .padding(.horizontal, 13 * s)
        .frame(width: width - 12 * s, height: height)
        .background(Capsule().fill(scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)))
    }

    private func grid(width: CGFloat, height: CGFloat, scale s: CGFloat) -> some View {
        let count = max(1, Int(rows.rounded()))
        let gap = CGFloat(spacing) * s
        let side = height / CGFloat(count)
        let vertical = scroll == "vertical"
        let cellWidth: CGFloat
        let columns: Int
        let inset: CGFloat
        if vertical {
            inset = side * 0.15
            columns = max(1, Int(max(0, width - inset * 2 + gap) / max(side + gap, 1)))
            cellWidth = max(0, (width - inset * 2 - gap * CGFloat(columns - 1)) / CGFloat(columns))
        } else {
            cellWidth = count == 4 ? 54.8 * s : side
            inset = count == 4 ? 7.3 * s : side * 0.2
            columns = Int(ceil(max(0, width - inset) / max(cellWidth + gap, 1))) + 1
        }
        let font = min(cellWidth, side) * CGFloat(size)
        let list = emoji
        return ZStack(alignment: .topLeading) {
            ForEach(0..<(columns * count), id: \.self) { index in
                // Down the columns when scrolling sideways, along the rows when scrolling down.
                let column = vertical ? index % columns : index / count
                let row = vertical ? index / columns : index % count
                Text(list[index % list.count])
                    .font(.system(size: font))
                    .frame(width: cellWidth, height: side)
                    .offset(x: inset + CGFloat(column) * (cellWidth + gap),
                            y: CGFloat(row) * (vertical ? side + gap : side))
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
    }

    private func bar(width: CGFloat, height: CGFloat, scale s: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text("ABC")
                .font(.system(size: 15 * s))
                .frame(width: 56 * s)
            Spacer(minLength: 0)
            if tabs != "hidden" {
                HStack(spacing: 0) {
                    ForEach(tabKeys.indices, id: \.self) { index in
                        let key = tabKeys[index]
                        let icon = EmojiPickerPreview.icons[key] ?? ("questionmark", "❓")
                        ZStack {
                            if index == 0 { Circle().fill(.tint).frame(width: 28 * s, height: 28 * s) }
                            if tabStyle == "emoji" {
                                Text(icon.emoji).font(.system(size: 16 * s))
                            } else {
                                Image(systemName: icon.symbol)
                                    .font(.system(size: 13 * s))
                                    .foregroundColor(index == 0 ? .white : .primary)
                            }
                        }
                        .frame(width: 32 * s, height: height)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "delete.left")
                .font(.system(size: 17 * s, weight: .light))
                .frame(width: 52 * s)
                .opacity(backspace ? 1 : 0)
        }
        .foregroundColor(.primary)
        .frame(width: width, height: height)
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
            GlassToggle(title: tr("Show recent emoji"),
                        subtitle: tr("A tab of the emoji you used lately. Move it anywhere on the Categories tab."),
                        isOn: $showRecents)
            HStack(spacing: 6) {
                if recents.isEmpty {
                    Text(tr("No recent emoji yet")).foregroundColor(.secondary)
                } else {
                    ForEach(recents.prefix(6), id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 26))
                            .frame(width: 40, height: 40)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.tertiarySystemFill)))
                    }
                }
                Spacer(minLength: 8)
                Button(tr("Clear")) {
                    Settings.shared.clearRecentEmoji()
                    Feedback.delete()
                    withAnimation(.easeOut(duration: 0.2)) { recents = [] }
                }
                .disabled(recents.isEmpty)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("Order")).font(.subheadline).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    OptionCard(title: tr("Most recent"), isOn: order == "recent") { choose("recent") } picture: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock").foregroundStyle(.tint)
                            Text("😇😉😁")
                        }
                    }
                    OptionCard(title: tr("Most used"), isOn: order == "used") { choose("used") } picture: {
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
            GlassSlider(title: tr("How many to keep"), symbol: "clock.arrow.circlepath", value: $limit,
                        range: Settings.emojiRecentLimitRange, step: 1) { "\(Int($0.rounded()))" }
                .disabled(!showRecents)
                .opacity(showRecents ? 1 : 0.45)
        } header: {
            SectionHeader(tr("Recent emoji"), symbol: "clock.fill", color: .orange)
        }
        .glassRows()
        .onAppear { recents = Settings.shared.orderedRecentEmoji() }
        .onChange(of: order) { _ in recents = Settings.shared.orderedRecentEmoji() }

        Section {
            GlassToggle(title: tr("Add a space after"),
                        subtitle: tr("A space follows each emoji picked, so a run of them doesn't come out as one block."),
                        isOn: $spaceAfter)
        } header: {
            SectionHeader(tr("Typing"), symbol: "character.cursor.ibeam", color: .blue)
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
        Setup(title: tr("Familiar"), symbol: "square.grid.3x3", rows: 4, size: 0.79, spacing: 0, search: "top", tabs: "bottom"),
        Setup(title: tr("Roomy"), symbol: "square.grid.2x2", rows: 3, size: 0.85, spacing: 4, search: "top", tabs: "bottom"),
        Setup(title: tr("Dense"), symbol: "square.grid.4x3.fill", rows: 6, size: 0.80, spacing: 0, search: "top", tabs: "bottom"),
        Setup(title: tr("Grid only"), symbol: "circle.grid.3x3", rows: 5, size: 0.79, spacing: 0, search: "hidden", tabs: "hidden")
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
            SectionHeader(tr("Quick setups"), symbol: "wand.and.stars", color: .purple)
        } footer: {
            Text(tr("Grid only hides the search field and the category tabs; ABC and delete stay."))
        }
        .glassRows()

        Section {
            OptionRow(title: tr("Scroll direction"),
                      options: [("vertical", tr("Vertical"), "arrow.down"), ("horizontal", tr("Horizontal"), "arrow.right")],
                      selection: $scroll)
            GlassToggle(title: tr("Swipe to switch tabs"),
                        subtitle: tr("Swipe across the scroll direction for the next or the previous category."),
                        isOn: $swipeTabs)
            GlassSlider(title: tr("Rows"), symbol: "rectangle.split.1x2", value: $rows,
                        range: Settings.emojiRowsRange, step: 1) { "\(Int($0.rounded()))" }
            GlassSlider(title: tr("Emoji size"), symbol: "textformat.size", value: $size,
                        range: Settings.emojiSizeRange, step: 0.01) { DeviceMetrics.points(EmojiPickerMetrics.cell(rows: Int(rows.rounded())) * $0) }
            GlassSlider(title: tr("Cell spacing"), symbol: "arrow.left.and.right", value: $spacing,
                        range: Settings.emojiSpacingRange, step: 1) { "\(Int($0.rounded())) pt" }
        } header: {
            SectionHeader(tr("Grid"), symbol: "square.grid.3x3.fill", color: .blue)
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
            OptionRow(title: tr("Search field"),
                      options: [("top", tr("Top"), "rectangle.topthird.inset.filled"),
                                ("bottom", tr("Bottom"), "rectangle.bottomthird.inset.filled"),
                                ("hidden", tr("Hidden"), "eye.slash")],
                      selection: $search)
            OptionRow(title: tr("Category tabs"),
                      options: [("top", tr("Top"), "rectangle.topthird.inset.filled"),
                                ("bottom", tr("Bottom"), "rectangle.bottomthird.inset.filled"),
                                ("hidden", tr("Hidden"), "eye.slash")],
                      selection: $tabs)
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("Tab style")).font(.subheadline).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    OptionCard(title: tr("Symbols"), isOn: tabStyle == "symbols") { chooseStyle("symbols") } picture: {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                            Image(systemName: "face.smiling")
                            Image(systemName: "pawprint")
                        }
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                    }
                    OptionCard(title: tr("Emoji"), isOn: tabStyle == "emoji") { chooseStyle("emoji") } picture: {
                        Text("🕘 😀 🐶").font(.system(size: 18))
                    }
                }
            }
            .padding(.vertical, 4)
            .disabled(tabs == "hidden")
            .opacity(tabs == "hidden" ? 0.45 : 1)
            GlassToggle(title: tr("Delete key"),
                        subtitle: tr("Delete beside the tabs. ABC always stays, so there is a way back to the letters."),
                        isOn: $backspace)
        } header: {
            SectionHeader(tr("Panel"), symbol: "rectangle.3.group", color: .teal)
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
        ("recent", tr("Recently used"), "🕘"),
        ("smileys", tr("Smileys & people"), "😀"),
        ("animals", tr("Animals & nature"), "🐶"),
        ("food", tr("Food & drink"), "🍎"),
        ("activity", tr("Activity"), "⚽"),
        ("travel", tr("Travel & places"), "🚗"),
        ("objects", tr("Objects"), "💡"),
        ("symbols", tr("Symbols"), "❤️"),
        ("flags", tr("Flags"), "🏁")
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
            Button(tr("Restore the standard order")) {
                Feedback.choose()
                withAnimation(.easeOut(duration: 0.2)) { order = EmojiCategoriesTab.standard.map { $0.key } }
                SharedStore.defaults.set([String](), forKey: SettingKey.emojiCategoryOrder)
            }
            .disabled(order == EmojiCategoriesTab.standard.map { $0.key })
        } header: {
            SectionHeader(tr("Categories"), symbol: "square.stack.fill", color: .indigo)
        } footer: {
            Text(tr("The picker's tabs, top to bottom here and left to right on the keyboard. At least one category stays shown."))
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
        .accessibilityLabel(symbol == "chevron.up" ? tr("Move up") : tr("Move down"))
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

    private static var names: [String] { return [tr("Default"), tr("Light"), tr("Medium-light"), tr("Medium"), tr("Medium-dark"), tr("Dark")] }
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
                GlassSlider(title: tr("Hold to pick a tone"), symbol: "hand.tap", value: $holdDelay,
                            range: Settings.emojiHoldDelayRange, step: 0.01) { "\(Int(($0 * 1000).rounded())) ms" }
            }
        } header: {
            SectionHeader(tr("Default skin tone"), symbol: "hand.raised.fill", color: .orange)
        } footer: {
            Text(tr("Emoji with skin tones show in this one. Hold an emoji for the others."))
        }
        .glassRows()
    }
}
