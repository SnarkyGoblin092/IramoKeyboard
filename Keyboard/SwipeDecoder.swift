import Foundation
import CoreGraphics

/// Turns a finger path over the letter keys into the most likely words.
///
/// Method (a simplified "SHARK2" location channel):
///   1. Only words whose first / last letter is near where the path starts / ends are considered.
///   2. For each candidate, an ideal path through the centres of its letters is built.
///   3. Both paths are resampled to the same number of points and compared point by point.
///   4. The average distance (in key widths) is combined with the word's frequency.
///
/// Accent-free spellings are used for the ideal path, so "szep" matches both "szép" and "szep"
/// and frequency decides, which means Hungarian accents never need extra keys when swiping.
final class SwipeDecoder {
    private let sampleCount = 32

    /// One dictionary the decoder may take words from: the language being typed in (no penalty), or another
    /// language the user switches to often (small penalty).
    struct Source {
        let store: WordStore
        /// The store's words and swipe index, copied when the swipe starts, so a dictionary reloading on the main
        /// thread never changes them under the decoder.
        let entries: [WordEntry]
        let edges: [String: [Int]]
        /// Added to the cost of every word from this source.
        var penalty: Double
        /// word -> extra score (0...0.6) given the word before the swipe (`WordStore.contextBonuses(after:)`).
        var contextBonuses: [String: Double]
        /// word -> how much this user writes it (0...1), from the learned words (`WordStore.personalStrengths()`).
        var personal: [String: Double]
        /// Words the user typed that the built-in dictionary does not have (names, slang).
        var extras: [WordEntry]
        /// word -> bonus (0...0.35) for words already used in the text field.
        var fieldBonuses: [String: Double]

        // Language model scoring (see Decoder): when any source has a model, words are ranked by
        // log10 P(word | context) - shapeWeight * shape cost instead of the frequency mix below.
        /// This language's trigram model and its share of the text (Decoder.Context.weights).
        var model: LanguageModel? = nil
        var weight: Double = 1
        /// The last two language model ids before the swipe.
        var previousId: Int32 = LanguageModel.start
        var beforeId: Int32? = nil
        /// log10 probabilities of the user's own words (`WordStore.learnedLogProb`).
        var learnedLogProbs: [String: Double] = [:]
        /// log10 boosts for the user's habits (words they write, words they put after the previous one).
        var boosts: [String: Double] = [:]

        init(store: WordStore,
             penalty: Double = 0,
             contextBonuses: [String: Double] = [:],
             personal: [String: Double] = [:],
             extras: [WordEntry] = [],
             fieldBonuses: [String: Double] = [:]) {
            self.store = store
            self.entries = store.entries
            self.edges = store.edgeIndex
            self.penalty = penalty
            self.contextBonuses = contextBonuses
            self.personal = personal
            self.extras = extras
            self.fieldBonuses = fieldBonuses
        }

        /// Indices of words that start near one of `first` and end near one of `last`.
        func candidateIndices(first: [Character], last: [Character]) -> [Int] {
            var result: [Int] = []
            for f in first {
                for l in last {
                    if let list = edges[String([f, l])] { result.append(contentsOf: list) }
                }
            }
            return result
        }
    }

    /// log10 cost of one unit of shape mismatch when words are scored with the language models. Tuned with
    /// scripts/predict_eval/tune.py --swipe (decoder.py SHAPE).
    static let shapeWeight = 10.0

    func decode(path rawPath: [CGPoint],
                keyCenters: [Character: CGPoint],
                keySize: CGSize,
                sources: [Source],
                limit: Int = 4) -> [String] {
        let path = thinned(rawPath, minimumStep: 2)
        guard path.count >= 2, let start = path.first, let end = path.last else { return [] }

        let keyWidth = max(keySize.width, 1)
        // A swipe that starts or ends between two keys is judged against several nearby keys.
        let startKeys = nearestKeys(to: start, centers: keyCenters, within: keyWidth * 1.9, count: 5)
        let endKeys = nearestKeys(to: end, centers: keyCenters, within: keyWidth * 1.9, count: 5)
        guard !startKeys.isEmpty, !endKeys.isEmpty else { return [] }

        let pathLength = length(of: path)
        let sampledPath = resample(path, count: sampleCount)

        // Keys the finger came near. A word with a letter elsewhere fails the coverage test below anyway, so it is
        // rejected before any geometry (most candidates of a big dictionary end here).
        var nearKeys = Set<Character>()
        for (key, center) in keyCenters
        where sampledPath.contains(where: { distance($0, center) <= keyWidth * 1.9 }) {
            nearKeys.insert(key)
        }

        var scored: [(word: String, score: Double)] = []
        var seen = Set<String>()
        // Language model scoring: word -> (best shape cost, summed weighted probability, best personal boost).
        let usesModels = sources.contains { $0.model != nil }
        var found: [String: (shape: Double, probability: Double, boost: Double)] = [:]

        func consider(_ entry: WordEntry, source: Source, keyFor: (Character) -> Character?) {
            if seen.contains(entry.word) { return }
            // Ideal path: centres of the word's letters, consecutive duplicates collapsed (a double letter is
            // one pass over the key).
            var template: [CGPoint] = []
            var previous: Character? = nil
            for character in entry.word where character.isLetter {
                guard let key = keyFor(character), nearKeys.contains(key) else { return }
                if key == previous { continue }
                previous = key
                guard let center = keyCenters[key] else { return }
                template.append(center)
            }
            guard template.count >= 2, let templateStart = template.first, let templateEnd = template.last else { return }

            // Start and end matter most: a swipe begins on the first letter and lifts on the last.
            let startMiss = Double(distance(start, templateStart) / keyWidth)
            let endMiss = Double(distance(end, templateEnd) / keyWidth)
            if startMiss > 1.9 || endMiss > 1.9 { return }

            let templateLength = length(of: template)
            guard templateLength > keyWidth * 0.5 else { return }
            let ratio = pathLength / templateLength
            if ratio < 0.45 || ratio > 2.8 { return }

            // 1. Shape: same-arc-length points of both paths, compared one by one.
            let sampledTemplate = resample(template, count: sampleCount)
            var shape = 0.0
            for i in 0..<sampleCount {
                shape += Double(min(distance(sampledPath[i], sampledTemplate[i]), keyWidth * 2.5))
            }
            shape /= Double(sampleCount) * Double(keyWidth)
            if shape > 1.8 { return }

            // 2. Coverage: every letter of the word has to lie close to the finger's path.
            var coverage = 0.0
            var worstLetter = 0.0
            for center in template {
                var nearest = CGFloat.greatestFiniteMagnitude
                for point in sampledPath { nearest = min(nearest, distance(point, center)) }
                let miss = Double(nearest / keyWidth)
                coverage += min(miss, 2)
                worstLetter = max(worstLetter, miss)
            }
            coverage /= Double(template.count)
            if worstLetter > 1.9 { return }

            // 3. Excess: the finger must not wander to places the word never goes.
            var excess = 0.0
            for point in sampledPath {
                excess += Double(min(distanceToPolyline(point, template), keyWidth * 2.5))
            }
            excess /= Double(sampleCount) * Double(keyWidth)

            if usesModels {
                let shapeCost = 0.45 * shape + 0.40 * coverage + 0.35 * excess
                    + 0.50 * (startMiss + endMiss) + 0.35 * max(0, worstLetter - 0.9)
                var logProb: Double
                if let model = source.model, entry.rank >= 0 {
                    logProb = model.logProb(entry.rank + LanguageModel.firstWord, previous: source.previousId, before: source.beforeId)
                } else {
                    logProb = -7 + 5 * entry.norm   // no model for this language: frequency only
                }
                if let learned = source.learnedLogProbs[entry.word] { logProb = max(logProb, learned) }
                seen.insert(entry.word)
                var item = found[entry.word] ?? (shape: Double.greatestFiniteMagnitude, probability: 0, boost: 0)
                item.shape = min(item.shape, shapeCost)
                item.probability += source.weight * pow(10, logProb)
                item.boost = max(item.boost, (source.boosts[entry.word] ?? 0) + 2 * (source.fieldBonuses[entry.word] ?? 0))
                found[entry.word] = item
                return
            }

            let frequency = entry.norm
            let context = source.contextBonuses[entry.word] ?? 0
            let personal = source.personal[entry.word] ?? 0
            let inField = source.fieldBonuses[entry.word] ?? 0
            let cost = 0.45 * shape + 0.40 * coverage + 0.35 * excess
                + 0.50 * (startMiss + endMiss) + 0.35 * max(0, worstLetter - 0.9) + source.penalty
            // Words this user writes (and words that tend to follow the previous word) are favoured.
            let score = cost - 0.55 * frequency - 0.8 * context - 0.45 * personal - 0.9 * inField
            seen.insert(entry.word)
            scored.append((word: entry.word, score: score))
        }

        for source in sources {
            // With the language models every language scores its own words (their probabilities add up).
            if usesModels { seen = [] }
            // Letter -> key, remembered: accented letters need Unicode folding, far too slow per word.
            var keyMemo: [Character: Character?] = [:]
            func keyFor(_ character: Character) -> Character? {
                if let known = keyMemo[character] { return known }
                let key = source.store.keyLetter(for: character)
                keyMemo[character] = key
                return key
            }
            for index in source.candidateIndices(first: startKeys, last: endKeys) {
                consider(source.entries[index], source: source, keyFor: keyFor)
            }
            for entry in source.extras { consider(entry, source: source, keyFor: keyFor) }
        }

        if usesModels {
            let ranked = found.map { word, item -> (word: String, score: Double) in
                let logProb = item.probability > 0 ? log10(item.probability) : -99
                return (word, logProb + item.boost - SwipeDecoder.shapeWeight * item.shape)
            }
            return ranked.sorted { $0.score == $1.score ? $0.word < $1.word : $0.score > $1.score }
                .prefix(limit).map { $0.word }
        }
        scored.sort { $0.score < $1.score }
        return scored.prefix(limit).map { $0.word }
    }

    // MARK: Geometry

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Distance from a point to the closest part of a polyline.
    private func distanceToPolyline(_ point: CGPoint, _ line: [CGPoint]) -> CGFloat {
        guard line.count > 1 else { return line.first.map { distance(point, $0) } ?? 0 }
        var best = CGFloat.greatestFiniteMagnitude
        for i in 1..<line.count {
            let a = line[i - 1]
            let b = line[i]
            let dx = b.x - a.x
            let dy = b.y - a.y
            let lengthSquared = dx * dx + dy * dy
            var t: CGFloat = 0
            if lengthSquared > 0 {
                t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
            }
            let closest = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
            best = min(best, distance(point, closest))
        }
        return best
    }

    private func length(of points: [CGPoint]) -> CGFloat {
        var total: CGFloat = 0
        if points.count > 1 {
            for i in 1..<points.count {
                total += distance(points[i - 1], points[i])
            }
        }
        return total
    }

    private func thinned(_ points: [CGPoint], minimumStep: CGFloat) -> [CGPoint] {
        guard var last = points.first else { return [] }
        var result = [last]
        for point in points.dropFirst() where distance(point, last) >= minimumStep {
            result.append(point)
            last = point
        }
        if let finalPoint = points.last, let resultLast = result.last, distance(finalPoint, resultLast) > 0 {
            result.append(finalPoint)
        }
        return result
    }

    private func nearestKeys(to point: CGPoint,
                             centers: [Character: CGPoint],
                             within radius: CGFloat,
                             count: Int) -> [Character] {
        let ranked = centers
            .map { (key: $0.key, distance: distance(point, $0.value)) }
            .filter { $0.distance <= radius }
            .sorted { $0.distance < $1.distance }
            .prefix(count)
        return ranked.map { $0.key }
    }

    /// Evenly spaced points along the polyline (by arc length).
    private func resample(_ points: [CGPoint], count n: Int) -> [CGPoint] {
        guard let first = points.first, let last = points.last else {
            return Array(repeating: .zero, count: n)
        }
        let total = length(of: points)
        guard points.count > 1, total > 0 else {
            return Array(repeating: first, count: n)
        }

        let step = total / CGFloat(n - 1)
        var result: [CGPoint] = [first]
        var accumulated: CGFloat = 0
        var working = points
        var i = 1
        while i < working.count {
            let a = working[i - 1]
            let b = working[i]
            let segment = distance(a, b)
            if segment > 0 && accumulated + segment >= step {
                let t = (step - accumulated) / segment
                let q = CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y))
                result.append(q)
                working.insert(q, at: i)
                accumulated = 0
            } else {
                accumulated += segment
            }
            i += 1
        }
        while result.count < n { result.append(last) }
        if result.count > n { result = Array(result.prefix(n)) }
        return result
    }
}
