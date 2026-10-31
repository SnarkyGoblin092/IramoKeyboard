import Foundation

/// Text emoticons (":)", "<3", "xD"...) and the emoji the suggestion bar offers for them.
enum Emoticons {
    private static let table: [String: String] = [
        ":)": "🙂", ":-)": "🙂", "(:": "🙂", ":]": "🙂",
        ":D": "😃", ":-D": "😃", "xD": "😆", "XD": "😆",
        ":(": "🙁", ":-(": "🙁", "):": "🙁", ":[": "🙁",
        ";)": "😉", ";-)": "😉",
        ":P": "😛", ":p": "😛", ":-P": "😛", ":-p": "😛", ";P": "😜", ";p": "😜", "xP": "😝", "XP": "😝",
        ":O": "😮", ":o": "😮", ":-O": "😮", ":-o": "😮",
        ":'(": "😢", ":')": "🥲", "T_T": "😭", "T.T": "😭", ";_;": "😭",
        ":*": "😘", ":-*": "😘",
        "<3": "❤️", "</3": "💔",
        "B)": "😎", "B-)": "😎", "8)": "😎",
        ":|": "😐", ":-|": "😐", "-_-": "😑",
        ":/": "😕", ":-/": "😕", ":\\": "😕", ":S": "😖", ":s": "😖",
        ">:(": "😠", ":@": "😡", ">:)": "😈",
        "^^": "😊", "^_^": "😊", ":3": "😺", ":$": "😳", "o_O": "😳", "O_o": "😳", "D:": "😧",
        "o/": "👋", "\\o": "👋", "\\o/": "🙌", "(y)": "👍", "(Y)": "👍", "(n)": "👎", "(N)": "👎",
    ]
    private static let longest = table.keys.map { $0.count }.max() ?? 0

    /// The emoticon that ends `text` (optionally followed by one space), standing on its own after a space or at
    /// the start: its emoji and how many characters to replace (the space included).
    static func match(atEndOf text: String) -> (emoji: String, length: Int)? {
        var body = Substring(text)
        var trailing = 0
        if body.hasSuffix(" ") {
            body = body.dropLast()
            trailing = 1
        }
        for count in stride(from: min(longest, body.count), through: 2, by: -1) {
            let candidate = String(body.suffix(count))
            guard let emoji = table[candidate] else { continue }
            let rest = body.dropLast(count)
            if rest.isEmpty || rest.last?.isWhitespace == true { return (emoji, count + trailing) }
        }
        return nil
    }
}
