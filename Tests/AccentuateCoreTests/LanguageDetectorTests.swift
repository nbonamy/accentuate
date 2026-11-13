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
        #expect(detector.isFrench(text))
    }

    @Test(arguments: [
        "i went to the store this morning to buy some milk",
        "we should schedule a meeting for next week to review the plan",
        "can you send me the report before the end of the day",
        "let's grab lunch tomorrow if you are free",
    ])
    func rejectsEnglish(_ text: String) {
        #expect(!detector.isFrench(text))
    }
}
