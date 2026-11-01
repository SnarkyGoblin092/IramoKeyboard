import UIKit

extension AccentChoice {
    var uiColor: UIColor {
        let value = rgb
        return UIColor(red: CGFloat(value.red), green: CGFloat(value.green), blue: CGFloat(value.blue), alpha: 1)
    }
}

extension ThemeRGBA {
    var uiColor: UIColor {
        return UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }
}

/// Resolves the active theme (see `ThemeCatalog`) into the colours and flags the keyboard draws with.
///
/// `Theme.reload()` re-reads the theme id and the theme editor's changes; the controller calls it whenever it
/// (re)builds the interface, so a theme change picked in the app takes effect the next time the keyboard appears.
enum Theme {

    struct Palette {
        var accent: UIColor
        var onAccent: UIColor
        var text: UIColor
        /// Label colour on the keys (differs from `text` on coloured keys, since the strip sits on the system background).
        var keyText: UIColor
        var secondaryText: UIColor
        var keySecondaryText: UIColor
        var letterKey: UIColor
        var functionKey: UIColor
        var letterKeyPressed: UIColor
        var functionKeyPressed: UIColor
        var keyShadow: UIColor
        var keyBorder: UIColor
        var popupFill: UIColor
        var panelBackground: UIColor
        var stripFill: UIColor
        var separator: UIColor
    }

    private(set) static var definition: ThemeDefinition = ThemeCatalog.native
    private(set) static var palette: Palette = makePalette(for: ThemeCatalog.native)

    // MARK: Loading

    /// The stored theme id, without touching the cached theme.
    static func storedID() -> String {
        return SharedStore.defaults.string(forKey: SettingKey.theme) ?? ThemeCatalog.defaultID
    }

    /// The stored theme editor changes, without touching the cached theme.
    static func storedEdits() -> String {
        return SharedStore.defaults.string(forKey: SettingKey.themeEdits) ?? ""
    }

    /// Re-reads the theme (with the editor's changes) and accent from the settings.
    static func reload() {
        let theme = ThemeCatalog.theme(id: storedID(), edits: storedEdits())
        definition = theme
        palette = makePalette(for: theme)
        contrastPalette = makeContrastPalette(from: palette, kind: theme.kind)
    }

    // MARK: Flags

    static var kind: ThemeDefinition.Kind { return definition.kind }
    static var isLiquidGlass: Bool { return kind == .liquidGlass }

    /// Real Liquid Glass (iOS 26 SDK + iOS 26 phone + the Liquid Glass theme).
    static var usesRealGlass: Bool { return isLiquidGlass && GlassSupport.isAvailable }

    /// A designed theme's look (nil for the system themes).
    static var style: ThemeStyle? { return definition.style }

    /// Dark/light forced by the theme (designed themes, by their backdrop), or `.unspecified` to follow the system.
    static var interfaceStyle: UIUserInterfaceStyle {
        guard let dark = definition.isDark else { return .unspecified }
        return dark ? .dark : .light
    }

    /// Corner radius of a key of this size: the roundness (0...1) times half the shorter side; a designed theme's
    /// own, else the user's (the Keys screen). 0.26 gives about the native 5.5pt on a phone-sized key; 1 is a
    /// full capsule.
    static func keyCornerRadius(for size: CGSize) -> CGFloat {
        let half = min(size.width, size.height) / 2
        guard half > 0 else { return 0 }
        let roundness = min(max(style?.roundness ?? Prefs.keyRoundness, 0), 1)
        return min(half, CGFloat(roundness) * half)
    }

    /// Native keys carry the 1pt shadow line under them.
    static var drawsKeyShadow: Bool { return kind == .native }
    // MARK: Key style (the Keys screen's Surface, Border and Glow for the system themes; designed themes bring
    // their own sheen and depth, outline, shadow or glow)

    enum KeySurface { case flat, sheen, raised }
    enum KeyBorderStyle { case none, thin, bold, accent }

    /// Flat fills, a soft light-to-shade sheen, or the sheen with a drop shadow under the key. Real Liquid Glass
    /// keys are glass and stay as they are; a designed theme has the sheen layer when it has sheen or depth (its
    /// shadow is `designedShadow`).
    static var keySurface: KeySurface {
        guard !usesRealGlass else { return .flat }
        if let style = style { return style.hasSheen ? .sheen : .flat }
        switch Prefs.keySurface {
        case "flat": return .flat
        case "sheen": return .sheen
        case "raised": return .raised
        default: return .flat
        }
    }

    /// The sheen layer's colours, top to bottom (at 0, 0.55 and 1): a designed theme's sheen and depth, else the
    /// Keys screen's soft light and shade.
    static func sheenColors(dark: Bool) -> [CGColor] {
        if let style = style {
            let alphas = style.sheenAlphas
            return [white(CGFloat(alphas.top)).cgColor, white(0).cgColor, black(CGFloat(alphas.bottom)).cgColor]
        }
        return [white(dark ? 0.12 : 0.22).cgColor, white(0).cgColor, black(dark ? 0.16 : 0.08).cgColor]
    }

    static var keyBorderStyle: KeyBorderStyle {
        if let style = style { return style.borderWidth > 0.01 ? .thin : .none }
        switch Prefs.keyBorderStyle {
        case "none": return .none
        case "thin": return .thin
        case "bold": return .bold
        case "accent": return .accent
        default: return kind == .native ? .none : .thin
        }
    }

    static var drawsKeyBorder: Bool { return !usesRealGlass && keyBorderStyle != .none }

    /// The keys' and the suggestion bar's typeface at a size (KeyFont, the Keys screen's Font). Named fonts have
    /// one weight; the system designs keep the weight asked for.
    static func keyFont(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let choice = KeyFont.named(Prefs.keyFont)
        if let name = choice.postScriptName, let font = UIFont(name: name, size: size) { return font }
        let system = UIFont.systemFont(ofSize: size, weight: weight)
        let design: UIFontDescriptor.SystemDesign
        switch choice {
        case .rounded: design = .rounded
        case .serif: design = .serif
        case .mono: design = .monospaced
        default: return system
        }
        guard let descriptor = system.fontDescriptor.withDesign(design) else { return system }
        return UIFont(descriptor: descriptor, size: size)
    }

    static var keyBorderWidth: CGFloat {
        if let style = style { return CGFloat(min(max(style.borderWidth, 0), ThemeStyle.borderWidthRange.upperBound)) }
        switch keyBorderStyle {
        case .none: return 0
        case .thin: return 0.5
        case .bold: return 1.5
        case .accent: return 1.2
        }
    }

    /// The outline: a designed theme's line colour, or the theme's hairline, a stronger line in the key label's
    /// colour, or the accent.
    static var keyBorderColor: UIColor {
        if let style = style { return style.line.uiColor }
        switch keyBorderStyle {
        case .none: return UIColor.clear
        case .thin: return kind == .native ? pick(black(0.18), white(0.28)) : palette.keyBorder
        case .bold: return keyText.withAlphaComponent(0.4)
        case .accent: return accent
        }
    }

    /// The Keys screen's accent glow around the keys: its blur radius and strength (0: none). Designed themes
    /// have their own (`designedShadow`).
    static var keyGlow: (radius: CGFloat, opacity: Float) {
        guard !usesRealGlass, style == nil else { return (0, 0) }
        switch Prefs.keyGlow {
        case "soft": return (5, 0.55)
        case "strong": return (10, 0.95)
        default: return (0, 0)
        }
    }

    /// A designed theme's shadow under a key (soft, lift, block or glow), pressed or not; nil for none.
    static func designedShadow(pressed: Bool) -> (color: UIColor, opacity: Float, radius: CGFloat, offset: CGSize)? {
        guard let metrics = style?.shadowMetrics(pressed: pressed) else { return nil }
        return (metrics.color.uiColor, Float(metrics.opacity), CGFloat(metrics.radius),
                CGSize(width: metrics.x, height: metrics.y))
    }

    /// A designed theme's glow around the key labels (radius, opacity), or nil.
    static var labelGlow: (radius: CGFloat, opacity: Float)? {
        guard let glow = style?.labelGlow else { return nil }
        return (CGFloat(glow.radius), Float(glow.opacity))
    }

    /// A designed theme's frosted keys: a blur of the backdrop under each key's fill.
    static var frostedKeys: Bool { return style?.frosted == true && !usesRealGlass }

    // MARK: Colours (read at use time, so they follow the cached palette)

    static var accent: UIColor { return palette.accent }
    static var onAccent: UIColor { return palette.onAccent }
    static var text: UIColor { return palette.text }
    static var secondaryText: UIColor { return palette.secondaryText }
    static var keyText: UIColor { return keyPalette.keyText }
    static var keySecondaryText: UIColor { return keyPalette.keySecondaryText }
    static var letterKey: UIColor { return keyPalette.letterKey }
    static var functionKey: UIColor { return keyPalette.functionKey }
    static var letterKeyPressed: UIColor { return keyPalette.letterKeyPressed }
    static var functionKeyPressed: UIColor { return keyPalette.functionKeyPressed }

    /// Set while the keys' light/dark differs from the app's, whose style the system keyboard backdrop follows
    /// (dark keys on a light backdrop, or light keys on a dark one). The keys then use `contrastPalette`.
    static var contrastKeys = false
    private static var contrastPalette = palette
    private static var keyPalette: Palette { return contrastKeys ? contrastPalette : palette }
    static var keyShadow: UIColor { return palette.keyShadow }
    static var keyBorder: UIColor { return palette.keyBorder }
    static var popupFill: UIColor { return palette.popupFill }
    static var panelBackground: UIColor { return palette.panelBackground }
    static var stripFill: UIColor { return palette.stripFill }
    static var separator: UIColor { return palette.separator }

    /// How the emoji search pills are drawn.
    struct SearchLook {
        let fill: UIColor
        let text: UIColor
        let secondaryText: UIColor
        /// A real Liquid Glass pill (the fill is then unused).
        let glass: Bool
    }

    /// The emoji search pills match the keys: letter-key fill and label colours (the native theme keeps the stock
    /// translucent grey pill). `besideKeys`: the search bar shown over the keys, which uses the keys' palette;
    /// the picker follows the app's style, so it takes the base palette.
    static func searchLook(besideKeys: Bool) -> SearchLook {
        let p = besideKeys ? keyPalette : palette
        switch kind {
        case .native:
            return SearchLook(fill: pick(black(0.08), white(0.14)), text: UIColor.label,
                              secondaryText: UIColor.secondaryLabel, glass: false)
        case .liquidGlass where usesRealGlass:
            return SearchLook(fill: UIColor.clear, text: p.keyText, secondaryText: p.keySecondaryText, glass: true)
        case .designed:
            // A clear key would leave the pill invisible: it is at least half solid.
            let fill = style.map { $0.key.withAlpha(max($0.key.a * $0.keyOpacity, 0.5)).uiColor } ?? p.letterKey
            return SearchLook(fill: fill, text: p.keyText, secondaryText: p.keySecondaryText, glass: false)
        default:
            return SearchLook(fill: p.letterKey, text: p.keyText, secondaryText: p.keySecondaryText, glass: false)
        }
    }

    // MARK: Palettes

    private static func pick(_ light: UIColor, _ dark: UIColor) -> UIColor {
        return UIColor { trait in trait.userInterfaceStyle == .dark ? dark : light }
    }

    /// White text on dark accents, near-black on light ones (yellow, mint...).
    private static func contrastingText(on rgb: (red: Double, green: Double, blue: Double)) -> UIColor {
        let luminance = 0.299 * rgb.red + 0.587 * rgb.green + 0.114 * rgb.blue
        return luminance > 0.62 ? UIColor(white: 0.08, alpha: 1) : UIColor.white
    }

    private static func white(_ alpha: CGFloat) -> UIColor { return UIColor(white: 1.0, alpha: alpha) }
    private static func black(_ alpha: CGFloat) -> UIColor { return UIColor(white: 0.0, alpha: alpha) }
    private static func grey(_ value: CGFloat, _ alpha: CGFloat = 1) -> UIColor { return UIColor(white: value, alpha: alpha) }

    private static func makePalette(for theme: ThemeDefinition) -> Palette {
        // Read straight from the shared store (not the throttled Settings cache) so a change made in the app
        // shows up the moment the keyboard rebuilds.
        let customHex = SharedStore.defaults.string(forKey: SettingKey.accentHex) ?? ""
        let accentName = SharedStore.defaults.string(forKey: SettingKey.accent) ?? SettingDefault.accent
        let rgb = HexColor.parse(customHex) ?? (AccentChoice(rawValue: accentName) ?? .blue).rgb
        let userAccent = UIColor(red: CGFloat(rgb.red), green: CGFloat(rgb.green), blue: CGFloat(rgb.blue), alpha: 1)
        let userOnAccent = contrastingText(on: rgb)

        switch theme.kind {
        case .native:
            let nativeFunction = UIColor(red: 0.675, green: 0.702, blue: 0.745, alpha: 1)
            return Palette(
                accent: userAccent,
                onAccent: userOnAccent,
                text: UIColor.label,
                keyText: UIColor.label,
                secondaryText: UIColor.secondaryLabel,
                keySecondaryText: UIColor.secondaryLabel,
                letterKey: pick(UIColor.white, grey(0.42)),
                functionKey: pick(nativeFunction, grey(0.27)),
                letterKeyPressed: pick(nativeFunction, grey(0.27)),
                functionKeyPressed: pick(UIColor.white, grey(0.42)),
                keyShadow: pick(UIColor(red: 0.53, green: 0.55, blue: 0.58, alpha: 1), black(0.55)),
                keyBorder: UIColor.clear,
                popupFill: pick(UIColor.white, grey(0.42)),
                panelBackground: pick(UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1), grey(0.17)),
                stripFill: UIColor.clear,
                separator: pick(black(0.12), white(0.20)))

        case .transparent:
            return Palette(
                accent: userAccent,
                onAccent: userOnAccent,
                text: UIColor.label,
                keyText: UIColor.label,
                secondaryText: UIColor.secondaryLabel,
                keySecondaryText: UIColor.secondaryLabel,
                letterKey: pick(white(0.34), white(0.16)),
                functionKey: pick(black(0.12), black(0.28)),
                letterKeyPressed: pick(white(0.62), white(0.32)),
                functionKeyPressed: pick(white(0.50), white(0.24)),
                keyShadow: UIColor.clear,
                keyBorder: pick(white(0.70), white(0.28)),
                popupFill: pick(white(0.97), grey(0.30, 0.97)),
                panelBackground: pick(grey(0.92, 0.72), grey(0.10, 0.72)),
                stripFill: UIColor.clear,
                separator: pick(black(0.12), white(0.20)))

        case .liquidGlass:
            // The glass itself supplies the key surface; these fills only tint it a little
            // (and give the blur fallback on older iOS something to draw).
            return Palette(
                accent: userAccent,
                onAccent: userOnAccent,
                text: UIColor.label,
                keyText: UIColor.label,
                secondaryText: UIColor.secondaryLabel,
                keySecondaryText: UIColor.secondaryLabel,
                letterKey: GlassSupport.isAvailable ? UIColor.clear : pick(white(0.34), white(0.16)),
                functionKey: GlassSupport.isAvailable ? pick(black(0.08), white(0.10)) : pick(black(0.12), black(0.28)),
                letterKeyPressed: pick(white(0.55), white(0.30)),
                functionKeyPressed: pick(white(0.45), white(0.24)),
                keyShadow: UIColor.clear,
                keyBorder: pick(white(0.60), white(0.25)),
                popupFill: pick(white(0.94), grey(0.22, 0.94)),
                panelBackground: UIColor.clear,
                stripFill: UIColor.clear,
                separator: pick(black(0.12), white(0.20)))

        case .designed:
            // Fixed colours (the theme forces light or dark by its backdrop) and its own accent, which the theme
            // editor changes, rather than the app's.
            guard let style = theme.style else { return makePalette(for: ThemeCatalog.native) }
            return Palette(
                accent: style.accent.uiColor,
                onAccent: style.onAccent.uiColor,
                text: style.text.uiColor,
                keyText: style.text.uiColor,
                secondaryText: style.secondaryText.uiColor,
                keySecondaryText: style.secondaryText.uiColor,
                letterKey: style.keyFill.uiColor,
                functionKey: style.functionFill.uiColor,
                letterKeyPressed: style.keyPressedFill.uiColor,
                functionKeyPressed: style.functionPressedFill.uiColor,
                keyShadow: UIColor.clear,
                keyBorder: style.line.uiColor,
                popupFill: style.popupFill.uiColor,
                panelBackground: style.background.uiColor,
                stripFill: UIColor.clear,
                separator: style.text.withAlpha(0.2).uiColor)
        }
    }

    /// The theme's key fills for a backdrop of the other style: the same look, but standing out from it. Dark
    /// keys (on a light backdrop) are a light grey with black letters; the see-through themes stay see-through
    /// with a stronger tint. (`pick`: light keys on a dark backdrop, dark keys on a light one.) Designed themes
    /// force their own light or dark, so they never need it.
    private static func makeContrastPalette(from base: Palette, kind: ThemeDefinition.Kind) -> Palette {
        var p = base
        guard kind != .designed else { return p }
        p.keyText = UIColor.black
        p.keySecondaryText = black(0.55)
        switch kind {
        case .native:
            let nativeFunction = UIColor(red: 0.675, green: 0.702, blue: 0.745, alpha: 1)
            p.letterKey = pick(UIColor.white, grey(0.78))
            p.functionKey = pick(nativeFunction, grey(0.64))
            p.letterKeyPressed = pick(nativeFunction, grey(0.64))
            p.functionKeyPressed = pick(UIColor.white, grey(0.78))
        case .transparent:
            p.letterKey = pick(white(0.55), black(0.14))
            p.functionKey = pick(white(0.38), black(0.28))
            p.letterKeyPressed = pick(white(0.75), black(0.28))
            p.functionKeyPressed = pick(white(0.62), black(0.14))
        case .liquidGlass:
            // The glass is drawn light (KeyView, KeyboardView) like the theme in light mode, so these tints are
            // fixed rather than light/dark; letter keys get one too, as they otherwise stay clear.
            p.letterKey = black(0.06)
            p.functionKey = black(0.14)
            p.letterKeyPressed = black(0.22)
            p.functionKeyPressed = black(0.06)
        case .designed:
            break
        }
        return p
    }
}
