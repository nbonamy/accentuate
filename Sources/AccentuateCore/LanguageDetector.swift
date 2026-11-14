import NaturalLanguage

public protocol LanguageDetecting {
    /// The language `text` is written in, if it is one we correct and we are confident enough.
    func detect(_ text: String) -> Language?
}

/// Detects the language over a short window of recent text. English is a candidate too, so
/// English text is recognized as such instead of being forced into the closest other language.
public struct NLLanguageDetector: LanguageDetecting {
    private let languages: [Language]
    private let threshold: Double

    public init(languages: [Language] = Language.available, threshold: Double = 0.6) {
        self.languages = languages
        self.threshold = threshold
    }

    public func detect(_ text: String) -> Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = languages.map(\.naturalLanguage) + [.english]
        recognizer.processString(text)
        guard let best = recognizer.languageHypotheses(withMaximum: 1).first, best.value >= threshold else { return nil }
        return languages.first { $0.naturalLanguage == best.key }
    }
}
