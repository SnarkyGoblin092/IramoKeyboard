import Foundation
import CoreGraphics

/// On-device model of where the user actually lands on each letter key.
///
/// For every letter it keeps a slowly-moving average of the touch-down offset from the key's centre
/// (as a fraction of the key's size). The keyboard then judges a touch against the *shifted* centres, so
/// a user who always lands a bit low-left of "a" gets that area credited to "a". Nothing leaves the device.
///
/// Stored compactly in the shared defaults under `hunkeys.touchModel` as
/// `[layoutID: [letter: [dx, dy, count]]]` (a plain property list). The app wipes it with `removeObject`.
final class TouchModel {
    static let shared = TouchModel()
    static let storeKey = "hunkeys.touchModel"

    /// Samples needed before a key's offset is used at all, and how many more until it counts fully.
    private static let warmup = 10.0
    private static let ramp = 30.0
    /// An offset never moves a key's centre by more than this share of its size.
    private static let maxShift = 0.25
    private static let maxLayouts = 6

    private struct Entry {
        var dx = 0.0
        var dy = 0.0
        var n = 0.0
    }

    private var layouts: [String: [String: Entry]] = [:]
    private var dirty = false
    private var lastSave = Date.distantPast

    private init() {
        reload()
    }

    /// Re-reads the stored model. Called when the keyboard appears, so a reset made in the app takes effect.
    func reload() {
        layouts = [:]
        dirty = false
        guard let raw = SharedStore.defaults.object(forKey: TouchModel.storeKey) as? [String: [String: [Double]]] else { return }
        for (layout, keys) in raw {
            var map: [String: Entry] = [:]
            for (letter, values) in keys where values.count == 3 {
                map[letter] = Entry(dx: values[0], dy: values[1], n: values[2])
            }
            layouts[layout] = map
        }
    }

    /// The learned shift of a letter, as a fraction of the key's width / height. Zero until enough data.
    func offset(letter: String, layout: String) -> (dx: Double, dy: Double) {
        guard Prefs.touchLearning, let entry = layouts[layout]?[letter], entry.n > TouchModel.warmup else { return (0, 0) }
        let confidence = min(1, (entry.n - TouchModel.warmup) / TouchModel.ramp)
        let cap = TouchModel.maxShift
        return (min(max(entry.dx * confidence, -cap), cap), min(max(entry.dy * confidence, -cap), cap))
    }

    /// Records one touch-down. `dx`/`dy` are relative to the key's geometric centre, in key sizes.
    func learn(letter: String, layout: String, dx: Double, dy: Double, weight: Double = 1) {
        guard Prefs.touchLearning else { return }
        let limit = 0.9
        guard abs(dx) <= limit, abs(dy) <= limit else { return }
        var map = layouts[layout] ?? [:]
        var entry = map[letter] ?? Entry()
        entry.n = min(entry.n + weight, 400)
        let alpha = max(0.04, 1 / max(entry.n, 1)) * weight
        entry.dx += (min(max(dx, -0.6), 0.6) - entry.dx) * alpha
        entry.dy += (min(max(dy, -0.6), 0.6) - entry.dy) * alpha
        map[letter] = entry
        if layouts[layout] == nil && layouts.count >= TouchModel.maxLayouts, let drop = layouts.keys.first {
            layouts.removeValue(forKey: drop)
        }
        layouts[layout] = map
        dirty = true
        if Date().timeIntervalSince(lastSave) > 20 { saveNow() }
    }

    func saveNow() {
        guard dirty else { return }
        dirty = false
        lastSave = Date()
        var raw: [String: [String: [Double]]] = [:]
        for (layout, keys) in layouts {
            var map: [String: [Double]] = [:]
            for (letter, entry) in keys {
                map[letter] = [(entry.dx * 1000).rounded() / 1000, (entry.dy * 1000).rounded() / 1000, entry.n.rounded()]
            }
            raw[layout] = map
        }
        SharedStore.defaults.set(raw, forKey: TouchModel.storeKey)
    }
}
