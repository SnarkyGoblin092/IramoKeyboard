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
    @AppStorage(SettingKey.spaceSelect, store: SharedStore.defaults) private var spaceSelect = SettingDefault.spaceSelect
    @AppStorage(SettingKey.cursorSpeed, store: SharedStore.defaults) private var cursorSpeed = SettingDefault.cursorSpeed
    @AppStorage(SettingKey.deleteRepeatInterval, store: SharedStore.defaults) private var repeatInterval = SettingDefault.deleteRepeatInterval
    @AppStorage(SettingKey.swipeDownHide, store: SharedStore.defaults) private var swipeDownHide = SettingDefault.swipeDownHide
    @AppStorage(SettingKey.flickUpCapital, store: SharedStore.defaults) private var flickUp = SettingDefault.flickUpCapital
    @AppStorage(SettingKey.flickDownAccent, store: SharedStore.defaults) private var flickDown = SettingDefault.flickDownAccent
    @AppStorage(SettingKey.swipeTrailLength, store: SharedStore.defaults) private var trailLength = SettingDefault.swipeTrailLength
    @AppStorage(SettingKey.swipeTrailShown, store: SharedStore.defaults) private var trailShown = SettingDefault.swipeTrailShown
    @AppStorage(SettingKey.swipeTrailWidth, store: SharedStore.defaults) private var trailWidth = SettingDefault.swipeTrailWidth
    @AppStorage(SettingKey.swipeTrailOpacity, store: SharedStore.defaults) private var trailOpacity = SettingDefault.swipeTrailOpacity
    @AppStorage(SettingKey.swipeTrailColor, store: SharedStore.defaults) private var trailColor = SettingDefault.swipeTrailColor
    @AppStorage(SettingKey.swipeTrailStyle, store: SharedStore.defaults) private var trailStyle = SettingDefault.swipeTrailStyle
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @ObservedObject private var languages = EnabledLanguages.shared
    /// The page of settings shown under the keyboard.
    @State private var page: GesturesPage
    @State private var trying = false

    private let trailStyles = ["fade", "solid", "dotted", "rainbow"]
    /// Ready-made trail colours (empty: the theme's accent).
    private let trailColors = ["", "#FFFFFF", "#1C1C1E", "#FF375F", "#FF9F0A", "#FFD60A", "#30D158", "#64D2FF", "#BF5AF2"]

    private var swipeOff: Bool { return !swipe || languages.lacking(.swipe).all }

    init() {
        // A setting picked in the search opens the page it is on.
        _page = State(initialValue: GesturesPage.holding(SearchFocus.shared.request?.anchor))
    }

    var body: some View {
        GlassList {
            Section {
                SegmentedChoice(names: GesturesPage.allCases.map { $0.title }, selected: page.rawValue) { index in
                    page = GesturesPage(rawValue: index) ?? .swipe
                }
                // The keyboard, as the gestures are set now, in a sheet to try them on.
                Button {
                    Feedback.tap()
                    trying = true
                } label: {
                    Label(tr("Try the gestures"), systemImage: "hand.draw.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundColor(.white)
                        .glassTile(Capsule(), isOn: true)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            .glassRows()
            switch page {
            case .swipe: swipeSections
            case .keys: keySections
            }
        }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $trying) {
            NavigationStack {
                VStack {
                    LiveKeyboard().frame(height: 300).padding(16)
                    Spacer(minLength: 0)
                }
                .glassScreen()
                .navigationTitle(tr("Gestures"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(tr("Done")) { trying = false } } }
            }
        }
        .navigationTitle(tr("Gestures"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Pages

    /// Swipe typing and the line it draws.
    @ViewBuilder private var swipeSections: some View {
        Section {
            GlassToggle(title: tr("Swipe typing"),
                        subtitle: tr("Slide across the letters to write a word; the bar offers the other readings."),
                        isOn: $swipe, feature: .swipe)
                .searchAnchor("gestures.swipe")
            Group {
                GlassToggle(title: tr("Thumb handoff"),
                            subtitle: tr("Touch a letter with your other thumb while gliding, or just after lifting, and the same word goes on."),
                            isOn: $twoThumbs)
                GlassToggle(title: tr("Glide through space"),
                            subtitle: tr("Slide onto the space bar to finish a word, then back onto the letters for the next one."),
                            isOn: $spaceCommits)
                GlassToggle(title: tr("Phrase glide"),
                            subtitle: tr("One glide may read as two or three words (\u{201C}do it\u{201D}); the single word stays in the bar."),
                            isOn: $multiWord)
                GlassToggle(title: tr("Undo a swipe with one delete"),
                            subtitle: tr("Delete right after a swipe removes the whole word. Off: one letter at a time."),
                            isOn: $deleteSwiped)
            }
            .disabled(swipeOff)
        } header: {
            SectionHeader(tr("Letters"), symbol: "hand.draw.fill", color: .blue)
        }
        .glassRows()

        Section {
            TrailPreview(shown: trailShown, width: trailWidth, opacity: trailOpacity, style: trailStyle,
                         color: trailColor.isEmpty ? Color.currentAccent(name: accentName, hex: accentHex) : Color(hex: trailColor),
                         length: trailLength)
                .frame(height: 96)
                .searchAnchor("gestures.trail")
            GlassToggle(title: tr("Show the trail"),
                        subtitle: tr("A line follows your finger while you swipe."),
                        isOn: $trailShown)
            Group {
                SegmentedChoice(title: tr("Style"), names: [tr("Fade"), tr("Solid"), tr("Dotted"), tr("Rainbow")],
                                selected: trailStyles.firstIndex(of: trailStyle)) { trailStyle = trailStyles[$0] }
                trailColorRow
                    .disabled(trailStyle == "rainbow")
                    .opacity(trailStyle == "rainbow" ? 0.45 : 1)
                GlassSlider(title: tr("Width"), symbol: "lineweight", value: $trailWidth,
                            range: Settings.swipeTrailWidthRange, step: 1) { "\(Int($0.rounded())) pt" }
                GlassSlider(title: tr("Opacity"), symbol: "circle.lefthalf.filled", value: $trailOpacity,
                            range: Settings.swipeTrailOpacityRange, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
                GlassSlider(title: tr("Trail length"), symbol: "scribble", value: $trailLength,
                            range: Settings.swipeTrailLengthRange, step: 10) { "\(Int($0.rounded())) pt" }
            }
            .disabled(!trailShown)
            .opacity(trailShown ? 1 : 0.45)
        } header: {
            SectionHeader(tr("Swipe trail"), symbol: "scribble", color: .purple)
        } footer: {
            Text(tr("The Effects screen's trail glow adds a halo around it."))
        }
        .glassRows()
        .disabled(swipeOff)
    }

    /// The gestures that start on one key: holds and flicks on the letters, the space bar, the delete key and the bar.
    @ViewBuilder private var keySections: some View {
        Section {
            SettingSlider(tr("Hold delay"),
                          key: SettingKey.holdDelay,
                          defaultValue: SettingDefault.holdDelay,
                          range: Settings.holdDelayRange,
                          step: 0.05,
                          subtitle: tr("How long to hold a key before its accents appear")) { String(format: "%.2f s", $0) }
                .searchAnchor("gestures.accents")
            GlassToggle(title: tr("Flick up for a capital"),
                        subtitle: tr("A short flick up on a letter types it as a capital."),
                        isOn: $flickUp, feature: .capitals)
            GlassToggle(title: tr("Flick down for an accent"),
                        subtitle: tr("A short flick straight down types the key's first accent."),
                        isOn: $flickDown)
        } header: {
            SectionHeader(tr("Accents and capitals"), symbol: "textformat.abc.dottedunderline", color: .orange)
        } footer: {
            Text(tr("Flicks are short and straight; a longer slide is still swipe typing."))
        }
        .glassRows()

        Section {
            GlassToggle(title: tr("Move the cursor"),
                        subtitle: tr("Hold the space bar until the letters fade, then slide left or right."),
                        isOn: $cursor)
                .searchAnchor("gestures.space")
            Group {
                GlassToggle(title: tr("Select text"),
                            subtitle: tr("While moving the cursor, touch the keys with a second finger: the slide then selects. The bar offers copy, cut, paste and case; typing replaces the selection."),
                            isOn: $spaceSelect)
                GlassSlider(title: tr("Cursor speed"), symbol: "speedometer", value: $cursorSpeed,
                            range: Settings.cursorSpeedRange, step: 0.1) { speedName($0) }
                    .searchAnchor("gestures.cursorSpeed")
            }
            .disabled(!cursor)
            .opacity(cursor ? 1 : 0.45)
        } header: {
            SectionHeader(tr("Space bar"), symbol: "space", color: .teal)
        } footer: {
            Text(tr("A quick sideways swipe on the space bar switches the language instead."))
        }
        .glassRows()

        Section {
            GlassToggle(title: tr("Delete whole words"),
                        subtitle: tr("Slide left from the delete key: each step removes one more word."),
                        isOn: $deleteWords)
                .searchAnchor("gestures.delete")
            SettingSlider(tr("Repeat delay"),
                          key: SettingKey.deleteRepeatDelay,
                          defaultValue: SettingDefault.deleteRepeatDelay,
                          range: Settings.deleteRepeatDelayRange,
                          step: 0.05,
                          subtitle: tr("How long to hold delete before it repeats letter by letter")) { String(format: "%.2f s", $0) }
            GlassSlider(title: tr("Repeat speed"), symbol: "hare", value: Binding(
                get: { 1 / max(repeatInterval, 0.001) },
                set: { repeatInterval = 1 / max($0, 1) }),
                        range: (1 / Settings.deleteRepeatIntervalRange.upperBound)...(1 / Settings.deleteRepeatIntervalRange.lowerBound),
                        step: 1) { tr("%@ a second", "\(Int($0.rounded()))") }
                .searchAnchor("gestures.repeatSpeed")
        } header: {
            SectionHeader(tr("Delete key"), symbol: "delete.left.fill", color: .red)
        } footer: {
            Text(tr("A tap deletes one letter when you let go. Hold to repeat letter by letter, or slide left before the delay to delete whole words."))
        }
        .glassRows()

        Section {
            GlassToggle(title: tr("Swipe down to hide"),
                        subtitle: tr("Swipe down from the suggestion bar to hide the keyboard."),
                        isOn: $swipeDownHide)
                .searchAnchor("gestures.hide")
        } header: {
            SectionHeader(tr("Suggestion bar"), symbol: "text.line.first.and.arrowtriangle.forward", color: .indigo)
        }
        .glassRows()
    }

    /// The cursor's speed in words: slower, normal, faster.
    private func speedName(_ value: Double) -> String {
        if abs(value - 1) < 0.05 { return tr("Normal") }
        return String(format: "%.1f\u{00D7}", value)
    }

    /// The trail's colour: the theme's accent or one of a few, or any colour from the picker.
    private var trailColorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tr("Colour")).font(.subheadline).foregroundColor(.secondary)
                Spacer()
                ColorPicker(tr("Colour"), selection: Binding(
                    get: { trailColor.isEmpty ? Color.currentAccent(name: accentName, hex: accentHex) : Color(hex: trailColor) },
                    set: { trailColor = $0.hexString }), supportsOpacity: false)
                    .labelsHidden()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(trailColors, id: \.self) { hex in
                        let swatch = hex.isEmpty ? Color.currentAccent(name: accentName, hex: accentHex) : Color(hex: hex)
                        Button {
                            Feedback.choose()
                            trailColor = hex
                        } label: {
                            ZStack {
                                Circle().fill(swatch).frame(width: 30, height: 30)
                                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                                if hex.isEmpty {
                                    Text(tr("Theme")).font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                                }
                                if trailColor.uppercased() == hex.uppercased() {
                                    Circle().strokeBorder(Color.primary, lineWidth: 2).frame(width: 38, height: 38)
                                }
                            }
                            .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(hex.isEmpty ? tr("Theme") : hex)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// The Gestures screen's pages, as its switch under the keyboard has them.
private enum GesturesPage: Int, CaseIterable {
    case swipe, keys

    var title: String {
        switch self {
        case .swipe: return tr("Swipe typing")
        case .keys: return tr("Keys")
        }
    }

    /// The page a row the search points at is on.
    static func holding(_ anchor: String?) -> GesturesPage {
        switch anchor ?? "" {
        case "gestures.swipe", "gestures.trail", "": return .swipe
        default: return .keys
        }
    }
}

/// A swipe drawn over a few keys again and again, in the trail's look, so its settings can be seen.
private struct TrailPreview: View {
    let shown: Bool
    let width: Double
    let opacity: Double
    let style: String
    let color: Color
    let length: Double
    /// On the tab that is shown: the swipe is only drawn again and again there.
    @Environment(\.tabIsFront) private var isFront

    /// The word the finger glides through ("hello" on a keyboard row), as points in a unit square.
    private static let path: [CGPoint] = [
        CGPoint(x: 0.62, y: 0.55), CGPoint(x: 0.28, y: 0.2), CGPoint(x: 0.86, y: 0.55),
        CGPoint(x: 0.86, y: 0.55), CGPoint(x: 0.82, y: 0.2), CGPoint(x: 0.46, y: 0.85)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isFront)) { timeline in
            Canvas { context, size in
                let cycle = 2.4
                let time = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
                let progress = min(1, time / (cycle * 0.75))
                let points = TrailPreview.sampled(size: size)
                let headIndex = max(1, Int(Double(points.count - 1) * progress))
                // The keys behind the trail.
                let rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
                for (row, letters) in rows.enumerated() {
                    let count = CGFloat(letters.count)
                    let keyWidth = size.width / 10
                    let start = (size.width - keyWidth * count) / 2
                    for (column, letter) in letters.enumerated() {
                        let rect = CGRect(x: start + CGFloat(column) * keyWidth + 2, y: CGFloat(row) * size.height / 3 + 2,
                                          width: keyWidth - 4, height: size.height / 3 - 4)
                        context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(Color.primary.opacity(0.07)))
                        context.draw(Text(String(letter)).font(.system(size: 11)).foregroundColor(.secondary),
                                     at: CGPoint(x: rect.midX, y: rect.midY))
                    }
                }
                guard shown, time < cycle * 0.92 else { return }
                // The newest stretch of the path, Trail length long (in the preview's scale).
                var kept: [CGPoint] = [points[headIndex]]
                var travelled: CGFloat = 0
                let limit = CGFloat(length) * size.width / 360
                var index = headIndex
                while index > 0, travelled < limit {
                    let a = points[index], b = points[index - 1]
                    travelled += hypot(a.x - b.x, a.y - b.y)
                    kept.append(b)
                    index -= 1
                }
                kept.reverse()
                // The same curved, smoothly fading ribbon as on the keyboard.
                let shade = UIColor(color)
                let hueShift = CGFloat(time / cycle)
                context.withCGContext { cg in
                    TrailGeometry.draw(in: cg, points: kept, width: CGFloat(width), style: style, color: shade,
                                       opacity: CGFloat(opacity), hueShift: hueShift)
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// The path as a smooth curve through the word's points, as many close points across the preview.
    private static func sampled(size: CGSize) -> [CGPoint] {
        let scaled = path.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        return TrailGeometry.curve(scaled, spacing: 3)
    }
}
