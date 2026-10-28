import SwiftUI

/// A miniature keyboard drawn from a `ThemeDefinition`, so the picker shows what the keyboard will look like.
struct ThemePreview: View {
    let theme: ThemeDefinition
    let accent: AccentChoice
    var showsStrip = true
    @AppStorage(SettingKey.keyRoundness, store: SharedStore.defaults) private var roundness = SettingDefault.keyRoundness

    @Environment(\.colorScheme) private var systemScheme

    private let rows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]

    // MARK: Palette

    private var isDark: Bool {
        if let forced = theme.isDark { return forced }
        return systemScheme == .dark
    }

    private var usesThemeColours: Bool { return theme.kind == .gradient }

    private var textColor: Color {
        switch theme.kind {
        case .native: return isDark ? .white : .black
        case .gradient: return Color(theme.text)
        case .transparent, .liquidGlass: return isDark ? .white : Color(white: 0.08)
        }
    }

    private var keyFill: Color {
        switch theme.kind {
        case .native: return isDark ? Color(white: 0.42) : .white
        case .gradient: return Color(theme.key)
        case .transparent: return Color.white.opacity(isDark ? 0.18 : 0.30)
        case .liquidGlass: return Color.white.opacity(0.10)
        }
    }

    private var functionFill: Color {
        switch theme.kind {
        case .native: return isDark ? Color(white: 0.27) : Color(red: 0.68, green: 0.70, blue: 0.74)
        case .gradient: return Color(theme.function)
        case .transparent: return Color.black.opacity(isDark ? 0.30 : 0.12)
        case .liquidGlass: return Color.white.opacity(0.06)
        }
    }

    private var borderColor: Color {
        switch theme.kind {
        case .native: return .clear
        case .gradient: return Color(theme.keyBorder)
        case .transparent: return Color.white.opacity(0.45)
        case .liquidGlass: return Color.white.opacity(0.55)
        }
    }

    private var accentColor: Color {
        return usesThemeColours ? Color(theme.accent) : Color(accent: accent)
    }

    private var onAccent: Color {
        return usesThemeColours ? Color(theme.onAccent) : .white
    }

    private var panelFill: Color {
        switch theme.kind {
        case .native: return isDark ? Color(white: 0.20) : Color.white.opacity(0.70)
        case .gradient: return Color(theme.panel)
        case .transparent: return Color.white.opacity(0.28)
        case .liquidGlass: return Color.white.opacity(0.10)
        }
    }

    @ViewBuilder private var backdrop: some View {
        switch theme.kind {
        case .native:
            Rectangle().fill(isDark ? Color(white: 0.13) : Color(red: 0.82, green: 0.84, blue: 0.87))
        case .transparent, .liquidGlass, .gradient:
            if theme.gradientStops.count > 1 {
                LinearGradient(colors: theme.gradientStops.map { Color($0) },
                               startPoint: UnitPoint(x: theme.gradientStart.x, y: theme.gradientStart.y),
                               endPoint: UnitPoint(x: theme.gradientEnd.x, y: theme.gradientEnd.y))
            } else {
                Rectangle().fill(Color(white: 0.6))
            }
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
            let keyHeight = (height - stripHeight - gap * (rowCount + 2) - (showsStrip ? gap : 0)) / rowCount
            let keyWidth = (width - gap * 11) / 10
            let radius = max(0, roundness * min(keyWidth, keyHeight) / 2)

            ZStack {
                backdrop
                VStack(spacing: gap) {
                    if showsStrip { strip(radius: radius, height: stripHeight, gap: gap) }
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
                        key(symbol: "face.smiling", fill: functionFill, width: keyWidth * 1.0, height: keyHeight, radius: radius)
                        key(text: "", fill: keyFill, width: keyWidth * 4.4, height: keyHeight, radius: radius)
                        key(symbol: "return", fill: accentColor, width: keyWidth * 1.6, height: keyHeight, radius: radius, tint: onAccent)
                    }
                }
                .padding(.horizontal, gap * 1.5)
                .padding(.vertical, gap)
            }
            .frame(width: width, height: height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .allowsHitTesting(false)
    }

    // MARK: Pieces

    private func strip(radius: CGFloat, height: CGFloat, gap: CGFloat) -> some View {
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
        .background(shape(radius * 1.3, fill: panelFill, glass: false))
    }

    private func key(text: String = "",
                     symbol: String? = nil,
                     fill: Color,
                     width: CGFloat,
                     height: CGFloat,
                     radius: CGFloat,
                     tint: Color? = nil) -> some View {
        ZStack {
            shape(radius, fill: fill, glass: theme.kind == .liquidGlass)
            if let symbol = symbol {
                Image(systemName: symbol)
                    .font(.system(size: max(5, height * 0.38)))
                    .foregroundColor(tint ?? textColor)
            } else if !text.isEmpty {
                Text(text)
                    .font(.system(size: max(6, height * 0.5), weight: .regular))
                    .foregroundColor(tint ?? textColor)
            }
        }
        .frame(width: width, height: height)
    }

    @ViewBuilder
    private func shape(_ radius: CGFloat, fill: Color, glass: Bool) -> some View {
        let rounded = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if glass {
            GlassFill(radius: radius, border: borderColor)
        } else {
            rounded
                .fill(fill)
                .overlay(rounded.stroke(borderColor, lineWidth: 0.5))
                .shadow(color: theme.kind == .native ? Color.black.opacity(isDark ? 0.5 : 0.28) : .clear,
                        radius: 0, x: 0, y: 0.7)
        }
    }
}

/// A key drawn with Liquid Glass on iOS 26 and with a thin material before that.
private struct GlassFill: View {
    let radius: CGFloat
    let border: Color

    var body: some View {
        let rounded = RoundedRectangle(cornerRadius: radius, style: .continuous)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: rounded)
        } else {
            rounded.fill(.ultraThinMaterial).overlay(rounded.stroke(border, lineWidth: 0.5))
        }
        #else
        rounded.fill(.ultraThinMaterial).overlay(rounded.stroke(border, lineWidth: 0.5))
        #endif
    }
}
