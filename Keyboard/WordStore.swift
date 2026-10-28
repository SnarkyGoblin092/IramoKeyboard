import Foundation

struct WordEntry {
    let word: String      // as written, lower-case, with accents ("szép")
    let folded: String    // accent-free ("szep")
    let freq: Int
}

enum TextFolding {
    /// Lower-case and strip accents. Mirrors `fold()` in scripts/build_data.py.
    static func fold(_ text: String) -> String {
        return text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}

/// Frequency dictionary for one language, plus words the user typed that are not in it.
///
/// `entries` is sorted by the folded spelling so prefix lookups are a binary search, and it is
/// immutable after `apply(_:)`, which makes it safe to read from the swipe decoder's thread.
final class WordStore {
    let language: Language

    private(set) var entries: [WordEntry] = []
    private(set) var isLoaded = false
    private(set) var maxLogFreq: Double = 1

    private var edgeIndex: [String: [Int]] = [:]
    private var learned: [String: Int]

    init(language: Language) {
        self.language = language
        self.learned = Settings.shared.learnedWords(for: language.rawValue)
    }

    // MARK: Loading (parse off the main thread, then apply on the main thread)

    struct Parsed {
        let entries: [WordEntry]
        let edges: [String: [Int]]
        let maxLogFreq: Double
    }

    static func parse(language: Language) -> Parsed {
        guard let url = Bundle.main.url(forResource: "words_\(language.rawValue)", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return Parsed(entries: [], edges: [:], maxLogFreq: 1)
        }

        var list: [WordEntry] = []
        list.reserveCapacity(50_000)
        text.enumerateLines { line, _ in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3, let freq = Int(parts[2]) else { return }
            list.append(WordEntry(word: String(parts[0]), folded: String(parts[1]), freq: freq))
        }
        list.sort { $0.folded < $1.folded }

        // Index by first + last letter so the swipe decoder only looks at plausible words.
        var edges: [String: [Int]] = [:]
        var maxFreq = 1
        for (index, entry) in list.enumerated() {
            maxFreq = max(maxFreq, entry.freq)
            let letters = entry.folded.filter { $0 >= "a" && $0 <= "z" }
            guard letters.count >= 2, let first = letters.first, let last = letters.last else { continue }
            edges[String([first, last]), default: []].append(index)
        }
        return Parsed(entries: list, edges: edges, maxLogFreq: max(log(Double(maxFreq) + 1), 1))
    }

    func apply(_ parsed: Parsed) {
        entries = parsed.entries
        edgeIndex = parsed.edges
        maxLogFreq = parsed.maxLogFreq
        isLoaded = true
    }

    // MARK: Lookup

    private func lowerBound(of folded: String) -> Int {
        var low = 0
        var high = entries.count
        while low < high {
            let mid = (low + high) / 2
            if entries[mid].folded < folded {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    /// Best completions for what the user has typed so far, most likely first.
    func completions(for typed: String, limit: Int) -> [String] {
        let folded = TextFolding.fold(typed)
        guard !folded.isEmpty, limit > 0 else { return [] }
        let lowerTyped = typed.lowercased()

        var top: [(word: String, score: Double)] = []

        func consider(_ word: String, _ score: Double) {
            if top.count == limit, let last = top.last, score <= last.score { return }
            if top.contains(where: { $0.word == word }) { return }
            var position = top.count
            while position > 0 && top[position - 1].score < score {
                position -= 1
            }
            top.insert((word: word, score: score), at: position)
            if top.count > limit { top.removeLast() }
        }

        var index = lowerBound(of: folded)
        while index < entries.count, entries[index].folded.hasPrefix(folded) {
            let entry = entries[index]
            var score = log(Double(entry.freq) + 1)
            if entry.word.hasPrefix(lowerTyped) { score += 3 }   // typed accents match exactly
            consider(entry.word, score)
            index += 1
        }

        for (word, count) in learned where TextFolding.fold(word).hasPrefix(folded) {
            consider(word, log(Double(count) + 1) + 8)
        }

        return top.map { $0.word }
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

    // MARK: Learning

    /// Remembers a word the dictionary does not know (names, slang) so it can be suggested later.
    func learn(_ word: String) {
        let lower = word.lowercased()
        guard lower.count >= 3, lower.count <= 24 else { return }
        let folded = TextFolding.fold(lower)
        let index = lowerBound(of: folded)
        if index < entries.count, entries[index].folded == folded { return }   // already known

        learned[lower, default: 0] += 1
        if learned.count > 1500 {
            let weakest = learned.sorted { $0.value < $1.value }.prefix(300)
            for (key, _) in weakest { learned.removeValue(forKey: key) }
        }
        Settings.shared.setLearnedWords(learned, for: language.rawValue)
    }

    func forgetLearnedWords() {
        learned = [:]
    }
}
