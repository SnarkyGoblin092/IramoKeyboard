import Foundation

struct WordEntry {
    let word: String      // as written, lower-case, with accents and apostrophes ("we're", "szép")
    let folded: String    // match key: accent-free, apostrophe-free ("were", "szep")
    let freq: Int
    let norm: Double      // log-frequency scaled to 0...1 within its language (comparable across languages)
    let length: Int       // number of characters in `folded`
}

enum TextFolding {
    /// Letters that do not decompose into base + accent. Must match SPECIAL_FOLDS in scripts/build_data.py.
    private static let special: [Character: String] = [
        "ł": "l", "đ": "d", "ø": "o", "ß": "ss", "æ": "ae", "œ": "oe", "ı": "i", "ð": "d", "þ": "th"
    ]

    /// Lower-case and strip accents ("Szép" -> "szep", "Й" -> "и"). Mirrors `fold()` in scripts/build_data.py.
    static func fold(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for scalar in text.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            if scalar.properties.generalCategory == .nonspacingMark { continue }
            let character = Character(scalar)
            if let replacement = special[character] {
                result += replacement
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    static func isApostrophe(_ character: Character) -> Bool {
        return character == "'" || character == "\u{2019}" || character == "\u{02BC}" || character == "\u{2018}"
    }

    /// The match key: folded and without apostrophes, so "we're", "were" and "WE’RE" all become "were".
    static func key(_ text: String) -> String {
        let folded = fold(text)
        if !folded.contains(where: { isApostrophe($0) }) { return folded }
        return String(folded.filter { !isApostrophe($0) })
    }

    /// Straight apostrophes only ("don’t" -> "don't").
    static func normalizeApostrophes(_ text: String) -> String {
        if !text.contains(where: { $0 == "\u{2019}" || $0 == "\u{02BC}" || $0 == "\u{2018}" }) { return text }
        return String(text.map { isApostrophe($0) ? Character("'") : $0 })
    }
}

/// One suggested word with its score (higher is better; roughly 0...1.5, comparable across languages).
struct WordCandidate {
    let word: String
    let score: Double
}

/// Frequency dictionary for one language, plus the words and word pairs the user typed.
///
/// `entries` is sorted by the match key so prefix lookups are a binary search, and it is
/// immutable after `apply(_:)`, which makes it safe to read from the swipe decoder's thread.
final class WordStore {
    let language: Language

    private(set) var entries: [WordEntry] = []
    private(set) var isLoaded = false
    /// False when only the most frequent words were loaded (languages that are not the active layout).
    private(set) var isFull = false
    private(set) var maxLogFreq: Double = 1

    private var edgeIndex: [String: [Int]] = [:]
    private var learned: [String: Int]
    private var learnedKeys: [String: String] = [:]   // learned word -> match key
    private var learnedKeySet: Set<String> = []
    private var bigrams: [String: Int]
    private let keyLetters: Set<Character>
    private let neighbors: [Character: Set<Character>]
    private var saveScheduled = false

    init(language: Language) {
        self.language = language
        self.keyLetters = language.keyLetterSet
        self.learned = Settings.shared.learnedWords(for: language.rawValue)
        self.bigrams = Settings.shared.learnedBigrams(for: language.rawValue)
        self.neighbors = WordStore.neighborMap(for: language)
        rebuildLearnedKeys()
    }

    private func rebuildLearnedKeys() {
        learnedKeys = [:]
        for word in learned.keys { learnedKeys[word] = TextFolding.key(word) }
        learnedKeySet = Set(learnedKeys.values)
    }

    // MARK: Loading (parse off the main thread, then apply on the main thread)

    struct Parsed {
        let entries: [WordEntry]
        let edges: [String: [Int]]
        let maxLogFreq: Double
        let isFull: Bool
    }

    /// The layout key a word's letter is typed on ("é" -> "e" in Hungarian, but "ö" stays "ö" in German).
    static func keyLetter(for character: Character, in keys: Set<Character>) -> Character? {
        if keys.contains(character) { return character }
        if let first = TextFolding.fold(String(character)).first, keys.contains(first) { return first }
        return nil
    }

    func keyLetter(for character: Character) -> Character? {
        return WordStore.keyLetter(for: character, in: keyLetters)
    }

    /// Parses `words_<lang>.tsv` (sorted by frequency, most common first).
    /// - Parameter limit: keep only the most frequent `limit` words (nil = all). Used for the languages
    ///   that are not the active layout, to keep memory low.
    /// - Parameter buildEdges: the swipe index; only the active layout needs it.
    static func parse(language: Language, limit: Int? = nil, buildEdges: Bool = true) -> Parsed {
        guard let url = Bundle.main.url(forResource: "words_\(language.rawValue)", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return Parsed(entries: [], edges: [:], maxLogFreq: 1, isFull: limit == nil)
        }

        var rows: [(word: String, freq: Int)] = []
        rows.reserveCapacity(limit ?? 50_000)
        var maxFreq = 1
        text.enumerateLines { line, stop in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3, let freq = Int(parts[2]) else { return }
            rows.append((word: TextFolding.normalizeApostrophes(String(parts[0])), freq: freq))
            maxFreq = max(maxFreq, freq)
            if let limit = limit, rows.count >= limit { stop = true }
        }

        let maxLog = max(log(Double(maxFreq) + 1), 1)
        var list: [WordEntry] = []
        list.reserveCapacity(rows.count)
        for row in rows {
            let key = TextFolding.key(row.word)
            guard !key.isEmpty else { continue }
            list.append(WordEntry(word: row.word,
                                  folded: key,
                                  freq: row.freq,
                                  norm: log(Double(row.freq) + 1) / maxLog,
                                  length: key.count))
        }
        list.sort { $0.folded < $1.folded }

        // Index by first + last letter so the swipe decoder only looks at plausible words.
        var edges: [String: [Int]] = [:]
        if buildEdges {
            let keys = language.keyLetterSet
            for (index, entry) in list.enumerated() {
                let letters = entry.word.compactMap { keyLetter(for: $0, in: keys) }
                guard letters.count >= 2, let first = letters.first, let last = letters.last else { continue }
                edges[String([first, last]), default: []].append(index)
            }
        }
        return Parsed(entries: list, edges: edges, maxLogFreq: maxLog, isFull: limit == nil)
    }

    func apply(_ parsed: Parsed) {
        entries = parsed.entries
        edgeIndex = parsed.edges
        maxLogFreq = parsed.maxLogFreq
        isFull = parsed.isFull
        isLoaded = true
    }

    // MARK: Lookup

    private func lowerBound(of key: String) -> Int {
        var low = 0
        var high = entries.count
        while low < high {
            let mid = (low + high) / 2
            if entries[mid].folded < key {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    /// True if the dictionary (or the user's own words) contains a word with this match key.
    func contains(key: String) -> Bool {
        guard !key.isEmpty else { return false }
        let index = lowerBound(of: key)
        if index < entries.count, entries[index].folded == key { return true }
        return learnedKeySet.contains(key)
    }

    /// Words that start with what was typed (apostrophes, accents and case are ignored when matching,
    /// but exact accents / apostrophes rank higher).
    /// - Parameter contractionsOnly: used right after the user typed an apostrophe ("we'" -> "we're").
    func completionCandidates(forKey key: String,
                              typedLower: String,
                              limit: Int,
                              contractionsOnly: Bool = false) -> [WordCandidate] {
        guard !key.isEmpty, limit > 0 else { return [] }
        var top: [WordCandidate] = []

        func consider(_ word: String, _ score: Double) {
            if top.count == limit, let last = top.last, score <= last.score { return }
            if top.contains(where: { $0.word == word }) { return }
            var position = top.count
            while position > 0 && top[position - 1].score < score {
                position -= 1
            }
            top.insert(WordCandidate(word: word, score: score), at: position)
            if top.count > limit { top.removeLast() }
        }

        var index = lowerBound(of: key)
        var scanned = 0
        while index < entries.count, scanned < 8000, entries[index].folded.hasPrefix(key) {
            let entry = entries[index]
            index += 1
            scanned += 1
            if contractionsOnly && !entry.word.contains("'") { continue }
            var score = entry.norm
            if entry.word.hasPrefix(typedLower) { score += 0.12 }   // typed accents / apostrophe match exactly
            consider(entry.word, score)
        }

        for (word, count) in learned {
            guard let learnedKey = learnedKeys[word], learnedKey.hasPrefix(key) else { continue }
            if contractionsOnly && !word.contains("'") { continue }
            var score = 0.55 + min(0.35, log(Double(count) + 1) * 0.12)
            if word.hasPrefix(typedLower) { score += 0.12 }
            consider(word, score)
        }
        return top
    }

    /// Whole words one typo away from `key` (swapped letters, a neighbouring key, a missing or extra letter).
    func fuzzyCandidates(forKey key: String, limit: Int) -> [WordCandidate] {
        let typed = Array(key)
        guard typed.count >= 3, limit > 0, let first = typed.first else { return [] }
        var top: [WordCandidate] = []

        var index = lowerBound(of: String(first))
        while index < entries.count, entries[index].folded.first == first {
            let entry = entries[index]
            index += 1
            if abs(entry.length - typed.count) > 1 || entry.folded == key { continue }
            guard let kind = editKind(typed, Array(entry.folded)) else { continue }
            var score = entry.norm * 0.8
            switch kind {
            case .transposition: score += 0.25
            case .neighborSubstitution: score += 0.25
            case .missingLetter, .extraLetter: score += 0.10
            case .otherSubstitution: break
            }
            if top.count == limit, let last = top.last, score <= last.score { continue }
            var position = top.count
            while position > 0 && top[position - 1].score < score {
                position -= 1
            }
            top.insert(WordCandidate(word: entry.word, score: score), at: position)
            if top.count > limit { top.removeLast() }
        }
        return top
    }

    private enum EditKind {
        case transposition, neighborSubstitution, otherSubstitution, missingLetter, extraLetter
    }

    /// The single edit that turns `typed` into `word` (nil if they differ by more than one edit).
    private func editKind(_ typed: [Character], _ word: [Character]) -> EditKind? {
        let n = typed.count
        let m = word.count
        var i = 0
        while i < n && i < m && typed[i] == word[i] { i += 1 }

        if n == m {
            if i + 1 < n, typed[i] == word[i + 1], typed[i + 1] == word[i], typed[(i + 2)...] == word[(i + 2)...] {
                return .transposition
            }
            guard typed[(i + 1)...] == word[(i + 1)...] else { return nil }
            return (neighbors[typed[i]]?.contains(word[i]) ?? false) ? .neighborSubstitution : .otherSubstitution
        }
        if n + 1 == m {   // the word has one more letter than typed
            return typed[i...] == word[(i + 1)...] ? .missingLetter : nil
        }
        if n == m + 1 {   // typed has one extra letter
            return typed[(i + 1)...] == word[i...] ? .extraLetter : nil
        }
        return nil
    }

    private static func neighborMap(for language: Language) -> [Character: Set<Character>] {
        var map: [Character: Set<Character>] = [:]
        let rows: [[Character]] = language.letterRows.map { row in
            row.compactMap { TextFolding.fold($0).first }
        }
        for (r, row) in rows.enumerated() {
            for (c, letter) in row.enumerated() {
                var set = map[letter] ?? []
                if c > 0 { set.insert(row[c - 1]) }
                if c + 1 < row.count { set.insert(row[c + 1]) }
                for other in [r - 1, r + 1] where other >= 0 && other < rows.count {
                    for d in -1...1 {
                        let k = c + d
                        if k >= 0 && k < rows[other].count { set.insert(rows[other][k]) }
                    }
                }
                map[letter] = set
            }
        }
        return map
    }

    /// Best completions for what the user has typed so far, most likely first (this language only).
    func completions(for typed: String, limit: Int) -> [String] {
        let normalized = TextFolding.normalizeApostrophes(typed)
        return completionCandidates(forKey: TextFolding.key(normalized),
                                    typedLower: normalized.lowercased(),
                                    limit: limit).map { $0.word }
    }

    /// Dictionary indices of words that start near `first` and end near `last` (swipe typing).
    func candidateIndices(first: [Character], last: [Character]) -> [Int] {
        var result: [Int] = []
        for f in first {
            for l in last {
                if let list = edgeIndex[String([f, l])] {
                    result.append(contentsOf: list)
                }
            }
        }
        return result
    }

    // MARK: Next-word prediction

    /// Words the user typed after `previous` (most frequent first), then a few built-in common pairs.
    func nextWords(after previous: String, limit: Int) -> [String] {
        let prev = TextFolding.normalizeApostrophes(previous).lowercased()
        guard !prev.isEmpty, limit > 0 else { return [] }
        let prefix = prev + " "
        var found: [(word: String, count: Int)] = []
        for (pair, count) in bigrams where pair.hasPrefix(prefix) {
            found.append((word: String(pair.dropFirst(prefix.count)), count: count))
        }
        found.sort { $0.count > $1.count }
        var result = found.prefix(limit).map { $0.word }
        if result.count < limit, let builtIn = WordStore.commonPairs[language.rawValue]?[prev] {
            for word in builtIn where !result.contains(word) {
                result.append(word)
                if result.count >= limit { break }
            }
        }
        return result
    }

    private static let commonPairs: [String: [String: [String]]] = [
        "en": [
            "i": ["am", "have", "think", "will"], "i'm": ["not", "going", "sure"], "i'll": ["be", "do", "see"],
            "i've": ["been", "got", "never"], "thank": ["you"], "thanks": ["for", "so"], "how": ["are", "do", "to"],
            "what": ["is", "are", "do"], "see": ["you"], "let's": ["go", "see", "do"], "do": ["you", "not", "it"],
            "you": ["are", "can", "have"], "it's": ["a", "not", "the"], "we": ["are", "can", "have"],
            "good": ["morning", "night", "luck"], "i'd": ["like", "love", "be"], "can": ["you", "i", "we"],
            "don't": ["know", "worry", "forget"], "see you": ["soon", "later", "tomorrow"], "looking": ["forward"],
            "talk": ["to", "soon", "later"], "have": ["a", "you", "to"], "is": ["it", "this", "there"],
            "of": ["course", "the", "my"], "on": ["my", "the", "it"], "in": ["the", "a", "my"],
            "happy": ["birthday", "new", "to"], "no": ["problem", "worries", "way"], "sounds": ["good", "great"],
        ],
        "hu": [
            "jó": ["reggelt", "estét", "napot"], "nagyon": ["szépen", "jó", "köszönöm"], "hogy": ["vagy", "van", "lehet"],
            "köszönöm": ["szépen", "a", "nagyon"], "szia": ["hogy", "mizu"], "mi": ["újság", "van", "a"],
            "viszlát": ["holnap", "később"], "kérlek": ["szépen", "hívj"], "szeretlek": ["téged"],
            "boldog": ["születésnapot", "karácsonyt", "új"], "sajnálom": ["hogy", "nagyon"],
        ],
    ]

    // MARK: Learning

    /// Remembers a word the dictionary does not know (names, slang) so it can be suggested later.
    func learn(_ word: String) {
        let lower = TextFolding.normalizeApostrophes(word).lowercased()
        guard lower.count >= 3, lower.count <= 24 else { return }
        let key = TextFolding.key(lower)
        let index = lowerBound(of: key)
        if index < entries.count, entries[index].folded == key { return }   // already known

        learned[lower, default: 0] += 1
        if learned.count > 1500 {
            let weakest = learned.sorted { $0.value < $1.value }.prefix(300)
            for (weakWord, _) in weakest { learned.removeValue(forKey: weakWord) }
            rebuildLearnedKeys()
        } else if learnedKeys[lower] == nil {
            learnedKeys[lower] = key
            learnedKeySet.insert(key)
        }
        scheduleSave()
    }

    /// Counts that `next` followed `previous`. Counts fade as the list fills up, so old habits expire.
    func learnBigram(previous: String, next: String) {
        let a = TextFolding.normalizeApostrophes(previous).lowercased()
        let b = TextFolding.normalizeApostrophes(next).lowercased()
        guard !a.isEmpty, !b.isEmpty, a.count <= 24, b.count <= 24 else { return }
        bigrams[a + " " + b, default: 0] += 1
        if bigrams.count > 2000 {
            var faded: [String: Int] = [:]
            for (pair, count) in bigrams where count > 1 { faded[pair] = count / 2 + count % 2 }
            if faded.count > 1500 {
                faded = Dictionary(uniqueKeysWithValues: faded.sorted { $0.value > $1.value }.prefix(1500).map { ($0.key, $0.value) })
            }
            bigrams = faded
        }
        scheduleSave()
    }

    func forgetLearnedWords() {
        learned = [:]
        bigrams = [:]
        rebuildLearnedKeys()
    }

    private func scheduleSave() {
        if saveScheduled { return }
        saveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.saveNow()
        }
    }

    /// Writes learned words and pairs to the shared settings (also called when the keyboard goes away).
    func saveNow() {
        guard saveScheduled else { return }
        saveScheduled = false
        Settings.shared.setLearnedWords(learned, for: language.rawValue)
        Settings.shared.setLearnedBigrams(bigrams, for: language.rawValue)
    }
}
