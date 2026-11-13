import CoreGraphics
import Foundation

/// Where taps landed on each letter key: the count, and the offsets from the key's centre (in the key's own width
/// and height) as running sums, so the average, the spread and the average miss are exact without keeping every tap.
/// Kept apart for portrait and landscape. Only the key and the offset are kept, never what was typed.
struct TapMapData: Codable, Equatable {
    struct Key: Codable, Equatable {
        var count = 0
        var sumX = 0.0, sumY = 0.0, sumXX = 0.0, sumYY = 0.0
        /// The distances from the centre, added up (the average miss).
        var sumDistance = 0.0
        /// The key's touch cell as it was last seen, as shares of the keyboard (centre and size).
        var cx = 0.0, cy = 0.0, w = 0.0, h = 0.0

        var meanX: Double { return count > 0 ? sumX / Double(count) : 0 }
        var meanY: Double { return count > 0 ? sumY / Double(count) : 0 }
        var spreadX: Double { return count > 1 ? max(0, sumXX / Double(count) - meanX * meanX).squareRoot() : 0 }
        var spreadY: Double { return count > 1 ? max(0, sumYY / Double(count) - meanY * meanY).squareRoot() : 0 }
        var meanDistance: Double { return count > 0 ? sumDistance / Double(count) : 0 }
    }

    /// One orientation: the keys by letter, and the keyboard's height over its width when last seen.
    struct Layout: Codable, Equatable {
        var keys: [String: Key] = [:]
        var aspect = 0.0

        var total: Int { return keys.values.reduce(0) { $0 + $1.count } }
        var maxCount: Int { return keys.values.map { $0.count }.max() ?? 0 }
        /// The average distance of a tap from the centre of its key, over every tap (in key sizes).
        var meanMiss: Double? {
            let taps = total
            guard taps > 0 else { return nil }
            return keys.values.reduce(0) { $0 + $1.sumDistance } / Double(taps)
        }
    }

    var portrait = Layout()
    var landscape = Layout()
    var since = Date()

    func layout(landscape wide: Bool) -> Layout { return wide ? landscape : portrait }

    static func decode(_ json: String?) -> TapMapData {
        guard let json = json, let data = json.data(using: .utf8),
              let map = try? JSONDecoder().decode(TapMapData.self, from: data) else { return TapMapData() }
        return map
    }

    func encoded() -> String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

/// Keeps the tap map: the keyboard adds every letter press, saving now and then; the app reads it for the Tap accuracy
/// screen and can wipe it (the keyboard notices on its next look at the settings).
final class TapAccuracy {
    static let shared = TapAccuracy()

    static let mapKey = "hunkeys.tapMap"
    /// Changed by the app when it wipes the tap data, so the keyboard drops what it holds in memory.
    static let resetKey = "hunkeys.tapReset"
    /// Whether this is the keyboard itself (the app's own previews show the same keys but are not typing).
    static let isKeyboard = Bundle.main.bundleURL.pathExtension == "appex"

    private var data: TapMapData
    private var stamp: String
    private var unsaved = 0
    private var lastSave = Date()

    private init() {
        data = TapMapData.decode(SharedStore.defaults.string(forKey: TapAccuracy.mapKey))
        stamp = SharedStore.defaults.string(forKey: TapAccuracy.resetKey) ?? ""
    }

    /// The tap map as saved (what the app shows).
    static func load() -> TapMapData {
        return TapMapData.decode(SharedStore.defaults.string(forKey: mapKey))
    }

    /// Wipes the saved map and the learned aim; the keyboard follows when it next reads its settings.
    static func reset() {
        SharedStore.defaults.removeObject(forKey: mapKey)
        SharedStore.defaults.removeObject(forKey: TapBias.savedKey)
        SharedStore.defaults.set(UUID().uuidString, forKey: resetKey)
    }

    /// Drops what is in memory when the app wiped the data meanwhile.
    func syncWithApp() {
        let current = SharedStore.defaults.string(forKey: TapAccuracy.resetKey) ?? ""
        guard current != stamp else { return }
        stamp = current
        data = TapMapData.decode(SharedStore.defaults.string(forKey: TapAccuracy.mapKey))
        unsaved = 0
    }

    /// A press at `point` was resolved to the letter `letter` whose touch cell is `cell`, in a keyboard of `bounds`.
    func record(letter: String, point: CGPoint, cell: CGRect, in bounds: CGRect) {
        guard TapAccuracy.isKeyboard, cell.width > 1, cell.height > 1, bounds.width > 1, bounds.height > 1 else { return }
        let dx = Double((point.x - cell.midX) / cell.width)
        let dy = Double((point.y - cell.midY) / cell.height)
        let wide = bounds.width > 500
        if data.portrait.keys.isEmpty && data.landscape.keys.isEmpty { data.since = Date() }
        var layout = wide ? data.landscape : data.portrait
        var key = layout.keys[letter] ?? TapMapData.Key()
        key.count += 1
        key.sumX += dx
        key.sumY += dy
        key.sumXX += dx * dx
        key.sumYY += dy * dy
        key.sumDistance += (dx * dx + dy * dy).squareRoot()
        key.cx = Double((cell.midX - bounds.minX) / bounds.width)
        key.cy = Double((cell.midY - bounds.minY) / bounds.height)
        key.w = Double(cell.width / bounds.width)
        key.h = Double(cell.height / bounds.height)
        layout.keys[letter] = key
        layout.aspect = Double(bounds.height / bounds.width)
        if wide { data.landscape = layout } else { data.portrait = layout }
        unsaved += 1
        if unsaved >= 40 || Date().timeIntervalSince(lastSave) > 30 { flush() }
    }

    /// Writes what has been added since.
    func flush() {
        guard unsaved > 0 else { return }
        unsaved = 0
        lastSave = Date()
        SharedStore.defaults.set(data.encoded(), forKey: TapAccuracy.mapKey)
    }
}
