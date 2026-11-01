import Foundation

/// Korean typed on the 2-beolsik layout: jamo keys (ㅎ ㅏ ㄴ) build up the syllable being typed (한), which is the
/// last character in the field until it is finished. A vowel after a final consonant takes that consonant for the
/// next syllable (각 + ㅏ -> 가가); backspace takes back one jamo at a time.
struct HangulComposer {
    private struct Syllable {
        var initial: Character?
        var medial: Character?
        var final: Character?
    }

    private static let initials = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    private static let medials = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
    /// Index 0 is "no final consonant".
    private static let finals: [Character?] = [nil] + Array("ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ").map { Optional($0) }
    private static let vowelPairs: [String: Character] = [
        "ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ", "ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ", "ㅡㅣ": "ㅢ"
    ]
    private static let finalPairs: [String: Character] = [
        "ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ", "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ", "ㄹㅅ": "ㄽ",
        "ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ"
    ]
    /// A double final consonant split back into its two parts (the second moves on to the next syllable).
    private static let finalSplits: [Character: (Character, Character)] = {
        var result: [Character: (Character, Character)] = [:]
        for (pair, combined) in finalPairs {
            let parts = Array(pair)
            result[combined] = (parts[0], parts[1])
        }
        return result
    }()

    /// The current syllable after each jamo typed into it, so backspace can step back.
    private var history: [Syllable] = []

    var isComposing: Bool { return !history.isEmpty }

    static func isJamo(_ character: Character) -> Bool {
        return initials.contains(character) || medials.contains(character)
    }

    /// Ends the syllable being typed (it stays in the field as it is).
    mutating func reset() {
        history = []
    }

    /// Types a jamo: how many characters before the cursor to delete (the syllable shown so far), and what to
    /// write in their place.
    mutating func type(_ jamo: Character) -> (delete: Int, insert: String) {
        let isVowel = HangulComposer.medials.contains(jamo)
        guard var syllable = history.last else {
            history = [isVowel ? Syllable(initial: nil, medial: jamo, final: nil) : Syllable(initial: jamo, medial: nil, final: nil)]
            return (0, String(jamo))
        }
        if isVowel {
            if syllable.initial != nil && syllable.medial == nil {
                syllable.medial = jamo
                return push(syllable)
            }
            if let medial = syllable.medial, syllable.final == nil,
               let combined = HangulComposer.vowelPairs[String([medial, jamo])] {
                syllable.medial = combined
                return push(syllable)
            }
            if let final = syllable.final, syllable.medial != nil {
                // The final consonant (or the second half of a double one) starts the next syllable.
                var kept = syllable
                let moved: Character
                if let parts = HangulComposer.finalSplits[final] {
                    kept.final = parts.0
                    moved = parts.1
                } else {
                    kept.final = nil
                    moved = final
                }
                let next = Syllable(initial: moved, medial: jamo, final: nil)
                history = [Syllable(initial: moved, medial: nil, final: nil), next]
                return (1, HangulComposer.render(kept) + HangulComposer.render(next))
            }
            history = [Syllable(initial: nil, medial: jamo, final: nil)]
            return (0, String(jamo))
        }
        if syllable.initial != nil && syllable.medial != nil {
            if syllable.final == nil, HangulComposer.finals.contains(jamo) {
                syllable.final = jamo
                return push(syllable)
            }
            if let final = syllable.final, let combined = HangulComposer.finalPairs[String([final, jamo])] {
                syllable.final = combined
                return push(syllable)
            }
        }
        history = [Syllable(initial: jamo, medial: nil, final: nil)]
        return (0, String(jamo))
    }

    /// Takes back the last jamo of the syllable being typed; nil when no syllable is being typed.
    mutating func backspace() -> (delete: Int, insert: String)? {
        guard !history.isEmpty else { return nil }
        history.removeLast()
        return (1, history.last.map { HangulComposer.render($0) } ?? "")
    }

    private mutating func push(_ syllable: Syllable) -> (delete: Int, insert: String) {
        history.append(syllable)
        return (1, HangulComposer.render(syllable))
    }

    /// The syllable as one character (가 = U+AC00 + (initial × 21 + medial) × 28 + final), or the lone jamo.
    private static func render(_ syllable: Syllable) -> String {
        guard let initial = syllable.initial, let medial = syllable.medial,
              let i = initials.firstIndex(of: initial), let m = medials.firstIndex(of: medial) else {
            return String(syllable.initial ?? syllable.medial ?? Character(" ")).trimmingCharacters(in: .whitespaces)
        }
        let f = syllable.final.flatMap { final in finals.firstIndex(where: { $0 == final }) } ?? 0
        guard let scalar = Unicode.Scalar(UInt32(0xAC00 + (i * 21 + m) * 28 + f)) else { return "" }
        return String(Character(scalar))
    }
}
