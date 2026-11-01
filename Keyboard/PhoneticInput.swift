import Foundation

/// Languages typed by their sound: Cantonese in Jyutping, Mandarin in Pinyin, Japanese in romaji. The letters typed
/// so far ("neihou", "nihao", "nihongo") become words ("你好", "日本語") picked from the suggestion bar. The
/// dictionary is `phonetic_<lang>.tsv` (scripts/build_data.py; rime-cantonese for Cantonese in traditional
/// characters, CC-CEDICT for Mandarin in simplified ones, JMdict for Japanese): the spelling without tones or spaces
/// (the reading in hiragana for Japanese) <TAB> word <TAB> how common it is, sorted by the spelling. Words the user
/// picks rank higher from then on ("spelling|word" -> picks, in the shared settings).
final class PhoneticInput {
    private static var instances: [Language: PhoneticInput] = [:]

    /// The dictionary of a language typed by sound (one per language, kept while the keyboard runs).
    static func shared(for language: Language) -> PhoneticInput {
        if let existing = instances[language] { return existing }
        let created = PhoneticInput(language: language)
        instances[language] = created
        return created
    }

    let language: Language
    private var picksKey: String { return SettingKey.phoneticPicksPrefix + language.rawValue }

    private init(language: Language) {
        self.language = language
    }

    struct Candidate {
        let word: String
        /// How many of the typed letters it stands for; the rest stay to be turned into the next word.
        let length: Int
        let key: String
    }

    private var keys: [String] = []
    private var words: [String] = []
    private var counts: [Float] = []
    private(set) var isLoaded = false
    private var isLoading = false
    private var picks: [String: Int] = [:]
    private var picksChanged = false
    /// Most picks remembered (the rarest are forgotten first).
    private let maxPicks = 3000

    /// Reads the dictionary in the background (once); `completion` runs on the main thread when it is ready.
    func loadIfNeeded(completion: @escaping () -> Void) {
        if isLoaded || isLoading { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            var keys: [String] = []
            var words: [String] = []
            var counts: [Float] = []
            if let url = Bundle.main.url(forResource: "phonetic_\(self.language.rawValue)", withExtension: "tsv"),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                keys.reserveCapacity(160_000)
                words.reserveCapacity(160_000)
                counts.reserveCapacity(160_000)
                for line in text.split(separator: "\n") {
                    let parts = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
                    guard parts.count == 3, let count = Float(parts[2]) else { continue }
                    keys.append(String(parts[0]))
                    words.append(String(parts[1]))
                    counts.append(count)
                }
            }
            let saved = SharedStore.defaults.dictionary(forKey: self.picksKey) as? [String: Int] ?? [:]
            DispatchQueue.main.async {
                self.keys = keys
                self.words = words
                self.counts = counts
                self.picks = saved
                self.isLoaded = true
                self.isLoading = false
                completion()
            }
        }
    }

    /// The picks were cleared or changed in the app ("Forget learned words").
    func reloadPicks() {
        picks = SharedStore.defaults.dictionary(forKey: picksKey) as? [String: Int] ?? [:]
        picksChanged = false
    }

    /// Remembers that `candidate` was picked, so it ranks higher for those letters next time.
    func learn(_ candidate: Candidate) {
        picks[candidate.key + "|" + candidate.word, default: 0] += 1
        picksChanged = true
    }

    func saveNow() {
        guard picksChanged else { return }
        if picks.count > maxPicks {
            let kept = picks.sorted { $0.value > $1.value }.prefix(maxPicks)
            picks = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
        }
        SharedStore.defaults.set(picks, forKey: picksKey)
        picksChanged = false
    }

    /// First index whose key is not before `key`.
    private func lowerBound(_ key: String) -> Int {
        var low = 0
        var high = keys.count
        while low < high {
            let mid = (low + high) / 2
            if keys[mid] < key { low = mid + 1 } else { high = mid }
        }
        return low
    }

    /// The typed letters as the dictionary spells them, how many typed letters each of its characters takes up,
    /// and letters that are not a whole syllable yet. Jyutping and Pinyin are their own spelling; Japanese romaji
    /// becomes kana ("nihon" -> にほ, with "n" still open).
    private func reading(of typed: String) -> (key: [Character], ends: [Int], rest: String) {
        if language == .japanese {
            let converted = Romaji.convert(typed)
            return (Array(converted.kana), converted.ends, converted.rest)
        }
        let letters = Array(typed.lowercased().filter { $0 >= "a" && $0 <= "z" })
        return (letters, letters.indices.map { $0 + 1 }, "")
    }

    /// What the field shows while typing: the letters for Jyutping and Pinyin, kana for Japanese.
    func display(_ typed: String) -> String {
        guard language == .japanese else { return typed }
        let converted = Romaji.convert(typed)
        return converted.kana + converted.rest
    }

    /// Words for the typed letters, best first: the letters exactly ("nei" -> 你), words they are the start of
    /// ("neih" -> 你好), then words for just the start of them ("ngohaihoeng" -> 我係, the rest converted next).
    /// Pinyin's ü is typed as v ("lv" -> 绿). Japanese also offers the kana themselves, in hiragana and katakana.
    func candidates(for typed: String, limit: Int = 60) -> [Candidate] {
        let reading = self.reading(of: typed)
        let input = String(reading.key)
        let whole = typed.count
        var result: [Candidate] = []
        if isLoaded && !input.isEmpty {
            var scored: [(candidate: Candidate, score: Double)] = []
            func add(_ index: Int, length: Int, penalty: Double) {
                let picked = picks.isEmpty ? 0 : Double(picks[keys[index] + "|" + words[index]] ?? 0)
                let score = log(Double(counts[index]) + 1) - penalty + 2.5 * log(1 + picked)
                scored.append((Candidate(word: words[index], length: length, key: keys[index]), score))
            }

            // An exact match leaves letters that are not a whole syllable yet for the next word; a longer word
            // takes a final "n" with it (にほ + n -> 日本), but not other unfinished letters.
            let exactLength = reading.rest.isEmpty ? whole : (reading.ends.last ?? whole)
            let longerLength = reading.rest == "n" ? whole : exactLength
            var index = lowerBound(input)
            var scanned = 0
            while index < keys.count, scanned < 20_000, keys[index].hasPrefix(input) {
                // A longer word must be clearly more common to come before an exact match.
                let exact = keys[index].count == input.count
                add(index, length: exact ? exactLength : longerLength, penalty: exact ? 0 : 3)
                index += 1
                scanned += 1
            }
            if reading.key.count > 1 {
                for length in stride(from: reading.key.count - 1, through: 1, by: -1) {
                    let start = String(reading.key.prefix(length))
                    var at = lowerBound(start)
                    while at < keys.count, keys[at] == start {
                        // The more letters it leaves over, the less likely it is what was meant.
                        add(at, length: reading.ends[length - 1],
                            penalty: 6 + Double(reading.key.count - length) * 0.5)
                        at += 1
                    }
                }
            }

            scored.sort { $0.score > $1.score }
            var seen = Set<String>()
            for item in scored where !seen.contains(item.candidate.word) {
                seen.insert(item.candidate.word)
                result.append(item.candidate)
                if result.count >= limit { break }
            }
        }
        if language == .japanese && !typed.isEmpty {
            // The kana as typed, after the best word: hiragana, then katakana (for loanwords and names).
            let hiragana = Romaji.finish(typed)
            let katakana = hiragana.applyingTransform(.hiraganaToKatakana, reverse: false) ?? hiragana
            result.removeAll { $0.word == hiragana || $0.word == katakana }
            result.insert(Candidate(word: hiragana, length: whole, key: input), at: min(1, result.count))
            if katakana != hiragana {
                result.insert(Candidate(word: katakana, length: whole, key: input), at: min(2, result.count))
            }
        }
        return result
    }
}

/// Japanese romaji to hiragana, as the system's romaji keyboard converts it: "konnichiha" -> こんにちは, doubled
/// consonants -> っ ("kitte" -> きって), "n" before a consonant -> ん, "-" -> ー.
enum Romaji {
    private static let table: [String: String] = {
        var table: [String: String] = [
            "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
            "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ", "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
            "sa": "さ", "si": "し", "shi": "し", "su": "す", "se": "せ", "so": "そ",
            "za": "ざ", "zi": "じ", "ji": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
            "ta": "た", "ti": "ち", "chi": "ち", "tu": "つ", "tsu": "つ", "te": "て", "to": "と",
            "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
            "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
            "ha": "は", "hi": "ひ", "hu": "ふ", "fu": "ふ", "he": "へ", "ho": "ほ",
            "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ", "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
            "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
            "ya": "や", "yu": "ゆ", "yo": "よ", "ye": "いぇ",
            "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
            "la": "ら", "li": "り", "lu": "る", "le": "れ", "lo": "ろ",
            "wa": "わ", "wi": "うぃ", "we": "うぇ", "wo": "を",
            "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ", "fyu": "ふゅ",
            "va": "ゔぁ", "vi": "ゔぃ", "vu": "ゔ", "ve": "ゔぇ", "vo": "ゔぉ",
            "tsa": "つぁ", "tsi": "つぃ", "tse": "つぇ", "tso": "つぉ",
            "thi": "てぃ", "thu": "てゅ", "dhi": "でぃ", "dhu": "でゅ", "twu": "とぅ", "dwu": "どぅ",
            "she": "しぇ", "je": "じぇ", "che": "ちぇ",
            "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ", "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ",
            "xtu": "っ", "xtsu": "っ", "ltu": "っ", "ltsu": "っ", "xwa": "ゎ", "xka": "ゕ", "xke": "ゖ",
            "-": "ー",
        ]
        // The contracted sounds: kya きゃ, sha しゃ, cha ちゃ, ja じゃ ...
        let rows: [(String, String)] = [("ky", "き"), ("gy", "ぎ"), ("sy", "し"), ("sh", "し"), ("zy", "じ"), ("jy", "じ"),
                                        ("j", "じ"), ("ty", "ち"), ("cy", "ち"), ("ch", "ち"), ("dy", "ぢ"), ("ny", "に"),
                                        ("hy", "ひ"), ("by", "び"), ("py", "ぴ"), ("my", "み"), ("ry", "り"), ("ly", "り")]
        for (start, kana) in rows {
            table[start + "a"] = kana + "ゃ"
            table[start + "u"] = kana + "ゅ"
            table[start + "o"] = kana + "ょ"
        }
        return table
    }()

    /// Every start of a table entry ("k", "ky", "sh"): letters that may still become a syllable.
    private static let starts: Set<String> = {
        var result = Set<String>()
        for key in table.keys where key.count > 1 {
            for length in 1..<key.count { result.insert(String(key.prefix(length))) }
        }
        return result
    }()

    private static let vowels: Set<Character> = ["a", "i", "u", "e", "o"]

    /// The kana for the typed letters, how many typed letters each kana takes up (counted from the start), and
    /// the letters at the end that are not a syllable yet ("k", "sh", a final "n").
    static func convert(_ typed: String) -> (kana: String, ends: [Int], rest: String) {
        let letters = Array(typed.lowercased())
        var kana = ""
        var ends: [Int] = []
        var i = 0
        func emit(_ text: String, upTo end: Int) {
            kana += text
            for _ in text { ends.append(end) }
            i = end
        }
        while i < letters.count {
            let letter = letters[i]
            let next: Character? = i + 1 < letters.count ? letters[i + 1] : nil
            if letter == "n" {
                guard let following = next else { return (kana, ends, "n") }   // may still become な, に ...
                if following == "n" {
                    // "nn" is ん; before a vowel or y the second n starts the next syllable ("konnichi" -> こんにち).
                    let third: Character? = i + 2 < letters.count ? letters[i + 2] : nil
                    let opensNext = third.map { vowels.contains($0) || $0 == "y" } ?? false
                    emit("ん", upTo: opensNext ? i + 1 : i + 2)
                    continue
                }
                if !vowels.contains(following) && following != "y" {
                    emit("ん", upTo: i + 1)
                    continue
                }
            }
            if let following = next, following == letter, letter.isLetter, !vowels.contains(letter) {
                emit("っ", upTo: i + 1)   // a doubled consonant: "kitte" -> きって
                continue
            }
            var matched = false
            for length in stride(from: min(4, letters.count - i), through: 1, by: -1) {
                if let found = table[String(letters[i..<(i + length)])] {
                    emit(found, upTo: i + length)
                    matched = true
                    break
                }
            }
            if matched { continue }
            let remaining = String(letters[i...])
            if starts.contains(remaining) { return (kana, ends, remaining) }
            emit(String(letter), upTo: i + 1)   // not romaji: kept as typed
        }
        return (kana, ends, "")
    }

    /// The kana to write when typing stops: a final "n" becomes ん, other unfinished letters stay as typed.
    static func finish(_ typed: String) -> String {
        let converted = convert(typed)
        return converted.kana + (converted.rest == "n" ? "ん" : converted.rest)
    }
}
