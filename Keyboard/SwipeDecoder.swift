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

    func decode(path rawPath: [CGPoint],
                keyCenters: [Character: CGPoint],
                keySize: CGSize,
                store: WordStore,
                limit: Int = 3) -> [String] {
        let path = thinned(rawPath, minimumStep: 2)
        guard path.count >= 2, let start = path.first, let end = path.last else { return [] }

        let keyWidth = max(keySize.width, 1)
        let startKeys = nearestKeys(to: start, centers: keyCenters, within: keyWidth * 1.6, count: 3)
        let endKeys = nearestKeys(to: end, centers: keyCenters, within: keyWidth * 1.6, count: 3)
        guard !startKeys.isEmpty, !endKeys.isEmpty else { return [] }

        let pathLength = length(of: path)
        let sampledPath = resample(path, count: sampleCount)

        var scored: [(word: String, score: Double)] = []

        for index in store.candidateIndices(first: startKeys, last: endKeys) {
            let entry = store.entries[index]

            // Ideal path: centres of the word's letters, consecutive duplicates collapsed.
            var template: [CGPoint] = []
            var previous: Character? = nil
            var knownKeys = true
            for character in entry.word where character.isLetter {
                guard let key = store.keyLetter(for: character) else {
                    knownKeys = false
                    break
                }
                if key == previous { continue }
                previous = key
                guard let center = keyCenters[key] else {
                    knownKeys = false
                    break
                }
                template.append(center)
            }
            guard knownKeys, template.count >= 2 else { continue }

            let templateLength = length(of: template)
            guard templateLength > keyWidth * 0.5 else { continue }
            let ratio = pathLength / templateLength
            if ratio < 0.4 || ratio > 3.0 { continue }

            let sampledTemplate = resample(template, count: sampleCount)
            var total: CGFloat = 0
            for i in 0..<sampleCount {
                total += distance(sampledPath[i], sampledTemplate[i])
            }
            let meanDistance = Double(total) / Double(sampleCount) / Double(keyWidth)

            let frequencyBonus = log(Double(entry.freq) + 1) / store.maxLogFreq   // 0...1
            scored.append((word: entry.word, score: meanDistance - 0.30 * frequencyBonus))
        }

        scored.sort { $0.score < $1.score }

        var words: [String] = []
        for item in scored {
            if !words.contains(item.word) { words.append(item.word) }
            if words.count >= limit { break }
        }
        return words
    }

    // MARK: Geometry

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
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
