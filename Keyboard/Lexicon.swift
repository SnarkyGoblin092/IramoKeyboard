import Foundation

/// One language's dictionary, `dict_<lang>.bin` (written by scripts/lexicon.py, which documents the format),
/// memory-mapped: its pages belong to the file, not to the keyboard's memory budget, so every enabled language can
/// be loaded in full. Immutable, so any thread may read it.
///
/// Records are sorted by match key (code point order, which is UTF-8 byte order), most common first within a key.
final class Lexicon {
    let count: Int
    let totalCount: Double
    let maxCount: Int
    private let storage: NSData
    private let base: UnsafeRawPointer
    private let edgeKeyCount: Int
    private let recordsOffset = 32
    private let byRankOffset: Int
    private let edgeKeysOffset: Int
    private let edgeEntriesOffset: Int
    private let textOffset: Int
    private let recordSize = 20

    init?(language: Language) {
        guard let url = Bundle.main.url(forResource: "dict_\(language.rawValue)", withExtension: "bin"),
              let data = try? NSData(contentsOf: url, options: .alwaysMapped),
              data.length >= 32 else { return nil }
        // Everything is read through locals first: a class may not read its own properties before all are set.
        let pointer = data.bytes
        guard pointer.loadUnaligned(as: UInt32.self) == 0x5844_4B48,                      // "HKDX"
              pointer.loadUnaligned(fromByteOffset: 4, as: UInt32.self) == 1 else { return nil }
        let words = Int(pointer.loadUnaligned(fromByteOffset: 8, as: UInt32.self))
        let edgeKeys = Int(pointer.loadUnaligned(fromByteOffset: 12, as: UInt32.self))
        let textBytes = Int(pointer.loadUnaligned(fromByteOffset: 16, as: UInt32.self))
        let edgeEntries = Int(pointer.loadUnaligned(fromByteOffset: 20, as: UInt32.self))
        let records = 32
        let byRank = records + 20 * words
        let edgeKeysStart = byRank + 4 * words
        let edgeEntriesStart = edgeKeysStart + 12 * edgeKeys
        let text = edgeEntriesStart + 4 * (edgeEntries + 1)
        guard text + textBytes <= data.length else { return nil }
        var largest = 1
        if words > 0 {
            // The most common word (rank 0) sets the scale of the 0...1 `norm`.
            let index = Int(pointer.loadUnaligned(fromByteOffset: byRank, as: UInt32.self))
            largest = max(1, Int(pointer.loadUnaligned(fromByteOffset: records + 20 * index + 8, as: UInt32.self)))
        }
        storage = data
        base = pointer
        count = words
        edgeKeyCount = edgeKeys
        totalCount = max(1, pointer.loadUnaligned(fromByteOffset: 24, as: Double.self))
        maxCount = largest
        byRankOffset = byRank
        edgeKeysOffset = edgeKeysStart
        edgeEntriesOffset = edgeEntriesStart
        textOffset = text
    }

    // MARK: Records

    @inline(__always) private func u32(_ offset: Int) -> Int {
        return Int(base.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }

    @inline(__always) private func u8(_ offset: Int) -> Int {
        return Int(base.load(fromByteOffset: offset, as: UInt8.self))
    }

    @inline(__always) private func record(_ index: Int) -> Int { return recordsOffset + recordSize * index }

    func frequency(_ index: Int) -> Int { return u32(record(index) + 8) }
    func rank(_ index: Int) -> Int32 { return Int32(u32(record(index) + 12)) }
    func keyLength(_ index: Int) -> Int { return u8(record(index) + 19) }

    func capitals(_ index: Int) -> WordCapitals {
        return WordCapitals(rawValue: UInt8(u8(record(index) + 18))) ?? .none
    }

    /// The match key's UTF-8 bytes.
    @inline(__always) func keyBytes(_ index: Int) -> UnsafeRawBufferPointer {
        let r = record(index)
        return UnsafeRawBufferPointer(start: base + textOffset + u32(r + 4), count: u8(r + 17))
    }

    private func string(offset: Int, length: Int) -> String {
        let bytes = UnsafeRawBufferPointer(start: base + textOffset + offset, count: length)
        return String(decoding: bytes, as: UTF8.self)
    }

    func word(_ index: Int) -> String {
        let r = record(index)
        return string(offset: u32(r), length: u8(r + 16))
    }

    func key(_ index: Int) -> String {
        let r = record(index)
        return string(offset: u32(r + 4), length: u8(r + 17))
    }

    func norm(_ index: Int) -> Double {
        return min(1, log(Double(frequency(index)) + 1) / max(log(Double(maxCount) + 1), 1))
    }

    /// The record as a `WordEntry` (strings are made here, so hot loops use the accessors above instead).
    func entry(_ index: Int) -> WordEntry {
        return WordEntry(word: word(index), folded: key(index), freq: frequency(index), norm: norm(index),
                         length: keyLength(index), rank: rank(index), capitals: capitals(index))
    }

    /// Record index of a language model rank (= line of words_<lang>.tsv), or nil.
    func index(ofRank rank: Int) -> Int? {
        guard rank >= 0, rank < count else { return nil }
        return u32(byRankOffset + 4 * rank)
    }

    // MARK: Search

    /// -1, 0, 1 comparing record `index`'s key with `key` bytewise.
    @inline(__always) private func compareKey(_ index: Int, _ key: [UInt8]) -> Int {
        let bytes = keyBytes(index)
        let n = min(bytes.count, key.count)
        for i in 0..<n {
            let a = bytes[i], b = key[i]
            if a != b { return a < b ? -1 : 1 }
        }
        return bytes.count == key.count ? 0 : (bytes.count < key.count ? -1 : 1)
    }

    /// First record whose key is not below `key`.
    func lowerBound(_ key: String) -> Int {
        let target = Array(key.utf8)
        var low = 0, high = count
        while low < high {
            let mid = (low + high) / 2
            if compareKey(mid, target) < 0 { low = mid + 1 } else { high = mid }
        }
        return low
    }

    /// True if record `index`'s key starts with `prefix` (UTF-8 bytes).
    @inline(__always) func keyHasPrefix(_ index: Int, _ prefix: [UInt8]) -> Bool {
        let bytes = keyBytes(index)
        guard bytes.count >= prefix.count else { return false }
        for i in 0..<prefix.count where bytes[i] != prefix[i] { return false }
        return true
    }

    func keyEquals(_ index: Int, _ key: [UInt8]) -> Bool { return compareKey(index, key) == 0 }

    // MARK: Swipe index

    /// Records whose first and last key letters are `first` and `last`.
    func edgeEntries(first: Character, last: Character) -> [Int] {
        guard let f = first.unicodeScalars.first?.value, let l = last.unicodeScalars.first?.value else { return [] }
        var low = 0, high = edgeKeyCount
        while low < high {
            let mid = (low + high) / 2
            let at = edgeKeysOffset + 12 * mid
            let mf = UInt32(u32(at)), ml = UInt32(u32(at + 4))
            if mf < f || (mf == f && ml < l) { low = mid + 1 } else { high = mid }
        }
        guard low < edgeKeyCount else { return [] }
        let at = edgeKeysOffset + 12 * low
        guard UInt32(u32(at)) == f, UInt32(u32(at + 4)) == l else { return [] }
        let start = u32(at + 8)
        let stop = low + 1 < edgeKeyCount ? u32(edgeKeysOffset + 12 * (low + 1) + 8) : totalEdgeEntries
        return (start..<stop).map { u32(edgeEntriesOffset + 4 * $0) }
    }

    /// The number of entries in the swipe index (stored after them).
    private var totalEdgeEntries: Int {
        return u32(textOffset - 4)
    }
}

/// A language's dictionary words, sorted by match key: memory-mapped (`Lexicon`), or parsed from
/// words_<lang>.tsv by builds without dict_<lang>.bin. `entries[i]` makes a `WordEntry`; the hot loops use the
/// accessors, which do not build strings for the memory-mapped list. A value type over immutable storage, so a copy
/// can be handed to another thread (the swipe decoder).
struct Entries {
    private let lexicon: Lexicon?
    private let list: [WordEntry]
    private let edges: [String: [Int]]
    private let byRank: [Int32]
    let count: Int
    /// Sum of all word counts (for unigram probabilities).
    let totalCount: Double

    static let empty = Entries(list: [], edges: [:], byRank: [], totalCount: 1)

    init(lexicon: Lexicon) {
        self.lexicon = lexicon
        list = []
        edges = [:]
        byRank = []
        count = lexicon.count
        totalCount = lexicon.totalCount
    }

    init(list: [WordEntry], edges: [String: [Int]], byRank: [Int32], totalCount: Double) {
        lexicon = nil
        self.list = list
        self.edges = edges
        self.byRank = byRank
        count = list.count
        self.totalCount = totalCount
    }

    var isMapped: Bool { return lexicon != nil }

    subscript(index: Int) -> WordEntry {
        if let lexicon = lexicon { return lexicon.entry(index) }
        return list[index]
    }

    func key(_ index: Int) -> String {
        if let lexicon = lexicon { return lexicon.key(index) }
        return list[index].folded
    }

    func freq(_ index: Int) -> Int {
        if let lexicon = lexicon { return lexicon.frequency(index) }
        return list[index].freq
    }

    /// First index whose match key is not below `key` (code point order).
    func lowerBound(_ key: String) -> Int {
        if let lexicon = lexicon { return lexicon.lowerBound(key) }
        var low = 0
        var high = list.count
        while low < high {
            let mid = (low + high) / 2
            if list[mid].folded < key { low = mid + 1 } else { high = mid }
        }
        return low
    }

    func keyHasPrefix(_ index: Int, _ prefix: [UInt8]) -> Bool {
        if let lexicon = lexicon { return lexicon.keyHasPrefix(index, prefix) }
        return list[index].folded.utf8.starts(with: prefix)
    }

    func keyEquals(_ index: Int, _ key: [UInt8]) -> Bool {
        if let lexicon = lexicon { return lexicon.keyEquals(index, key) }
        return list[index].folded.utf8.elementsEqual(key)
    }

    /// Indices of words whose first and last key letters are `first` and `last` (the swipe index).
    func edgeEntries(first: Character, last: Character) -> [Int] {
        if let lexicon = lexicon { return lexicon.edgeEntries(first: first, last: last) }
        return edges[String([first, last])] ?? []
    }

    /// Index of the word on line `rank` of words_<lang>.tsv (language model id - 3), if loaded.
    func index(ofRank rank: Int) -> Int? {
        if let lexicon = lexicon { return lexicon.index(ofRank: rank) }
        guard rank >= 0, rank < byRank.count, byRank[rank] >= 0 else { return nil }
        return Int(byRank[rank])
    }

    /// Indices of the `limit` most common words, most common first.
    func mostCommon(_ limit: Int) -> [Int] {
        if lexicon != nil { return (0..<min(limit, count)).compactMap { index(ofRank: $0) } }
        return Array((0..<list.count).sorted { list[$0].freq > list[$1].freq }.prefix(limit))
    }
}
