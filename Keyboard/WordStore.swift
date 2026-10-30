import Foundation

struct WordEntry {
    let word: String      // as written, lower-case, with accents and apostrophes ("we're", "szép")
    let folded: String    // match key: accent-free, apostrophe-free ("were", "szep")
    let freq: Int
    let norm: Double      // log-frequency scaled to 0...1 within its language (comparable across languages)
    let length: Int       // number of characters in `folded`
    var rank: Int32 = -1  // line in words_<lang>.tsv (the language model's word id minus 3); -1 for learned words
    var capitals: WordCapitals = .none   // how the word is written ("i'm" -> I'm, "haus" -> Haus)
}

/// How a dictionary word is written (column 4 of words_<lang>.tsv, counted from text by scripts/language_model.py).
enum WordCapitals: UInt8 {
    case none       // as listed, lower case
    case title      // first letter capital: names, English "I'm", German nouns
    case all        // all capitals: "TV", "USA"
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
/// `entries` is sorted by the match key so prefix lookups are a binary search. It is memory-mapped from
/// dict_<lang>.bin (see `Lexicon`), and immutable after `apply(_:)`, which makes it safe to read from the swipe
/// decoder's thread.
final class WordStore {
    let language: Language

    private(set) var entries: Entries = .empty
    private(set) var isLoaded = false
    /// True when every word of the list is loaded (false when it was cut at a limit).
    private(set) var isFull = false
    /// The word limit the dictionary was loaded with (nil = none), for the languages that are not the active layout.
    private(set) var loadedLimit: Int?
    private var learned: [String: Int]
    /// "typed\tmeant" -> how often the user replaced the typed word by the meant one (their own typos).
    private var corrections: [String: Int]
    /// Dictionary words the user wrote -> how often, so their own vocabulary outranks the corpus's.
    private var used: [String: Int]
    private var learnedKeys: [String: String] = [:]   // learned word -> match key
    private var learnedKeySet: Set<String> = []
    private var bigrams: [String: Int]
    private var trigrams: [String: Int]
    /// "word" / "a b" / "a b c" -> last day it was used (days since 1970); older use counts for less.
    private var usage: [String: Int]
    private var prefixCache: [String: [Int]] = [:]
    /// word -> common next words, space separated ("." -> sentence starters); see `Parsed.pairs`.
    private var builtInPairs: [String: String] = [:]
    private let keyLetters: Set<Character>
    /// Keys next to each key of this language's layout (folded letters).
    let neighbors: [Character: Set<Character>]
    /// The word trigram model (nil when the app was built without it).
    private(set) var model: LanguageModel?
    /// Restores accents on words the dictionary lacks (nil for languages without keyless accents).
    private(set) var accentModel: AccentModel?
    private var saveScheduled = false

    init(language: Language) {
        self.language = language
        self.keyLetters = language.keyLetterSet
        self.learned = Settings.shared.learnedWords(for: language.rawValue)
        self.corrections = Settings.shared.corrections(for: language.rawValue)
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
        let entries: Entries
        let isFull: Bool
        let limit: Int?
        /// word -> its most common next words, space separated ("." -> sentence starters), from `pairs_<lang>.tsv`.
        let pairs: [String: String]
        var model: LanguageModel? = nil
        var accents: AccentModel? = nil
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

    /// Opens `dict_<lang>.bin` (memory-mapped, always the whole list), or else parses `words_<lang>.tsv` (sorted by
    /// frequency, most common first).
    /// - Parameter limit: for the text list only: keep the most frequent `limit` words (nil = all). Used for the
    ///   languages that are not the active layout, to keep memory low.
    static func parse(language: Language, limit: Int? = nil) -> Parsed {
        if let lexicon = Lexicon(language: language) {
            return Parsed(entries: Entries(lexicon: lexicon), isFull: true, limit: nil,
                          pairs: parsePairs(language: language), model: LanguageModel(language: language),
                          accents: AccentModel(language: language))
        }
        guard let url = Bundle.main.url(forResource: "words_\(language.rawValue)", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return Parsed(entries: .empty, isFull: limit == nil, limit: limit, pairs: parsePairs(language: language))
        }

        // One pass: the file is sorted by frequency, so the first row has the highest count, and its second
        // column already holds the match key (folding 100k+ words here would be slow).
        var list: [WordEntry] = []
        list.reserveCapacity(limit ?? 160_000)
        var maxLog = 1.0
        var total = 0.0
        var lineNumber = -1
        text.enumerateLines { line, stop in
            lineNumber += 1   // every line, so ranks stay the language model's ids
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3, let freq = Int(parts[2]) else { return }
            total += Double(freq)
            if list.isEmpty { maxLog = max(log(Double(freq) + 1), 1) }
            let word = TextFolding.normalizeApostrophes(String(parts[0]))
            let key = parts[1].isEmpty ? TextFolding.key(word) : String(parts[1])
            guard !key.isEmpty else { return }
            list.append(WordEntry(word: word,
                                  folded: key,
                                  freq: freq,
                                  norm: min(1, log(Double(freq) + 1) / maxLog),
                                  length: key.count,
                                  rank: Int32(lineNumber),
                                  capitals: parts.count >= 4 ? (parts[3] == "T" ? .title : (parts[3] == "U" ? .all : .none)) : .none))
            if let limit = limit, list.count >= limit { stop = true }
        }
        list.sort { $0.folded < $1.folded }
        var byRank = [Int32](repeating: -1, count: lineNumber + 1)
        for (index, entry) in list.enumerated() where entry.rank >= 0 && Int(entry.rank) < byRank.count {
            byRank[Int(entry.rank)] = Int32(index)
        }

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
        return Parsed(entries: Entries(list: list, edges: edges, byRank: byRank, totalCount: max(total, 1)),
                      isFull: isFull, limit: limit, pairs: parsePairs(language: language),
                      model: LanguageModel(language: language))
    }

    /// Reads `pairs_<lang>.tsv`: word <TAB> next words (space separated). Missing file = no built-in pairs.
    private static func parsePairs(language: Language) -> [String: String] {
        guard let url = Bundle.main.url(forResource: "pairs_\(language.rawValue)", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var pairs: [String: String] = [:]
        text.enumerateLines { line, _ in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { return }
            pairs[String(parts[0])] = String(parts[1])
        }
        return pairs
    }

    /// Frees the dictionary (on a memory warning, before it is reloaded smaller). Learned words are kept.
    func unload() {
        entries = .empty
        builtInPairs = [:]
        model = nil
        accentModel = nil
        prefixCache = [:]
        frequencyOrder = nil
        loadedLimit = nil
        isFull = false
        isLoaded = false
    }

    func apply(_ parsed: Parsed) {
        entries = parsed.entries
        isFull = parsed.isFull
        loadedLimit = parsed.limit
        builtInPairs = parsed.pairs
        model = parsed.model
        accentModel = parsed.accents
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
        var matches: [(index: Int, freq: Int)] = []
        let bytes = Array(prefix.utf8)
        var index = lowerBound(of: prefix)
        while index < entries.count, entries.keyHasPrefix(index, bytes) {
            matches.append((index, entries.freq(index)))
            index += 1
        }
        matches.sort { $0.freq > $1.freq }
        let top = matches.prefix(100).map { $0.index }
        if prefixCache.count > 400 { prefixCache = [:] }
        prefixCache[prefix] = top
        return top
    }

    // MARK: Lookup

    private func lowerBound(of key: String) -> Int {
        return entries.lowerBound(key)
    }

    /// True if the dictionary (or the user's own words) contains a word with this match key.
    func contains(key: String) -> Bool {
        guard !key.isEmpty else { return false }
        let index = lowerBound(of: key)
        if index < entries.count, entries.keyEquals(index, Array(key.utf8)) { return true }
        return learnedKeySet.contains(key)
    }

    /// 0...1: how common the most common word with this match key is (a learned word counts as fairly common);
    /// 0 when the language does not know it. Used to tell which language a word belongs to.
    func frequency(ofKey key: String) -> Double {
        guard !key.isEmpty else { return 0 }
        var index = lowerBound(of: key)
        var best = 0.0
        let bytes = Array(key.utf8)
        while index < entries.count, entries.keyEquals(index, bytes) {
            best = max(best, entries[index].norm)
            index += 1
        }
        if best == 0 && learnedKeySet.contains(key) { best = 0.5 }
        return best
    }

    enum SpellingCheck {
        case unknown                          // neither the word nor another spelling of it
        case keep                             // a word as typed
        case fix(word: String, norm: Double)  // the usual spelling of what was typed
    }

    /// What this dictionary says about a finished word typed without its accents or apostrophe: `.fix` when a
    /// spelling with the same letters is far more common ("koszonom" -> "köszönöm", "dont" -> "don't", "deja" ->
    /// "déjà") and clearly the usual one ("ot" could be "őt" or "öt": not fixed); `.keep` when the word is fine
    /// as typed (including the user's own words).
    func spellingCheck(_ typed: String) -> SpellingCheck {
        let lower = TextFolding.normalizeApostrophes(typed).lowercased()
        let key = TextFolding.key(lower)
        guard !key.isEmpty else { return .unknown }
        if learned[lower] != nil || used[lower] != nil { return .keep }
        var typedFreq = 0
        var typedNorm = 0.0
        var best: WordEntry?
        var runnerUp = 0
        var index = lowerBound(of: key)
        while index < entries.count, entries[index].folded == key {
            let entry = entries[index]
            index += 1
            if entry.word == lower {
                typedFreq = entry.freq
                typedNorm = entry.norm
            } else if entry.freq > (best?.freq ?? 0) {
                runnerUp = best?.freq ?? 0
                best = entry
            } else {
                runnerUp = max(runnerUp, entry.freq)
            }
        }
        guard let variant = best else { return typedFreq > 0 ? .keep : .unknown }
        // 50x the typed spelling, which must not be a common word itself ("its" stays), and 3x any other spelling.
        if variant.freq >= 50 * typedFreq && typedNorm < 0.65 && variant.freq >= 3 * runnerUp && variant.norm >= 0.15 {
            return .fix(word: variant.word, norm: variant.norm)
        }
        return typedFreq > 0 ? .keep : .unknown
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
            let bytes = Array(key.utf8)
            while index < entries.count, scanned < 40_000, entries.keyHasPrefix(index, bytes) {
                let entry = entries[index]
                index += 1
                scanned += 1
                if contractionsOnly && !entry.word.contains("'") { continue }
                consider(entry.word, entryScore(entry))
            }
        }

        for (word, count) in learned where count >= WordStore.learnAfter {
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
            while index < entries.count {
                let folded = entries.key(index)
                guard folded.first == start else { break }
                let current = index
                index += 1
                var row = 0
                var shared = true
                var complete = true
                var over = false
                var prefixCost = Double.greatestFiniteMagnitude
                for character in folded {
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
                    if rowMin[row] > maxCost && rowMin[row - 1] > maxCost { complete = false; over = true; break }
                }
                known = row
                guard prefixCost <= maxCost else {
                    // Every word sharing this failed beginning fails the same way: skip them all.
                    if over { index = max(index, lowerBound(of: String(letters[0..<row]) + "\u{10FFFF}")) }
                    continue
                }
                visit(entries[current], prefixCost, complete ? table[row * width + n] : nil)
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

    /// The most frequent words whose first letter is in `letters` (used after "l'", "j'", "dell'" ...); nil = any.
    func frequentWords(startingWith letters: Set<Character>?, limit: Int) -> [WordCandidate] {
        if frequencyOrder == nil {
            frequencyOrder = entries.mostCommon(6000)
        }
        var result: [WordCandidate] = []
        for index in frequencyOrder ?? [] {
            let entry = entries[index]
            guard let letter = entry.folded.first, letters?.contains(letter) ?? letter.isLetter,
                  !entry.word.contains("'"), entry.length >= 2 else { continue }
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
        } else if bonus == 0, let position = builtInFollowers(of: prev).firstIndex(of: following) {
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
        for (word, count) in learned where count >= WordStore.learnAfter {
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
            guard folded.count >= 2, count >= WordStore.learnAfter else { return nil }
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
        for (position, word) in builtInFollowers(of: prev).enumerated() where result[word] == nil {
            result[word] = 0.35 - 0.05 * Double(position)
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
        if result.count < limit {
            for word in builtInFollowers(of: prev) where !result.contains(word) && word != prev {
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
        let builtIn = (WordStore.starters[language.rawValue] ?? []) + builtInFollowers(of: ".")
        for word in builtIn where result.count < limit && !result.contains(word) {
            result.append(word)
        }
        if result.count < limit {
            let blocked: Set<String> = ["the", "a", "an", "of", "to", "and"]
            for candidate in frequentWords(startingWith: nil, limit: 40)
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

    /// The usual next words after `prev`: the hand-picked ones below, then the ones from example sentences.
    private func builtInFollowers(of prev: String) -> [String] {
        var result = WordStore.commonPairs[language.rawValue]?[prev] ?? []
        if let line = builtInPairs[prev] {
            for word in line.split(separator: " ") where !result.contains(String(word)) {
                result.append(String(word))
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
    /// - Parameter asTyped: keep this exact spelling even though the dictionary has the word with accents (an
    ///   auto-fix the user took back), so it is never fixed again.
    func learn(_ word: String, asTyped: Bool = false) {
        let lower = TextFolding.normalizeApostrophes(word).lowercased()
        guard lower.count >= (asTyped ? 2 : 3), lower.count <= 24 else { return }
        let key = TextFolding.key(lower)
        let index = lowerBound(of: key)
        if !asTyped, index < entries.count, entries[index].folded == key { return }   // already known

        // Taking back an auto-correction is a deliberate choice: the word counts as the user's own at once.
        learned[lower, default: 0] += asTyped ? WordStore.learnAfter : 1
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
        corrections = [:]
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
        Settings.shared.setCorrections(corrections, for: language.rawValue)
        Settings.shared.setUsedWords(used, for: language.rawValue)
        Settings.shared.setLearnedBigrams(bigrams, for: language.rawValue)
        Settings.shared.setLearnedTrigrams(trigrams, for: language.rawValue)
        Settings.shared.setLearnedUsage(usage, for: language.rawValue)
    }
}

// MARK: - Language model and personal learning (used by Decoder)

extension WordStore {
    /// The dictionary entry with this exact spelling, if loaded.
    func entry(forWord word: String) -> WordEntry? {
        let key = TextFolding.key(word)
        guard !key.isEmpty else { return nil }
        var index = lowerBound(of: key)
        while index < entries.count, entries[index].folded == key {
            if entries[index].word == word { return entries[index] }
            index += 1
        }
        return nil
    }

    /// The language model's id for a dictionary word (exact spelling), or nil.
    func modelId(of word: String) -> Int32? {
        guard model != nil, let entry = entry(forWord: word), entry.rank >= 0 else { return nil }
        return entry.rank + LanguageModel.firstWord
    }

    /// The loaded dictionary entry of a language model id, or nil (specials, or beyond a secondary store's limit).
    func entry(forModelId id: Int32) -> WordEntry? {
        guard let index = entries.index(ofRank: Int(id - LanguageModel.firstWord)) else { return nil }
        return entries[index]
    }

    /// log10 P(word) from the word counts alone (when the app has no language model for this language).
    func unigramLogProb(of word: String) -> Double? {
        guard let entry = entry(forWord: word) else { return nil }
        return log10(Double(max(entry.freq, 1)) / entries.totalCount)
    }

    /// An unknown word counts as the user's own after this many uses: a slip typed once is not a word.
    static let learnAfter = 2

    func isLearned(_ word: String) -> Bool {
        return (learned[word] ?? 0) >= WordStore.learnAfter
    }

    /// log10 probability of a word the user taught the keyboard (names, slang), by how much they use it; nil if
    /// it is not one.
    func learnedLogProb(_ word: String) -> Double? {
        guard let count = learned[word], count >= WordStore.learnAfter else { return nil }
        return -5.5 + min(2.0, 0.6 * log(1 + effective(count, key: word)))
    }

    /// log10 boost for this user's habits: dictionary words they write, and words they put after `previous`.
    func personalLogBonus(_ word: String, previous: String?, before2: String?) -> Double {
        var bonus = 0.0
        if let count = used[word] {
            bonus += min(0.8, 0.25 * log(1 + effective(count, key: word)))
        }
        if let previous = previous {
            let pair = previous + " " + word
            if let count = bigrams[pair] {
                bonus += min(1.2, 0.5 * log(1 + effective(count, key: pair)))
            }
            if let before2 = before2 {
                let triple = before2 + " " + pair
                if let count = trigrams[triple] {
                    bonus += min(0.6, 0.3 * log(1 + effective(count, key: triple)))
                }
            }
        }
        return bonus
    }

    /// Words this user wrote after `previous` ("." = at a sentence start), with a log10 strength.
    func userFollowers(of previous: String) -> [(word: String, strength: Double)] {
        let prefix = previous + " "
        var result: [(word: String, strength: Double)] = []
        for (pair, count) in bigrams where pair.hasPrefix(prefix) {
            result.append((String(pair.dropFirst(prefix.count)), min(1.2, 0.5 * log(1 + effective(count, key: pair)))))
        }
        return result
    }
}

extension WordStore {
    /// The word as this language writes it ("i'm" -> "I'm", "haus" -> "Haus"), or nil when the dictionary lacks it.
    func written(_ word: String) -> String? {
        guard let entry = entry(forWord: word) else { return nil }
        return WordStore.written(entry, language: language)
    }

    static func written(_ entry: WordEntry, language: Language) -> String {
        switch entry.capitals {
        case .none: return entry.word
        case .title: return Predictor.capitalized(entry.word, language: language)
        case .all: return language.uppercase(entry.word)
        }
    }
}

// MARK: - The user's own typos

extension WordStore {
    /// The user deleted `typed` and wrote `meant` in its place: after `learnAfter` times, typing `typed` offers
    /// (and corrects to) `meant`.
    func learnCorrection(from typed: String, to meant: String) {
        let key = typed + "\t" + meant
        corrections[key, default: 0] += 1
        if corrections.count > 400 {
            for (weak, _) in corrections.sorted(by: { $0.value < $1.value }).prefix(100) { corrections.removeValue(forKey: weak) }
        }
        scheduleSave()
    }

    /// The word the user usually means when they type `typed`, if they taught one.
    func correction(for typed: String) -> String? {
        let prefix = typed + "\t"
        var best: (word: String, count: Int)? = nil
        for (key, count) in corrections where count >= WordStore.learnAfter && key.hasPrefix(prefix) {
            if count > (best?.count ?? 0) { best = (String(key.dropFirst(prefix.count)), count) }
        }
        return best?.word
    }
}
