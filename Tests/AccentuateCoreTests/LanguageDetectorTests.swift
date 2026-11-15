import Testing
@testable import AccentuateCore

struct LanguageDetectorTests {
    let detector = NLLanguageDetector()

    @Test(arguments: [
        "je suis alle a l ecole ce matin",
        "nous allons manger au restaurant ce soir avec les enfants",
        "il faut que je te dise quelque chose de tres important",
        "est-ce que tu as vu le film hier soir",
    ])
    func detectsAccentlessFrench(_ text: String) {
        #expect(detector.detect(text) == .french)
    }

    @Test(arguments: [
        "i went to the store this morning to buy some milk",
        "we should schedule a meeting for next week to review the plan",
        "can you send me the report before the end of the day",
        "let's grab lunch tomorrow if you are free",
    ])
    func rejectsEnglish(_ text: String) {
        #expect(detector.detect(text) == nil)
    }

    @Test(arguments: [
        ("es", "voy a la escuela manana por la manana con mis amigos"),
        ("pt", "eu vou para a escola amanha de manha com os meus amigos"),
        ("it", "domani mattina andiamo a scuola con i nostri amici"),
        ("de", "morgen fruh gehen wir mit unseren freunden zur schule"),
    ])
    func detectsOtherLanguages(_ id: String, _ text: String) throws {
        #expect(detector.detect(text)?.id == id)
    }

    @Test func aChosenLanguageIsOnlyWeighedAgainstEnglish() {
        // Short accent-less French is often taken for Spanish; the user already said it is French.
        #expect(detector.confidence(of: .french, in: "je suis alle a l ecole ce matin") >= 0.6)
        #expect(detector.confidence(of: .french, in: "nous avons decide de partir") >= 0.6)
        #expect(detector.confidence(of: .french, in: "we should schedule a meeting for next week") < 0.2)
        #expect(detector.confidence(of: .french, in: "echo $pre && git status") < 0.6)
    }

    @Test(arguments: [(Sensitivity.cautious, 0.8, 4), (.balanced, 0.6, 3), (.eager, 0.45, 2)])
    func sensitivityLevelsMapToConfidenceAndContext(_ level: Sensitivity, _ confidence: Double, _ words: Int) {
        #expect(level.confidence == confidence)
        #expect(Confidence.contextWords(for: level.confidence) == words)
    }
}
