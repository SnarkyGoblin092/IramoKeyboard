import Foundation

/// A function on the keyboard's Functions panel (the button at the left of the suggestion bar). The app's
/// Functions screen picks which ones the panel shows and in what order (Settings.keyboardTools).
/// Things the keyboard already has elsewhere (the globe key, the hide button) are not here.
enum KeyboardTool: String, CaseIterable {
    case oneHanded, emoji, copy, cut, paste, clipboard, numberRow, swipeTyping, autoCorrect, vibration
    case split, openApp
    case changeCase, deleteWord, lineStart, lineEnd, clearAll, insertDate, insertTime

    var title: String {
        switch self {
        case .oneHanded: return "One-handed"
        case .emoji: return "Emoji"
        case .copy: return "Copy"
        case .cut: return "Cut"
        case .paste: return "Paste"
        case .clipboard: return "Clipboard"
        case .numberRow: return "Number row"
        case .swipeTyping: return "Swipe typing"
        case .autoCorrect: return "Auto-correct"
        case .vibration: return "Vibration"
        case .split: return "Split keyboard"
        case .openApp: return "Settings"
        case .changeCase: return "Change case"
        case .deleteWord: return "Delete word"
        case .lineStart: return "Line start"
        case .lineEnd: return "Line end"
        case .clearAll: return "Clear text"
        case .insertDate: return "Date"
        case .insertTime: return "Time"
        }
    }

    var symbol: String {
        switch self {
        case .oneHanded: return "hand.raised"
        case .emoji: return "face.smiling"
        case .copy: return "doc.on.doc"
        case .cut: return "scissors"
        case .paste: return "doc.on.clipboard"
        case .clipboard: return "list.clipboard"
        case .numberRow: return "number"
        case .swipeTyping: return "hand.draw"
        case .autoCorrect: return "checkmark.seal"
        case .vibration: return "iphone.radiowaves.left.and.right"
        case .split: return "rectangle.split.2x1"
        case .openApp: return "gearshape"
        case .changeCase: return "textformat"
        case .deleteWord: return "delete.backward"
        case .lineStart: return "arrow.left.to.line"
        case .lineEnd: return "arrow.right.to.line"
        case .clearAll: return "trash"
        case .insertDate: return "calendar"
        case .insertTime: return "clock"
        }
    }

    /// What it does, for the app's Functions screen.
    var subtitle: String {
        switch self {
        case .oneHanded: return "One-handed keyboard on or off; the arrow beside the keys switches sides"
        case .emoji: return "Opens the emoji picker"
        case .copy: return "Copies the selected text"
        case .cut: return "Cuts the selected text"
        case .paste: return "Pastes what you copied"
        case .clipboard: return "The last things you copied; tap one to paste it"
        case .numberRow: return "Numbers above the letters, on or off"
        case .swipeTyping: return "Swipe typing on or off"
        case .autoCorrect: return "Auto-correction on or off"
        case .vibration: return "Key vibration on or off"
        case .split: return "iPad: the keys in two halves, on or off"
        case .openApp: return "Opens the Iramo app"
        case .changeCase: return "Selected text: UPPERCASE, lowercase, Capitalized, in turn"
        case .deleteWord: return "Deletes the word before the cursor"
        case .lineStart: return "Moves the cursor to the start of the line"
        case .lineEnd: return "Moves the cursor to the end of the line"
        case .clearAll: return "Deletes all the text of the field"
        case .insertDate: return "Types today's date"
        case .insertTime: return "Types the time now"
        }
    }

    /// The tools a new install's panel shows (split only appears on an iPad).
    static let standard: [KeyboardTool] = [.oneHanded, .split, .emoji, .copy, .paste, .clipboard, .changeCase, .deleteWord,
                                           .lineStart, .lineEnd, .numberRow, .swipeTyping, .openApp]

    /// Stored names in order, unknown ones dropped.
    static func list(from names: [String]) -> [KeyboardTool] {
        var seen = Set<KeyboardTool>()
        return names.compactMap { KeyboardTool(rawValue: $0) }.filter { seen.insert($0).inserted }
    }
}
