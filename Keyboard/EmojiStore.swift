import UIKit
import CoreText

struct EmojiItem {
    let base: String
    let variants: [String]   // skin tones etc., not including `base`
}

/// One tab of the picker, laid out like the system keyboard's emoji categories.
struct EmojiCategory {
    let key: String
    let symbol: String         // SF Symbol for the tab
    let fallbackIcon: String   // used if the symbol does not exist on this iOS version
    let items: [EmojiItem]

    private static let titles: [String: (en: String, hu: String)] = [
        "recent": ("Recently Used", "Legutóbbi"),
        "smileys": ("Smileys & People", "Mosolygók és emberek"),
        "animals": ("Animals & Nature", "Állatok és természet"),
        "food": ("Food & Drink", "Étel és ital"),
        "activity": ("Activity", "Tevékenység"),
        "travel": ("Travel & Places", "Utazás és helyek"),
        "objects": ("Objects", "Tárgyak"),
        "symbols": ("Symbols", "Szimbólumok"),
        "flags": ("Flags", "Zászlók")
    ]

    func title(for language: Language) -> String {
        guard let pair = EmojiCategory.titles[key] else { return key }
        return language == .hungarian ? pair.hu : pair.en
    }

    /// Display order, names, and tab icons - the same order as the system emoji keyboard.
    static let layout: [(key: String, symbol: String, fallback: String)] = [
        ("smileys", "face.smiling", "😀"),
        ("animals", "leaf", "🐻"),
        ("food", "fork.knife", "🍔"),
        ("activity", "sportscourt", "⚽"),
        ("travel", "car", "🚗"),
        ("objects", "lightbulb", "💡"),
        ("symbols", "heart", "❤️"),
        ("flags", "flag", "🏁")
    ]

    static let recentSymbol = "clock"
    static let recentFallback = "🕘"
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

/// Emoji picker data, emoji suggestions for typed words, and emoji search.
final class EmojiStore {
    static let shared = EmojiStore()

    private(set) var categories: [EmojiCategory] = []
    private(set) var isReady = false
    private(set) var unicodeVersion = ""
    private(set) var totalCount = 0
    private(set) var shownCount = 0

    private var keywords: [Language: [String: [String]]] = [:]
    private var isLoading = false
    private var waiting: [() -> Void] = []

    // Search index (loaded the first time search is used)
    private var searchIndex: [(emoji: String, keywords: [String], order: Int)] = []
    private var orderIndex: [String: Int] = [:]
    private(set) var searchReady = false
    private var searchLoading = false
    private var searchWaiting: [() -> Void] = []

    private init() {}

    // MARK: Loading

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
            let loaded = EmojiStore.loadCategories()
            var words: [Language: [String: [String]]] = [:]
            for language in Language.allCases {
                words[language] = EmojiStore.loadKeywords(language)
            }
            DispatchQueue.main.async {
                self.categories = loaded.categories
                self.unicodeVersion = loaded.version
                self.totalCount = loaded.total
                self.shownCount = loaded.shown
                self.keywords = words

                var order = 0
                for category in loaded.categories {
                    for item in category.items {
                        self.orderIndex[item.base] = order
                        order += 1
                    }
                }

                self.isReady = true
                self.isLoading = false
                if loaded.total > 0 {
                    Settings.shared.recordEmojiStats(version: loaded.version, total: loaded.total, shown: loaded.shown)
                }
                let callbacks = self.waiting
                self.waiting = []
                callbacks.forEach { $0() }
            }
        }
    }

    /// Loads the search words (both languages are searched at once). Calls back on the main thread.
    func loadSearchIfNeeded(completion: @escaping () -> Void) {
        if searchReady {
            completion()
            return
        }
        searchWaiting.append(completion)
        if searchLoading { return }
        searchLoading = true

        loadIfNeeded { [weak self] in
            guard let self = self else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                var merged: [String: [String]] = [:]
                for language in Language.allCases {
                    let table = EmojiStore.loadSearchWords(language)
                    for (emoji, words) in table {
                        var list = merged[emoji] ?? []
                        for word in words where !list.contains(word) { list.append(word) }
                        merged[emoji] = list
                    }
                }
                DispatchQueue.main.async {
                    var index: [(emoji: String, keywords: [String], order: Int)] = []
                    index.reserveCapacity(merged.count)
                    for (emoji, words) in merged {
                        index.append((emoji: emoji, keywords: words, order: self.orderIndex[emoji] ?? Int.max))
                    }
                    self.searchIndex = index
                    self.searchReady = true
                    self.searchLoading = false
                    let callbacks = self.searchWaiting
                    self.searchWaiting = []
                    callbacks.forEach { $0() }
                }
            }
        }
    }

    // MARK: Suggestions and search

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

    /// Emoji whose names / keywords start with every word of `query` (English and Hungarian).
    func search(_ query: String, limit: Int = 80) -> [String] {
        guard searchReady else { return [] }
        let tokens = TextFolding.fold(query)
            .split(separator: " ")
            .map { String($0) }
        guard !tokens.isEmpty else { return [] }

        var scored: [(emoji: String, score: Int, order: Int)] = []
        for entry in searchIndex {
            var total = 0
            var matchesAll = true
            for token in tokens {
                var best = 0
                for keyword in entry.keywords {
                    if keyword == token {
                        best = 3
                        break
                    }
                    if keyword.hasPrefix(token) { best = max(best, 2) }
                }
                if best == 0 {
                    matchesAll = false
                    break
                }
                total += best
            }
            if matchesAll { scored.append((emoji: entry.emoji, score: total, order: entry.order)) }
        }

        scored.sort { left, right in
            if left.score != right.score { return left.score > right.score }
            return left.order < right.order
        }

        var result: [String] = []
        for item in scored {
            if EmojiSupport.isSupported(item.emoji) { result.append(item.emoji) }
            if result.count >= limit { break }
        }
        return result
    }

    // MARK: Background loading

    private static func loadCategories() -> (categories: [EmojiCategory], version: String, total: Int, shown: Int) {
        guard let url = Bundle.main.url(forResource: "emoji", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(EmojiFile.self, from: data) else {
            return ([], "", 0, 0)
        }

        // Unicode groups -> the system keyboard's tabs (People & Body joins Smileys, like iOS).
        let tabForGroup: [String: String] = [
            "Smileys & Emotion": "smileys",
            "People & Body": "smileys",
            "Animals & Nature": "animals",
            "Food & Drink": "food",
            "Activities": "activity",
            "Travel & Places": "travel",
            "Objects": "objects",
            "Symbols": "symbols",
            "Flags": "flags"
        ]

        var total = 0
        var shown = 0
        var supported: [String: [EmojiItem]] = [:]
        var everything: [String: [EmojiItem]] = [:]

        for group in file.groups {
            guard let tab = tabForGroup[group.name] else { continue }
            for raw in group.items {
                guard let base = raw.first else { continue }
                let variants = Array(raw.dropFirst())
                everything[tab, default: []].append(EmojiItem(base: base, variants: variants))
                total += 1
                if EmojiSupport.isSupported(base) {
                    shown += 1
                    let usable = variants.filter { EmojiSupport.isSupported($0) }
                    supported[tab, default: []].append(EmojiItem(base: base, variants: usable))
                }
            }
        }

        // Safety net: if the support check somehow rejects most emoji, trust the data instead.
        let useAll = total > 0 && shown * 2 < total
        if useAll { shown = total }
        let source = useAll ? everything : supported

        var categories: [EmojiCategory] = []
        for entry in EmojiCategory.layout {
            guard let items = source[entry.key], !items.isEmpty else { continue }
            categories.append(EmojiCategory(key: entry.key,
                                            symbol: entry.symbol,
                                            fallbackIcon: entry.fallback,
                                            items: items))
        }
        return (categories, file.version, total, shown)
    }

    private static func loadKeywords(_ language: Language) -> [String: [String]] {
        guard let url = Bundle.main.url(forResource: "emoji_keywords_\(language.rawValue)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return table
    }

    private static func loadSearchWords(_ language: Language) -> [String: [String]] {
        guard let url = Bundle.main.url(forResource: "emoji_search_\(language.rawValue)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return table
    }
}
