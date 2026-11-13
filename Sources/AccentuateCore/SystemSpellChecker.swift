import AppKit

/// The macOS spell checker (French, offline). Its guesses take the sentence into account.
public final class SystemSpellChecker: SpellChecking {
    private let checker = NSSpellChecker.shared
    private let tag = NSSpellChecker.uniqueSpellDocumentTag()
    private let language: String

    public init(language: String = "fr") {
        self.language = language
        checker.setLanguage(language)
    }

    public func isMisspelled(_ word: String) -> Bool {
        checker.checkSpelling(of: word, startingAt: 0, language: language, wrap: false,
                              inSpellDocumentWithTag: tag, wordCount: nil).location != NSNotFound
    }

    public func guesses(for word: String, before: String, after: String) -> [String] {
        let range = NSRange(location: (before as NSString).length, length: (word as NSString).length)
        return checker.guesses(forWordRange: range, in: before + word + after, language: language,
                               inSpellDocumentWithTag: tag) ?? []
    }
}
