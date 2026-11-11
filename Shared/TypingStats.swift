import Foundation

/// What the keyboard counts while typing (never in password fields), for the app's Stats screen. Stored as JSON in the
/// shared settings; everything stays on the device.
struct TypingStatsData: Codable, Equatable {
    var since = Date()
    var words = 0
    var characters = 0
    /// Character keys tapped (letters, digits, marks).
    var keystrokes = 0
    var deletes = 0
    var swipedWords = 0
    var suggestionsPicked = 0
    var autoCorrections = 0
    var correctionsUndone = 0
    var emojis = 0
    var shortcuts = 0
    var calculations = 0
    var conversions = 0
    /// Characters written by suggestions, swipes and shortcuts that were not typed one by one.
    var savedKeystrokes = 0
    /// Typing time (pauses under a few seconds) and the characters typed in it, for the typing speed.
    var activeSeconds: Double = 0
    var activeCharacters = 0
    /// "2026-11-11" -> words written that day (the last 60 days).
    var days: [String: Int] = [:]
    /// Language code -> words written in it.
    var languages: [String: Int] = [:]

    static func decode(_ json: String) -> TypingStatsData {
        guard let data = json.data(using: .utf8), !data.isEmpty,
              let stats = try? JSONDecoder().decode(TypingStatsData.self, from: data) else { return TypingStatsData() }
        return stats
    }

    func encoded() -> String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Words per minute while typing (five characters a word), or nil before there is enough to tell.
    var wordsPerMinute: Double? {
        guard activeSeconds >= 20, activeCharacters >= 50 else { return nil }
        return Double(activeCharacters) / 5 / (activeSeconds / 60)
    }

    /// The share of key taps that were not deleted again, or nil before there is enough to tell.
    var accuracy: Double? {
        guard keystrokes >= 50 else { return nil }
        return max(0, min(1, 1 - Double(deletes) / Double(keystrokes)))
    }

    static func dayKey(_ date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// Adds counts made since the last save (the stored ones may have been reset by the app meanwhile).
    mutating func add(_ other: TypingStatsData) {
        words += other.words
        characters += other.characters
        keystrokes += other.keystrokes
        deletes += other.deletes
        swipedWords += other.swipedWords
        suggestionsPicked += other.suggestionsPicked
        autoCorrections += other.autoCorrections
        correctionsUndone += other.correctionsUndone
        emojis += other.emojis
        shortcuts += other.shortcuts
        calculations += other.calculations
        conversions += other.conversions
        savedKeystrokes += other.savedKeystrokes
        activeSeconds += other.activeSeconds
        activeCharacters += other.activeCharacters
        for (day, count) in other.days { days[day, default: 0] += count }
        for (code, count) in other.languages { languages[code, default: 0] += count }
        // Only the last 60 days are kept.
        if days.count > 60 {
            for day in days.keys.sorted().dropLast(60) { days.removeValue(forKey: day) }
        }
    }
}

/// The keyboard's counter: counts go into a pending batch that is added to the stored stats every few words and
/// when the keyboard goes away, so a reset in the app is never undone by a keyboard that was open meanwhile.
final class TypingStats {
    static let shared = TypingStats()

    private var pending = TypingStatsData()
    private var changes = 0
    private var lastKeyTime: TimeInterval = 0

    private init() {}

    enum Event {
        case swipe, suggestion, autoCorrection, correctionUndone, emoji, shortcut, calculation, conversion
    }

    /// A word was finished (typed, swiped, picked...) in `language`.
    func word(_ language: Language) {
        guard Prefs.statsEnabled else { return }
        pending.words += 1
        pending.days[TypingStatsData.dayKey(Date()), default: 0] += 1
        pending.languages[language.rawValue, default: 0] += 1
        changed()
    }

    /// A character key was tapped and wrote `count` characters.
    func keystroke(characters count: Int = 1) {
        guard Prefs.statsEnabled else { return }
        pending.keystrokes += 1
        pending.characters += count
        let now = ProcessInfo.processInfo.systemUptime
        let gap = now - lastKeyTime
        // Pauses longer than a few seconds are thinking, not typing.
        if lastKeyTime > 0, gap < 3 {
            pending.activeSeconds += gap
            pending.activeCharacters += count
        }
        lastKeyTime = now
    }

    func delete() {
        guard Prefs.statsEnabled else { return }
        pending.deletes += 1
    }

    /// Characters written for the user (suggestions, swipes, shortcuts) beyond the keys tapped for them.
    func saved(_ count: Int, writing characters: Int) {
        guard Prefs.statsEnabled else { return }
        pending.savedKeystrokes += max(0, count)
        pending.characters += max(0, characters)
    }

    func note(_ event: Event) {
        guard Prefs.statsEnabled else { return }
        switch event {
        case .swipe: pending.swipedWords += 1
        case .suggestion: pending.suggestionsPicked += 1
        case .autoCorrection: pending.autoCorrections += 1
        case .correctionUndone: pending.correctionsUndone += 1
        case .emoji: pending.emojis += 1
        case .shortcut: pending.shortcuts += 1
        case .calculation: pending.calculations += 1
        case .conversion: pending.conversions += 1
        }
        changed()
    }

    private func changed() {
        changes += 1
        if changes >= 20 { save() }
    }

    /// Adds the pending counts to the stored stats.
    func save() {
        changes = 0
        guard pending != TypingStatsData(since: pending.since) else { return }
        var stored = TypingStatsData.decode(Settings.shared.typingStatsJSON)
        stored.add(pending)
        Settings.shared.typingStatsJSON = stored.encoded()
        pending = TypingStatsData()
    }
}
