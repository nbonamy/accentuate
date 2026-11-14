import Foundation

public protocol AccentSuggesting {
    /// The accented form of `word`, or nil when it should be left as typed.
    /// - Parameters:
    ///   - before: the sentence up to `word`.
    ///   - after: the rest of the sentence, empty while it is still being typed.
    ///   - language: the language the sentence is written in.
    func replacement(for word: String, before: String, after: String, language: Language) -> String?
}

extension AccentSuggesting {
    /// While typing: `sentence` is the text so far, ending with `word`.
    func replacement(for word: String, in sentence: String, language: Language = .french) -> String? {
        replacement(for: word, before: String(sentence.dropLast(word.count)), after: "", language: language)
    }
}

public protocol SpellChecking {
    func isMisspelled(_ word: String, language: Language) -> Bool
    /// Best-first guesses for `word`, in the context of `before` + word + `after`.
    func guesses(for word: String, before: String, after: String, language: Language) -> [String]
}

/// Decides which words get accents, using the spell checker's context-aware guesses
/// only when they can be trusted.
public final class AccentSuggester: AccentSuggesting {
    private let spellChecker: SpellChecking
    /// French only: the evidence used for words that are valid with and without their accent.
    private let frequencies: WordFrequencies
    private var cache: [String: String?] = [:]

    public init(spellChecker: SpellChecking, frequencies: WordFrequencies) {
        self.spellChecker = spellChecker
        self.frequencies = frequencies
    }

    public func replacement(for word: String, before: String, after: String, language: Language) -> String? {
        let lowered = word.lowercased()
        // Only plain ASCII letters: anything else is already accented or not a word.
        guard lowered.count > 1 || lowered == "a", lowered.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        // A capital in the middle of a sentence is a name (all caps is shouting, fine).
        // Not in German, where every noun has one.
        if language.id != "de", isCapitalized(word), before.contains(where: \.isLetter) { return nil }

        let key = language.id + "|" + Self.cacheKey(word, before, after)
        if let cached = cache[key] { return cached }
        let result = decide(word, lowered: lowered, before: before, after: after, language: language)
        if cache.count > 2000 { cache.removeAll() }
        cache[key] = .some(result)
        return result
    }

    private func decide(_ word: String, lowered: String, before: String, after: String, language: Language) -> String? {
        if AmbiguityRules.words(for: language).contains(lowered) {
            return AmbiguityRules.replacement(for: word, before: before, after: after).map { Self.applyCase(of: word, to: $0) }
        }
        guard let guess = spellChecker.guesses(for: word, before: before, after: after, language: language)
            .map({ $0.lowercased() })
            .first(where: { Self.fold($0) == lowered && $0 != lowered })
        else { return nil }

        guard spellChecker.isMisspelled(word, language: language) else {
            return trustsAccentedForm(guess, over: lowered, before: before, language: language)
                ? Self.applyCase(of: word, to: guess) : nil
        }
        return Self.applyCase(of: word, to: guess)
    }

    /// The word is valid as typed, so the guess needs real evidence: either it is far more
    /// common than every other spelling, or the previous word says "participle/noun here"
    /// and the two are about equally common.
    private func trustsAccentedForm(_ guess: String, over plain: String, before: String, language: Language) -> Bool {
        // Without frequency evidence or French grammar, a valid word is left as typed.
        guard language == .french else { return false }
        let spellings = frequencies.spellings(forKey: plain)
        guard let guessFrequency = spellings[guess], let plainFrequency = spellings[plain] else { return false }
        let competitors = spellings.filter { $0.key != guess }.values.reduce(0, +)
        if guessFrequency >= 10 * competitors { return true }
        guard let previous = Self.lastWord(of: before), Self.contextTriggers.contains(previous) else { return false }
        return guessFrequency >= 0.5 * plainFrequency
    }

    // French. Auxiliaries (before a participle) and determiners (before a noun or adjective).
    // Deliberately without le/la/les/en: they are often pronouns in front of a verb.
    private static let contextTriggers: Set<String> = [
        "ai", "as", "a", "avons", "avez", "ont", "avait", "avais", "avaient", "avions", "aurai", "aura", "aurons", "auront",
        "suis", "es", "est", "sommes", "etes", "sont", "etait", "etais", "etaient", "serai", "sera", "seront",
        "un", "une", "ce", "cet", "cette", "ces", "mon", "ma", "mes", "ton", "ta", "tes", "son", "sa", "ses", "des", "par",
    ]

    private static func lastWord(of text: String) -> String? {
        text.lowercased().split(whereSeparator: { !$0.isLetter }).last.map(String.init)
    }

    private static func cacheKey(_ word: String, _ before: String, _ after: String) -> String {
        let head = before.split(separator: " ").suffix(4).joined(separator: " ")
        let tail = after.split(separator: " ").prefix(2).joined(separator: " ")
        return head + "|" + word + "|" + tail
    }

    private func isCapitalized(_ word: String) -> Bool {
        word.first?.isUppercase == true && word.dropFirst().contains(where: \.isLowercase)
    }

    /// Letters that are not "a letter plus a mark", so Unicode decomposition does not fold them.
    private static let specialLetters: [String: String] = [
        "œ": "oe", "æ": "ae", "ß": "ss", "ł": "l", "ø": "o", "đ": "d", "ı": "i",
    ]

    static func fold(_ text: String) -> String {
        var folded = text.lowercased()
        for (letter, plain) in specialLetters { folded = folded.replacingOccurrences(of: letter, with: plain) }
        return folded.folding(options: .diacriticInsensitive, locale: nil)
    }

    static func applyCase(of source: String, to word: String) -> String {
        let letters = source.filter(\.isLetter)
        if letters.count > 1, letters.allSatisfy(\.isUppercase) { return word.uppercased() }
        if letters.first?.isUppercase == true { return word.prefix(1).uppercased() + word.dropFirst() }
        return word
    }
}
