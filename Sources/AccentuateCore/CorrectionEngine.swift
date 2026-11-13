public enum KeyInput: Equatable {
    case character(Character)
    case backspace
    /// Cursor moved, focus changed, shortcut used...: whatever we tracked is no longer reliable.
    case reset
}

public enum EngineAction: Equatable {
    /// The word just completed should be replaced by its accented form.
    case replace(original: String, replacement: String)
    /// Backspace right after a correction: restore the original word.
    case revert(original: String, replacement: String)
}

/// Tracks typed text and decides when a finished word deserves accents.
public struct CorrectionEngine {
    public var assumeFrench = false

    private let suggester: AccentSuggesting
    private let detector: LanguageDetecting
    private let minimumContextWords: Int
    private let maximumContextLength = 120
    private let maximumSentenceLength = 200

    /// Recent text, across sentences: what language detection looks at.
    private var context = ""
    /// The sentence typed so far, corrections included: what the suggester looks at.
    private var sentence = ""
    private var word = ""
    /// The current word cannot be trusted (we backspaced into it, or it was just reverted).
    private var wordIsOff = false
    private var lastCorrection: (original: String, replacement: String)?

    public init(suggester: AccentSuggesting, detector: LanguageDetecting, minimumContextWords: Int = 3) {
        self.suggester = suggester
        self.detector = detector
        self.minimumContextWords = minimumContextWords
    }

    @discardableResult
    public mutating func process(_ input: KeyInput) -> EngineAction? {
        let correction = lastCorrection
        lastCorrection = nil

        switch input {
        case .reset:
            context = ""
            sentence = ""
            word = ""
            wordIsOff = false
            return nil

        case .backspace:
            if let correction {
                context.removeLast(min(context.count, correction.replacement.count + 1))
                context += correction.original
                sentence.removeLast(min(sentence.count, correction.replacement.count + 1))
                sentence += correction.original
                word = correction.original
                wordIsOff = true
                return .revert(original: correction.original, replacement: correction.replacement)
            }
            if word.isEmpty {
                wordIsOff = true
            } else {
                word.removeLast()
            }
            if !context.isEmpty { context.removeLast() }
            if !sentence.isEmpty { sentence.removeLast() }
            return nil

        case .character(let character):
            if character.isLetter || character.isNumber {
                word.append(character)
                remember(character)
                return nil
            }
            return finishWord(boundary: character)
        }
    }

    private mutating func finishWord(boundary: Character) -> EngineAction? {
        defer {
            word = ""
            wordIsOff = false
        }
        var action: EngineAction?
        if !word.isEmpty, !wordIsOff, isFrenchContext(),
           let replacement = suggester.replacement(for: word, in: sentence) {
            action = .replace(original: word, replacement: replacement)
            context.removeLast(word.count)
            context += replacement
            sentence.removeLast(word.count)
            sentence += replacement
            lastCorrection = (word, replacement)
        }
        remember(boundary)
        if ".!?\n".contains(boundary) { sentence = "" }
        return action
    }

    private func isFrenchContext() -> Bool {
        if assumeFrench { return true }
        let words = context.split { !$0.isLetter && !$0.isNumber }
        return words.count >= minimumContextWords && detector.isFrench(context)
    }

    private mutating func remember(_ character: Character) {
        context.append(character)
        if context.count > maximumContextLength {
            context.removeFirst(context.count - maximumContextLength)
        }
        if !(sentence.isEmpty && character.isWhitespace) { sentence.append(character) }
        if sentence.count > maximumSentenceLength {
            // Keep whole words: cut after the first space of the excess.
            sentence.removeFirst(sentence.count - maximumSentenceLength)
            if let space = sentence.firstIndex(of: " ") { sentence.removeSubrange(...space) }
        }
    }
}
