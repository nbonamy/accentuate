import Testing
@testable import AccentuateCore

private struct FixedDetector: LanguageDetecting {
    var french: Bool
    func isFrench(_ text: String) -> Bool { french }
}

private final class FakeSuggester: AccentSuggesting {
    let table = ["ete": "été", "ecole": "école", "deja": "déjà"]
    var sentences: [String] = []
    func replacement(for word: String, in sentence: String) -> String? {
        sentences.append(sentence)
        return table[word.lowercased()]
    }
}

private func makeEngine(french: Bool = true, minWords: Int = 1, suggester: FakeSuggester = FakeSuggester()) -> CorrectionEngine {
    CorrectionEngine(suggester: suggester, detector: FixedDetector(french: french), minimumContextWords: minWords)
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
        #expect(type("ecole ", into: &engine).isEmpty)
        #expect(type("je suis ", into: &engine).isEmpty)
        _ = type("ecole", into: &engine)
        #expect(engine.process(.character(" ")) != nil)
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

    @Test func assumeFrenchSkipsDetection() {
        var engine = makeEngine(french: false)
        engine.assumeFrench = true
        _ = type("ecole", into: &engine)
        #expect(engine.process(.character(" ")) != nil)
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
}
