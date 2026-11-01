import SwiftUI

// MARK: - Live previews for the settings screens
//
// Each screen opens with a small picture of the keyboard that shows what its settings do: the suggestion bar as
// it will look, a swipe being drawn the way the gestures are set, the keys' touch areas, the vibration's feel.
// They read the same stored settings as the controls below them, so they change as the controls do.

/// A card around a preview, with a caption under it. The card is the chosen theme's keyboard background (the
/// keys inside are drawn with the theme too, through ThemeLook), so every preview looks like the user's keyboard.
struct PreviewCard<Content: View>: View {
    let caption: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        CurrentThemeLook { look in
            VStack(spacing: 10) {
                content()
                    .padding(10)
                    .background(look.backdrop())
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(caption)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(nil, value: caption)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }
}

/// A key of the previews, drawn with the theme: its shape (fill, sheen, outline, shadow or glass) and a letter.
private struct MiniKey: View {
    @AppStorage(SettingKey.keyFont, store: SharedStore.defaults) private var keyFont = SettingDefault.keyFont
    let look: ThemeLook
    var kind: ThemeLook.KeyKind = .letter
    var letter: String? = nil
    var symbol: String? = nil
    var letterColor: Color? = nil
    var fontSize: CGFloat = 14

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                look.keyShape(kind, radius: look.radius(width: size.width, height: size.height) * 0.9 + 2)
                if let letter = letter {
                    Text(letter)
                        .font(KeyFont.named(keyFont).font(size: fontSize))
                        .foregroundColor(letterColor ?? (kind == .accent ? look.onAccent : look.textColor))
                } else if let symbol = symbol {
                    Image(systemName: symbol)
                        .font(.system(size: fontSize))
                        .foregroundColor(letterColor ?? (kind == .accent ? look.onAccent : look.textColor))
                }
            }
        }
    }
}

// MARK: - Pinned preview

/// A settings screen with its preview pinned at the top: the preview stays in view while the settings below it
/// scroll, and the bar under the preview drags to make it bigger or smaller (remembered per screen). The pane is
/// never smaller than the preview needs: a card preview's natural height (caption included), or for the
/// keyboard, which sizes itself to the pane, a size where it stays readable.
struct PinnedPreview<Preview: View, Content: View>: View {
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let content: () -> Content
    /// The preview sizes itself to the pane (the keyboard) instead of keeping its own height.
    let fills: Bool

    @AppStorage private var storedHeight: Double
    @State private var dragStartHeight: CGFloat?
    @State private var liveHeight: CGFloat?
    /// The card preview's own height, measured (0 until it has been laid out once).
    @State private var naturalHeight: CGFloat = 0

    private static var topPadding: CGFloat { return 12 }
    private static var bottomPadding: CGFloat { return 6 }
    /// The keyboard preview's smallest pane.
    private static var keyboardMinimum: CGFloat { return 150 }

    /// `id` names the screen (its height is remembered under it); `height` is where it starts.
    init(id: String, height: CGFloat, fills: Bool = false,
         @ViewBuilder preview: @escaping () -> Preview,
         @ViewBuilder content: @escaping () -> Content) {
        self.preview = preview
        self.content = content
        self.fills = fills
        _storedHeight = AppStorage(wrappedValue: Double(height), "previewHeight." + id)
    }

    /// The smallest pane that still shows the whole preview.
    private var minimum: CGFloat {
        if fills { return PinnedPreview.keyboardMinimum }
        let content = naturalHeight > 0 ? naturalHeight : 90
        return content + PinnedPreview.topPadding + PinnedPreview.bottomPadding
    }

    private func clamped(_ height: CGFloat, maximum: CGFloat) -> CGFloat {
        return min(max(height, minimum), maximum)
    }

    var body: some View {
        GeometryReader { geometry in
            let maximum = max(minimum, geometry.size.height * 0.62)
            let height = clamped(liveHeight ?? CGFloat(storedHeight), maximum: maximum)
            VStack(spacing: 0) {
                Group {
                    if fills {
                        preview().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // At its own height (measured for the minimum), centred in a taller pane.
                        preview()
                            .fixedSize(horizontal: false, vertical: true)
                            .background(GeometryReader { inner in
                                Color.clear.preference(key: NaturalHeightKey.self, value: inner.size.height)
                            })
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, PinnedPreview.topPadding)
                .padding(.bottom, PinnedPreview.bottomPadding)
                .frame(height: height)
                .clipped()
                handle(height: height, maximum: maximum)
                content()
                    .frame(maxHeight: .infinity)
            }
        }
        .background(GlassBackdrop())
        .onPreferenceChange(NaturalHeightKey.self) { value in
            if abs(value - naturalHeight) > 0.5 { naturalHeight = value }
        }
    }

    /// The grip under the preview: drag it to resize (never below what the preview needs).
    private func handle(height: CGFloat, maximum: CGFloat) -> some View {
        Capsule()
            .fill(Color.secondary.opacity(0.45))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity, minHeight: 26)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if dragStartHeight == nil { dragStartHeight = height }
                    liveHeight = clamped((dragStartHeight ?? height) + value.translation.height, maximum: maximum)
                }
                .onEnded { _ in
                    if let final = liveHeight { storedHeight = Double(final) }
                    liveHeight = nil
                    dragStartHeight = nil
                    Feedback.tick()
                })
            .overlay(alignment: .bottom) { Divider().opacity(0.6) }
            .accessibilityElement()
            .accessibilityLabel("Preview size")
            .accessibilityValue("\(Int(height)) points")
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = direction == .increment ? 30 : -30
                storedHeight = Double(clamped(height + step, maximum: maximum))
            }
    }
}

private struct NaturalHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// The keyboard preview for the pinned pane: as large as the pane allows, keeping the keyboard's proportions.
struct PinnedKeyboard: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    // Its proportions (ThemePreview.aspectWithStrip): read here so a change redraws it at once.
    @AppStorage(SettingKey.keyHeight, store: SharedStore.defaults) private var keyHeight = SettingDefault.keyHeight
    @AppStorage(SettingKey.rowGap, store: SharedStore.defaults) private var rowGap = SettingDefault.rowGap
    @AppStorage(SettingKey.suggestionHeight, store: SharedStore.defaults) private var barHeight = SettingDefault.suggestionHeight
    @AppStorage(SettingKey.numberRow, store: SharedStore.defaults) private var numberRow = SettingDefault.numberRow

    var body: some View {
        GeometryReader { geometry in
            // The largest keyboard that fits: by width, or by height when the pane is short.
            let rows: Double = (numberRow ? 5 : 4) + Double(ThemePreview.extraLetterRows)
            let aspect = CGFloat(440 / (barHeight + 8 + rows * (keyHeight + rowGap)))
            let width = min(geometry.size.width, geometry.size.height * aspect)
            ThemePreview(theme: ThemeCatalog.theme(id: themeID),
                         accent: Color.currentAccent(name: accentName, hex: accentHex),
                         cornerRadius: 14)
                .frame(width: width, height: width / aspect)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(minHeight: 60)
    }
}

// MARK: - Suggestion bar

/// The suggestion bar as the Suggestion bar settings draw it, over a row of keys, while "hel" is typed.
struct SuggestionBarPreview: View {
    @AppStorage(SettingKey.suggestions, store: SharedStore.defaults) private var enabled = SettingDefault.suggestions
    @AppStorage(SettingKey.suggestionFit, store: SharedStore.defaults) private var fit = SettingDefault.suggestionFit
    @AppStorage(SettingKey.suggestionScroll, store: SharedStore.defaults) private var scroll = SettingDefault.suggestionScroll
    @AppStorage(SettingKey.suggestionStyle, store: SharedStore.defaults) private var style = SettingDefault.suggestionStyle
    @AppStorage(SettingKey.separatorStyle, store: SharedStore.defaults) private var separator = SettingDefault.separatorStyle
    @AppStorage(SettingKey.suggestionFollowTheme, store: SharedStore.defaults) private var followTheme = SettingDefault.suggestionFollowTheme
    @AppStorage(SettingKey.suggestionHeight, store: SharedStore.defaults) private var height = SettingDefault.suggestionHeight
    @AppStorage(SettingKey.suggestionTransition, store: SharedStore.defaults) private var transition = SettingDefault.suggestionTransition

    /// What the bar offers as "hel", "help" and "he" are typed in turn; the preview keeps cycling through them so
    /// the Switching setting can be seen.
    private let wordSets = [
        ["\u{201C}hel\u{201D}", "hello", "help", "held", "helmet", "helps", "helping", "helpful", "helper", "hell"],
        ["\u{201C}help\u{201D}", "helpful", "helped", "helping", "helps", "helper", "helpers", "helpless", "helpline", "helpdesk"],
        ["\u{201C}he\u{201D}", "he", "her", "here", "hey", "help", "head", "health", "hear", "heart"],
    ]
    @State private var step = 0
    /// The word space would write, on the accent pill.
    private let best = 1

    private var words: [String] { return wordSets[step % wordSets.count] }
    private var shown: [String] { return Array(words.prefix(scroll ? 10 : (fit ? 6 : 3))) }

    /// The keyboard's switch (Keyboard/SuggestionBar.animateSwitch) in SwiftUI terms.
    private var switchTransition: AnyTransition {
        switch transition {
        case "fade": return .opacity
        case "rise": return .asymmetric(insertion: .offset(y: 10).combined(with: .opacity),
                                        removal: .offset(y: -10).combined(with: .opacity))
        case "slide": return .asymmetric(insertion: .offset(x: 18).combined(with: .opacity),
                                         removal: .offset(x: -18).combined(with: .opacity))
        case "pop": return .asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity),
                                       removal: .scale(scale: 0.92).combined(with: .opacity))
        default: return .identity
        }
    }

    private var switchAnimation: Animation? {
        switch transition {
        case "instant": return nil
        case "pop": return .spring(response: 0.3, dampingFraction: 0.7)
        case "fade": return .easeOut(duration: 0.16)
        default: return .easeOut(duration: 0.18)
        }
    }

    private var caption: String {
        if !enabled { return "The bar stays empty: no suggestions while you type." }
        if scroll { return "Up to ten words; swipe the bar sideways for the rest." }
        if fit { return "Each word as wide as it needs, so more of them fit." }
        return "Three words; the one space will write sits on the accent pill."
    }

    var body: some View {
        PreviewCard(caption: caption) {
            CurrentThemeLook { look in
                GeometryReader { geometry in
                    let barWidth = geometry.size.width - 34
                    VStack(spacing: 6) {
                        HStack(spacing: 0) {
                            if enabled {
                                ZStack {
                                    slots(width: barWidth, look: look)
                                        .id(step)
                                        .transition(switchTransition)
                                }
                                .frame(width: barWidth)
                                .clipped()
                            } else {
                                Spacer()
                            }
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundColor(look.accentColor)
                                .frame(width: 34)
                        }
                        .frame(height: CGFloat(height) * 0.8)
                        keyRow(look: look)
                    }
                }
            }
            .frame(height: CGFloat(height) * 0.8 + 50)
            .animation(.easeOut(duration: 0.25), value: fit)
            .animation(.easeOut(duration: 0.25), value: scroll)
            .animation(.easeOut(duration: 0.25), value: height)
        }
        .task {
            // New words every so often, switched the chosen way.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                withAnimation(switchAnimation) { step += 1 }
            }
        }
    }

    private func natural(_ word: String) -> CGFloat { return CGFloat(word.count) * 8.5 + 26 }

    private func widths(total: CGFloat) -> [CGFloat] {
        let words = shown
        if !fit && !scroll { return Array(repeating: total / 3, count: 3) }
        var result = words.map(natural)
        if fit && !scroll {
            var used: CGFloat = 0
            var count = 0
            for width in result where used + width <= total {
                used += width
                count += 1
            }
            result = Array(result.prefix(max(count, 3)))
        }
        let sum = result.reduce(0, +)
        if sum < total, !result.isEmpty {
            let extra = (total - sum) / CGFloat(result.count)
            result = result.map { $0 + extra }
        }
        return result
    }

    private func slots(width total: CGFloat, look: ThemeLook) -> some View {
        let sizes = widths(total: total)
        return HStack(spacing: 0) {
            ForEach(0..<sizes.count, id: \.self) { index in
                slot(index: index, width: sizes[index], last: index == sizes.count - 1, look: look)
            }
        }
        .frame(width: total, alignment: .leading)
        .clipped()
        // More words wait past the edge: the strip fades out there.
        .mask(LinearGradient(stops: [.init(color: .black, location: 0),
                                     .init(color: .black, location: scroll ? 0.86 : 1),
                                     .init(color: scroll ? .clear : .black, location: 1)],
                             startPoint: .leading, endPoint: .trailing))
        .frame(width: total)
    }

    private func slot(index: Int, width: CGFloat, last: Bool, look: ThemeLook) -> some View {
        let word = index < shown.count ? shown[index] : ""
        let isBest = index == best
        let tiles = style == "segments"
        return Text(word)
            .font(.system(size: 14, weight: isBest ? .semibold : .regular))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundColor(isBest ? look.onAccent : (tiles && followTheme ? look.textColor : look.stripText))
            .padding(.horizontal, 4)
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .background {
                if isBest {
                    look.pill(radius: 9)
                        .padding(tiles ? 2 : 5)
                        .padding(.horizontal, tiles ? 0 : max(0, (width - natural(word) - 6) / 2))
                } else if tiles {
                    Group {
                        if followTheme {
                            look.keyShape(.letter, radius: 9)
                        } else {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(look.pick(Color.black.opacity(0.06), Color.white.opacity(0.12)))
                        }
                    }
                    .padding(2)
                }
            }
            .overlay(alignment: .trailing) {
                if !tiles && !last && separator != "none" {
                    Path { path in
                        path.move(to: CGPoint(x: 0.5, y: 0))
                        path.addLine(to: CGPoint(x: 0.5, y: 18))
                    }
                    .stroke(followTheme ? look.textColor.opacity(0.35) : look.stripText.opacity(0.2),
                            style: StrokeStyle(lineWidth: separator == "dotted" ? 1.5 : 1,
                                               lineCap: separator == "dotted" ? .round : .butt,
                                               dash: separator == "dashed" ? [3, 2] : (separator == "dotted" ? [0.1, 3] : [])))
                    .frame(width: 1, height: 18)
                }
            }
    }

    private func keyRow(look: ThemeLook) -> some View {
        HStack(spacing: 5) {
            ForEach(Array("qwertyuiop"), id: \.self) { letter in
                MiniKey(look: look, letter: String(letter))
            }
        }
        .glassKeyGroup(look.theme.kind == .liquidGlass, spacing: 2)
        .frame(height: 34)
    }
}

// MARK: - Gestures

/// A finger drawing on a miniature keyboard, the way the gestures are set: taps when swipe typing is off, a
/// glide for "hello", and with "Glide through space" the glide going on through the space bar to "you".
struct GesturePreview: View {
    @AppStorage(SettingKey.swipe, store: SharedStore.defaults) private var swipe = SettingDefault.swipe
    @AppStorage(SettingKey.spaceCommits, store: SharedStore.defaults) private var throughSpace = SettingDefault.spaceCommits
    @AppStorage(SettingKey.twoThumbSwipe, store: SharedStore.defaults) private var handoff = SettingDefault.twoThumbSwipe
    @AppStorage(SettingKey.multiWordSwipe, store: SharedStore.defaults) private var phrase = SettingDefault.multiWordSwipe

    private let rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]

    private var caption: String {
        if !swipe { return "Swipe typing is off: words are typed key by key." }
        if throughSpace { return "One glide writes \u{201C}hello you\u{201D}: through the space bar, then on to the next word." }
        if phrase { return "One glide can read as a few words; the single word stays in the bar." }
        if handoff { return "The second half of the word comes from your other thumb." }
        return "Glide across the letters of \u{201C}hello\u{201D} and lift at the end."
    }

    var body: some View {
        PreviewCard(caption: caption) {
            CurrentThemeLook { look in
                GeometryReader { geometry in
                    let size = geometry.size
                    let centers = keyCenters(in: size)
                    TimelineView(.animation) { timeline in
                        let progress = phase(timeline.date)
                        ZStack(alignment: .topLeading) {
                            keyboard(size: size, look: look)
                            if swipe {
                                trail(centers: centers, size: size, progress: progress, look: look)
                            } else {
                                taps(centers: centers, progress: progress, look: look)
                            }
                        }
                    }
                }
            }
            .frame(height: 150)
        }
    }

    /// 0...1 over a loop of 2.6 seconds (the glide), with a pause at the end.
    private func phase(_ date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.6) / 2.0
        return CGFloat(min(1, t))
    }

    private func keyCenters(in size: CGSize) -> [Character: CGPoint] {
        var centers: [Character: CGPoint] = [:]
        let rowHeight = size.height / 4
        let keyWidth = size.width / 10
        for (r, row) in rows.enumerated() {
            let left = (size.width - CGFloat(row.count) * keyWidth) / 2
            for (c, letter) in row.enumerated() {
                centers[letter] = CGPoint(x: left + (CGFloat(c) + 0.5) * keyWidth, y: (CGFloat(r) + 0.5) * rowHeight)
            }
        }
        centers[" "] = CGPoint(x: size.width / 2, y: 3.5 * rowHeight)
        return centers
    }

    private func keyboard(size: CGSize, look: ThemeLook) -> some View {
        let rowHeight = size.height / 4
        let keyWidth = size.width / 10
        return VStack(spacing: 0) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(Array(row), id: \.self) { letter in
                        MiniKey(look: look, letter: String(letter), fontSize: 12)
                            .padding(2)
                            .frame(width: keyWidth, height: rowHeight)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            MiniKey(look: look, letter: "space", fontSize: 11)
                .padding(2)
                .frame(width: keyWidth * 5, height: rowHeight)
        }
        .glassKeyGroup(look.theme.kind == .liquidGlass, spacing: 2)
        .frame(width: size.width, height: size.height)
    }

    private var word: [Character] {
        return throughSpace ? Array("hello you") : Array("hello")
    }

    private func trail(centers: [Character: CGPoint], size: CGSize, progress: CGFloat, look: ThemeLook) -> some View {
        let points = word.compactMap { centers[$0] }
        let path = Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
        }
        let style = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
        return ZStack {
            if handoff && !throughSpace {
                // Two thumbs: the second half in another shade.
                path.trim(from: 0, to: min(progress, 0.5)).stroke(look.accentColor, style: style)
                path.trim(from: 0.5, to: max(0.5, progress)).stroke(Color.purple, style: style)
            } else {
                path.trim(from: 0, to: progress).stroke(look.accentColor, style: style)
            }
        }
        .opacity(0.8)
    }

    private func taps(centers: [Character: CGPoint], progress: CGFloat, look: ThemeLook) -> some View {
        let letters = Array("hello")
        let shownCount = Int(progress * CGFloat(letters.count + 1))
        return ZStack(alignment: .topLeading) {
            ForEach(0..<letters.count, id: \.self) { index in
                if index < shownCount, let center = centers[letters[index]] {
                    Circle()
                        .fill(look.accentColor)
                        .frame(width: 16, height: 16)
                        .opacity(0.7)
                        .position(center)
                }
            }
        }
    }
}

// MARK: - Hitboxes

/// The bottom letter row with shift and delete: dashed outlines are the touch areas. "Letter room" moves the
/// border between the letters and shift / delete; adaptive keys give the likely next letter ("e" after "th")
/// more room.
struct HitboxPreview: View {
    @AppStorage(SettingKey.hitboxSize, store: SharedStore.defaults) private var size = SettingDefault.hitboxSize
    @AppStorage(SettingKey.adaptiveHitboxes, store: SharedStore.defaults) private var adaptive = SettingDefault.adaptiveHitboxes
    @AppStorage(SettingKey.adaptiveGrow, store: SharedStore.defaults) private var grow = SettingDefault.adaptiveGrow
    @AppStorage(SettingKey.adaptiveShrink, store: SharedStore.defaults) private var shrink = SettingDefault.adaptiveShrink
    @AppStorage(SettingKey.adaptiveStrength, store: SharedStore.defaults) private var strength = SettingDefault.adaptiveStrength

    private let letters = ["w", "e", "r", "t", "y"]

    private var caption: String {
        let likely = adaptive ? " After \u{201C}th\u{201D}, the likely \u{201C}e\u{201D} gets more room." : ""
        if size < 0.999 { return "Letters give up room to the keys beside them." + likely }
        if size > 1.001 { return "Letters take room from the keys beside them." + likely }
        return "Each key's touch area is the key you see." + likely
    }

    var body: some View {
        PreviewCard(caption: caption) {
            CurrentThemeLook { look in
            HStack(spacing: 6) {
                functionKey("shift", look: look)
                ForEach(letters, id: \.self) { letter in
                    let likely = adaptive && letter == "e"
                    let factor = size * (adaptive ? (likely ? 1 + grow * strength : 1 - shrink * strength) : 1)
                    // The key keeps its size: only its touch area (the dashed outline, an overlay that takes no
                    // room of its own) grows and shrinks.
                    MiniKey(look: look, letter: letter, letterColor: likely ? look.accentColor : nil, fontSize: 20)
                        .frame(width: 32, height: 44)
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                .foregroundColor(look.accentColor)
                                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(likely ? look.accentColor.opacity(0.12) : Color.clear))
                                .frame(width: 36 * factor, height: 50 * factor)
                                .allowsHitTesting(false)
                        }
                        .zIndex(likely ? 1 : 0)
                }
                functionKey("delete.left", look: look)
            }
            .glassKeyGroup(look.theme.kind == .liquidGlass, spacing: 2)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: size)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: adaptive)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: grow * strength - shrink)
        }
    }

    private func functionKey(_ symbol: String, look: ThemeLook) -> some View {
        MiniKey(look: look, kind: .function, symbol: symbol, fontSize: 15)
            .frame(width: 42, height: 44)
    }
}

// MARK: - Haptics

/// The vibration's feel: a wide, low bump for a soft one, a narrow spike (with a short ring) for a crisp one; as
/// tall as it is strong. Tapping it plays it.
struct HapticPreview: View {
    @AppStorage(SettingKey.vibration, store: SharedStore.defaults) private var strength = SettingDefault.vibration
    @AppStorage(SettingKey.hapticSharpness, store: SharedStore.defaults) private var sharpness = SettingDefault.hapticSharpness
    @State private var pulse = false

    private var caption: String {
        if strength < 0.01 { return "No vibration on key presses." }
        return "Tap the key to feel it. Wider means softer, taller means stronger."
    }

    var body: some View {
        PreviewCard(caption: caption) {
            CurrentThemeLook { look in
            HStack(spacing: 16) {
                Button {
                    Feedback.test(strength: strength, sharpness: sharpness)
                    withAnimation(.easeOut(duration: 0.12)) { pulse = true }
                    withAnimation(.easeOut(duration: 0.3).delay(0.12)) { pulse = false }
                } label: {
                    MiniKey(look: look, letter: "a", fontSize: 28)
                        .frame(width: 56, height: 62)
                        .scaleEffect(pulse ? 0.9 : 1)
                }
                .buttonStyle(.plain)
                .disabled(strength < 0.01)
                .accessibilityLabel("Play the vibration")
                FeelShape(sharpness: sharpness, strength: strength < 0.01 ? 0.02 : strength)
                    .stroke(look.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .background(FeelShape(sharpness: sharpness, strength: strength < 0.01 ? 0.02 : strength, closed: true)
                        .fill(look.accentColor.opacity(0.15)))
                    .frame(height: 70)
                    .animation(.easeOut(duration: 0.25), value: sharpness)
                    .animation(.easeOut(duration: 0.25), value: strength)
            }
            .padding(.horizontal, 4)
            }
        }
    }
}

private struct FeelShape: Shape {
    var sharpness: Double
    var strength: Double
    var closed = false

    var animatableData: AnimatablePair<Double, Double> {
        get { return AnimatablePair(sharpness, strength) }
        set {
            sharpness = newValue.first
            strength = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = 0.55 - 0.45 * sharpness        // share of the width the bump takes
        let center = 0.35
        let steps = 70
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let d = (t - center) / max(width / 2.5, 0.02)
            var value = exp(-d * d / 2) * strength
            if t > center && sharpness > 0.5 {
                value += sin((t - center) * 60) * 0.06 * sharpness * exp(-(t - center) * 12)
            }
            let point = CGPoint(x: rect.minX + CGFloat(t) * rect.width,
                                y: rect.maxY - CGFloat(max(0, min(1, value))) * rect.height)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        if closed {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}
