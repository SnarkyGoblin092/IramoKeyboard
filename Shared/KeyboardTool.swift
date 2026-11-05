import Foundation

/// A function on the keyboard's Functions panel (the button at the left of the suggestion bar). The app's
/// Functions screen picks which ones the panel shows and in what order (Settings.keyboardTools).
/// Things the keyboard already has elsewhere (the globe key, the hide button) are not here.
enum KeyboardTool: String, CaseIterable {
    case oneHanded, clipboard, numberRow, split, openApp
    case changeCase, lineStart, lineEnd, quotes, insertDate, insertTime

    var title: String {
        switch self {
        case .oneHanded: return "One-handed"
        case .clipboard: return "Clipboard"
        case .numberRow: return "Number row"
        case .split: return "Split keyboard"
        case .openApp: return "Settings"
        case .changeCase: return "Change case"
        case .quotes: return "Quotes"
        case .lineStart: return "Line start"
        case .lineEnd: return "Line end"
        case .insertDate: return "Date"
        case .insertTime: return "Time"
        }
    }

    var symbol: String {
        switch self {
        case .oneHanded: return "hand.raised"
        case .clipboard: return "list.clipboard"
        case .numberRow: return "number"
        case .split: return "rectangle.split.2x1"
        case .openApp: return "gearshape"
        case .changeCase: return "textformat"
        case .quotes: return "quote.opening"
        case .lineStart: return "arrow.left.to.line"
        case .lineEnd: return "arrow.right.to.line"
        case .insertDate: return "calendar"
        case .insertTime: return "clock"
        }
    }

    /// What it does, for the app's Functions screen.
    var subtitle: String {
        switch self {
        case .oneHanded: return "One-handed keyboard on or off; the arrow beside the keys switches sides"
        case .clipboard: return "The last things you copied; tap one to paste it"
        case .numberRow: return "Numbers above the letters, on or off"
        case .split: return "The keys in two halves (on an iPhone, in landscape), on or off"
        case .openApp: return "Opens the Iramo app"
        case .changeCase: return "Selected text: UPPERCASE, lowercase, Capitalized, in turn"
        case .quotes: return "Wraps the selected text in quotation marks, or types a pair"
        case .lineStart: return "Moves the cursor to the start of the line"
        case .lineEnd: return "Moves the cursor to the end of the line"
        case .insertDate: return "Types today's date"
        case .insertTime: return "Types the time now"
        }
    }

    /// The tools a new install's panel shows (split only appears on an iPad).
    static let standard: [KeyboardTool] = [.oneHanded, .split, .clipboard, .changeCase, .lineStart, .lineEnd, .quotes,
                                           .numberRow, .openApp]

    /// Stored names in order, unknown ones dropped.
    static func list(from names: [String]) -> [KeyboardTool] {
        var seen = Set<KeyboardTool>()
        return names.compactMap { KeyboardTool(rawValue: $0) }.filter { seen.insert($0).inserted }
    }
}
