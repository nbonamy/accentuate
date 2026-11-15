import NaturalLanguage

public protocol LanguageDetecting {
    /// The language `text` is written in, if it is one we correct and the recognizer gives it
    /// at least `minimumConfidence` (0...1).
    func detect(_ text: String, minimumConfidence: Double) -> Language?

    /// How sure we are (0...1) that `text` is written in `candidate`, weighed against English only.
    /// For when the user has already said which language they write: all that remains to rule out
    /// is that this particular text is something else, like English or code.
    func confidence(of candidate: Language, in text: String) -> Double
}

extension LanguageDetecting {
    func detect(_ text: String) -> Language? { detect(text, minimumConfidence: Confidence.standard) }
}

/// How sure Accentuate must be that you are writing the language before it corrects anything.
public enum Sensitivity: String, CaseIterable, Identifiable {
    /// A surer verdict from more text: stays out of mixed or English-heavy writing.
    case cautious
    case balanced
    /// Starts sooner and accepts a weaker verdict.
    case eager

    public var id: String { rawValue }
    public var name: String { rawValue.capitalized }
    public var confidence: Double { [.cautious: 0.8, .balanced: Confidence.standard, .eager: 0.45][self]! }
}

public enum Confidence {
    public static let standard = 0.6

    /// A surer verdict is also given more text to look at.
    public static func contextWords(for confidence: Double) -> Int {
        confidence >= 0.75 ? 4 : confidence >= 0.5 ? 3 : 2
    }
}

/// Detects the language over a short window of recent text. English is a candidate too, so
/// English text is recognized as such instead of being forced into the closest other language.
public struct NLLanguageDetector: LanguageDetecting {
    private let languages: [Language]

    public init(languages: [Language] = Language.available) {
        self.languages = languages
    }

    public func detect(_ text: String, minimumConfidence: Double) -> Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = languages.map(\.naturalLanguage) + [.english]
        recognizer.processString(text)
        guard let best = recognizer.languageHypotheses(withMaximum: 1).first, best.value >= minimumConfidence else { return nil }
        return languages.first { $0.naturalLanguage == best.key }
    }

    public func confidence(of candidate: Language, in text: String) -> Double {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [candidate.naturalLanguage, .english]
        recognizer.processString(text)
        return recognizer.languageHypotheses(withMaximum: 2)[candidate.naturalLanguage] ?? 0
    }
}
