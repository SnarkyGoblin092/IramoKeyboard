import Foundation

/// A function on the keyboard's Functions panel (the button at the left of the suggestion bar). The app's
/// Functions screen picks which ones the panel shows and in what order (Settings.keyboardTools).
/// Things the keyboard already has elsewhere (the globe key, the hide button) are not here.
enum KeyboardTool: String, CaseIterable {
    case oneHanded, numberRow, split
    case lineStart, lineEnd

    var title: String {
        switch self {
        case .oneHanded: return "One-handed"
        case .numberRow: return "Number row"
        case .split: return "Split keyboard"
        case .lineStart: return "Line start"
        case .lineEnd: return "Line end"
        }
    }

    var symbol: String {
        switch self {
        case .oneHanded: return "hand.raised"
        case .numberRow: return "number"
        case .split: return "rectangle.split.2x1"
        case .lineStart: return "arrow.left.to.line"
        case .lineEnd: return "arrow.right.to.line"
        }
    }

    /// What it does, for the app's Functions screen.
    var subtitle: String {
        switch self {
        case .oneHanded: return "One-handed keyboard on or off; the arrow beside the keys switches sides"
        case .numberRow: return "Numbers above the letters, on or off"
        case .split: return "The keys in two halves (on an iPhone, in landscape), on or off"
        case .lineStart: return "Moves the cursor to the start of the line"
        case .lineEnd: return "Moves the cursor to the end of the line"
        }
    }

    /// The tools a new install's panel shows (split only appears on an iPad).
    static let standard: [KeyboardTool] = [.oneHanded, .split, .lineStart, .lineEnd, .numberRow]

    /// Stored names in order, unknown ones dropped.
    static func list(from names: [String]) -> [KeyboardTool] {
        var seen = Set<KeyboardTool>()
        return names.compactMap { KeyboardTool(rawValue: $0) }.filter { seen.insert($0).inserted }
    }
}
