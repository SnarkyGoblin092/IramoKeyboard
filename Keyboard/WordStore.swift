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
    /// True when every word of the list is loaded (false when it was cut at a limit).
    private(set) var isFull = false
    /// The word limit the dictionary was loaded with (nil = none), for the languages that are not the active layout.
    private(set) var loadedLimit: Int?
    private(set) var maxLogFreq: Double = 1

    /// "first letter + last letter" key -> word indices, for swipe typing.
    private(set) var edgeIndex: [String: [Int]] = [:]
    private var learned: [String: Int]
    /// Dictionary words the user wrote -> how often, so their own vocabulary outranks the corpus's.
    private var used: [String: Int]
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
        self.used = Settings.shared.usedWords(for: language.rawValue)
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
        let limit: Int?
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
    static func parse(language: Language, limit: Int? = nil) -> Parsed {
        guard let url = Bundle.main.url(forResource: "words_\(language.rawValue)", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return Parsed(entries: [], edges: [:], maxLogFreq: 1, isFull: limit == nil, limit: limit)
        }

        // One pass: the file is sorted by frequency, so the first row has the highest count, and its second
        // column already holds the match key (folding 100k+ words here would be slow).
        var list: [WordEntry] = []
        list.reserveCapacity(limit ?? 160_000)
        var maxLog = 1.0
        text.enumerateLines { line, stop in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3, let freq = Int(parts[2]) else { return }
            if list.isEmpty { maxLog = max(log(Double(freq) + 1), 1) }
            let word = TextFolding.normalizeApostrophes(String(parts[0]))
            let key = parts[1].isEmpty ? TextFolding.key(word) : String(parts[1])
            guard !key.isEmpty else { return }
            list.append(WordEntry(word: word,
                                  folded: key,
                                  freq: freq,
                                  norm: min(1, log(Double(freq) + 1) / maxLog),
                                  length: key.count))
            if let limit = limit, list.count >= limit { stop = true }
        }
        list.sort { $0.folded < $1.folded }

        // Index by first + last letter so the swipe decoder only looks at plausible words.
        var edges: [String: [Int]] = [:]
        let keys = language.keyLetterSet
        var memo: [Character: Character?] = [:]
        for (index, entry) in list.enumerated() {
            var first: Character? = nil
            var last: Character? = nil
            var count = 0
            for character in entry.word {
                let letter: Character?
                if let known = memo[character] {
                    letter = known
                } else {
                    letter = keyLetter(for: character, in: keys)
                    memo[character] = letter
                }
                guard let found = letter else { continue }
                if first == nil { first = found }
                last = found
                count += 1
            }
            guard count >= 2, let start = first, let end = last else { continue }
            edges[String([start, end]), default: []].append(index)
        }
        // A limit the list never reached still loaded every word.
        let isFull = limit.map { list.count < $0 } ?? true
        return Parsed(entries: list, edges: edges, maxLogFreq: maxLog, isFull: isFull, limit: limit)
    }

    func apply(_ parsed: Parsed) {
        entries = parsed.entries
        edgeIndex = parsed.edges
        maxLogFreq = parsed.maxLogFreq
        isFull = parsed.isFull
        loadedLimit = parsed.limit
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
        let top = Array(matches.prefix(100))
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
            WordStore.insert(WordCandidate(word: word, score: score), into: &top, limit: limit)
        }

        func entryScore(_ entry: WordEntry) -> Double {
            var score = entry.norm
            if entry.word.hasPrefix(typedLower) { score += 0.12 }       // typed accents / apostrophe match exactly
            if entry.folded == key && entry.word != typedLower { score += 0.15 }   // "szep" -> "szép"
            let extra = entry.length - key.count
            if extra > 0 { score -= min(0.10, 0.012 * Double(extra)) }   // common short words beat rare long ones
            return score + personalBonus(entry.word)
        }

        if key.count <= 3 && !contractionsOnly {
            for index in topIndices(forPrefix: key) {
                let entry = entries[index]
                consider(entry.word, entryScore(entry))
            }
        } else {
            var index = lowerBound(of: key)
            var scanned = 0
            // The run is alphabetical, so stopping early would hide frequent words late in the alphabet; the cap
            // only guards against pathological lists.
            while index < entries.count, scanned < 40_000, entries[index].folded.hasPrefix(key) {
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
        guard typed.count >= 3, limit > 0 else { return [] }
        var top: [WordCandidate] = []
        let maxCost = typed.count >= 6 ? 1.6 : 1.1
        fuzzyScan(typed, maxCost: maxCost) { entry, _, wholeCost in
            guard let cost = wholeCost, cost <= maxCost, entry.folded != key,
                  abs(entry.length - typed.count) <= 2 else { return }
            let score = entry.norm * 0.75 + (maxCost - cost) * 0.30 + self.personalBonus(entry.word)
            WordStore.insert(WordCandidate(word: entry.word, score: score), into: &top, limit: limit)
        }
        return top
    }

    /// Words whose beginning is a slip or two away from what was typed, so one typo does not stop completion
    /// ("bilenty" -> "billentyűzet", "mrg" -> "meg"). Exact prefixes are left to `completionCandidates`.
    /// Scores are on the same scale as completions: frequency minus the cost of the slips.
    func fuzzyCompletionCandidates(forKey key: String, limit: Int) -> [WordCandidate] {
        let typed = Array(key)
        guard typed.count >= 3, limit > 0 else { return [] }
        // Three letters allow one neighbouring-key slip, longer ones one real mistake, long ones a bit more.
        let maxCost = typed.count >= 7 ? 1.5 : (typed.count >= 4 ? 1.0 : 0.5)
        var top: [WordCandidate] = []
        fuzzyScan(typed, maxCost: maxCost) { entry, prefixCost, _ in
            guard prefixCost > 0 else { return }   // an exact prefix
            // Most typing is right, so every slip costs; a wrong first letter is rarer still.
            var score = entry.norm - 0.10 - 0.40 * prefixCost
            if entry.folded.first != typed.first { score -= 0.20 }
            let extra = entry.length - typed.count
            if extra > 0 { score -= min(0.10, 0.012 * Double(extra)) }
            score += self.personalBonus(entry.word)
            WordStore.insert(WordCandidate(word: entry.word, score: score), into: &top, limit: limit)
        }
        return top
    }

    /// Reports every word whose beginning is within `maxCost` of `typed`: `prefixCost` compares `typed` with the
    /// word's best-fitting beginning, `wholeCost` (for words at most two letters longer) with the whole word.
    /// Weighted Damerau-Levenshtein: neighbouring-key slips cost 0.5, swapped letters 0.8, other mistakes 1.
    /// Only words starting with the typed first letter, a key next to it, or the second typed letter (first letter
    /// doubled / extra) are looked at. The list is sorted, so words with a common beginning share its rows.
    private func fuzzyScan(_ typed: [Character],
                           maxCost: Double,
                           visit: (_ entry: WordEntry, _ prefixCost: Double, _ wholeCost: Double?) -> Void) {
        let n = typed.count
        guard n > 0, let firstTyped = typed.first else { return }
        let width = n + 1
        let depth = n + 2
        let near = typed.map { neighbors[$0] ?? [] }
        var table = [Double](repeating: 0, count: (depth + 1) * width)   // row r: the word's first r letters
        for j in 0...n { table[j] = Double(j) }
        var rowMin = [Double](repeating: 0, count: depth + 1)
        var letters = [Character](repeating: " ", count: depth)

        var starts: Set<Character> = [firstTyped]
        starts.formUnion(near[0])
        if n >= 2 { starts.insert(typed[1]) }

        for start in starts {
            var index = lowerBound(of: String(start))
            var known = 0   // leading rows of `table` that still belong to `letters`
            while index < entries.count, entries[index].folded.first == start {
                let entry = entries[index]
                index += 1
                var row = 0
                var shared = true
                var complete = true
                var prefixCost = Double.greatestFiniteMagnitude
                for character in entry.folded {
                    if row == depth { complete = false; break }
                    if !(shared && row < known && letters[row] == character) {
                        shared = false
                        letters[row] = character
                        let r = row + 1
                        let base = r * width
                        let up = base - width
                        table[base] = Double(r)
                        var minimum = table[base]
                        for j in 1...n {
                            let t = typed[j - 1]
                            let substitution: Double = t == character ? 0 : (near[j - 1].contains(character) ? 0.5 : 1)
                            var value = min(table[up + j - 1] + substitution, min(table[up + j] + 1, table[base + j - 1] + 1))
                            if r > 1, j > 1, t == letters[r - 2], typed[j - 2] == character {
                                value = min(value, table[up - width + j - 2] + 0.8)
                            }
                            table[base + j] = value
                            minimum = min(minimum, value)
                        }
                        rowMin[r] = minimum
                    }
                    row += 1
                    prefixCost = min(prefixCost, table[row * width + n])
                    // Two rows over the limit: no longer beginning can get back under it (a swap reaches back two).
                    if rowMin[row] > maxCost && rowMin[row - 1] > maxCost { complete = false; break }
                }
                known = row
                guard prefixCost <= maxCost else { continue }
                visit(entry, prefixCost, complete ? table[row * width + n] : nil)
            }
        }
    }

    /// Keeps `top` best first, at most `limit` long, one entry per word.
    private static func insert(_ candidate: WordCandidate, into top: inout [WordCandidate], limit: Int) {
        if top.count == limit, let last = top.last, candidate.score <= last.score { return }
        if top.contains(where: { $0.word == candidate.word }) { return }
        var position = top.count
        while position > 0 && top[position - 1].score < candidate.score {
            position -= 1
        }
        top.insert(candidate, at: position)
        if top.count > limit { top.removeLast() }
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

    /// word -> 0...1: how much this user writes each learned word (more and more recent = higher). A plain value
    /// copy that is safe to hand to another thread.
    func personalStrengths() -> [String: Double] {
        var result: [String: Double] = [:]
        for (word, count) in learned {
            let key = learnedKeys[word] ?? TextFolding.key(word)
            let strength = effective(count, key: key)
            result[word] = min(1, log(1 + strength) / log(31))
        }
        for (word, count) in used {
            result[word] = min(1, log(1 + effective(count, key: word)) / log(31))
        }
        return result
    }

    /// 0...0.3 for dictionary words this user writes, by how often and how recently.
    private func personalBonus(_ word: String) -> Double {
        guard !used.isEmpty, let count = used[word] else { return 0 }
        return min(0.30, 0.10 * log(1 + effective(count, key: word)))
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

    /// Counts a dictionary word the user wrote (exact spelling), so it ranks higher from now on. Returns false when
    /// this dictionary does not have the word. A negative `delta` takes a use back (a swiped word that was replaced).
    @discardableResult
    func noteUse(_ word: String, delta: Int = 1) -> Bool {
        let lower = TextFolding.normalizeApostrophes(word).lowercased()
        let key = TextFolding.key(lower)
        guard !key.isEmpty, lower.count <= 24 else { return false }
        var index = lowerBound(of: key)
        var found = false
        while index < entries.count, entries[index].folded == key {
            if entries[index].word == lower { found = true; break }
            index += 1
        }
        guard found else { return false }
        let count = (used[lower] ?? 0) + delta
        if count <= 0 { used.removeValue(forKey: lower) } else { used[lower] = count }
        if delta > 0 { touch(lower) }
        if used.count > 3000 { used = pruned(used, keep: 2400) }
        scheduleSave()
        return true
    }

    func forgetLearnedWords() {
        learned = [:]
        used = [:]
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
        Settings.shared.setUsedWords(used, for: language.rawValue)
        Settings.shared.setLearnedBigrams(bigrams, for: language.rawValue)
        Settings.shared.setLearnedTrigrams(trigrams, for: language.rawValue)
        Settings.shared.setLearnedUsage(usage, for: language.rawValue)
    }
}
