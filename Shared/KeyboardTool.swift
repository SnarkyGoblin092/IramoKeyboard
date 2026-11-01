import Foundation

/// A function on the keyboard's Functions panel (the button at the left of the suggestion bar). The app's
/// Functions screen picks which ones the panel shows and in what order (Settings.keyboardTools).
enum KeyboardTool: String, CaseIterable {
    case oneHanded, emoji, copy, cut, paste, clipboard, numberRow, swipeTyping, autoCorrect, vibration, nextLanguage
    case split, hideKeyboard, openApp

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
        case .nextLanguage: return "Next language"
        case .split: return "Split keyboard"
        case .hideKeyboard: return "Hide keyboard"
        case .openApp: return "Settings"
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
        case .nextLanguage: return "globe"
        case .split: return "rectangle.split.2x1"
        case .hideKeyboard: return "keyboard.chevron.compact.down"
        case .openApp: return "gearshape"
        }
    }

    /// What it does, for the app's Functions screen.
    var subtitle: String {
        switch self {
        case .oneHanded: return "Off, left hand or right hand, in turn"
        case .emoji: return "Opens the emoji picker"
        case .copy: return "Copies the selected text"
        case .cut: return "Cuts the selected text"
        case .paste: return "Pastes what you copied"
        case .clipboard: return "The last things you copied; tap one to paste it"
        case .numberRow: return "Numbers above the letters, on or off"
        case .swipeTyping: return "Swipe typing on or off"
        case .autoCorrect: return "Auto-correction on or off"
        case .vibration: return "Key vibration on or off"
        case .nextLanguage: return "Switches to your next language"
        case .split: return "iPad: the keys in two halves, on or off"
        case .hideKeyboard: return "Puts the keyboard away"
        case .openApp: return "Opens the Iramo app"
        }
    }

    /// Copy, cut, paste and the clipboard use the system clipboard, which needs Full Access.
    var needsFullAccess: Bool {
        return self == .copy || self == .cut || self == .paste || self == .clipboard
    }

    /// The tools a new install's panel shows.
    static let standard: [KeyboardTool] = [.oneHanded, .emoji, .copy, .paste, .clipboard, .numberRow, .swipeTyping, .nextLanguage, .openApp]

    /// Stored names in order, unknown ones dropped.
    static func list(from names: [String]) -> [KeyboardTool] {
        var seen = Set<KeyboardTool>()
        return names.compactMap { KeyboardTool(rawValue: $0) }.filter { seen.insert($0).inserted }
    }
}
