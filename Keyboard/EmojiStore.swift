import UIKit
import CoreText

/// Whether THIS iPhone can actually draw an emoji.
///
/// The emoji keywords are generated from the newest Unicode data at build time, which can be newer
/// than the emoji font on the phone. Anything the phone cannot draw is never suggested.
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

/// Emoji suggestions for typed words.
final class EmojiStore {
    static let shared = EmojiStore()

    /// language -> keyword -> emoji; loaded on demand, one language at a time.
    private var keywords: [Language: [String: [String]]] = [:]

    private init() {}

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

    /// Up to `limit` emoji that match a complete word in any of `languages` (earlier languages first).
    func suggestions(for word: String, languages: [Language], limit: Int) -> [String] {
        var result: [String] = []
        for language in languages where result.count < limit {
            for emoji in suggestions(for: word, language: language, limit: limit)
            where result.count < limit && !result.contains(emoji) {
                result.append(emoji)
            }
        }
        return result
    }

    private static func loadKeywords(_ language: Language) -> [String: [String]] {
        guard let url = LanguageData.url(forResource: "emoji_keywords_\(language.rawValue)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return table
    }
}
