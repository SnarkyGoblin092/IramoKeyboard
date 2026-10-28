import SwiftUI

/// A miniature keyboard drawn from a `ThemeDefinition`, so the picker shows what the keyboard will look like.
/// Every theme uses the same translucent look (thin border, soft fills); only the colours differ.
struct ThemePreview: View {
    let theme: ThemeDefinition
    let accent: Color
    var showsStrip = true
    var cornerRadius: CGFloat = 14
    @AppStorage(SettingKey.keyRoundness, store: SharedStore.defaults) private var roundness = SettingDefault.keyRoundness

    @Environment(\.colorScheme) private var systemScheme

    private let rows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]

    // MARK: Palette (straight from the theme)

    /// Native follows the system, so its dark variant is swapped in here; every other theme is fixed.
    private var nativeDark: Bool { return theme.kind == .native && systemScheme == .dark }

    private var textColor: Color { return nativeDark ? .white : Color(theme.text) }
    private var keyFill: Color { return nativeDark ? Color(white: 0.42) : Color(theme.key) }
    private var functionFill: Color { return nativeDark ? Color(white: 0.27) : Color(theme.function) }
    private var borderColor: Color { return Color(theme.keyBorder) }
    private var panelFill: Color { return nativeDark ? Color(white: 0.20) : Color(theme.panel) }

    /// Gradient themes carry their own accent; the others use the accent chosen in the app.
    private var accentColor: Color { return theme.kind == .gradient ? Color(theme.accent) : accent }
    private var onAccent: Color { return theme.kind == .gradient ? Color(theme.onAccent) : .white }

    @ViewBuilder private var backdrop: some View {
        if nativeDark {
            Rectangle().fill(Color(white: 0.13))
        } else if theme.gradientStops.count > 1 {
            LinearGradient(colors: theme.gradientStops.map { Color($0) },
                           startPoint: UnitPoint(x: theme.gradientStart.x, y: theme.gradientStart.y),
                           endPoint: UnitPoint(x: theme.gradientEnd.x, y: theme.gradientEnd.y))
        } else {
            Rectangle().fill(Color(white: 0.6))
        }
    }

    // MARK: Body

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let gap = max(1.5, width * 0.012)
            let stripHeight = showsStrip ? height * 0.15 : 0
            let rowCount: CGFloat = 4
            let keyHeight = max(1, (height - stripHeight - gap * (rowCount + 2) - (showsStrip ? gap : 0)) / rowCount)
            let keyWidth = max(1, (width - gap * 11) / 10)
            let radius = max(0, roundness * min(keyWidth, keyHeight) / 2)

            ZStack {
                backdrop
                VStack(spacing: gap) {
                    if showsStrip { strip(radius: radius, height: stripHeight) }
                    ForEach(0..<rows.count, id: \.self) { index in
                        HStack(spacing: gap) {
                            if index == 2 {
                                key(symbol: "shift", fill: functionFill, width: keyWidth * 1.4, height: keyHeight, radius: radius)
                            }
                            ForEach(rows[index], id: \.self) { letter in
                                key(text: letter, fill: keyFill, width: keyWidth, height: keyHeight, radius: radius)
                            }
                            if index == 2 {
                                key(symbol: "delete.left", fill: functionFill, width: keyWidth * 1.4, height: keyHeight, radius: radius)
                            }
                        }
                    }
                    HStack(spacing: gap) {
                        key(text: "123", fill: functionFill, width: keyWidth * 1.3, height: keyHeight, radius: radius)
                        key(symbol: "face.smiling", fill: functionFill, width: keyWidth, height: keyHeight, radius: radius)
                        key(text: "", fill: keyFill, width: keyWidth * 4.4, height: keyHeight, radius: radius)
                        key(symbol: "return", fill: accentColor, width: keyWidth * 1.6, height: keyHeight, radius: radius, tint: onAccent)
                    }
                }
                .padding(.horizontal, gap * 1.5)
                .padding(.vertical, gap)
            }
            .frame(width: width, height: height)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Pieces

    private func strip(radius: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(["the", "that", "this"], id: \.self) { word in
                Text(word)
                    .font(.system(size: max(6, height * 0.42)))
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity)
            }
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: max(6, height * 0.42)))
                .foregroundColor(textColor.opacity(0.7))
                .frame(width: height * 1.5)
        }
        .frame(height: height)
        .background(shape(radius * 1.3, fill: panelFill))
    }

    private func key(text: String = "",
                     symbol: String? = nil,
                     fill: Color,
                     width: CGFloat,
                     height: CGFloat,
                     radius: CGFloat,
                     tint: Color? = nil) -> some View {
        ZStack {
            shape(radius, fill: fill)
            if let symbol = symbol {
                Image(systemName: symbol)
                    .font(.system(size: max(5, height * 0.38)))
                    .foregroundColor(tint ?? textColor)
            } else if !text.isEmpty {
                Text(text)
                    .font(.system(size: max(6, height * 0.5)))
                    .foregroundColor(tint ?? textColor)
            }
        }
        .frame(width: width, height: height)
    }

    private func shape(_ radius: CGFloat, fill: Color) -> some View {
        let rounded = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return rounded
            .fill(fill)
            .overlay(rounded.stroke(borderColor, lineWidth: 0.5))
    }
}
