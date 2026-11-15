import Testing
@testable import AccentuateCore

/// Always says `language`, with total certainty.
private struct FixedDetector: LanguageDetecting {
    var language: Language?
    func detect(_ text: String, minimumConfidence: Double) -> Language? { language }
    func confidence(of candidate: Language, in text: String) -> Double { language == candidate ? 1 : 0 }
}

private final class ToggleDetector: LanguageDetecting {
    var language: Language?
    func detect(_ text: String, minimumConfidence: Double) -> Language? { language }
    func confidence(of candidate: Language, in text: String) -> Double { language == candidate ? 1 : 0 }
}

/// Reports a fixed confidence for any language and records what it was asked for.
private final class RecordingDetector: LanguageDetecting {
    var minimums: [Double] = []
    var confidence = 1.0
    func detect(_ text: String, minimumConfidence: Double) -> Language? {
        minimums.append(minimumConfidence)
        return .french
    }
    func confidence(of candidate: Language, in text: String) -> Double {
        minimums.append(-1)
        return confidence
    }
}

private final class FakeSuggester: AccentSuggesting {
    let table = ["ete": "été", "ecole": "école", "deja": "déjà"]
    var sentences: [String] = []
    var afters: [String: String] = [:]
    var languages: [Language] = []
    func replacement(for word: String, before: String, after: String, language: Language) -> String? {
        languages.append(language)
        sentences.append(before + word)
        afters[word] = after
        return table[word.lowercased()]
    }
}

private func makeEngine(french: Bool = true, minWords: Int = 1, suggester: FakeSuggester = FakeSuggester()) -> CorrectionEngine {
    CorrectionEngine(suggester: suggester, detector: FixedDetector(language: french ? .french : nil), minimumContextWords: minWords)
}

private func type(_ text: String, into engine: inout CorrectionEngine) -> [EngineAction] {
    text.compactMap { engine.process(.character($0)) }
}

struct CorrectionEngineTests {
    @Test func correctsWordAtBoundary() {
        var engine = makeEngine()
        #expect(type("j ai ete", into: &engine).isEmpty)
        #expect(engine.process(.character(" ")) == .replace(original: "ete", replacement: "été"))
    }

    @Test func doesNotCorrectBeforeBoundary() {
        var engine = makeEngine()
        #expect(type("ecole", into: &engine).isEmpty)
    }

    @Test func ignoresWordsTheSuggesterDoesNotKnow() {
        var engine = makeEngine()
        #expect(type("a hello ", into: &engine).isEmpty)
    }

    @Test func punctuationIsABoundary() {
        var engine = makeEngine()
        _ = type("ecole", into: &engine)
        #expect(engine.process(.character(".")) == .replace(original: "ecole", replacement: "école"))
    }

    @Test func apostropheAndHyphenSplitWords() {
        var engine = makeEngine()
        _ = type("l", into: &engine)
        #expect(engine.process(.character("'")) == nil)
        _ = type("ecole", into: &engine)
        #expect(engine.process(.character(" ")) == .replace(original: "ecole", replacement: "école"))
    }

    @Test func staysQuietWhenNotFrench() {
        var engine = makeEngine(french: false)
        #expect(type("ecole ", into: &engine).isEmpty)
    }

    @Test func needsEnoughContext() {
        var engine = makeEngine(minWords: 3)
        #expect(type("ecole je ", into: &engine).isEmpty)
        _ = type("suis", into: &engine)
        // Enough context at last: the words typed so far are fixed too.
        #expect(engine.process(.character(" ")) == .replace(original: "ecole je suis", replacement: "école je suis"))
    }

    @Test func backspaceEditsCurrentWord() {
        var engine = makeEngine()
        _ = type("ecolx", into: &engine)
        _ = engine.process(.backspace)
        _ = type("e", into: &engine)
        #expect(engine.process(.character(" ")) == .replace(original: "ecole", replacement: "école"))
    }

    @Test func resetDropsPendingWord() {
        var engine = makeEngine()
        _ = type("ecole", into: &engine)
        engine.process(.reset)
        #expect(engine.process(.character(" ")) == nil)
    }

    @Test func backspaceRightAfterCorrectionReverts() {
        var engine = makeEngine()
        _ = type("ecole ", into: &engine)
        #expect(engine.process(.backspace) == .revert(original: "ecole", replacement: "école"))
    }

    @Test func revertedWordIsNotCorrectedAgain() {
        var engine = makeEngine()
        _ = type("ecole ", into: &engine)
        _ = engine.process(.backspace)
        #expect(engine.process(.character(" ")) == nil)
    }

    @Test func revertOnlyAppliesToTheVeryNextKey() {
        var engine = makeEngine()
        _ = type("ecole x", into: &engine)
        #expect(engine.process(.backspace) == nil)
    }

    // What the suggester gets to see: the sentence typed so far.

    @Test func suggesterSeesTheSentenceSoFarWithCorrections() {
        let suggester = FakeSuggester()
        var engine = makeEngine(suggester: suggester)
        _ = type("nous avons ete a l ecole", into: &engine)
        _ = engine.process(.character(" "))
        #expect(suggester.sentences.last == "nous avons été a l ecole")
    }

    @Test func sentenceRestartsAfterTerminators() {
        let suggester = FakeSuggester()
        var engine = makeEngine(suggester: suggester)
        _ = type("il fait beau. nous allons a l ecole ", into: &engine)
        #expect(suggester.sentences.contains("nous allons a l ecole"))
        suggester.sentences.removeAll()
        _ = type("super!\nok ecole ", into: &engine)
        #expect(suggester.sentences.last == "ok ecole")
    }

    @Test func sentenceFollowsBackspaces() {
        let suggester = FakeSuggester()
        var engine = makeEngine(suggester: suggester)
        _ = type("ecolx", into: &engine)
        _ = engine.process(.backspace)
        _ = type("e ", into: &engine)
        #expect(suggester.sentences.last == "ecole")
    }

    // End of sentence: one more look at everything the live pass could not judge.

    @Test func finalDotFixesWordsSkippedForLackOfContext() {
        var engine = makeEngine(minWords: 3)
        #expect(type("ecole deja ete", into: &engine).isEmpty)
        #expect(engine.process(.character(".")) == .replace(original: "ecole deja ete", replacement: "école déjà été"))
    }

    @Test func finalPassOnlyRewritesFromTheFirstChangedWord() {
        var engine = makeEngine(minWords: 3)
        _ = type("il fait deja beau et ecole", into: &engine)
        // "deja" was already judged live, so only the last word changes.
        #expect(engine.process(.character("!")) == .replace(original: "ecole", replacement: "école"))
    }

    @Test func sentenceIsJudgedAgainAsItGrows() {
        let suggester = FakeSuggester()
        var engine = makeEngine(minWords: 1, suggester: suggester)
        _ = type("nous partons a l", into: &engine)
        _ = engine.process(.character(" "))
        #expect(suggester.afters["a"] == " l")
    }

    @Test func finalPassStaysQuietWhenNotFrench() {
        var engine = makeEngine(french: false, minWords: 1)
        _ = type("ecole deja ete", into: &engine)
        #expect(engine.process(.character(".")) == nil)
    }

    @Test func finalPassRechecksAmbiguousWordsWithWhatFollows() {
        let suggester = FakeSuggester()
        var engine = makeEngine(minWords: 1, suggester: suggester)
        _ = type("nous partons a l ecole", into: &engine)
        _ = engine.process(.character("."))
        #expect(suggester.afters["a"] == " l ecole")
    }

    @Test func returnEndsTheSentenceToo() {
        var engine = makeEngine(minWords: 3)
        _ = type("ecole deja ete", into: &engine)
        #expect(engine.process(.character("\n")) == .replace(original: "ecole deja ete", replacement: "école déjà été"))
    }

    @Test func backspaceAfterFinalPassRestoresTheSentenceAndLeavesItAlone() {
        var engine = makeEngine(minWords: 3)
        _ = type("ecole deja ete.", into: &engine)
        #expect(engine.process(.backspace) == .revert(original: "ecole deja ete", replacement: "école déjà été"))
        _ = type(".", into: &engine)
        #expect(engine.process(.character(" ")) == nil)
    }

    @Test func aNewSentenceStartsAfterTheFinalDot() {
        let suggester = FakeSuggester()
        var engine = makeEngine(minWords: 3, suggester: suggester)
        _ = type("il fait beau. ", into: &engine)
        suggester.sentences.removeAll()
        _ = type("ecole ", into: &engine)
        #expect(suggester.sentences == ["ecole"])
    }

    @Test func undoneWordsStayAsTypedForTheRestOfTheSentence() {
        var engine = makeEngine()
        _ = type("ecole ", into: &engine)
        _ = engine.process(.backspace)
        _ = type(" ete ", into: &engine)
        #expect(engine.process(.backspace) == .revert(original: "ete", replacement: "été"))
    }

    @Test func theEndOfTheSentenceJudgesEveryWordNotJustTheLatest() {
        let detector = ToggleDetector()
        var engine = CorrectionEngine(suggester: FakeSuggester(), detector: detector, minimumContextWords: 1)
        let filler = String(repeating: "un deux trois quatre ", count: 4) // 16 words, far more than the live window
        _ = type("ecole " + filler, into: &engine)
        detector.language = .french
        let action = engine.process(.character("."))
        #expect(action == .replace(original: "ecole " + filler, replacement: "école " + filler))
    }

    @Test func usesTheDetectedLanguage() throws {
        let spanish = try #require(Language.withID("es"))
        let suggester = FakeSuggester()
        var engine = CorrectionEngine(suggester: suggester, detector: FixedDetector(language: spanish), minimumContextWords: 1)
        _ = type("ecole ", into: &engine)
        #expect(suggester.languages == [spanish])
    }

    // Sensitivity: how sure we must be of the language, and how much text we want first.

    // A language you pick is a promise about you, not about every word you type.

    @Test func aChosenLanguageStillHasToLookLikeThatLanguage() {
        let detector = RecordingDetector()
        detector.confidence = 0.2 // the text around looks like something else, say English
        var engine = CorrectionEngine(suggester: FakeSuggester(), detector: detector)
        engine.selection = .fixed(.french)
        #expect(type("$pre ok voila ecole ", into: &engine).isEmpty)

        detector.confidence = 0.9
        #expect(!type("ecole ", into: &engine).isEmpty)
    }

    @Test func aChosenLanguageIsUsedOnceTheTextLooksLikeIt() throws {
        let german = try #require(Language.withID("de"))
        let suggester = FakeSuggester()
        var engine = CorrectionEngine(suggester: suggester, detector: FixedDetector(language: german), minimumContextWords: 1)
        engine.selection = .fixed(german)
        _ = type("ecole ", into: &engine)
        #expect(suggester.languages == [german])
    }

    @Test func theConfidenceIsWhatTheDetectorMustReach() {
        let detector = RecordingDetector()
        var engine = CorrectionEngine(suggester: FakeSuggester(), detector: detector)
        engine.confidence = 0.8
        _ = type("je suis alle a l ecole ", into: &engine)
        #expect(Set(detector.minimums) == [0.8])
    }

    @Test func aChosenLanguageMustReachTheConfidenceToo() {
        let detector = RecordingDetector()
        detector.confidence = 0.7
        var engine = CorrectionEngine(suggester: FakeSuggester(), detector: detector, minimumContextWords: 1)
        engine.selection = .fixed(.french)
        engine.confidence = 0.8
        #expect(type("ecole ", into: &engine).isEmpty)
        engine.confidence = 0.6
        #expect(type("ecole ", into: &engine).count == 1)
    }

    @Test(arguments: [(0.9, 4), (0.8, 4), (0.6, 3), (0.5, 3), (0.45, 2)])
    func moreConfidenceAsksForMoreWords(_ confidence: Double, _ words: Int) {
        let detector = RecordingDetector()
        var engine = CorrectionEngine(suggester: FakeSuggester(), detector: detector)
        engine.confidence = confidence
        _ = type(String(repeating: "mot ", count: words - 1), into: &engine)
        #expect(detector.minimums.isEmpty)
        _ = type("mot ", into: &engine)
        #expect(!detector.minimums.isEmpty)
    }
}
