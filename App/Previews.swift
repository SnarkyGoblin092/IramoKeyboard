import SwiftUI

// MARK: - Live previews for the settings screens
//
// Each screen opens with a small picture of the keyboard that shows what its settings do: the suggestion bar as
// it will look, a swipe being drawn the way the gestures are set, the keys' touch areas, the vibration's feel.
// They read the same stored settings as the controls below them, so they change as the controls do.

/// The colours of the miniature keyboards (neutral, light and dark like the system keyboard).
private enum Mini {
    static let backdrop = Color(.systemGray5)
    static let key = Color(.systemBackground)
    static let function = Color(.systemGray3)
    static let shadow = Color.black.opacity(0.12)
}

/// A card around a preview, with a caption under it.
struct PreviewCard<Content: View>: View {
    let caption: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 10) {
            content()
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Mini.backdrop))
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

// MARK: - Pinned preview

/// A settings screen with its preview pinned at the top: the preview stays in view while the settings below it
/// scroll, and the bar under the preview drags to make it bigger or smaller (remembered per screen).
struct PinnedPreview<Preview: View, Content: View>: View {
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let content: () -> Content
    /// The preview sizes itself to the pane (the keyboard) instead of being shown at its own size, scaled to fit.
    let fills: Bool

    @AppStorage private var storedHeight: Double
    @State private var dragStartHeight: CGFloat?
    @State private var liveHeight: CGFloat?

    private static var minimumHeight: CGFloat { return 90 }

    /// `id` names the screen (its height is remembered under it); `height` is where it starts.
    init(id: String, height: CGFloat, fills: Bool = false,
         @ViewBuilder preview: @escaping () -> Preview,
         @ViewBuilder content: @escaping () -> Content) {
        self.preview = preview
        self.content = content
        self.fills = fills
        _storedHeight = AppStorage(wrappedValue: Double(height), "previewHeight." + id)
    }

    var body: some View {
        GeometryReader { geometry in
            let maximum = max(PinnedPreview.minimumHeight, geometry.size.height * 0.62)
            let height = min(max(liveHeight ?? CGFloat(storedHeight), PinnedPreview.minimumHeight), maximum)
            VStack(spacing: 0) {
                Group {
                    if fills {
                        preview().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        FitToPane { preview() }
                    }
                }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .frame(height: height)
                handle(height: height, maximum: maximum)
                content()
                    .frame(maxHeight: .infinity)
            }
        }
        .background(GlassBackdrop())
    }

    /// The grip under the preview: drag it to resize; double-tap goes back to the starting size.
    private func handle(height: CGFloat, maximum: CGFloat) -> some View {
        Capsule()
            .fill(Color.secondary.opacity(0.45))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity, minHeight: 26)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if dragStartHeight == nil { dragStartHeight = height }
                    liveHeight = min(max((dragStartHeight ?? height) + value.translation.height,
                                         PinnedPreview.minimumHeight), maximum)
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
                storedHeight = Double(min(max(height + step, PinnedPreview.minimumHeight), maximum))
            }
    }
}

/// Shows a preview at its natural size, scaled down (never up) to fit the pane, and centred in it. Previews that
/// size themselves to the space (the keyboard) simply fill it.
private struct FitToPane<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var natural: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let scale = natural.height > 0 ? min(1, geometry.size.height / natural.height) : 1
            content()
                .frame(width: geometry.size.width)
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { inner in
                    Color.clear.preference(key: NaturalSizeKey.self, value: inner.size)
                })
                .scaleEffect(scale, anchor: .center)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onPreferenceChange(NaturalSizeKey.self) { natural = $0 }
    }
}

private struct NaturalSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// The keyboard preview for the pinned pane: as large as the pane allows, keeping the keyboard's proportions.
struct PinnedKeyboard: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    var body: some View {
        GeometryReader { geometry in
            // The largest keyboard that fits: by width, or by height when the pane is short.
            let aspect = ThemePreview.aspectWithStrip
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

    private let words = ["\u{201C}hel\u{201D}", "hello", "help", "held", "helmet", "helps", "helping", "helpful", "helper", "hell"]
    /// The word space would write, on the accent pill.
    private let best = 1

    private var shown: [String] { return Array(words.prefix(scroll ? 10 : (fit ? 6 : 3))) }

    private var caption: String {
        if !enabled { return "The bar stays empty: no suggestions while you type." }
        if scroll { return "Up to ten words; swipe the bar sideways for the rest." }
        if fit { return "Each word as wide as it needs, so more of them fit." }
        return "Three words; the one space will write sits on the accent pill."
    }

    var body: some View {
        PreviewCard(caption: caption) {
            GeometryReader { geometry in
                let barWidth = geometry.size.width - 34
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        if enabled { slots(width: barWidth) } else { Spacer() }
                        Image(systemName: "keyboard.chevron.compact.down")
                            .foregroundStyle(.tint)
                            .frame(width: 34)
                    }
                    .frame(height: CGFloat(height) * 0.8)
                    keyRow
                }
            }
            .frame(height: CGFloat(height) * 0.8 + 50)
            .animation(.easeOut(duration: 0.25), value: fit)
            .animation(.easeOut(duration: 0.25), value: scroll)
            .animation(.easeOut(duration: 0.25), value: height)
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

    private func slots(width total: CGFloat) -> some View {
        let sizes = widths(total: total)
        return ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                ForEach(0..<sizes.count, id: \.self) { index in
                    slot(index: index, width: sizes[index], last: index == sizes.count - 1)
                }
            }
            .frame(width: total, alignment: .leading)
            .clipped()
            if scroll {
                // More words wait past the edge.
                LinearGradient(colors: [Mini.backdrop.opacity(0), Mini.backdrop], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 28)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: total)
    }

    private func slot(index: Int, width: CGFloat, last: Bool) -> some View {
        let word = index < shown.count ? shown[index] : ""
        let isBest = index == best
        let tiles = style == "segments"
        return Text(word)
            .font(.system(size: 14, weight: isBest ? .semibold : .regular))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundColor(isBest ? .white : .primary)
            .padding(.horizontal, 4)
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .background {
                if isBest {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.tint)
                        .padding(tiles ? 2 : 5)
                        .padding(.horizontal, tiles ? 0 : max(0, (width - natural(word) - 6) / 2))
                } else if tiles {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(followTheme ? Mini.key : Color.primary.opacity(0.07))
                        .padding(2)
                }
            }
            .overlay(alignment: .trailing) {
                if !tiles && !last && separator != "none" {
                    Path { path in
                        path.move(to: CGPoint(x: 0.5, y: 0))
                        path.addLine(to: CGPoint(x: 0.5, y: 18))
                    }
                    .stroke(followTheme ? Color.primary.opacity(0.35) : Color.primary.opacity(0.2),
                            style: StrokeStyle(lineWidth: separator == "dotted" ? 1.5 : 1,
                                               lineCap: separator == "dotted" ? .round : .butt,
                                               dash: separator == "dashed" ? [3, 2] : (separator == "dotted" ? [0.1, 3] : [])))
                    .frame(width: 1, height: 18)
                }
            }
    }

    private var keyRow: some View {
        HStack(spacing: 5) {
            ForEach(Array("qwertyuiop"), id: \.self) { letter in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Mini.key)
                    .shadow(color: Mini.shadow, radius: 0, x: 0, y: 1)
                    .overlay(Text(String(letter)).font(.system(size: 14)).foregroundColor(.primary))
            }
        }
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
            GeometryReader { geometry in
                let size = geometry.size
                let centers = keyCenters(in: size)
                TimelineView(.animation) { timeline in
                    let progress = phase(timeline.date)
                    ZStack(alignment: .topLeading) {
                        keyboard(size: size)
                        if swipe {
                            trail(centers: centers, size: size, progress: progress)
                        } else {
                            taps(centers: centers, progress: progress)
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

    private func keyboard(size: CGSize) -> some View {
        let rowHeight = size.height / 4
        let keyWidth = size.width / 10
        return VStack(spacing: 0) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(Array(row), id: \.self) { letter in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Mini.key)
                            .overlay(Text(String(letter)).font(.system(size: 12)).foregroundColor(.secondary))
                            .padding(2)
                            .frame(width: keyWidth, height: rowHeight)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Mini.key)
                .overlay(Text("space").font(.system(size: 11)).foregroundColor(.secondary))
                .padding(2)
                .frame(width: keyWidth * 5, height: rowHeight)
        }
        .frame(width: size.width, height: size.height)
    }

    private var word: [Character] {
        return throughSpace ? Array("hello you") : Array("hello")
    }

    private func trail(centers: [Character: CGPoint], size: CGSize, progress: CGFloat) -> some View {
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
                path.trim(from: 0, to: min(progress, 0.5)).stroke(.tint, style: style)
                path.trim(from: 0.5, to: max(0.5, progress)).stroke(Color.purple, style: style)
            } else {
                path.trim(from: 0, to: progress).stroke(.tint, style: style)
            }
        }
        .opacity(0.8)
    }

    private func taps(centers: [Character: CGPoint], progress: CGFloat) -> some View {
        let letters = Array("hello")
        let shownCount = Int(progress * CGFloat(letters.count + 1))
        return ZStack(alignment: .topLeading) {
            ForEach(0..<letters.count, id: \.self) { index in
                if index < shownCount, let center = centers[letters[index]] {
                    Circle()
                        .fill(.tint)
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
            HStack(spacing: 6) {
                functionKey("shift")
                ForEach(letters, id: \.self) { letter in
                    let likely = adaptive && letter == "e"
                    let factor = size * (adaptive ? (likely ? 1 + grow * strength : 1 - shrink * strength) : 1)
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Mini.key)
                            .shadow(color: Mini.shadow, radius: 0, x: 0, y: 1)
                        Text(letter)
                            .font(.system(size: 20))
                            .foregroundStyle(likely ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .foregroundStyle(.tint)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(likely ? AnyShapeStyle(TintShapeStyle().opacity(0.12)) : AnyShapeStyle(Color.clear)))
                            .frame(width: 36 * factor, height: 50 * factor)
                    }
                    .frame(width: 32, height: 44)
                    .zIndex(likely ? 1 : 0)
                }
                functionKey("delete.left")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: size)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: adaptive)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: grow * strength - shrink)
        }
    }

    private func functionKey(_ symbol: String) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Mini.function)
            .frame(width: 42, height: 44)
            .overlay(Image(systemName: symbol).font(.system(size: 15)).foregroundColor(.primary))
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
            HStack(spacing: 16) {
                Button {
                    Feedback.test(strength: strength, sharpness: sharpness)
                    withAnimation(.easeOut(duration: 0.12)) { pulse = true }
                    withAnimation(.easeOut(duration: 0.3).delay(0.12)) { pulse = false }
                } label: {
                    Text("a")
                        .font(.system(size: 28))
                        .foregroundColor(.primary)
                        .frame(width: 56, height: 62)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Mini.key)
                            .shadow(color: Mini.shadow, radius: 0, x: 0, y: 1))
                        .scaleEffect(pulse ? 0.9 : 1)
                }
                .buttonStyle(.plain)
                .disabled(strength < 0.01)
                .accessibilityLabel("Play the vibration")
                FeelShape(sharpness: sharpness, strength: strength < 0.01 ? 0.02 : strength)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .background(FeelShape(sharpness: sharpness, strength: strength < 0.01 ? 0.02 : strength, closed: true)
                        .fill(TintShapeStyle().opacity(0.15)))
                    .frame(height: 70)
                    .animation(.easeOut(duration: 0.25), value: sharpness)
                    .animation(.easeOut(duration: 0.25), value: strength)
            }
            .padding(.horizontal, 4)
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
