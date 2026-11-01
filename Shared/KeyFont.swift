import Foundation

/// The typeface of the keys and the suggestion bar (the Keys screen's Font). The system's own designs, and fonts
/// every iPhone has built in; a font without a letter (Arabic, Cyrillic in some) falls back to the system font for it.
enum KeyFont: String, CaseIterable {
    case system, rounded, serif, mono
    case avenir, futura, gillSans, optima
    case georgia, baskerville, didot
    case typewriter, chalkboard, marker, noteworthy

    var displayName: String {
        switch self {
        case .system: return "System"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .mono: return "Monospaced"
        case .avenir: return "Avenir Next"
        case .futura: return "Futura"
        case .gillSans: return "Gill Sans"
        case .optima: return "Optima"
        case .georgia: return "Georgia"
        case .baskerville: return "Baskerville"
        case .didot: return "Didot"
        case .typewriter: return "Typewriter"
        case .chalkboard: return "Chalkboard"
        case .marker: return "Marker Felt"
        case .noteworthy: return "Noteworthy"
        }
    }

    /// The built-in font's PostScript name; nil for the system font and its rounded, serif and monospaced designs.
    var postScriptName: String? {
        switch self {
        case .system, .rounded, .serif, .mono: return nil
        case .avenir: return "AvenirNext-Regular"
        case .futura: return "Futura-Medium"
        case .gillSans: return "GillSans"
        case .optima: return "Optima-Regular"
        case .georgia: return "Georgia"
        case .baskerville: return "Baskerville"
        case .didot: return "Didot"
        case .typewriter: return "AmericanTypewriter"
        case .chalkboard: return "ChalkboardSE-Regular"
        case .marker: return "MarkerFelt-Thin"
        case .noteworthy: return "Noteworthy-Light"
        }
    }

    static func named(_ id: String) -> KeyFont { return KeyFont(rawValue: id) ?? .system }
}
