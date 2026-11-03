import UIKit

/// Learns where the user really taps each letter key: the average offset from the key's centre (in key widths and
/// heights). The keys then move their touch centres that way (`KeyboardView.hitOffsets`), so a thumb that always
/// lands a little low and left still hits the letter it means.
///
/// Where a thumb lands depends on the hand and on where the key is on the screen, not on the language, so there is
/// one map for every language, kept by key position (`position(row:index:count:)`): languages whose letter keys sit
/// in the same places learn together, a row of another length learns on its own.
///
/// Only taps of finished words count, and only when the word ended up as typed or auto-fixed to a word of the
/// same length: each tap is then known to have meant that letter.
final class HitMap {
    /// position -> (taps, mean x, mean y)
    private var stats: [String: (count: Double, x: Double, y: Double)] = [:]
    private var saveScheduled = false

    /// Taps a key needs before its offset is used.
    static let minimumTaps = 8.0
    /// Older taps fade out: the mean follows the user's last ~150 taps of a key.
    private static let memory = 150.0
    /// Farthest a key's touch centre may move (key widths / heights).
    private static let maxShift = 0.35

    /// The name a letter key is learned under: its letter row, its place among that row's letters, and how many
    /// letters the row has.
    static func position(row: Int, index: Int, count: Int) -> String {
        return "\(row).\(index).\(count)"
    }

    init() {
        reload()
    }

    func reload() {
        HitMap.mergeLegacyMaps()
        stats = [:]
        for (key, values) in Settings.shared.hitMapData() where values.count == 3 {
            stats[key] = (values[0], values[1], values[2])
        }
    }

    /// Records the taps of a finished word. `points` are tap positions (KeyboardView coordinates), one per letter of
    /// `word`; `centers`, `positions` and `keySize` describe the letter keys (KeyboardView.letterCenters,
    /// letterPositions, letterKeySize).
    func record(word: String, points: [CGPoint], centers: [Character: CGPoint], positions: [Character: String],
                keySize: CGSize) {
        let letters = Array(word.lowercased())
        guard letters.count == points.count, keySize.width > 0, keySize.height > 0 else { return }
        var changed = false
        for (letter, point) in zip(letters, points) {
            guard let center = centers[letter], let position = positions[letter] else { continue }
            let dx = Double((point.x - center.x) / keySize.width)
            let dy = Double((point.y - center.y) / keySize.height)
            // Farther than a key away it was a slip onto another key that the correction fixed: no information
            // about how this key is aimed at.
            guard abs(dx) < 0.9, abs(dy) < 0.9 else { continue }
            var entry = stats[position] ?? (0, 0, 0)
            let weight = 1 / min(entry.count + 1, HitMap.memory)
            entry.x += (dx - entry.x) * weight
            entry.y += (dy - entry.y) * weight
            entry.count += 1
            stats[position] = entry
            changed = true
        }
        if changed { scheduleSave() }
    }

    /// Each learned letter key's touch-centre shift, scaled by `strength` (0...1). `positions` are the keyboard's
    /// letter keys (KeyboardView.letterPositions).
    func offsets(strength: Double, positions: [Character: String]) -> [Character: CGPoint] {
        guard strength > 0 else { return [:] }
        var result: [Character: CGPoint] = [:]
        for (letter, position) in positions {
            guard let entry = stats[position], entry.count >= HitMap.minimumTaps else { continue }
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
        for (position, entry) in stats { data[position] = [entry.count, entry.x, entry.y] }
        Settings.shared.setHitMapData(data)
    }

    // MARK: Earlier builds

    /// Earlier builds kept one map per language, by letter: their taps are added to the shared map (each letter at
    /// its key's place in that language's layout) and the old maps removed.
    static func mergeLegacyMaps() {
        let legacy = Settings.shared.legacyHitMaps()
        guard !legacy.isEmpty else { return }
        var merged: [String: [Double]] = Settings.shared.hitMapData()
        for (code, letters) in legacy {
            guard let language = Language(rawValue: code) else { continue }
            let positions = letterPositions(rows: language.letterRows)
            for (key, values) in letters {
                guard values.count == 3, let letter = key.first, key.count == 1,
                      let position = positions[letter], values[0] > 0 else { continue }
                let old = merged[position] ?? [0, 0, 0]
                let count = old[0] + values[0]
                merged[position] = [count,
                                    (old[1] * old[0] + values[1] * values[0]) / count,
                                    (old[2] * old[0] + values[2] * values[0]) / count]
            }
        }
        Settings.shared.setHitMapData(merged)
        Settings.shared.removeLegacyHitMaps()
    }

    /// The position of every letter in a layout's letter rows.
    private static func letterPositions(rows: [[String]]) -> [Character: String] {
        var positions: [Character: String] = [:]
        var letterRow = 0
        for row in rows {
            let letters: [Character] = row.compactMap { text in
                guard text.count == 1, let letter = text.lowercased().first, letter.isLetter else { return nil }
                return letter
            }
            guard !letters.isEmpty else { continue }
            for (index, letter) in letters.enumerated() where positions[letter] == nil {
                positions[letter] = position(row: letterRow, index: index, count: letters.count)
            }
            letterRow += 1
        }
        return positions
    }
}
