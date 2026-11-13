import Foundation

public protocol AccentSuggesting {
    /// The accented form of `word`, or nil when it should be left as typed.
    /// - Parameter sentence: the sentence typed so far, ending with `word`.
    func replacement(for word: String, in sentence: String) -> String?
}

public protocol SpellChecking {
    func isMisspelled(_ word: String) -> Bool
    /// Best-first guesses for `word`, the last word of `sentence`.
    func guesses(for word: String, in sentence: String) -> [String]
}

/// Decides which words get accents, using the spell checker's context-aware guesses
/// only when they can be trusted.
public final class AccentSuggester: AccentSuggesting {
    private let spellChecker: SpellChecking
    private let frequencies: WordFrequencies
    private var cache: [String: String?] = [:]

    public init(spellChecker: SpellChecking, frequencies: WordFrequencies) {
        self.spellChecker = spellChecker
        self.frequencies = frequencies
    }

    public func replacement(for word: String, in sentence: String) -> String? {
        let lowered = word.lowercased()
        // Only plain ASCII letters: anything else is already accented or not a word.
        guard lowered.count > 1 || lowered == "a", lowered.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        // A capital in the middle of a sentence is a name (all caps is shouting, fine).
        if isCapitalized(word), sentence.dropLast(word.count).contains(where: \.isLetter) { return nil }

        let key = Self.cacheKey(word, sentence)
        if let cached = cache[key] { return cached }
        let result = decide(word, lowered: lowered, sentence: sentence)
        if cache.count > 2000 { cache.removeAll() }
        cache[key] = .some(result)
        return result
    }

    private func decide(_ word: String, lowered: String, sentence: String) -> String? {
        if AmbiguityRules.words.contains(lowered) {
            return AmbiguityRules.replacement(for: word, in: sentence).map { Self.applyCase(of: word, to: $0) }
        }
        guard let guess = spellChecker.guesses(for: word, in: sentence)
            .map({ $0.lowercased() })
            .first(where: { Self.fold($0) == lowered && $0 != lowered })
        else { return nil }

        guard spellChecker.isMisspelled(word) else {
            return trustsAccentedForm(guess, over: lowered, sentence: sentence)
                ? Self.applyCase(of: word, to: guess) : nil
        }
        return Self.applyCase(of: word, to: guess)
    }

    /// The word is valid as typed, so the guess needs real evidence: either it is far more
    /// common than every other spelling, or the previous word says "participle/noun here"
    /// and the two are about equally common.
    private func trustsAccentedForm(_ guess: String, over plain: String, sentence: String) -> Bool {
        let spellings = frequencies.spellings(forKey: plain)
        guard let guessFrequency = spellings[guess], let plainFrequency = spellings[plain] else { return false }
        let competitors = spellings.filter { $0.key != guess }.values.reduce(0, +)
        if guessFrequency >= 10 * competitors { return true }
        guard let previous = Self.previousWord(of: plain, in: sentence), Self.contextTriggers.contains(previous) else { return false }
        return guessFrequency >= 0.5 * plainFrequency
    }

    // Auxiliaries (before a participle) and determiners (before a noun or adjective).
    // Deliberately without le/la/les/en: they are often pronouns in front of a verb.
    private static let contextTriggers: Set<String> = [
        "ai", "as", "a", "avons", "avez", "ont", "avait", "avais", "avaient", "avions", "aurai", "aura", "aurons", "auront",
        "suis", "es", "est", "sommes", "etes", "sont", "etait", "etais", "etaient", "serai", "sera", "seront",
        "un", "une", "ce", "cet", "cette", "ces", "mon", "ma", "mes", "ton", "ta", "tes", "son", "sa", "ses", "des", "par",
    ]

    private static func previousWord(of word: String, in sentence: String) -> String? {
        let words = sentence.lowercased().split(whereSeparator: { !$0.isLetter })
        guard words.count >= 2 else { return nil }
        return String(words[words.count - 2])
    }

    private static func cacheKey(_ word: String, _ sentence: String) -> String {
        let tail = sentence.split(separator: " ").suffix(4).joined(separator: " ")
        return word + "|" + tail
    }

    private func isCapitalized(_ word: String) -> Bool {
        word.first?.isUppercase == true && word.dropFirst().contains(where: \.isLowercase)
    }

    static func fold(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: nil)
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae")
    }

    static func applyCase(of source: String, to word: String) -> String {
        let letters = source.filter(\.isLetter)
        if letters.count > 1, letters.allSatisfy(\.isUppercase) { return word.uppercased() }
        if letters.first?.isUppercase == true { return word.prefix(1).uppercased() + word.dropFirst() }
        return word
    }
}
