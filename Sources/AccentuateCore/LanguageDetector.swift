import NaturalLanguage

public protocol LanguageDetecting {
    func isFrench(_ text: String) -> Bool
}

/// Detects French over a short window of recent text, constrained to a few languages
/// so accent-less French is not mistaken for something exotic.
public struct NLLanguageDetector: LanguageDetecting {
    private let threshold: Double
    private static let candidates: [NLLanguage] = [.french, .english, .spanish, .german, .italian, .portuguese]

    public init(threshold: Double = 0.6) {
        self.threshold = threshold
    }

    public func isFrench(_ text: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = Self.candidates
        recognizer.processString(text)
        return recognizer.languageHypotheses(withMaximum: 1)[.french, default: 0] >= threshold
    }
}
