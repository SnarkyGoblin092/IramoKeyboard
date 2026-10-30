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
/// `Theme.reload()` re-reads the theme id; the controller calls it whenever it (re)builds the interface,
/// so a theme change picked in the app takes effect the next time the keyboard appears.
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
        var activeKey: UIColor
        var keyShadow: UIColor
        var keyBorder: UIColor
        var popupFill: UIColor
        var panelBackground: UIColor
        var stripFill: UIColor
        var searchField: UIColor
        var separator: UIColor
    }

    private(set) static var definition: ThemeDefinition = ThemeCatalog.native
    private(set) static var palette: Palette = makePalette(for: ThemeCatalog.native)

    // MARK: Loading

    /// The stored theme id, without touching the cached theme.
    static func storedID() -> String {
        return SharedStore.defaults.string(forKey: SettingKey.theme) ?? ThemeCatalog.defaultID
    }

    /// Re-reads the theme and accent from the settings.
    static func reload() {
        let theme = ThemeCatalog.theme(id: storedID())
        definition = theme
        palette = makePalette(for: theme)
        contrastPalette = makeContrastPalette(from: palette, kind: theme.kind)
    }

    // MARK: Flags

    static var kind: ThemeDefinition.Kind { return definition.kind }
    static var isTransparent: Bool { return kind == .transparent }
    static var isColored: Bool { return kind == .colored }
    static var isLiquidGlass: Bool { return kind == .liquidGlass }

    /// Real Liquid Glass (iOS 26 SDK + iOS 26 phone + the Liquid Glass theme).
    static var usesRealGlass: Bool { return isLiquidGlass && GlassSupport.isAvailable }

    /// Keys are blurred / see-through rather than solid.
    static var wantsClearBackdrop: Bool { return kind != .native && kind != .colored }

    /// Whether the keyboard draws its own gradient behind everything. Only the gradient themes do:
    /// Liquid Glass must stay see-through, so nothing is painted behind it.
    static var drawsBackdrop: Bool { return false }

    /// Opacity of that gradient.
    static var backdropOpacity: CGFloat { return 0.45 }

    /// Dark/light forced by the theme (gradient themes), or `.unspecified` to follow the system.
    static var interfaceStyle: UIUserInterfaceStyle {
        guard let dark = definition.isDark else { return .unspecified }
        return dark ? .dark : .light
    }

    /// Corner radius of a key of this size: the user's roundness (0...1) times half the shorter side.
    /// 0.26 gives about the native 5.5pt on a phone-sized key; 1 is a full capsule.
    static func keyCornerRadius(for size: CGSize) -> CGFloat {
        let half = min(size.width, size.height) / 2
        guard half > 0 else { return 0 }
        return min(half, CGFloat(Prefs.keyRoundness) * half)
    }

    /// Native keys carry the 1pt shadow line under them.
    static var drawsKeyShadow: Bool { return kind == .native }
    /// Everything but the native theme gets a hairline outline.
    static var drawsKeyBorder: Bool { return kind != .native && !usesRealGlass && Prefs.keyBorders }

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
    static var activeKey: UIColor { return palette.activeKey }
    static var keyShadow: UIColor { return palette.keyShadow }
    static var keyBorder: UIColor { return palette.keyBorder }
    static var popupFill: UIColor { return palette.popupFill }
    static var panelBackground: UIColor { return palette.panelBackground }
    static var stripFill: UIColor { return palette.stripFill }
    static var searchField: UIColor { return palette.searchField }
    static var separator: UIColor { return palette.separator }

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
        // Any accent the user picked wins; a gradient theme only keeps its own accent while the default is untouched.
        let userPicked = !customHex.isEmpty || accentName != SettingDefault.accent
        let gradientAccent = userPicked ? userAccent : theme.accent.uiColor
        let gradientOnAccent = userPicked ? userOnAccent : theme.onAccent.uiColor

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
                activeKey: UIColor.white,
                keyShadow: pick(UIColor(red: 0.53, green: 0.55, blue: 0.58, alpha: 1), black(0.55)),
                keyBorder: UIColor.clear,
                popupFill: pick(UIColor.white, grey(0.42)),
                panelBackground: pick(UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1), grey(0.17)),
                stripFill: UIColor.clear,
                searchField: pick(black(0.08), white(0.16)),
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
                activeKey: pick(white(0.88), white(0.78)),
                keyShadow: UIColor.clear,
                keyBorder: pick(white(0.70), white(0.28)),
                popupFill: pick(white(0.97), grey(0.30, 0.97)),
                panelBackground: pick(grey(0.92, 0.72), grey(0.10, 0.72)),
                stripFill: UIColor.clear,
                searchField: pick(black(0.08), white(0.16)),
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
                activeKey: pick(white(0.80), white(0.60)),
                keyShadow: UIColor.clear,
                keyBorder: pick(white(0.60), white(0.25)),
                popupFill: pick(white(0.94), grey(0.22, 0.94)),
                panelBackground: UIColor.clear,
                stripFill: UIColor.clear,
                searchField: pick(black(0.06), white(0.12)),
                separator: pick(black(0.12), white(0.20)))

        case .colored:
            return Palette(
                accent: gradientAccent,
                onAccent: gradientOnAccent,
                text: UIColor.label,
                keyText: theme.text.uiColor,
                secondaryText: UIColor.secondaryLabel,
                keySecondaryText: theme.secondaryText.uiColor,
                letterKey: theme.key.uiColor,
                functionKey: theme.function.uiColor,
                letterKeyPressed: theme.keyPressed.uiColor,
                functionKeyPressed: theme.functionPressed.uiColor,
                activeKey: white(0.92),
                keyShadow: UIColor.clear,
                keyBorder: pick(white(0.60), white(0.28)),
                popupFill: theme.popup.uiColor,
                panelBackground: pick(UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1), grey(0.17)),
                stripFill: UIColor.clear,
                searchField: pick(black(0.08), white(0.16)),
                separator: pick(black(0.12), white(0.20)))
        }
    }

    /// The theme's key fills for a backdrop of the other style: the same look, but standing out from it. Dark
    /// keys (on a light backdrop) are a light grey with black letters; the see-through themes stay see-through
    /// with a stronger tint. (`pick`: light keys on a dark backdrop, dark keys on a light one.)
    private static func makeContrastPalette(from base: Palette, kind: ThemeDefinition.Kind) -> Palette {
        var p = base
        if kind != .colored {
            p.keyText = UIColor.black
            p.keySecondaryText = black(0.55)
        }
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
        case .colored:
            break   // coloured themes set light/dark themselves, so they never differ from the backdrop
        }
        return p
    }

    /// Text colour on top of the shift key when it is on (always dark: the key turns near-white).
    static var onActiveKey: UIColor { return UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1) }
}
