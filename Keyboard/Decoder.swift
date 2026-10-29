import Foundation

/// The typing decoder: every suggestion, auto-correction and next word comes from one probability,
///
///     score(word) = log10 P(word | previous words, language mix) - slip * typing cost(typed keys, word)
///
/// P comes from each enabled language's trigram model (`LanguageModel`), weighted by how well each language explains
/// the recent text, plus the user's own habits. The typing cost is the weighted Damerau-Levenshtein distance between
/// the keys typed and the word's letters (a neighbouring key 0.5, two swapped letters 0.8, anything else 1; accents
/// and apostrophes are free, the keys have none): against the word's best-fitting beginning while typing, so words
/// complete, and against the whole word on space.
///
/// scripts/predict_eval/decoder.py is the reference implementation the settings were tuned on; keep the two in step.
enum Decoder {
    // Tuned with scripts/predict_eval/tune.py.
    static let slip = 3.5               // log10 cost of one typing mistake
    static let firstLetter = 0.6        // extra log10 cost when the first letter is wrong
    static let unknownWord = -10.0      // log10 probability of a word no dictionary has (a name, slang)
    static let correctMargin = 1.0      // log10 margin a correction needs over the text as typed
    private static let candidateLimit = 30
    private static let maxCost = 2.0
    private static let weightFloor = 0.02

    /// True when at least one loaded language has its language model (otherwise the older predictor is used).
    static func isAvailable(_ stores: [Language: WordStore]) -> Bool {
        return stores.values.contains { $0.isLoaded && $0.model != nil }
    }

    // MARK: Context

    struct Context {
        /// P(language | recent text), summing to 1 over the loaded languages.
        var weights: [Language: Double] = [:]
        /// Per language: language model ids of the current sentence, sentence start first.
        var histories: [Language: [Int32]] = [:]
        /// The last two words of the current sentence (lower-case), for the user's own word pairs.
        var previous: String?
        var before2: String?
        var atSentenceStart = true
    }

    private enum Token {
        case word(String)
        case comma
        case end
    }

    /// Words, commas and sentence ends of the last few hundred characters.
    private static func tokens(_ text: String) -> [Token] {
        var result: [Token] = []
        var current = ""
        func flush() {
            if !current.isEmpty {
                let cleaned = TextFolding.normalizeApostrophes(current).trimmingCharacters(in: CharacterSet(charactersIn: "'"))
                if !cleaned.isEmpty { result.append(.word(cleaned)) }
                current = ""
            }
        }
        for character in text.suffix(300) {
            if Predictor.isWordCharacter(character) {
                current.append(character)
                continue
            }
            flush()
            if character == "," {
                result.append(.comma)
            } else if character == "." || character == "!" || character == "?" || character == "…" || character == "\n" {
                result.append(.end)
            }
        }
        flush()
        return result
    }

    private static func lowered(_ word: String, _ language: Language) -> String {
        if language == .turkish { return word.lowercased(with: Locale(identifier: "tr")) }
        return word.lowercased()
    }

    /// The context of the text before the caret (which must not include the word being typed).
    static func context(before: String, active: Language, stores: [Language: WordStore]) -> Context {
        var context = Context()
        let tokens = Decoder.tokens(before)
        var scores: [Language: Double] = [:]
        for (language, store) in stores where store.isLoaded {
            var history: [Int32] = [LanguageModel.start]
            var recent: [Double] = []   // log10 probabilities of the last words, for the language weights
            for token in tokens {
                switch token {
                case .end:
                    history = [LanguageModel.start]
                case .comma:
                    if history.count > 1 && history.last != LanguageModel.comma { history.append(LanguageModel.comma) }
                case .word(let word):
                    let lower = lowered(word, language)
                    let id = store.modelId(of: lower) ?? LanguageModel.unknown
                    if let model = store.model {
                        let u = history.count >= 2 ? history[history.count - 2] : nil
                        recent.append(model.logProb(id, previous: history[history.count - 1], before: u))
                    } else {
                        recent.append(store.unigramLogProb(of: lower) ?? -9)
                    }
                    if recent.count > 8 { recent.removeFirst() }
                    history.append(id)
                }
            }
            context.histories[language] = history
            scores[language] = recent.reduce(0, +) + (language == active ? log10(1.5) : 0)
        }
        if let top = scores.values.max() {
            var total = 0.0
            for (language, score) in scores {
                let weight = pow(10, score - top)
                context.weights[language] = weight
                total += weight
            }
            context.weights = context.weights.mapValues { $0 / total }
        }

        var sentence: [String] = []
        for token in tokens {
            switch token {
            case .end: sentence = []
            case .comma: break
            case .word(let word): sentence.append(word.lowercased())
            }
        }
        context.atSentenceStart = sentence.isEmpty
        context.previous = sentence.last
        context.before2 = sentence.count >= 2 ? sentence[sentence.count - 2] : nil
        return context
    }

    // MARK: Probability

    /// log10 P(word | context), mixed over the languages, with the user's habits and the field's words added.
    static func logProb(_ word: String,
                        context: Context,
                        stores: [Language: WordStore],
                        field: Predictor.FieldContext?) -> Double {
        var total = 0.0
        var personal = 0.0
        for (language, weight) in context.weights where weight >= 1e-6 {
            guard let store = stores[language] else { continue }
            var value: Double? = nil
            if let model = store.model, let id = store.modelId(of: word), let history = context.histories[language] {
                let u = history.count >= 2 ? history[history.count - 2] : nil
                value = model.logProb(id, previous: history[history.count - 1], before: u)
            } else if store.model == nil {
                value = store.unigramLogProb(of: word)
            }
            if let learned = store.learnedLogProb(word) { value = max(value ?? -99, learned) }
            if let value = value { total += weight * pow(10, value) }
            personal = max(personal, store.personalLogBonus(word, previous: context.previous, before2: context.before2))
        }
        var result = total > 0 ? log10(total) : -99
        result += personal
        if let field = field { result += 2 * field.bonus(for: word) }
        return result
    }

    // MARK: Typing cost

    /// (cost against the word's best-fitting beginning, cost against the whole word) of typing `typed` for
    /// `word`, both match keys. Same as `typing_cost` in decoder.py.
    static func typingCost(_ typed: [Character], _ word: [Character], near: [Set<Character>]) -> (prefix: Double, whole: Double) {
        let n = typed.count
        var previous2 = [Double](repeating: 0, count: n + 1)
        var previous = (0...n).map { Double($0) }
        var row = [Double](repeating: 0, count: n + 1)
        var bestPrefix = previous[n]
        guard !word.isEmpty else { return (bestPrefix, previous[n]) }
        for i in 1...word.count {
            let character = word[i - 1]
            row[0] = Double(i)
            if n > 0 {
                for j in 1...n {
                    let t = typed[j - 1]
                    let substitution: Double = t == character ? 0 : (near[j - 1].contains(character) ? 0.5 : 1)
                    var value = min(previous[j - 1] + substitution, min(previous[j] + 1, row[j - 1] + 1))
                    if i > 1, j > 1, t == word[i - 2], typed[j - 2] == character {
                        value = min(value, previous2[j - 2] + 0.8)
                    }
                    row[j] = value
                }
            }
            bestPrefix = min(bestPrefix, row[n])
            previous2 = previous
            previous = row
        }
        return (bestPrefix, previous[n])
    }

    // MARK: Candidates

    private struct Row {
        let word: String
        let logProb: Double
        let prefixCost: Double
        let wholeCost: Double
        let firstWrong: Bool
    }

    private static func variants(of key: [Character], near: [Character: Set<Character>]) -> [String] {
        var result: Set<String> = [String(key)]
        for (i, character) in key.enumerated() {
            for other in near[character] ?? [] {
                var copy = key
                copy[i] = other
                result.insert(String(copy))
            }
        }
        return Array(result)
    }

    private static func rows(typed: String,
                             before: String,
                             active: Language,
                             ordered: [Language],
                             stores: [Language: WordStore],
                             field: Predictor.FieldContext?) -> (rows: [Row], lower: String, context: Context) {
        let lower = TextFolding.normalizeApostrophes(typed).lowercased()
        let key = Array(TextFolding.key(lower))
        var head = before
        if !typed.isEmpty, head.hasSuffix(typed) { head = String(head.dropLast(typed.count)) }
        let context = Decoder.context(before: head, active: active, stores: stores)
        guard let first = key.first else { return ([], lower, context) }
        let near = stores[active]?.neighbors ?? [:]
        let keyString = String(key)

        var words = Set<String>()
        for language in ordered {
            guard let store = stores[language], store.isLoaded else { continue }
            for candidate in store.completionCandidates(forKey: keyString, typedLower: lower, limit: candidateLimit) {
                words.insert(candidate.word)
            }
            if key.count >= 3 {
                for candidate in store.fuzzyCompletionCandidates(forKey: keyString, limit: candidateLimit) { words.insert(candidate.word) }
                for candidate in store.fuzzyCandidates(forKey: keyString, limit: candidateLimit) { words.insert(candidate.word) }
            } else {
                // One or two letters: every slip to a neighbouring key, looked up directly.
                for variant in variants(of: key, near: near) {
                    for candidate in store.completionCandidates(forKey: variant, typedLower: variant, limit: 8) {
                        words.insert(candidate.word)
                    }
                }
            }
            // What the language model expects here, if it starts like the typed word.
            if let model = store.model, (context.weights[language] ?? 0) >= 0.05, let history = context.histories[language] {
                var starts: Set<Character> = [first]
                starts.formUnion(near[first] ?? [])
                if key.count >= 2 { starts.insert(key[1]) }
                let u = history.count >= 2 ? history[history.count - 2] : nil
                for id in model.followers(previous: history[history.count - 1], before: u)
                where id >= LanguageModel.firstWord {
                    if let entry = store.entry(forModelId: id), let letter = entry.folded.first, starts.contains(letter) {
                        words.insert(entry.word)
                    }
                }
            }
        }
        // Words already in the field complete too, even when no dictionary has them.
        if let field = field {
            for word in field.counts.keys where TextFolding.key(word).hasPrefix(keyString) { words.insert(word) }
        }

        let nearTyped = key.map { near[$0] ?? [] }
        var result: [Row] = []
        for word in words {
            let wordKey = Array(TextFolding.key(word))
            guard !wordKey.isEmpty else { continue }
            let cost = typingCost(key, wordKey, near: nearTyped)
            guard cost.prefix <= maxCost else { continue }
            result.append(Row(word: word,
                              logProb: logProb(word, context: context, stores: stores, field: field),
                              prefixCost: cost.prefix,
                              wholeCost: cost.whole,
                              firstWrong: wordKey[0] != first))
        }
        return (result, lower, context)
    }

    private static func ranked(_ rows: [Row], whole: Bool) -> [(word: String, score: Double)] {
        var scored: [(word: String, score: Double)] = []
        for row in rows {
            let cost = whole ? row.wholeCost : row.prefixCost
            guard cost <= maxCost else { continue }
            scored.append((row.word, row.logProb - slip * cost - (row.firstWrong ? firstLetter : 0)))
        }
        scored.sort { $0.score == $1.score ? $0.word < $1.word : $0.score > $1.score }
        return scored
    }

    // MARK: The keyboard's questions

    /// Up to `limit` words for the word being typed, best first (never the typed text itself). `before` includes it.
    static func suggest(typed: String,
                        before: String,
                        active: Language,
                        enabled: [Language],
                        stores: [Language: WordStore],
                        limit: Int,
                        field: Predictor.FieldContext?) -> [String] {
        let ordered = ([active] + enabled.filter { $0 != active }).filter { stores[$0]?.isLoaded == true }
        let found = rows(typed: typed, before: before, active: active, ordered: ordered, stores: stores, field: field)
        return Array(ranked(found.rows, whole: false).map { $0.word }.filter { $0 != found.lower }.prefix(limit))
            .map { written($0, context: found.context, stores: stores) }
    }

    /// How to write `word`: as the language that most likely produced it writes it ("i'm" -> "I'm", "london" ->
    /// "London", German "haus" -> "Haus"); unchanged when no dictionary has it.
    static func written(_ word: String, context: Context, stores: [Language: WordStore]) -> String {
        var best: (weight: Double, text: String)? = nil
        for (language, store) in stores where store.isLoaded {
            guard let text = store.written(word) else { continue }
            let weight = context.weights[language] ?? 0
            if best == nil || weight > best!.weight { best = (weight, text) }
        }
        return best?.text ?? word
    }

    /// What space should leave in place of the word just typed, or nil to keep it: the most likely word, when it
    /// is clearly more likely than the text as typed ("vsgyok" -> "vagyok", "koszonom" -> "köszönöm",
    /// "dont" -> "don't"), written the way its language writes it ("im" -> "I'm", "monday" -> "Monday"). Words the
    /// user taught the keyboard, or keeps using in the field, are left alone.
    static func autoCorrect(typed: String,
                            before: String,
                            active: Language,
                            enabled: [Language],
                            stores: [Language: WordStore],
                            field: Predictor.FieldContext?) -> String? {
        let lower = TextFolding.normalizeApostrophes(typed).lowercased()
        guard !lower.isEmpty, lower.allSatisfy({ Predictor.isWordCharacter($0) }) else { return nil }
        // ALLCAPS, iPhone: deliberate spellings.
        guard typed.filter({ $0.isUppercase }).count < 2 else { return nil }
        if field?.uses(lower, atLeast: 2) == true { return nil }
        if stores.values.contains(where: { $0.isLearned(lower) }) { return nil }

        let ordered = ([active] + enabled.filter { $0 != active }).filter { stores[$0]?.isLoaded == true }
        let found = rows(typed: typed, before: before, active: active, ordered: ordered, stores: stores, field: field)
        var choice = lower
        if let best = ranked(found.rows, whole: true).first, best.word != lower {
            let typedScore = max(logProb(lower, context: found.context, stores: stores, field: field), unknownWord)
            if best.score >= typedScore + correctMargin { choice = best.word }
        }
        // Someone writing everything in lower case keeps it that way.
        let text = field?.style == .lower ? choice : written(choice, context: found.context, stores: stores)
        // Nothing to change: the word stays as typed, in whatever case the user typed it.
        if text == TextFolding.normalizeApostrophes(typed) || (choice == lower && text == lower) { return nil }
        return text
    }

    /// The likeliest next words (the text ends with a space), capitalised at a sentence start.
    static func nextWords(before: String,
                          active: Language,
                          stores: [Language: WordStore],
                          limit: Int,
                          field: Predictor.FieldContext?) -> [String] {
        let context = Decoder.context(before: before, active: active, stores: stores)
        var combined: [String: Double] = [:]
        var bestLanguage: [String: (language: Language, weight: Double)] = [:]
        for (language, weight) in context.weights where weight >= weightFloor {
            guard let store = stores[language], let model = store.model, let history = context.histories[language] else { continue }
            let u = history.count >= 2 ? history[history.count - 2] : nil
            for (id, logProb) in model.nextWords(previous: history[history.count - 1], before: u,
                                                 count: limit * 4, common: model.mostCommon(100)) {
                guard let entry = store.entry(forModelId: id) else { continue }
                combined[entry.word, default: 0] += weight * pow(10, logProb)
                if weight > (bestLanguage[entry.word]?.weight ?? 0) { bestLanguage[entry.word] = (language, weight) }
            }
        }
        // The user's own habits and the field's words.
        for (language, weight) in context.weights where weight >= weightFloor {
            guard let store = stores[language] else { continue }
            for follower in store.userFollowers(of: context.previous ?? ".") {
                combined[follower.word] = max(combined[follower.word] ?? 0, 1e-4) * pow(10, follower.strength)
                if bestLanguage[follower.word] == nil { bestLanguage[follower.word] = (language, weight) }
            }
        }
        if let field = field {
            for (word, value) in combined { combined[word] = value * pow(10, 2 * field.bonus(for: word)) }
        }
        if let previous = context.previous { combined.removeValue(forKey: previous) }
        let ranked = combined.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.prefix(limit)
        return ranked.map { item in
            let text = written(item.key, context: context, stores: stores)
            guard context.atSentenceStart else { return text }
            return Predictor.capitalized(text, language: bestLanguage[item.key]?.language ?? active)
        }
    }
}
