import Foundation

/// Chooses the words shown in the suggestion strip.
///
/// All enabled languages are searched and compete on score. The active layout's language gets a head
/// start, and the language of the last few words (the "context") a bigger one, so typing English in the
/// Hungarian layout soon offers English words, while a Hungarian sentence keeps Hungarian suggestions.
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

    fileprivate static func clean(_ token: String) -> String {
        var text = TextFolding.normalizeApostrophes(token).lowercased()
        while text.first == "'" { text.removeFirst() }
        while text.last == "'" { text.removeLast() }
        return text
    }

    // MARK: Field text

    /// What the text already in the field says about the writer: words used (with how recent), the word
    /// right after the caret, the dominant language and the case style. Built once per distinct field text.
    final class FieldContext {
        enum Style { case mixed, lower, upper }
        fileprivate(set) var counts: [String: Int] = [:]
        fileprivate(set) var recency: [String: Double] = [:]
        fileprivate(set) var nextWord: String?
        fileprivate(set) var style: Style = .mixed
        private var dominantKey = ""
        private var dominantValue: Language?

        /// Bounded bonus for a word that is already in the field: grows with use, fades with age.
        func bonus(for word: String) -> Double {
            let key = Predictor.clean(word)
            guard let count = counts[key] else { return 0 }
            let base = min(0.35, 0.10 + 0.05 * Double(min(count, 5)))
            return base * (0.6 + 0.4 * (recency[key] ?? 0))
        }

        func uses(_ word: String, atLeast times: Int = 1) -> Bool {
            return (counts[Predictor.clean(word)] ?? 0) >= times
        }

        /// The enabled language most of the field's words belong to (nil when unclear or too little text).
        func dominant(active: Language, stores: [Language: WordStore]) -> Language? {
            let loaded = stores.filter { $0.value.isLoaded }
            let memo = "\(active)-\(loaded.count)"
            if memo == dominantKey { return dominantValue }
            dominantKey = memo
            dominantValue = nil
            let sample = recency.sorted { $0.value < $1.value }.map { $0.key }.suffix(60)
                .filter { TextFolding.key($0).count >= 3 }
            guard sample.count >= 3, !loaded.isEmpty else { return nil }
            var hits: [Language: Int] = [:]
            for word in sample {
                for language in Predictor.owners(of: word, stores: loaded) { hits[language, default: 0] += 1 }
            }
            let activeHits = hits[active] ?? 0
            var winner = active
            var winnerHits = activeHits
            for (language, count) in hits where count > winnerHits {
                winner = language
                winnerHits = count
            }
            if Double(winnerHits) >= 0.4 * Double(sample.count) { dominantValue = winner }
            return dominantValue
        }
    }

    private static var cachedField: (key: Int, context: FieldContext)?

    private static func tokens(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            if isWordCharacter(character) {
                current.append(character)
            } else if !current.isEmpty {
                let token = clean(current)
                if token.count >= 2 { result.append(token) }
                current = ""
            }
        }
        if !current.isEmpty {
            let token = clean(current)
            if token.count >= 2 { result.append(token) }
        }
        return result
    }

    /// Words of the whole field text (before and after the caret), excluding the word being typed.
    /// Cached by the text itself, capped at a few hundred words.
    static func fieldContext(before: String, after: String) -> FieldContext {
        var hasher = Hasher()
        hasher.combine(before)
        hasher.combine(after)
        let key = hasher.finalize()
        if let cached = cachedField, cached.key == key { return cached.context }

        let context = FieldContext()
        var head = String(before.suffix(2000))
        let lettersSample = head.suffix(300)
        while let last = head.last, isWordCharacter(last) { head.removeLast() }   // the word being typed
        var tail = String(after.prefix(600))
        let midWord = tail.first.map { isWordCharacter($0) } ?? false
        if midWord { while let first = tail.first, isWordCharacter(first) { tail.removeFirst() } }
        else {
            let following = tail.drop(while: { $0 == " " })
            if let first = following.first, isWordCharacter(first) {
                context.nextWord = tokens(in: String(following.prefix(40))).first
            }
        }

        let all = Array(tokens(in: head).suffix(300)) + Array(tokens(in: tail).prefix(100))
        let count = all.count
        for (index, token) in all.enumerated() {
            context.counts[token, default: 0] += 1
            context.recency[token] = count > 1 ? Double(index) / Double(count - 1) : 1
        }

        var letters = 0, upper = 0, lower = 0
        for character in lettersSample where character.isLetter {
            letters += 1
            if character.isUppercase { upper += 1 } else if character.isLowercase { lower += 1 }
        }
        if letters >= 8 && upper == 0 { context.style = .lower }
        else if letters >= 6 && lower == 0 { context.style = .upper }

        cachedField = (key, context)
        return context
    }

    /// Keeps a suggestion in the field's case style (all lower-case / ALL CAPS).
    static func styled(_ word: String, field: FieldContext?, allowLower: Bool = true) -> String {
        guard let field = field else { return word }
        switch field.style {
        case .upper: return word.uppercased()
        case .lower: return allowLower ? word.lowercased() : word
        case .mixed: return word
        }
    }

    // MARK: Language context

    /// The loaded languages a word most likely belongs to: those where it is (nearly) as common as in the language
    /// where it is most common ("the" -> English, "most" -> Hungarian, "is" -> both). Empty when none knows it.
    /// Every language is judged the same way, whichever layout is showing.
    static func owners(of word: String, stores: [Language: WordStore]) -> [Language] {
        let key = TextFolding.key(word)
        var frequencies: [Language: Double] = [:]
        for (language, store) in stores where store.isLoaded {
            let value = store.frequency(ofKey: key)
            if value > 0 { frequencies[language] = value }
        }
        guard let top = frequencies.values.max() else { return [] }
        return frequencies.filter { $0.value >= top - 0.08 }.map { $0.key }
    }

    /// How strongly the recent text points at each language, 0...1: the share of the last few words that belong
    /// to it (see `owners(of:stores:)`).
    static func contextWeights(before: String,
                               currentPrefix: String,
                               active: Language,
                               stores: [Language: WordStore]) -> [Language: Double] {
        var text = before
        if !currentPrefix.isEmpty, text.hasSuffix(currentPrefix) { text = String(text.dropLast(currentPrefix.count)) }
        let words = lastWords(in: text, count: 4).filter { TextFolding.key($0).count >= 3 }
        guard !words.isEmpty else { return [:] }

        var hits: [Language: Int] = [:]
        for word in words {
            for language in owners(of: word, stores: stores) { hits[language, default: 0] += 1 }
        }
        let total = Double(words.count)
        return hits.mapValues { Double($0) / total }
    }

    // MARK: Completions

    /// Up to `limit` words for the token being typed, best first. The typed token itself is never returned.
    static func suggest(typed: String,
                        before: String,
                        active: Language,
                        enabled: [Language],
                        stores: [Language: WordStore],
                        limit: Int,
                        field: FieldContext? = nil,
                        taps: Decoder.Taps? = nil) -> [String] {
        let token = TextFolding.normalizeApostrophes(typed)
        let lower = token.lowercased()
        let key = TextFolding.key(token)
        guard !key.isEmpty, limit > 0 else { return [] }
        let endsWithApostrophe = lower.hasSuffix("'")

        // The language-model decoder; typed apostrophes ("we'", "l'ami") keep the dictionary rules below.
        if Decoder.isAvailable(stores) && !lower.contains("'") {
            return Decoder.suggest(typed: typed, before: before, active: active, enabled: enabled,
                                   stores: stores, limit: limit, field: field, taps: taps)
        }

        let weights = contextWeights(before: before, currentPrefix: typed, active: active, stores: stores)
        let ordered = ([active] + enabled.filter { $0 != active }).filter { stores[$0]?.isLoaded == true }

        // The language of the text already in the field (when it differs from the layout, it wins).
        let dominant = field?.dominant(active: active, stores: stores)
        let foreignDominant: Language? = (dominant != nil && dominant != active) ? dominant : nil
        func languageBonus(_ language: Language) -> Double {
            // The layout's language only breaks near-ties; the language of the text decides.
            var bonus = 0.5 * (weights[language] ?? 0)
            if language == active { bonus += foreignDominant == nil ? 0.08 : 0.03 }
            if language == foreignDominant { bonus += 0.30 }
            return bonus
        }

        // The word right before the one being typed (only when it is directly separated by a space).
        var previousWord: String? = nil
        var wordBeforePrevious: String? = nil
        var head = before
        if !typed.isEmpty, head.hasSuffix(typed) { head = String(head.dropLast(typed.count)) }
        if head.hasSuffix(" ") && !isSentenceStart(head) {
            let words = lastWords(in: head, count: 2)
            previousWord = words.last
            if words.count == 2 { wordBeforePrevious = words[0] }
        }

        var best: [String: Double] = [:]

        // Every enabled language competes on score; `bonus` is the language's head start (the layout's language,
        // and much more the language of the recent words), so another language wins only with a clearly better word.
        func add(_ candidates: [WordCandidate], bonus: Double, language: Language, prefix: String = "") {
            for candidate in candidates {
                let word = prefix + candidate.word
                if word == lower { continue }
                var score = candidate.score + bonus
                if let previous = previousWord, let store = stores[language] {
                    score += store.bigramBonus(previous: previous, next: word, before2: wordBeforePrevious)
                }
                if let field = field {
                    score += field.bonus(for: word)
                    // Mid-text: a word that forms a known pair with the word after the caret.
                    if let following = field.nextWord, let store = stores[language] {
                        score += 0.5 * store.bigramBonus(previous: word, next: following)
                    }
                }
                if score > (best[word] ?? -1) { best[word] = score }
            }
        }

        for language in ordered {
            guard let store = stores[language] else { continue }
            let bonus = languageBonus(language)
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

        // A slip while typing must not stop completion: words whose beginning is a key or two away
        // ("mrg" -> "meg", "bilenty" -> "billentyűzet"). Their scores carry the cost of the slip, so they only
        // win over exact completions when those are much rarer.
        if !endsWithApostrophe && key.count >= 3 {
            for language in ordered {
                guard let store = stores[language] else { continue }
                add(store.fuzzyCompletionCandidates(forKey: key, limit: 4), bonus: languageBonus(language), language: language)
            }
        }

        // Words already in the field complete the prefix too, even when no dictionary has them.
        if let field = field, !endsWithApostrophe {
            for word in field.counts.keys where word != lower && word.count > lower.count {
                let wordKey = TextFolding.key(word)
                guard !wordKey.isEmpty, wordKey.hasPrefix(key) else { continue }
                let score = 0.40 + field.bonus(for: word)
                if score > (best[word] ?? -1) { best[word] = score }
            }
        }

        // The typed word is not a word anywhere: offer the closest real ones (one or two slips).
        if !endsWithApostrophe && key.count >= 3 {
            let known = ordered.contains { stores[$0]?.contains(key: key) == true }
                || (field?.uses(lower) ?? false)
            if !known {
                for language in ordered {
                    guard let store = stores[language] else { continue }
                    let bonus = languageBonus(language)
                    add(store.fuzzyCandidates(forKey: key, limit: 4), bonus: bonus, language: language)
                }
            }
        }

        return best.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    // MARK: Auto-fix (missing accents and apostrophes)

    /// Hand-picked English fixes that hold even though subtitles also spell them without the apostrophe.
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

    /// `suggest` and `autoFix` together (one decoder pass when the language models are there).
    static func suggestAndFix(typed: String,
                              before: String,
                              active: Language,
                              enabled: [Language],
                              stores: [Language: WordStore],
                              limit: Int,
                              field: FieldContext?,
                              taps: Decoder.Taps? = nil) -> (words: [String], fix: String?) {
        if Decoder.isAvailable(stores) && !TextFolding.normalizeApostrophes(typed).contains("'") {
            return Decoder.suggestAndCorrect(typed: typed, before: before, active: active, enabled: enabled,
                                             stores: stores, limit: limit, field: field, taps: taps)
        }
        return (suggest(typed: typed, before: before, active: active, enabled: enabled, stores: stores, limit: limit,
                        field: field, taps: taps),
                autoFix(typed: typed, before: before, active: active, enabled: enabled, stores: stores, field: field,
                        taps: taps))
    }

    /// The spelling to put in place of a word that was just finished, or nil to leave it: its missing accents or
    /// apostrophe, in whichever enabled language it belongs to ("dont" -> "don't", "koszonom" -> "köszönöm",
    /// "deja" -> "déjà", "nao" -> "não"). Never when an enabled language has the word as typed, or the writer keeps
    /// using it; when several languages could fix it, the language of the text decides.
    static func autoFix(typed: String,
                        before: String,
                        active: Language,
                        enabled: [Language],
                        stores: [Language: WordStore],
                        field: FieldContext?,
                        taps: Decoder.Taps? = nil) -> String? {
        if Decoder.isAvailable(stores) {
            return Decoder.autoCorrect(typed: typed, before: before, active: active, enabled: enabled,
                                       stores: stores, field: field, taps: taps)
        }
        let lower = TextFolding.normalizeApostrophes(typed).lowercased()
        guard lower.count >= 2, field?.uses(lower, atLeast: 2) != true else { return nil }
        let languages = ([active] + enabled.filter { $0 != active }).filter { stores[$0]?.isLoaded == true }
        let weights = contextWeights(before: before, currentPrefix: typed, active: active, stores: stores)
        var best: (word: String, score: Double)?
        for language in languages {
            guard let store = stores[language] else { continue }
            var fix: (word: String, norm: Double)?
            if language == .english, let fixed = englishApostrophes[lower] {
                fix = (fixed, 0.8)
            } else {
                switch store.spellingCheck(lower) {
                case .keep: return nil
                case .unknown: break
                case .fix(let word, let norm): fix = (word, norm)
                }
            }
            guard let candidate = fix else { continue }
            let score = candidate.norm + 0.5 * (weights[language] ?? 0) + (language == active ? 0.08 : 0)
            if score > (best?.score ?? -1) { best = (candidate.word, score) }
        }
        return best?.word
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
                          limit: Int,
                          field: FieldContext? = nil) -> [String] {
        // An empty field gets sentence starters from the language models.
        if Decoder.isAvailable(stores) && (before.isEmpty || before.hasSuffix(" ")) {
            return Decoder.nextWords(before: before, active: active, stores: stores, limit: limit, field: field)
        }
        guard let last = before.last, last == " " else { return [] }
        let wide = field == nil ? limit : limit * 2
        let weights = contextWeights(before: before, currentPrefix: "", active: active, stores: stores)
        var languages = [active]
        if let foreign = weights.filter({ $0.key != active && $0.value >= 0.5 }).max(by: { $0.value < $1.value })?.key {
            languages.insert(foreign, at: 0)
        }
        if let fieldLanguage = field?.dominant(active: active, stores: stores),
           fieldLanguage != active, !languages.contains(fieldLanguage) {
            languages.insert(fieldLanguage, at: 0)
        }

        var result: [String] = []
        if isSentenceStart(before) {
            for language in languages {
                guard let store = stores[language] else { continue }
                for word in store.sentenceStarters(limit: limit) {
                    let cased = capitalized(word, language: language)
                    if !result.contains(cased) { result.append(cased) }
                }
            }
            return Array(result.prefix(limit))
        }

        var trimmed = before
        while trimmed.last == " " { trimmed.removeLast() }
        guard let tail = trimmed.last, isWordCharacter(tail) else { return [] }
        let words = lastWords(in: trimmed, count: 2)
        guard let previous = words.last, !previous.isEmpty else { return [] }
        let beforePrevious = words.count == 2 ? words[0] : nil

        // The other enabled languages too, after a word that belongs to them ("thank" in the Hungarian layout ->
        // "you"). A word that is just as much the layout's language's ("is" is Hungarian too) keeps its followers.
        let previousOwners = owners(of: previous, stores: stores)
        if !previousOwners.contains(active) {
            for language in enabled where previousOwners.contains(language) && !languages.contains(language) {
                languages.insert(language, at: 0)
            }
        }

        for language in languages {
            guard let store = stores[language] else { continue }
            for word in store.nextWords(after: previous, before2: beforePrevious, limit: wide)
            where word != previous && !result.contains(word) {
                result.append(word)
            }
        }
        // Too little context-specific knowledge: fill with common words of the language.
        if result.count < wide, let store = stores[active] {
            for candidate in store.frequentWords(startingWith: nil, limit: 12)
            where result.count < wide && candidate.word != previous && candidate.word.count >= 2 && !result.contains(candidate.word) {
                result.append(candidate.word)
            }
        }
        guard let field = field else { return Array(result.prefix(limit)) }

        // Re-rank with the field text: words already used there, and words that pair with the word after the caret.
        var scored: [(word: String, score: Double)] = []
        for (index, word) in result.enumerated() {
            var score = 1.0 - 0.06 * Double(index) + 1.2 * field.bonus(for: word)
            if let following = field.nextWord {
                for language in languages {
                    if let store = stores[language] { score += 0.5 * store.bigramBonus(previous: word, next: following) }
                }
            }
            scored.append((word, score))
        }
        let frequent = field.counts.filter { $0.value >= 2 && $0.key.count >= 3 && $0.key != previous && !result.contains($0.key) }
        for (word, _) in frequent { scored.append((word, 0.35 + field.bonus(for: word))) }
        let order = Dictionary(uniqueKeysWithValues: scored.enumerated().map { ($0.element.word, $0.offset) })
        scored.sort { $0.score == $1.score ? (order[$0.word] ?? 0) < (order[$1.word] ?? 0) : $0.score > $1.score }
        return Array(scored.prefix(limit).map { $0.word })
    }

    // MARK: Sentences and capitalisation

    /// True when the text is empty or its last finished sentence ended with . ! ? (ignoring trailing spaces).
    static func isSentenceStart(_ text: String) -> Bool {
        var trimmed = Substring(text)
        while let last = trimmed.last, last == " " || last == "\n" { trimmed = trimmed.dropLast() }
        guard let last = trimmed.last else { return true }
        return last == "." || last == "!" || last == "?" || last == "…"
    }

    static func capitalized(_ word: String, language: Language = .english) -> String {
        guard let first = word.first else { return word }
        return language.uppercase(String(first)) + word.dropFirst()   // Turkish i -> İ
    }

    /// Applies the typed word's capitalisation (Title, ALLCAPS) to a suggestion.
    static func matchCase(of typed: String, for word: String) -> String {
        let letters = typed.filter { $0.isLetter }
        guard let first = letters.first else { return word }
        if letters.count >= 2 && letters.allSatisfy({ $0.isUppercase }) { return word.uppercased() }
        if first.isUppercase { return capitalized(word) }
        return word
    }
}
