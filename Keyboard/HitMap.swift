import UIKit

/// Learns where the user really taps each letter: the average offset from the key's centre (in key widths and
/// heights), per language. The keys then move their touch centres that way (`KeyboardView.hitOffsets`), so a
/// thumb that always lands a little low and left still hits the letter it means.
///
/// Only taps of finished words count, and only when the word ended up as typed or auto-fixed to a word of the
/// same length: each tap is then known to have meant that letter.
final class HitMap {
    let language: Language
    /// letter -> (taps, mean x, mean y)
    private var stats: [Character: (count: Double, x: Double, y: Double)] = [:]
    private var saveScheduled = false

    /// Taps a key needs before its offset is used.
    static let minimumTaps = 8.0
    /// Older taps fade out: the mean follows the user's last ~150 taps of a key.
    private static let memory = 150.0
    /// Farthest a key's touch centre may move (key widths / heights).
    private static let maxShift = 0.35

    init(language: Language) {
        self.language = language
        reload()
    }

    func reload() {
        stats = [:]
        for (key, values) in Settings.shared.hitMapData(for: language.rawValue) {
            guard let letter = key.first, key.count == 1, values.count == 3 else { continue }
            stats[letter] = (values[0], values[1], values[2])
        }
    }

    /// Records the taps of a finished word. `points` are tap positions (KeyboardView coordinates), one per letter of
    /// `word`; `centers` and `keySize` describe the letter keys.
    func record(word: String, points: [CGPoint], centers: [Character: CGPoint], keySize: CGSize) {
        let letters = Array(word.lowercased())
        guard letters.count == points.count, keySize.width > 0, keySize.height > 0 else { return }
        var changed = false
        for (letter, point) in zip(letters, points) {
            guard let center = centers[letter] else { continue }
            let dx = Double((point.x - center.x) / keySize.width)
            let dy = Double((point.y - center.y) / keySize.height)
            // Farther than a key away it was a slip onto another key that the correction fixed: no information
            // about how this key is aimed at.
            guard abs(dx) < 0.9, abs(dy) < 0.9 else { continue }
            var entry = stats[letter] ?? (0, 0, 0)
            let weight = 1 / min(entry.count + 1, HitMap.memory)
            entry.x += (dx - entry.x) * weight
            entry.y += (dy - entry.y) * weight
            entry.count += 1
            stats[letter] = entry
            changed = true
        }
        if changed { scheduleSave() }
    }

    /// Each learned key's touch-centre shift, scaled by `strength` (0...1).
    func offsets(strength: Double) -> [Character: CGPoint] {
        guard strength > 0 else { return [:] }
        var result: [Character: CGPoint] = [:]
        for (letter, entry) in stats where entry.count >= HitMap.minimumTaps {
            // Trusted more as taps come in.
            let confidence = min(1, entry.count / 40)
            let scale = strength * confidence
            let x = min(max(entry.x * scale, -HitMap.maxShift), HitMap.maxShift)
            let y = min(max(entry.y * scale, -HitMap.maxShift), HitMap.maxShift)
            result[letter] = CGPoint(x: x, y: y)
        }
        return result
    }

    private func scheduleSave() {
        if saveScheduled { return }
        saveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.saveNow() }
    }

    func saveNow() {
        guard saveScheduled else { return }
        saveScheduled = false
        var data: [String: [Double]] = [:]
        for (letter, entry) in stats { data[String(letter)] = [entry.count, entry.x, entry.y] }
        Settings.shared.setHitMapData(data, for: language.rawValue)
    }
}
