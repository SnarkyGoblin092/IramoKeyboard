import CoreGraphics
import Foundation

/// Where taps landed on each letter key: the count, and the offsets from the key's centre (in the key's own width
/// and height) as running sums, so the average, the spread and the average miss are exact without keeping every tap.
/// Each key also keeps its learned aim: where this user's taps for it land, as a slowly moving average. Kept apart
/// for portrait and landscape. Only the key and the offsets are kept, never what was typed.
struct TapMapData: Codable, Equatable {
    struct Key: Codable, Equatable {
        var count = 0
        var sumX = 0.0, sumY = 0.0, sumXX = 0.0, sumYY = 0.0
        /// The distances from the centre, added up (the average miss).
        var sumDistance = 0.0
        /// The key's touch cell as it was last seen, as shares of the keyboard (centre and size).
        var cx = 0.0, cy = 0.0, w = 0.0, h = 0.0
        /// The learned aim: the average landing point relative to the key's centre (in key sizes), and the taps it
        /// is made of.
        var aimX = 0.0, aimY = 0.0, aimCount = 0

        init() {}

        // Older saves lack the aim: every field is optional on reading.
        init(from decoder: Swift.Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
            sumX = try c.decodeIfPresent(Double.self, forKey: .sumX) ?? 0
            sumY = try c.decodeIfPresent(Double.self, forKey: .sumY) ?? 0
            sumXX = try c.decodeIfPresent(Double.self, forKey: .sumXX) ?? 0
            sumYY = try c.decodeIfPresent(Double.self, forKey: .sumYY) ?? 0
            sumDistance = try c.decodeIfPresent(Double.self, forKey: .sumDistance) ?? 0
            cx = try c.decodeIfPresent(Double.self, forKey: .cx) ?? 0
            cy = try c.decodeIfPresent(Double.self, forKey: .cy) ?? 0
            w = try c.decodeIfPresent(Double.self, forKey: .w) ?? 0
            h = try c.decodeIfPresent(Double.self, forKey: .h) ?? 0
            aimX = try c.decodeIfPresent(Double.self, forKey: .aimX) ?? 0
            aimY = try c.decodeIfPresent(Double.self, forKey: .aimY) ?? 0
            aimCount = try c.decodeIfPresent(Int.self, forKey: .aimCount) ?? 0
        }

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

        /// The part of the keyboard's height the keys cover, as shares of it (the pictures are cut to it, so they have
        /// no empty room under the last row).
        var verticalSpan: (top: Double, span: Double) {
            let known = keys.values.filter { $0.w > 0 && $0.h > 0 }
            guard let top = known.map({ $0.cy - $0.h / 2 }).min(), let bottom = known.map({ $0.cy + $0.h / 2 }).max() else {
                return (0, 1)
            }
            let low = max(0, top), high = min(1, bottom)
            return high > low ? (low, high - low) : (0, 1)
        }

        /// The keys with taps recorded (the others only carry an aim).
        var tapped: [String: Key] { return keys.filter { $0.value.count > 0 } }
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

/// The aim over the whole keyboard: every key that has learned where its taps land pulls the points near it by that
/// much (the nearer the key and the more taps behind it, the more), and the keys that have not yet learned follow
/// the average of their half of the keyboard. The shift changes smoothly from one key to the next, so the edges
/// between keys bend and tilt to follow the thumbs instead of staying straight lines. With nothing learned there is
/// no shift and the keys are the plain rectangles.
///
/// Points are shares of the keyboard (0...1 across and down); offsets are in key sizes.
struct TapAimField {
    struct Anchor {
        var cx: Double, cy: Double, w: Double, h: Double
        /// Where taps for this key land, from its centre, in key sizes.
        var ox: Double, oy: Double
        /// How much the key's own taps count against the half's average: 0 (none yet) up to 1.
        var confidence: Double
    }

    var anchors: [Anchor]
    /// A key's size, for the half's average.
    var unitW: Double, unitH: Double
    var priorLeft: (x: Double, y: Double)
    var priorRight: (x: Double, y: Double)

    /// How far a key's aim reaches, in key sizes, and how much the half's average weighs against the keys'.
    private static let reach = 0.6
    private static let priorWeight = 0.4
    /// Taps for the key's own aim to count half as much as the half's average.
    static let halfWayTaps = 10.0

    static func confidence(taps: Int) -> Double {
        return Double(taps) / (Double(taps) + halfWayTaps)
    }

    /// From a saved layout: the keys as last seen.
    init(layout: TapMapData.Layout, priorLeft: (x: Double, y: Double), priorRight: (x: Double, y: Double)) {
        let known = layout.keys.values.filter { $0.w > 0 && $0.h > 0 }
        anchors = known.map {
            Anchor(cx: $0.cx, cy: $0.cy, w: $0.w, h: $0.h, ox: $0.aimX, oy: $0.aimY,
                   confidence: TapAimField.confidence(taps: $0.aimCount))
        }
        let widths = known.map { $0.w }.sorted(), heights = known.map { $0.h }.sorted()
        unitW = widths.isEmpty ? 0.1 : widths[widths.count / 2]
        unitH = heights.isEmpty ? 0.2 : heights[heights.count / 2]
        self.priorLeft = priorLeft
        self.priorRight = priorRight
    }

    init(anchors: [Anchor], unitW: Double, unitH: Double, priorLeft: (x: Double, y: Double), priorRight: (x: Double, y: Double)) {
        self.anchors = anchors
        self.unitW = unitW
        self.unitH = unitH
        self.priorLeft = priorLeft
        self.priorRight = priorRight
    }

    /// How far the taps that land at `point` are off from where they were meant, as shares of the keyboard.
    func offset(at point: CGPoint) -> CGPoint {
        let reach = TapAimField.reach
        var weight = 0.0, x = 0.0, y = 0.0
        for anchor in anchors where anchor.confidence > 0 {
            let u = (Double(point.x) - anchor.cx) / anchor.w
            let v = (Double(point.y) - anchor.cy) / anchor.h
            let closeness = anchor.confidence * exp(-(u * u + v * v) / (2 * reach * reach))
            weight += closeness
            x += closeness * anchor.ox * anchor.w
            y += closeness * anchor.oy * anchor.h
        }
        let prior = point.x > 0.5 ? priorRight : priorLeft
        let base = TapAimField.priorWeight
        return CGPoint(x: (x + base * prior.x * unitW) / (weight + base),
                       y: (y + base * prior.y * unitH) / (weight + base))
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
    /// A key's aim moves by at most this much of a key from its centre.
    static let aimLimit = 0.3

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

    /// The aim learned for a letter: where its taps land from the key's centre (key sizes), and how many taps.
    func aim(of letter: String, landscape wide: Bool) -> (x: Double, y: Double, taps: Int)? {
        guard let key = (wide ? data.landscape : data.portrait).keys[letter], key.aimCount > 0 else { return nil }
        return (key.aimX, key.aimY, key.aimCount)
    }

    /// A press at `point` was resolved to the letter `letter` whose touch cell is `cell`, in a keyboard of `bounds`.
    /// `record` adds it to the heatmap; `learn` moves the key's aim towards it (`speed`: 0 slow, 1 normal, 2 fast).
    func press(letter: String, point: CGPoint, cell: CGRect, in bounds: CGRect, record: Bool, learn: Bool, speed: Int) {
        guard TapAccuracy.isKeyboard, record || learn, cell.width > 1, cell.height > 1, bounds.width > 1, bounds.height > 1 else { return }
        let dx = Double((point.x - cell.midX) / cell.width)
        let dy = Double((point.y - cell.midY) / cell.height)
        let wide = bounds.width > 500
        if data.portrait.keys.isEmpty && data.landscape.keys.isEmpty { data.since = Date() }
        var layout = wide ? data.landscape : data.portrait
        var key = layout.keys[letter] ?? TapMapData.Key()
        if record {
            key.count += 1
            key.sumX += dx
            key.sumY += dy
            key.sumXX += dx * dx
            key.sumYY += dy * dy
            key.sumDistance += (dx * dx + dy * dy).squareRoot()
        }
        // Presses near a key's edge are as likely a neighbour's: only the middle and its surroundings teach the aim.
        if learn, abs(dx) < 0.6, abs(dy) < 0.6 {
            key.aimCount += 1
            // The first taps average out; later ones move it a little (how much: the learning speed).
            let rate = max(1 / Double(key.aimCount), [0.03, 0.06, 0.12][min(2, max(0, speed))])
            let limit = TapAccuracy.aimLimit
            key.aimX = max(-limit, min(limit, key.aimX + (dx - key.aimX) * rate))
            key.aimY = max(-limit, min(limit, key.aimY + (dy - key.aimY) * rate))
        }
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
