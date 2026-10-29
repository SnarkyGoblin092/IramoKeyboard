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
    private var trigrams: [String: Int]
    /// "word" / "a b" / "a b c" -> last day it was used (days since 1970); older use counts for less.
    private var usage: [String: Int]
    private var prefixCache: [String: [Int]] = [:]
    private let keyLetters: Set<Character>
    private let neighbors: [Character: Set<Character>]
    private var saveScheduled = false

    init(language: Language) {
        self.language = language
        self.keyLetters = language.keyLetterSet
        self.learned = Settings.shared.learnedWords(for: language.rawValue)
        self.bigrams = Settings.shared.learnedBigrams(for: language.rawValue)
        self.trigrams = Settings.shared.learnedTrigrams(for: language.rawValue)
        self.usage = Settings.shared.learnedUsage(for: language.rawValue)
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
        prefixCache = [:]
        frequencyOrder = nil
        isLoaded = true
    }

    // MARK: Recency

    private static var today: Int { return Int(Date().timeIntervalSince1970 / 86_400) }

    /// 1 for something used today, halving every ~45 days without use.
    private func recency(_ key: String) -> Double {
        guard let day = usage[key] else { return 1 }
        let age = max(0, WordStore.today - day)
        return pow(0.5, Double(age) / 45)
    }

    private func effective(_ count: Int, key: String) -> Double {
        return Double(count) * recency(key)
    }

    private func touch(_ key: String) { usage[key] = WordStore.today }

    /// The most frequent words that start with a short prefix (cached), so one or two typed letters never
    /// scan thousands of words per keystroke.
    private func topIndices(forPrefix prefix: String) -> [Int] {
        if let cached = prefixCache[prefix] { return cached }
        var matches: [Int] = []
        var index = lowerBound(of: prefix)
        while index < entries.count, entries[index].folded.hasPrefix(prefix) {
            matches.append(index)
            index += 1
        }
        matches.sort { entries[$0].freq > entries[$1].freq }
        let top = Array(matches.prefix(60))
        if prefixCache.count > 400 { prefixCache = [:] }
        prefixCache[prefix] = top
        return top
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

        func entryScore(_ entry: WordEntry) -> Double {
            var score = entry.norm
            if entry.word.hasPrefix(typedLower) { score += 0.12 }       // typed accents / apostrophe match exactly
            if entry.folded == key && entry.word != typedLower { score += 0.15 }   // "szep" -> "szép"
            let extra = entry.length - key.count
            if extra > 0 { score -= min(0.10, 0.012 * Double(extra)) }   // common short words beat rare long ones
            return score
        }

        if key.count <= 3 && !contractionsOnly {
            for index in topIndices(forPrefix: key) {
                let entry = entries[index]
                consider(entry.word, entryScore(entry))
            }
        } else {
            var index = lowerBound(of: key)
            var scanned = 0
            while index < entries.count, scanned < 3000, entries[index].folded.hasPrefix(key) {
                let entry = entries[index]
                index += 1
                scanned += 1
                if contractionsOnly && !entry.word.contains("'") { continue }
                consider(entry.word, entryScore(entry))
            }
        }

        for (word, count) in learned {
            guard let learnedKey = learnedKeys[word], learnedKey.hasPrefix(key) else { continue }
            if contractionsOnly && !word.contains("'") { continue }
            var score = 0.50 + min(0.35, log(effective(count, key: word) + 1) * 0.12)
            if word.hasPrefix(typedLower) { score += 0.12 }
            consider(word, score)
        }
        return top
    }

    /// Whole words a typo or two away from `key`: neighbouring-key slips cost half, swapped / missing / extra /
    /// other wrong letters cost one. The cheapest, most frequent words win.
    func fuzzyCandidates(forKey key: String, limit: Int) -> [WordCandidate] {
        let typed = Array(key)
        guard typed.count >= 3, limit > 0, let first = typed.first else { return [] }
        var top: [WordCandidate] = []
        let maxCost = typed.count >= 6 ? 1.6 : 1.1

        // The first letter is usually right; a neighbouring key slip is the other likely case.
        var starts: Set<Character> = [first]
        if let near = neighbors[first] { starts.formUnion(near) }
        if typed.count >= 2 { starts.insert(typed[1]) }   // first letter doubled / extra

        for start in starts {
            var index = lowerBound(of: String(start))
            while index < entries.count, entries[index].folded.first == start {
                let entry = entries[index]
                index += 1
                if abs(entry.length - typed.count) > 2 || entry.folded == key { continue }
                guard let cost = editCost(typed, Array(entry.folded), limit: maxCost) else { continue }
                let score = entry.norm * 0.75 + (maxCost - cost) * 0.30
                if top.count == limit, let last = top.last, score <= last.score { continue }
                if top.contains(where: { $0.word == entry.word }) { continue }
                var position = top.count
                while position > 0 && top[position - 1].score < score {
                    position -= 1
                }
                top.insert(WordCandidate(word: entry.word, score: score), at: position)
                if top.count > limit { top.removeLast() }
            }
        }
        return top
    }

    /// Weighted Damerau-Levenshtein distance, or nil as soon as it must exceed `limit`.
    private func editCost(_ a: [Character], _ b: [Character], limit: Double) -> Double? {
        let n = a.count
        let m = b.count
        if n == 0 || m == 0 { return nil }
        var previousPrevious = [Double](repeating: 0, count: m + 1)
        var previous = (0...m).map { Double($0) }
        var current = [Double](repeating: 0, count: m + 1)
        for i in 1...n {
            current[0] = Double(i)
            var rowMin = current[0]
            for j in 1...m {
                var substitution = 1.0
                if a[i - 1] == b[j - 1] {
                    substitution = 0
                } else if neighbors[a[i - 1]]?.contains(b[j - 1]) ?? false {
                    substitution = 0.5
                }
                var best = min(previous[j - 1] + substitution, min(previous[j] + 1, current[j - 1] + 1))
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    best = min(best, previousPrevious[j - 2] + 0.8)
                }
                current[j] = best
                rowMin = min(rowMin, best)
            }
            if rowMin > limit { return nil }
            previousPrevious = previous
            previous = current
        }
        let cost = previous[m]
        return cost <= limit ? cost : nil
    }

    // MARK: Frequency order (elision continuations)

    private var frequencyOrder: [Int]?

    /// The most frequent words whose first letter is in `letters` (used after "l'", "j'", "dell'" ...).
    func frequentWords(startingWith letters: Set<Character>, limit: Int) -> [WordCandidate] {
        if frequencyOrder == nil {
            let capped = min(entries.count, 6000)
            frequencyOrder = Array(0..<entries.count).sorted { entries[$0].freq > entries[$1].freq }.prefix(capped).map { $0 }
        }
        var result: [WordCandidate] = []
        for index in frequencyOrder ?? [] {
            let entry = entries[index]
            guard let letter = entry.folded.first, letters.contains(letter), !entry.word.contains("'"), entry.length >= 2 else { continue }
            result.append(WordCandidate(word: entry.word, score: entry.norm))
            if result.count >= limit { break }
        }
        return result
    }

    // MARK: Context

    private func pairStrength(_ count: Int, key: String) -> Double {
        return min(0.6, 0.25 + log(effective(count, key: key) + 1) * 0.15)
    }

    /// 0...0.7: how strongly the preceding word(s) point at `next` (user triples, user pairs, then built-in pairs).
    func bigramBonus(previous: String, next: String, before2: String? = nil) -> Double {
        let prev = TextFolding.normalizeApostrophes(previous).lowercased()
        let following = TextFolding.normalizeApostrophes(next).lowercased()
        guard !prev.isEmpty, !following.isEmpty else { return 0 }
        var bonus = 0.0
        if let before2 = before2 {
            let first = TextFolding.normalizeApostrophes(before2).lowercased()
            let tripleKey = first + " " + prev + " " + following
            if !first.isEmpty, let count = trigrams[tripleKey] {
                bonus = pairStrength(count, key: tripleKey) + 0.1
            }
        }
        let pairKey = prev + " " + following
        if let count = bigrams[pairKey] {
            bonus = max(bonus, pairStrength(count, key: pairKey))
        } else if bonus == 0, let list = WordStore.commonPairs[language.rawValue]?[prev],
                  let position = list.firstIndex(of: following) {
            bonus = 0.35 - 0.05 * Double(position)
        }
        return bonus
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

    /// word -> 0...1: how much this user writes each learned word (more and more recent = higher). A plain value
    /// copy that is safe to hand to another thread.
    func personalStrengths() -> [String: Double] {
        var result: [String: Double] = [:]
        for (word, count) in learned {
            let key = learnedKeys[word] ?? TextFolding.key(word)
            let strength = effective(count, key: key)
            result[word] = min(1, log(1 + strength) / log(31))
        }
        return result
    }

    /// Entries for learned words (names, slang...) so swiping can find them too. Duplicates of dictionary words
    /// are skipped by the decoder.
    func learnedEntries() -> [WordEntry] {
        return learned.compactMap { (word, count) -> WordEntry? in
            let folded = learnedKeys[word] ?? TextFolding.key(word)
            guard folded.count >= 2 else { return nil }
            let norm = min(0.9, 0.35 + log(1 + Double(count)) / 12)
            return WordEntry(word: word, folded: folded, freq: count, norm: norm, length: folded.count)
        }
    }

    /// word -> bonus for every word known to follow `previous`; a plain value copy that is safe to hand to another thread.
    func contextBonuses(after previous: String, before2: String? = nil) -> [String: Double] {
        let prev = TextFolding.normalizeApostrophes(previous).lowercased()
        guard !prev.isEmpty else { return [:] }
        var result: [String: Double] = [:]
        let prefix = prev + " "
        for (pair, count) in bigrams where pair.hasPrefix(prefix) {
            result[String(pair.dropFirst(prefix.count))] = pairStrength(count, key: pair)
        }
        if let list = WordStore.commonPairs[language.rawValue]?[prev] {
            for (position, word) in list.enumerated() where result[word] == nil {
                result[word] = 0.35 - 0.05 * Double(position)
            }
        }
        if let before2 = before2 {
            let triplePrefix = TextFolding.normalizeApostrophes(before2).lowercased() + " " + prefix
            for (triple, count) in trigrams where triple.hasPrefix(triplePrefix) {
                result[String(triple.dropFirst(triplePrefix.count))] = pairStrength(count, key: triple) + 0.1
            }
        }
        return result
    }

    // MARK: Next-word prediction

    /// Likely words after `previous` (and `before2`): user triples, user pairs, then built-in pairs; never `previous` itself.
    func nextWords(after previous: String, before2: String? = nil, limit: Int) -> [String] {
        let prev = TextFolding.normalizeApostrophes(previous).lowercased()
        guard !prev.isEmpty, limit > 0 else { return [] }
        var scored: [String: Double] = [:]
        for (word, bonus) in contextBonuses(after: prev, before2: before2) where word != prev {
            scored[word] = bonus
        }
        var result = scored.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
        if result.count < limit, let builtIn = WordStore.commonPairs[language.rawValue]?[prev] {
            for word in builtIn where !result.contains(word) && word != prev {
                result.append(word)
                if result.count >= limit { break }
            }
        }
        return result
    }

    /// Words that typically open a sentence: the ones the user starts sentences with, then built-in / frequent words.
    func sentenceStarters(limit: Int) -> [String] {
        var result: [String] = []
        let learnedStarts = bigrams.filter { $0.key.hasPrefix(". ") }
            .sorted { $0.value > $1.value }
            .map { String($0.key.dropFirst(2)) }
        for word in learnedStarts where result.count < limit { result.append(word) }
        for word in WordStore.starters[language.rawValue] ?? [] where result.count < limit && !result.contains(word) {
            result.append(word)
        }
        if result.count < limit {
            let blocked: Set<String> = ["the", "a", "an", "of", "to", "and"]
            for candidate in frequentWords(startingWith: Set("abcdefghijklmnopqrstuvwxyz"), limit: 40)
            where result.count < limit && !result.contains(candidate.word) && candidate.word.count >= 2 && !blocked.contains(candidate.word) {
                result.append(candidate.word)
            }
        }
        return result
    }

    private static let starters: [String: [String]] = [
        "en": ["i", "the", "thanks", "hey", "hi", "what", "do", "can", "we", "it's"],
        "hu": ["szia", "köszi", "én", "nem", "hogy", "mi", "jó", "igen", "ma", "nagyon"],
        "de": ["ich", "hallo", "danke", "das", "wir", "was", "ja", "nein", "es", "hast"],
        "fr": ["je", "salut", "merci", "bonjour", "on", "c'est", "oui", "non", "tu", "il"],
        "es": ["hola", "gracias", "yo", "no", "sí", "qué", "me", "es", "buenos", "te"],
        "it": ["ciao", "grazie", "io", "non", "sì", "che", "come", "è", "ho", "buongiorno"],
        "pt": ["olá", "obrigado", "eu", "não", "sim", "o", "que", "bom", "tudo", "oi"],
        "nl": ["hoi", "dank", "ik", "het", "wat", "ja", "nee", "we", "je", "goed"],
    ]

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
        touch(lower)
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

    /// Counts that `next` followed `previous`. Old, unused pairs fade (by last-use date) when the list fills up.
    func learnBigram(previous: String, next: String) {
        let a = TextFolding.normalizeApostrophes(previous).lowercased()
        let b = TextFolding.normalizeApostrophes(next).lowercased()
        guard !a.isEmpty, !b.isEmpty, a.count <= 24, b.count <= 24 else { return }
        let key = a + " " + b
        bigrams[key, default: 0] += 1
        touch(key)
        if bigrams.count > 2000 { bigrams = pruned(bigrams, keep: 1500) }
        scheduleSave()
    }

    /// Counts that `next` followed the two words `first second` (context for stronger predictions).
    func learnTrigram(first: String, second: String, next: String) {
        let a = TextFolding.normalizeApostrophes(first).lowercased()
        let b = TextFolding.normalizeApostrophes(second).lowercased()
        let c = TextFolding.normalizeApostrophes(next).lowercased()
        guard !a.isEmpty, !b.isEmpty, !c.isEmpty, a.count <= 24, b.count <= 24, c.count <= 24 else { return }
        let key = a + " " + b + " " + c
        trigrams[key, default: 0] += 1
        touch(key)
        if trigrams.count > 2000 { trigrams = pruned(trigrams, keep: 1500) }
        scheduleSave()
    }

    /// Keeps the `keep` entries with the highest recency-weighted count; survivors' counts are halved so new habits can overtake old ones.
    private func pruned(_ table: [String: Int], keep: Int) -> [String: Int] {
        let ranked = table.sorted { effective($0.value, key: $0.key) > effective($1.value, key: $1.key) }.prefix(keep)
        var result: [String: Int] = [:]
        for (key, count) in ranked { result[key] = max(1, count / 2 + count % 2) }
        let dropped = Set(table.keys).subtracting(result.keys)
        for key in dropped { usage.removeValue(forKey: key) }
        return result
    }

    func forgetLearnedWords() {
        learned = [:]
        bigrams = [:]
        trigrams = [:]
        usage = [:]
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
        Settings.shared.setLearnedTrigrams(trigrams, for: language.rawValue)
        Settings.shared.setLearnedUsage(usage, for: language.rawValue)
    }
}
