import AppKit

/// The macOS spell checker (offline). Its guesses take the sentence into account.
public final class SystemSpellChecker: SpellChecking {
    private let checker = NSSpellChecker.shared
    private let tag = NSSpellChecker.uniqueSpellDocumentTag()

    public init() {}

    public func isMisspelled(_ word: String, language: Language) -> Bool {
        checker.checkSpelling(of: word, startingAt: 0, language: language.spellCheckerCode, wrap: false,
                              inSpellDocumentWithTag: tag, wordCount: nil).location != NSNotFound
    }

    public func guesses(for word: String, before: String, after: String, language: Language) -> [String] {
        let range = NSRange(location: (before as NSString).length, length: (word as NSString).length)
        return checker.guesses(forWordRange: range, in: before + word + after, language: language.spellCheckerCode,
                               inSpellDocumentWithTag: tag) ?? []
    }
}
