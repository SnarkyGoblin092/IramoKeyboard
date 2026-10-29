import Foundation

/// Chooses the words shown in the suggestion strip.
///
/// All enabled languages are searched. The active layout's language gets a head start, and the
/// language of the last few words (the "context") gets one too, so typing English in the Hungarian
/// layout soon offers English words. Weak prefix matches from another language never push out decent
/// matches in the language being used.
enum Predictor {

    // MARK: Tokens

    /// Letters and apostrophes (straight or curly) form words.
    static func isWordCharacter(_ character: Character) -> Bool {
        return character.isLetter || TextFolding.isApostrophe(character)
    }

    /// The last `count` whole words in `text` (lower-case, straight apostrophes), oldest first.
    static func lastWords(in text: String, count: Int) -> [String] {
        var words: [String] = []
        var current: [Character] = []
        for character in text.suffix(120).reversed() {
            if isWordCharacter(character) {
                current.append(character)
            } else if !current.isEmpty {
                words.append(clean(String(current.reversed())))
                current = []
                if words.count >= count { break }
            }
        }
        if !current.isEmpty && words.count < count { words.append(clean(String(current.reversed()))) }
        return Array(words.filter { !$0.isEmpty }.reversed())
    }

    private static func clean(_ token: String) -> String {
        var text = TextFolding.normalizeApostrophes(token).lowercased()
        while text.first == "'" { text.removeFirst() }
        while text.last == "'" { text.removeLast() }
        return text
    }

    // MARK: Language context

    /// How strongly the recent text points at each language, 0...1. The active layout's weight is the
    /// share of recent words it knows; another language only gets weight for words the active one does not know.
    static func contextWeights(before: String,
                               currentPrefix: String,
                               active: Language,
                               stores: [Language: WordStore]) -> [Language: Double] {
        var text = before
        if !currentPrefix.isEmpty, text.hasSuffix(currentPrefix) { text = String(text.dropLast(currentPrefix.count)) }
        let words = lastWords(in: text, count: 4).filter { TextFolding.key($0).count >= 3 }
        guard !words.isEmpty else { return [:] }

        var hits: [Language: Int] = [:]
        for (language, store) in stores where store.isLoaded {
            var count = 0
            for word in words where store.contains(key: TextFolding.key(word)) { count += 1 }
            hits[language] = count
        }
        let total = Double(words.count)
        let activeHits = hits[active] ?? 0
        var weights: [Language: Double] = [active: Double(activeHits) / total]
        for (language, count) in hits where language != active {
            weights[language] = max(0, Double(count - activeHits)) / total
        }
        return weights
    }

    // MARK: Completions

    /// Up to `limit` words for the token being typed, best first. The typed token itself is never returned.
    static func suggest(typed: String,
                        before: String,
                        active: Language,
                        enabled: [Language],
                        stores: [Language: WordStore],
                        limit: Int) -> [String] {
        let token = TextFolding.normalizeApostrophes(typed)
        let lower = token.lowercased()
        let key = TextFolding.key(token)
        guard !key.isEmpty, limit > 0 else { return [] }
        let endsWithApostrophe = lower.hasSuffix("'")

        let weights = contextWeights(before: before, currentPrefix: typed, active: active, stores: stores)
        let ordered = ([active] + enabled.filter { $0 != active }).filter { stores[$0]?.isLoaded == true }
        let activeConfident = (weights[active] ?? 0) >= 0.6

        // The word right before the one being typed (only when it is directly separated by a space).
        var previousWord: String? = nil
        var head = before
        if !typed.isEmpty, head.hasSuffix(typed) { head = String(head.dropLast(typed.count)) }
        if head.hasSuffix(" ") { previousWord = lastWords(in: head, count: 1).first }

        var best: [String: Double] = [:]
        var activeCount = 0

        func add(_ candidates: [WordCandidate], bonus: Double, language: Language, prefix: String = "") {
            for candidate in candidates {
                let word = prefix + candidate.word
                if word == lower { continue }
                let isExact = TextFolding.key(word) == key
                if language != active {
                    // Another language: only with context support, as an accent variant of what was typed,
                    // or when the active language has little to offer. A confident context shuts it out.
                    let supported = (weights[language] ?? 0) > 0
                    if !supported && !isExact && activeCount >= (activeConfident ? 1 : 2) { continue }
                }
                var score = candidate.score + bonus
                if let previous = previousWord, let store = stores[language] {
                    score += store.bigramBonus(previous: previous, next: word)
                }
                if score > (best[word] ?? -1) { best[word] = score }
                if language == active { activeCount += 1 }
            }
        }

        for language in ordered {
            guard let store = stores[language] else { continue }
            let bonus = (language == active ? 0.30 : 0) + 0.5 * (weights[language] ?? 0)
            add(store.completionCandidates(forKey: key,
                                           typedLower: lower,
                                           limit: 8,
                                           contractionsOnly: endsWithApostrophe),
                bonus: bonus,
                language: language)

            // French / Italian elision: "l'" + word, "dell'" + word ...
            if let (elisionHead, tail) = splitElision(lower, language: language) {
                if tail.isEmpty {
                    // Just typed "j'": offer the usual continuations (vowel or silent h).
                    let letters: Set<Character> = language == .french
                        ? Set("aeiouyhàâéèêîôû")
                        : Set("aeiouhàèéìòù")
                    add(store.frequentWords(startingWith: letters, limit: 6),
                        bonus: bonus,
                        language: language,
                        prefix: elisionHead + "'")
                } else {
                    let tailKey = TextFolding.key(tail)
                    add(store.completionCandidates(forKey: tailKey, typedLower: tail, limit: 6),
                        bonus: bonus,
                        language: language,
                        prefix: elisionHead + "'")
                }
            }
        }

        // The typed word is not a word anywhere: offer the closest real ones (one or two slips).
        if !endsWithApostrophe && key.count >= 3 {
            let known = ordered.contains { stores[$0]?.contains(key: key) == true }
            if !known || best.count < 2 {
                for language in ordered where language == active || (weights[language] ?? 0) >= 0.5 {
                    guard let store = stores[language] else { continue }
                    let bonus = (language == active ? 0.30 : 0) + 0.5 * (weights[language] ?? 0)
                    add(store.fuzzyCandidates(forKey: key, limit: 4), bonus: bonus, language: language)
                }
            }
        }

        return best.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    // MARK: Missing apostrophes

    private static let englishApostrophes: [String: String] = [
        "dont": "don't", "cant": "can't", "doesnt": "doesn't", "didnt": "didn't", "isnt": "isn't",
        "arent": "aren't", "wasnt": "wasn't", "werent": "weren't", "hasnt": "hasn't", "havent": "haven't",
        "hadnt": "hadn't", "couldnt": "couldn't", "wouldnt": "wouldn't", "shouldnt": "shouldn't",
        "mustnt": "mustn't", "im": "i'm", "ive": "i've", "youre": "you're", "theyre": "they're",
        "thats": "that's", "whats": "what's", "theres": "there's", "youve": "you've", "theyve": "they've",
        "youll": "you'll", "theyll": "they'll", "itll": "it'll", "couldve": "could've", "wouldve": "would've",
        "shouldve": "should've", "mightve": "might've", "mustve": "must've", "whos": "who's",
        "heres": "here's", "hows": "how's", "wheres": "where's",
    ]

    /// "dont" -> "don't" for typed words that are not words without the apostrophe (English only).
    static func withApostrophe(_ typed: String, language: Language) -> String? {
        guard language == .english else { return nil }
        return englishApostrophes[typed.lowercased()]
    }

    private static let elisionHeads: [Language: Set<String>] = [
        .french: ["l", "d", "j", "m", "n", "s", "t", "c", "qu", "jusqu", "lorsqu", "puisqu", "quoiqu"],
        .italian: ["l", "un", "dell", "all", "dall", "nell", "sull", "quest", "quell", "c", "d", "m", "t", "s", "v", "nessun", "buon", "sant", "bell", "tutt", "com", "dov", "cos"],
    ]

    /// "l'ami" -> ("l", "ami") when the part before the apostrophe is an elided word.
    static func splitElision(_ token: String, language: Language) -> (head: String, tail: String)? {
        guard let heads = elisionHeads[language], let index = token.firstIndex(of: "'") else { return nil }
        let head = String(token[token.startIndex..<index])
        let tail = String(token[token.index(after: index)...])
        guard heads.contains(head) else { return nil }
        return (head, tail)
    }

    // MARK: Next word

    /// Words likely to follow the last finished word (when the text ends with a space).
    static func nextWords(before: String,
                          active: Language,
                          enabled: [Language],
                          stores: [Language: WordStore],
                          limit: Int) -> [String] {
        guard let last = before.last, last == " " else { return [] }
        var trimmed = before
        while trimmed.last == " " { trimmed.removeLast() }
        guard let tail = trimmed.last, isWordCharacter(tail), let previous = lastWords(in: trimmed, count: 1).first,
              !previous.isEmpty else { return [] }

        let weights = contextWeights(before: before, currentPrefix: "", active: active, stores: stores)
        var languages = [active]
        if let foreign = weights.filter({ $0.key != active && $0.value >= 0.5 }).max(by: { $0.value < $1.value })?.key {
            languages.insert(foreign, at: 0)
        }

        var result: [String] = []
        for language in languages {
            guard let store = stores[language] else { continue }
            for word in store.nextWords(after: previous, limit: limit) where !result.contains(word) {
                result.append(word)
            }
        }
        return Array(result.prefix(limit))
    }
}
