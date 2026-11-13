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
        /// A keycap theme's modifier keys, each in its own colour.
        var roles: [KeyRole: RoleColor] = [:]
        /// An outline round the plain keycaps' faces (nil: none).
        var keyRing: UIColor? = nil
    }

    struct RoleColor {
        let fill: UIColor
        let text: UIColor
        /// An outline round the key's face (nil: none).
        let ring: UIColor?
    }

    /// A key's own colour and label colour in a keycap theme (nil: the usual letter or function colours).
    static func roleColor(_ role: KeyRole) -> RoleColor? { return palette.roles[role] }

    /// The outline round the plain keycaps, if the theme draws one.
    static var keyRing: UIColor? { return palette.keyRing }

    /// A letter key's own label colour in a theme that tints its letters (its ring is the same, lighter).
    static func letterTint(_ title: String) -> UIColor? {
        guard let colors = definition.colors,
              let light = colors.light.letterTint(title), let dark = colors.dark.letterTint(title) else { return nil }
        return pick(light.uiColor, dark.uiColor)
    }

    private(set) static var definition: ThemeDefinition = ThemeCatalog.native
    private(set) static var palette: Palette = makePalette(for: ThemeCatalog.native)

    // MARK: Loading

    /// The stored theme id, without touching the cached theme.
    static func storedID() -> String {
        return SharedStore.defaults.string(forKey: SettingKey.theme) ?? ThemeCatalog.defaultID
    }

    /// Re-reads the theme (with the editor's changes) and accent from the settings.
    static func reload() {
        let theme = ThemeCatalog.theme(id: storedID())
        definition = theme
        palette = applying(theme.systemStyle, to: makePalette(for: theme))
    }

    /// A system theme's editor solidity laid over its palette (the palette as it is for no edits).
    private static func applying(_ system: SystemStyle?, to base: Palette) -> Palette {
        guard let system = system else { return base }
        var p = base
        let k = CGFloat(system.keyOpacity)
        if k < 0.999 {
            func solid(_ c: UIColor) -> UIColor {
                return UIColor { trait in
                    let resolved = c.resolvedColor(with: trait)
                    var alpha: CGFloat = 0
                    resolved.getRed(nil, green: nil, blue: nil, alpha: &alpha)
                    return resolved.withAlphaComponent(alpha * k)
                }
            }
            p.letterKey = solid(p.letterKey)
            p.functionKey = solid(p.functionKey)
            p.letterKeyPressed = solid(p.letterKeyPressed)
            p.functionKeyPressed = solid(p.functionKeyPressed)
        }
        return p
    }

    // MARK: Flags

    static var kind: ThemeDefinition.Kind { return definition.kind }
    static var isLiquidGlass: Bool { return kind == .liquidGlass }

    /// Real Liquid Glass (iOS 26 SDK + iOS 26 phone + the Liquid Glass theme).
    static var usesRealGlass: Bool { return isLiquidGlass && GlassSupport.isAvailable }

    /// A system theme's own style from its editor (nil: not edited, the old global key settings apply).
    static var system: SystemStyle? { return definition.systemStyle }

    /// Corner radius of a key of this size: the roundness (0...1) times half the shorter side; the theme's own, else
    /// the user's (the Keys screen). 0.26 gives about the native 5.5pt on a phone-sized key; 1 is a
    /// full capsule.
    static func keyCornerRadius(for size: CGSize) -> CGFloat {
        let half = min(size.width, size.height) / 2
        guard half > 0 else { return 0 }
        let roundness = min(max(system?.roundness ?? Prefs.keyRoundness, 0), 1)
        return min(half, CGFloat(roundness) * half)
    }

    /// Native keys carry the 1pt shadow line under them.
    static var drawsKeyShadow: Bool { return definition.hasSolidKeys }

    /// 3D keycaps: a face set into a shell, which drops into it when pressed.
    static var isKeycap: Bool { return kind == .keycap }

    /// How the keycaps are built (KeycapProfile).
    static var keycapProfile: KeycapProfile { return definition.profile }
    // MARK: Key style (the Surface, Border and Glow of the system themes)

    enum KeySurface { case flat, sheen, raised }
    enum KeyBorderStyle { case none, thin, bold, accent }

    /// Flat fills, a soft light-to-shade sheen, or the sheen with a drop shadow under the key. Real Liquid Glass
    /// keys are glass and stay as they are.
    static var keySurface: KeySurface {
        guard !usesRealGlass else { return .flat }
        switch system?.surface ?? Prefs.keySurface {
        case "flat": return .flat
        case "sheen": return .sheen
        case "raised": return .raised
        default: return .flat
        }
    }

    /// The sheen layer's colours, top to bottom (at 0, 0.55 and 1): the soft light and shade.
    static func sheenColors(dark: Bool) -> [CGColor] {
        let strength = CGFloat(system?.sheen ?? 1)
        return [white(min(1, (dark ? 0.12 : 0.22) * strength)).cgColor, white(0).cgColor,
                black(min(1, (dark ? 0.16 : 0.08) * strength)).cgColor]
    }

    static var keyBorderStyle: KeyBorderStyle {
        let chosen: KeyBorderStyle
        switch system?.border ?? Prefs.keyBorderStyle {
        case "none": chosen = .none
        case "thin": chosen = .thin
        case "bold": chosen = .bold
        case "accent": chosen = .accent
        default: chosen = definition.hasSolidKeys ? .none : .thin
        }
        // An outline width of its own (the theme's editor) draws an outline even where the style has none.
        if let width = system?.borderWidth { return width > 0.01 ? (chosen == .none ? .thin : chosen) : .none }
        return chosen
    }

    static var drawsKeyBorder: Bool { return !usesRealGlass && keyBorderStyle != .none }

    /// The keys' and the suggestion bar's typeface at a size (KeyFont, the Keys screen's Font). Named fonts have
    /// one weight; the system designs keep the weight asked for.
    static func keyFont(ofSize size: CGFloat, weight asked: UIFont.Weight = .regular) -> UIFont {
        let weight = asked
        let choice = KeyFont.named(definition.fontID(chosen: Prefs.keyFont))
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
        if let width = system?.borderWidth, keyBorderStyle != .none {
            return CGFloat(min(max(width, 0), SystemStyle.borderWidthRange.upperBound))
        }
        switch keyBorderStyle {
        case .none: return 0
        case .thin: return 0.5
        case .bold: return 1.5
        case .accent: return 1.2
        }
    }

    /// The outline: the theme's hairline, a stronger line in the key label's colour, or the accent.
    static var keyBorderColor: UIColor {
        switch keyBorderStyle {
        case .none: return UIColor.clear
        case .thin: return kind == .native ? pick(black(0.18), white(0.28)) : palette.keyBorder
        case .bold: return keyText.withAlphaComponent(0.4)
        case .accent: return accent
        }
    }

    /// The accent glow around the keys: its blur radius and strength (0: none).
    static var keyGlow: (radius: CGFloat, opacity: Float) {
        guard !usesRealGlass else { return (0, 0) }
        switch system?.glow ?? Prefs.keyGlow {
        case "soft": return (5, 0.55)
        case "strong": return (10, 0.95)
        default: return (0, 0)
        }
    }

    /// A glow around the key labels in their own colour (radius, opacity), or nil.
    static var labelGlow: (radius: CGFloat, opacity: Float)? {
        if let amount = system?.labelGlow, amount > 0.001 { return (CGFloat(2 + 6 * amount), Float(0.35 + 0.65 * amount)) }
        return nil
    }

    // MARK: Colours (read at use time, so they follow the cached palette)

    /// The mode the user picked for the keyboard (`.unspecified`: follow the open app).
    static var appearanceStyle: UIUserInterfaceStyle {
        switch SharedStore.defaults.string(forKey: SettingKey.appearance) ?? SettingDefault.appearance {
        case "light": return .light
        case "dark": return .dark
        default: return .unspecified
        }
    }

    static var accent: UIColor { return palette.accent }
    static var onAccent: UIColor { return palette.onAccent }
    static var text: UIColor { return palette.text }
    static var secondaryText: UIColor { return palette.secondaryText }
    static var keyText: UIColor { return palette.keyText }
    static var keySecondaryText: UIColor { return palette.keySecondaryText }
    static var letterKey: UIColor { return palette.letterKey }
    static var functionKey: UIColor { return palette.functionKey }
    static var letterKeyPressed: UIColor { return palette.letterKeyPressed }
    static var functionKeyPressed: UIColor { return palette.functionKeyPressed }

    // Parts that have a colour of their own in some looks; the themes draw them with the shared colours.
    static var spaceKey: UIColor { return letterKey }
    static var returnKey: UIColor { return accent }
    static var onReturnKey: UIColor { return onAccent }
    static var shiftOn: UIColor { return accent }
    static var onShiftOn: UIColor { return onAccent }
    static var functionKeyText: UIColor { return keyText }
    static var hintText: UIColor { return keySecondaryText }
    static var pill: UIColor { return accent }
    static var onPill: UIColor { return onAccent }
    static var barIcons: UIColor { return accent }
    static var swipeTrail: UIColor { return accent }
    /// The suggestion bar's words; on key-like segments the key labels' colour.
    static func suggestionText(onSegments: Bool) -> UIColor {
        return onSegments ? keyText : text
    }

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
        let p = palette
        switch kind {
        case .native:
            return SearchLook(fill: pick(black(0.08), white(0.14)), text: UIColor.label,
                              secondaryText: UIColor.secondaryLabel, glass: false)
        case .liquidGlass where usesRealGlass:
            return SearchLook(fill: UIColor.clear, text: p.keyText, secondaryText: p.keySecondaryText, glass: true)
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

        case .keycap:
            let colors = theme.colors ?? ThemeColors(
                light: ThemeTones(key: 0xFFFFFF, text: 0x000000, dark: false, mods: KeyMods(ret: 0x007AFF)),
                dark: ThemeTones(key: 0x6B6B6B, text: 0xFFFFFF, dark: true, mods: KeyMods(ret: 0x0A84FF)))
            // Each colour follows the app's light or dark mode.
            func both(_ make: (ThemeTones) -> ThemeRGBA, _ alpha: CGFloat = 1) -> UIColor {
                return pick(make(colors.light).uiColor.withAlphaComponent(alpha),
                            make(colors.dark).uiColor.withAlphaComponent(alpha))
            }
            func maybeBoth(_ make: (ThemeTones) -> ThemeRGBA?) -> UIColor? {
                guard let light = make(colors.light), let dark = make(colors.dark) else { return nil }
                return pick(light.uiColor, dark.uiColor)
            }
            var roles: [KeyRole: RoleColor] = [:]
            for role in [KeyRole.shift, .delete, .numbers, .space, .ret] {
                // Only the keys with a look of their own (the others keep the usual colours and states).
                guard colors.light.roles[role] != nil || colors.dark.roles[role] != nil else { continue }
                roles[role] = RoleColor(fill: both { $0.fill(role) }, text: both { $0.label(role) },
                                        ring: maybeBoth { $0.roles[role]?.ring })
            }
            var palette = Palette(
                accent: both { $0.ret },
                onAccent: both { $0.label(.ret) },
                text: both { $0.stripText },
                keyText: both { $0.text },
                secondaryText: both({ $0.stripText }, 0.6),
                keySecondaryText: both({ $0.text }, 0.6),
                letterKey: both { $0.key },
                functionKey: both { $0.function },
                letterKeyPressed: both { $0.function },
                functionKeyPressed: both { $0.key },
                keyShadow: pick(black(0.22), black(0.55)),
                keyBorder: both({ $0.text }, 0.18),
                popupFill: both { $0.key },
                panelBackground: UIColor.clear,   // the keys sit on the system keyboard backdrop
                stripFill: UIColor.clear,
                separator: both({ $0.stripText }, 0.15))
            palette.roles = roles
            palette.keyRing = maybeBoth { $0.keyRing }
            return palette
        }
    }
}
