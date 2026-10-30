import Foundation

/// Restores accents on words no dictionary has ("unokadbol" -> "unokádból"): `accents_<lang>.bin`, written by
/// scripts/accents.py, which documents the method and the format. Memory-mapped and immutable.
final class AccentModel {
    private let storage: NSData
    private let base: UnsafeRawPointer
    private let count: Int
    private let textOffset: Int
    private static let radii = [3, 2, 1, 0]

    init?(language: Language) {
        guard let url = Bundle.main.url(forResource: "accents_\(language.rawValue)", withExtension: "bin"),
              let data = try? NSData(contentsOf: url, options: .alwaysMapped),
              data.length >= 16 else { return nil }
        let pointer = data.bytes
        guard pointer.loadUnaligned(as: UInt32.self) == 0x4341_4B48,                       // "HKAC"
              pointer.loadUnaligned(fromByteOffset: 4, as: UInt32.self) == 1 else { return nil }
        let windows = Int(pointer.loadUnaligned(fromByteOffset: 8, as: UInt32.self))
        let textBytes = Int(pointer.loadUnaligned(fromByteOffset: 12, as: UInt32.self))
        let text = 16 + 12 * windows
        guard text + textBytes <= data.length else { return nil }
        storage = data
        base = pointer
        count = windows
        textOffset = text
    }

    /// The accented form of an accent-free word; letters the model knows nothing about stay as they are.
    func restore(_ folded: String) -> String {
        let letters = Array(folded)
        var result = ""
        for index in letters.indices {
            var choice = letters[index]
            for radius in AccentModel.radii {
                if let found = letter(for: AccentModel.window(letters, index, radius)) {
                    choice = found
                    break
                }
            }
            result.append(choice)
        }
        return result
    }

    /// "<left>|<letter>|<right>", "^" / "$" marking the word's ends (accents.py `window`).
    private static func window(_ letters: [Character], _ index: Int, _ radius: Int) -> String {
        guard radius > 0 else { return "|\(letters[index])|" }
        let left = String((["^"] + Array(letters[0..<index])).suffix(radius))
        let right = String((Array(letters[(index + 1)...]) + ["$"]).prefix(radius))
        return left + "|" + String(letters[index]) + "|" + right
    }

    private func letter(for window: String) -> Character? {
        let target = Array(window.utf8)
        var low = 0, high = count
        while low < high {
            let mid = (low + high) / 2
            let order = compare(mid, target)
            if order == 0 {
                let scalar = base.loadUnaligned(fromByteOffset: 16 + 12 * mid + 8, as: UInt32.self)
                return Unicode.Scalar(scalar).map { Character($0) }
            }
            if order < 0 { low = mid + 1 } else { high = mid }
        }
        return nil
    }

    private func compare(_ index: Int, _ key: [UInt8]) -> Int {
        let offset = Int(base.loadUnaligned(fromByteOffset: 16 + 12 * index, as: UInt32.self))
        let length = Int(base.loadUnaligned(fromByteOffset: 16 + 12 * index + 4, as: UInt32.self))
        let bytes = UnsafeRawBufferPointer(start: base + textOffset + offset, count: length)
        let n = min(length, key.count)
        for i in 0..<n where bytes[i] != key[i] { return bytes[i] < key[i] ? -1 : 1 }
        return length == key.count ? 0 : (length < key.count ? -1 : 1)
    }
}
