import Foundation

/// The word trigram model of one language, `lm_<lang>.bin` (built by scripts/language_model.py, which documents
/// the format). The file is memory-mapped, so it costs the keyboard's memory budget almost nothing.
///
/// Word ids are line numbers of `words_<lang>.tsv` plus `firstWord`; 0 is the sentence start, 1 an unknown word,
/// 2 a comma. Probabilities are log10.
final class LanguageModel {
    static let start: Int32 = 0
    static let unknown: Int32 = 1
    static let comma: Int32 = 2
    static let firstWord: Int32 = 3

    let vocabularySize: Int
    private let storage: NSData
    private let base: UnsafeRawPointer
    private let bigramCount: Int
    private let trigramCount: Int
    private let pMin: Double, pStep: Double, bMin: Double, bStep: Double
    // Byte offsets of the tables.
    private let p1Offset: Int, bo1Offset: Int, startOffset: Int
    private let next2Offset: Int, p2Offset: Int, bo2Offset: Int
    private let contextOffset: Int, next3Offset: Int, p3Offset: Int

    init?(language: Language) {
        guard let url = Bundle.main.url(forResource: "lm_\(language.rawValue)", withExtension: "bin"),
              let data = try? NSData(contentsOf: url, options: .alwaysMapped),
              data.length >= 36 else { return nil }
        storage = data
        base = data.bytes
        guard base.loadUnaligned(as: UInt32.self) == 0x4D4C_4B48 else { return nil }   // "HKLM"
        let version = base.loadUnaligned(fromByteOffset: 4, as: UInt32.self)
        guard version == 1 else { return nil }
        vocabularySize = Int(base.loadUnaligned(fromByteOffset: 8, as: UInt32.self))
        bigramCount = Int(base.loadUnaligned(fromByteOffset: 12, as: UInt32.self))
        trigramCount = Int(base.loadUnaligned(fromByteOffset: 16, as: UInt32.self))
        pMin = Double(base.loadUnaligned(fromByteOffset: 20, as: Float32.self))
        pStep = Double(base.loadUnaligned(fromByteOffset: 24, as: Float32.self))
        bMin = Double(base.loadUnaligned(fromByteOffset: 28, as: Float32.self))
        bStep = Double(base.loadUnaligned(fromByteOffset: 32, as: Float32.self))
        var offset = 36
        p1Offset = offset; offset += vocabularySize
        bo1Offset = offset; offset += vocabularySize
        startOffset = offset; offset += 4 * (vocabularySize + 1)
        next2Offset = offset; offset += 3 * bigramCount
        p2Offset = offset; offset += bigramCount
        bo2Offset = offset; offset += bigramCount
        contextOffset = offset; offset += 4 * trigramCount
        next3Offset = offset; offset += 3 * trigramCount
        p3Offset = offset; offset += trigramCount
        guard offset <= data.length else { return nil }
    }

    // MARK: Raw tables

    @inline(__always) private func byte(_ offset: Int) -> Double {
        return Double(base.load(fromByteOffset: offset, as: UInt8.self))
    }

    @inline(__always) private func id24(_ offset: Int, _ index: Int) -> Int32 {
        let at = offset + 3 * index
        let b0 = Int32(base.load(fromByteOffset: at, as: UInt8.self))
        let b1 = Int32(base.load(fromByteOffset: at + 1, as: UInt8.self))
        let b2 = Int32(base.load(fromByteOffset: at + 2, as: UInt8.self))
        return b0 | (b1 << 8) | (b2 << 16)
    }

    @inline(__always) private func u32(_ offset: Int, _ index: Int) -> Int {
        return Int(base.loadUnaligned(fromByteOffset: offset + 4 * index, as: UInt32.self))
    }

    private func unigram(_ w: Int32) -> Double { return pMin + pStep * byte(p1Offset + Int(w)) }
    private func backoff1(_ v: Int32) -> Double { return bMin + bStep * byte(bo1Offset + Int(v)) }

    /// The bigram entries of context `v`.
    private func bigramRange(_ v: Int32) -> Range<Int> {
        guard v >= 0, Int(v) < vocabularySize else { return 0..<0 }
        return u32(startOffset, Int(v))..<u32(startOffset, Int(v) + 1)
    }

    /// Index of the bigram (v, w), or nil.
    private func bigram(_ v: Int32, _ w: Int32) -> Int? {
        var range = bigramRange(v)
        while !range.isEmpty {
            let mid = (range.lowerBound + range.upperBound) / 2
            let value = id24(next2Offset, mid)
            if value == w { return mid }
            if value < w { range = (mid + 1)..<range.upperBound } else { range = range.lowerBound..<mid }
        }
        return nil
    }

    /// The trigram entries whose context is bigram entry `index`.
    private func trigramRange(_ index: Int) -> Range<Int> {
        var low = 0, high = trigramCount
        while low < high {
            let mid = (low + high) / 2
            if u32(contextOffset, mid) < index { low = mid + 1 } else { high = mid }
        }
        var end = low
        while end < trigramCount && u32(contextOffset, end) == index { end += 1 }
        return low..<end
    }

    // MARK: Probabilities

    /// log10 P(w | u v); `u` nil (or no trigram data) uses the bigram context only.
    func logProb(_ w: Int32, previous v: Int32, before u: Int32?) -> Double {
        guard w >= 0, Int(w) < vocabularySize, v >= 0, Int(v) < vocabularySize else { return pMin }
        var backoff = 0.0
        if let u = u, let context = bigram(u, v) {
            var range = trigramRange(context)
            while !range.isEmpty {
                let mid = (range.lowerBound + range.upperBound) / 2
                let value = id24(next3Offset, mid)
                if value == w { return pMin + pStep * byte(p3Offset + mid) }
                if value < w { range = (mid + 1)..<range.upperBound } else { range = range.lowerBound..<mid }
            }
            backoff = bMin + bStep * byte(bo2Offset + context)
        }
        if let index = bigram(v, w) { return backoff + pMin + pStep * byte(p2Offset + index) }
        return backoff + backoff1(v) + unigram(w)
    }

    /// Word ids the model knows to follow the context (trigram continuations first, then bigram ones).
    func followers(previous v: Int32, before u: Int32?, limit: Int = 4000) -> [Int32] {
        var result: [Int32] = []
        if let u = u, let context = bigram(u, v) {
            for i in trigramRange(context) { result.append(id24(next3Offset, i)) }
        }
        for i in bigramRange(v) {
            if result.count >= limit { break }
            result.append(id24(next2Offset, i))
        }
        return result
    }

    /// The `count` most likely next words after the context, best first (comma and specials excluded).
    func nextWords(previous v: Int32, before u: Int32?, count: Int, common: [Int32]) -> [(id: Int32, logProb: Double)] {
        var seen = Set<Int32>()
        var scored: [(id: Int32, logProb: Double)] = []
        for w in followers(previous: v, before: u) + common where w >= LanguageModel.firstWord && seen.insert(w).inserted {
            scored.append((w, logProb(w, previous: v, before: u)))
        }
        scored.sort { $0.logProb > $1.logProb }
        return Array(scored.prefix(count))
    }

    /// Ids by unigram probability, most common first (fallback next words).
    func mostCommon(_ count: Int) -> [Int32] {
        let limit = min(count, max(0, vocabularySize - Int(LanguageModel.firstWord)))
        // Ids are dictionary line numbers, and the dictionary is sorted by frequency.
        return (0..<limit).map { LanguageModel.firstWord + Int32($0) }
    }
}
