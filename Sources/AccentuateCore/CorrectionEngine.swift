public enum KeyInput: Equatable {
    case character(Character)
    case backspace
    /// Cursor moved, focus changed, shortcut used...: whatever we tracked is no longer reliable.
    case reset
}

public enum EngineAction: Equatable {
    /// Replace the text just before the cursor (a word, or a stretch of the sentence at its end).
    case replace(original: String, replacement: String)
    /// Backspace right after a correction: restore the original text.
    case revert(original: String, replacement: String)
}

/// Tracks typed text and decides when it deserves accents.
///
/// At every word boundary the whole sentence typed so far is judged again, with each word
/// seen in the context of its neighbours, and whatever changed is rewritten (usually just
/// the last word). The final . ! ? or return gets the same treatment, then a new sentence starts.
public struct CorrectionEngine {
    public var selection: LanguageSelection = .auto
    /// How sure we must be that the text is in the language before correcting it (0...1).
    public var confidence = Confidence.standard

    private let suggester: AccentSuggesting
    private let detector: LanguageDetecting
    private let minimumContextWords: Int?
    private let maximumContextLength = 120
    private let maximumSentenceLength = 200
    /// Each re-judged word may cost a spell-checker call: while typing, only look at the latest ones.
    private let maximumJudgedWords = 12

    /// Recent text, across sentences: what language detection looks at.
    private var context = ""
    /// The sentence typed so far, corrections included.
    private var sentence = ""
    private var word = ""
    /// Words the user undid in this sentence: they stay as typed.
    private var rejectedWords: Set<String> = []
    private var lastCorrection: (original: String, replacement: String)?

    public init(suggester: AccentSuggesting, detector: LanguageDetecting, minimumContextWords: Int? = nil) {
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
            startNewSentence()
            word = ""
            return nil

        case .backspace:
            if let correction {
                context.removeLast(min(context.count, correction.replacement.count + 1))
                context += correction.original
                sentence.removeLast(min(sentence.count, correction.replacement.count + 1))
                sentence += correction.original
                word = String(correction.original.reversed().prefix(while: \.isLetter).reversed())
                rejectedWords.formUnion(correction.original.lowercased().split { !$0.isLetter }.map(String.init))
                return .revert(original: correction.original, replacement: correction.replacement)
            }
            if !word.isEmpty { word.removeLast() }
            if !context.isEmpty { context.removeLast() }
            if !sentence.isEmpty { sentence.removeLast() }
            return nil

        case .character(let character):
            // "_" keeps identifiers (pre_commit) in one piece, which we then leave alone.
            if character.isLetter || character.isNumber || character == "_" {
                word.append(character)
                remember(character)
                return nil
            }
            return finishWord(boundary: character)
        }
    }

    private mutating func finishWord(boundary: Character) -> EngineAction? {
        let endsSentence = ".!?\n".contains(boundary)
        var action: EngineAction?
        if (!word.isEmpty || endsSentence), let language = currentLanguage() {
            let typed = sentence
            let corrected = judgedSentence(typed, language: language, everyWord: endsSentence)
            if let edit = difference(from: typed, to: corrected), case .replace(let original, let replacement) = edit {
                sentence = corrected
                context.removeLast(min(context.count, original.count))
                context += replacement
                lastCorrection = (original, replacement)
                action = edit
            }
        }
        word = ""
        remember(boundary)
        if endsSentence { startNewSentence() }
        return action
    }

    /// Every word, judged with the rest of the sentence around it. While typing only the
    /// latest words are looked at; at the end of the sentence, all of them.
    private func judgedSentence(_ text: String, language: Language, everyWord: Bool) -> String {
        var segments: [(text: String, isWord: Bool)] = []
        for character in text {
            if let last = segments.last, last.isWord == character.isLetter {
                segments[segments.count - 1].text.append(character)
            } else {
                segments.append((String(character), character.isLetter))
            }
        }

        let allWords = segments.indices.filter { segments[$0].isWord }
        let wordIndices = everyWord ? allWords : Array(allWords.suffix(maximumJudgedWords))
        for index in wordIndices {
            let word = segments[index].text
            guard !rejectedWords.contains(word.lowercased()) else { continue }
            let before = segments[..<index].map(\.text).joined()
            let after = segments[(index + 1)...].map(\.text).joined()
            if let replacement = suggester.replacement(for: word, before: before, after: after, language: language) {
                segments[index].text = replacement
            }
        }
        return segments.map(\.text).joined()
    }

    /// The smallest edit at the end of the text, widened to whole words.
    private func difference(from old: String, to new: String) -> EngineAction? {
        guard old != new else { return nil }
        let oldCharacters = Array(old), newCharacters = Array(new)
        var start = 0
        while start < min(oldCharacters.count, newCharacters.count), oldCharacters[start] == newCharacters[start] { start += 1 }
        while start > 0, oldCharacters[start - 1].isLetter { start -= 1 }
        let replacement = String(newCharacters[start...])
        // A tab would move the focus when retyped.
        guard !replacement.contains("\t") else { return nil }
        return .replace(original: String(oldCharacters[start...]), replacement: replacement)
    }

    private mutating func startNewSentence() {
        sentence = ""
        rejectedWords = []
    }

    private func currentLanguage() -> Language? {
        let words = context.split { !$0.isLetter && !$0.isNumber }
        guard words.count >= (minimumContextWords ?? Confidence.contextWords(for: confidence)) else { return nil }
        switch selection {
        case .auto:
            return detector.detect(context, minimumConfidence: confidence)
        case .fixed(let language):
            return detector.confidence(of: language, in: context) >= confidence ? language : nil
        }
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
