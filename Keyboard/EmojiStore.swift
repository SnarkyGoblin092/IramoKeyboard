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

    func title(for language: Language) -> String {
        if key == "people" { return language.peopleCategoryTitle }
        return language.strings.categoryTitle(key) ?? key
    }

    /// Display order, names, and tab icons - the same order as the system emoji keyboard.
    static let layout: [(key: String, symbol: String, fallback: String)] = [
        ("smileys", "face.smiling", "😀"),
        ("people", "person", "🧑"),
        ("animals", "pawprint", "🐶"),
        ("food", "fork.knife", "🍎"),
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

    /// Errs on the side of SHOWING an emoji. It is hidden only when there is strong evidence that the phone
    /// would draw a box or several loose pieces instead of one picture:
    ///  - a single-character emoji that the system emoji font has no glyph for, or
    ///  - a multi-part sequence (ZWJ / modifier) that the phone draws side by side (twice as wide as one emoji).
    /// Flags, keycaps and tag sequences are always kept.
    static func isSupported(_ emoji: String) -> Bool {
        let scalars = Array(emoji.unicodeScalars).filter { $0.value != 0xFE0F }
        guard let first = scalars.first else { return false }

        // Flags (regional indicator pairs), keycaps and tag-sequence flags: always kept.
        if (0x1F1E6...0x1F1FF).contains(first.value) { return true }
        if scalars.contains(where: { $0.value == 0x20E3 }) { return true }
        if scalars.contains(where: { (0xE0020...0xE007F).contains($0.value) }) { return true }

        if scalars.count == 1 {
            // Characters below U+1F000 (©, ™, ☺, ⭐ ...) exist in every iOS version's emoji font.
            if first.value < 0x1F000 { return true }
            if hasGlyph(first) { return true }
            // No glyph in the font table: the system may still draw it (updated font / fallback), so look at the pixels.
            return rendersAsPicture(emoji)
        }

        // A sequence: if the phone does not know the combination it draws the parts next to each other.
        if lineWidth(emoji) > referenceWidth * 1.7 { return false }
        // One glyph wide: still reject it if it is drawn exactly like the "missing character" box.
        return !looksLikeMissingGlyph(emoji)
    }

    // MARK: Render probe

    private static let probeSize = 40

    /// Draws `text` into a small RGBA bitmap and returns its pixels (nil if the bitmap cannot be made).
    private static func render(_ text: String) -> [UInt8]? {
        let size = probeSize
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: size, height: size,
                                          bitsPerComponent: 8, bytesPerRow: size * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            let attributed = NSAttributedString(string: text, attributes: [.font: font])
            let line = CTLineCreateWithAttributedString(attributed)
            context.textPosition = CGPoint(x: 6, y: 12)
            CTLineDraw(line, context)
            return true
        }
        return drawn ? pixels : nil
    }

    /// Reference renderings of characters that no font has: whatever the system draws for them is "missing".
    private static let missingSignatures: Set<[UInt8]> = {
        var set = Set<[UInt8]>()
        for text in ["\u{10FFFD}", "\u{FFFF}", "\u{1FFFD}", "\u{E0080}"] {
            if let pixels = render(text) { set.insert(pixels) }
        }
        return set
    }()

    private static func looksLikeMissingGlyph(_ text: String) -> Bool {
        guard let pixels = render(text) else { return false }   // cannot tell: show it
        return missingSignatures.contains(pixels)
    }

    /// For a single new character without a font-table glyph: it counts as drawn when the system renders
    /// something that is not blank and not the missing-character box. Uncertain results are shown.
    private static func rendersAsPicture(_ text: String) -> Bool {
        guard let pixels = render(text) else { return true }
        if missingSignatures.contains(pixels) { return false }
        var inked = 0
        var index = 3
        while index < pixels.count {
            if pixels[index] > 8 { inked += 1 }
            index += 4
        }
        return inked > 12
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

    private var keywords: [Language: [String: [String]]] = [:]   // loaded on demand, one language at a time
    private var isLoading = false
    private var waiting: [() -> Void] = []

    // Search index (loaded the first time search is used)
    private var searchIndex: [(emoji: String, keywords: [String], order: Int)] = []
    private var orderIndex: [String: Int] = [:]
    private(set) var searchReady = false
    private var searchLanguages: Set<Language> = []
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
            DispatchQueue.main.async {
                self.categories = loaded.categories
                self.unicodeVersion = loaded.version
                self.totalCount = loaded.total
                self.shownCount = loaded.shown

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

    /// Loads the search words for the given languages (the typing language and English, so the memory use stays small).
    /// Calls back on the main thread.
    func loadSearchIfNeeded(languages: [Language], completion: @escaping () -> Void) {
        let wanted = Set(languages)
        if searchReady && searchLanguages == wanted {
            completion()
            return
        }
        searchWaiting.append(completion)
        if searchLoading { return }
        searchLoading = true
        searchReady = false

        loadIfNeeded { [weak self] in
            guard let self = self else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                var merged: [String: [String]] = [:]
                for language in wanted {
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
                    self.searchLanguages = wanted
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
        guard key.count >= 2 else { return [] }
        if keywords[language] == nil {
            keywords[language] = EmojiStore.loadKeywords(language)   // small file, loaded once per language
        }
        guard let matches = keywords[language]?[key] else { return [] }
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

        // Unicode groups -> the picker's tabs (one tab per Unicode group).
        let tabForGroup: [String: String] = [
            "Smileys & Emotion": "smileys",
            "People & Body": "people",
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
