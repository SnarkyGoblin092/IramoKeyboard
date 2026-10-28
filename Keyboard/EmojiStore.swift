import UIKit
import CoreText

struct EmojiItem {
    let base: String
    let variants: [String]   // skin tones etc., not including `base`
}

struct EmojiGroup {
    let name: String
    let icon: String
    let items: [EmojiItem]
}

private struct EmojiFile: Decodable {
    struct Group: Decodable {
        let name: String
        let icon: String
        let items: [[String]]   // [base, variant, variant, ...]
    }
    let version: String
    let groups: [Group]
}

/// Whether THIS iPhone can actually draw an emoji.
///
/// The emoji list is generated from the newest Unicode data at build time, which can be newer
/// than the emoji font on the phone. Anything the phone cannot draw is hidden instead of
/// showing an empty box.
enum EmojiSupport {
    private static let font: UIFont = UIFont(name: "AppleColorEmoji", size: 24) ?? UIFont.systemFont(ofSize: 24)
    private static let ctFont: CTFont = CTFontCreateWithName(font.fontName as CFString, 24, nil)
    private static let referenceWidth: Double = lineWidth("😀")

    static func isSupported(_ emoji: String) -> Bool {
        let scalars = Array(emoji.unicodeScalars)

        // 1. Every "real" emoji component must have a glyph in the system emoji font.
        for scalar in scalars {
            let value = scalar.value
            if value == 0x200D || value == 0xFE0F || value == 0x20E3 { continue }   // joiner, selector, keycap
            if value >= 0x1F3FB && value <= 0x1F3FF { continue }                    // skin tones
            if value >= 0x1F1E6 && value <= 0x1F1FF { continue }                    // regional indicators
            if value >= 0xE0000 && value <= 0xE007F { continue }                    // tag characters
            if value >= 0x1F000 && !hasGlyph(scalar) { return false }
        }

        // 2. A multi-part sequence must collapse into ONE glyph. If the phone does not know the
        //    combination it draws the parts side by side, which makes the line much wider.
        let parts = scalars.filter { $0.value != 0xFE0F }.count
        if parts > 1 && lineWidth(emoji) > referenceWidth * 1.45 {
            return false
        }
        return true
    }

    private static func hasGlyph(_ scalar: Unicode.Scalar) -> Bool {
        let units = Array(String(scalar).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        _ = CTFontGetGlyphsForCharacters(ctFont, units, &glyphs, units.count)
        return (glyphs.first ?? 0) != 0
    }

    private static func lineWidth(_ text: String) -> Double {
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        return CTLineGetTypographicBounds(line, nil, nil, nil)
    }
}

/// Emoji picker data and emoji suggestions for typed words.
final class EmojiStore {
    static let shared = EmojiStore()

    private(set) var groups: [EmojiGroup] = []
    private(set) var isReady = false
    private(set) var unicodeVersion = ""

    private var keywords: [Language: [String: [String]]] = [:]
    private var isLoading = false
    private var waiting: [() -> Void] = []

    private init() {}

    /// Loads (once) in the background. `completion` runs on the main thread when data is ready.
    func loadIfNeeded(completion: (() -> Void)? = nil) {
        if isReady {
            completion?()
            return
        }
        if let completion = completion { waiting.append(completion) }
        if isLoading { return }
        isLoading = true

        DispatchQueue.global(qos: .utility).async {
            let loaded = EmojiStore.loadGroups()
            var words: [Language: [String: [String]]] = [:]
            for language in Language.allCases {
                words[language] = EmojiStore.loadKeywords(language)
            }
            DispatchQueue.main.async {
                self.groups = loaded.groups
                self.unicodeVersion = loaded.version
                self.keywords = words
                self.isReady = true
                self.isLoading = false
                let callbacks = self.waiting
                self.waiting = []
                callbacks.forEach { $0() }
            }
        }
    }

    /// Up to `limit` emoji that match a complete word, e.g. "smile" -> 😀.
    func suggestions(for word: String, language: Language, limit: Int) -> [String] {
        let key = TextFolding.fold(word)
        guard key.count >= 2, let matches = keywords[language]?[key] else { return [] }
        var result: [String] = []
        for emoji in matches where EmojiSupport.isSupported(emoji) {
            result.append(emoji)
            if result.count >= limit { break }
        }
        return result
    }

    // MARK: Background loading

    private static func loadGroups() -> (groups: [EmojiGroup], version: String) {
        guard let url = Bundle.main.url(forResource: "emoji", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(EmojiFile.self, from: data) else {
            return ([], "")
        }
        let version = file.version

        var total = 0
        var kept = 0
        var filtered: [EmojiGroup] = []
        var everything: [EmojiGroup] = []

        for group in file.groups {
            var supportedItems: [EmojiItem] = []
            var allItems: [EmojiItem] = []
            for raw in group.items {
                guard let base = raw.first else { continue }
                let variants = Array(raw.dropFirst())
                allItems.append(EmojiItem(base: base, variants: variants))
                total += 1
                if EmojiSupport.isSupported(base) {
                    kept += 1
                    supportedItems.append(EmojiItem(base: base, variants: variants.filter { EmojiSupport.isSupported($0) }))
                }
            }
            if !supportedItems.isEmpty {
                filtered.append(EmojiGroup(name: group.name, icon: group.icon, items: supportedItems))
            }
            everything.append(EmojiGroup(name: group.name, icon: group.icon, items: allItems))
        }

        // Safety net: if the support check somehow rejects most emoji, trust the data instead.
        if total > 0 && kept * 2 < total {
            return (everything, version)
        }
        return (filtered, version)
    }

    private static func loadKeywords(_ language: Language) -> [String: [String]] {
        guard let url = Bundle.main.url(forResource: "emoji_keywords_\(language.rawValue)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return table
    }
}
