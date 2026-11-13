import Testing
@testable import AccentuateCore

struct AmbiguityRulesTests {
    @Test(arguments: [
        ("par rapport a", "à"),
        ("nous allons a", "à"),
        ("je vais a", "à"),
        ("je suis alle a", "à"),
        ("grace a", "à"),
        ("jusqu'a", "à"),
        ("rendez-vous demain a", "à"),
        ("d'ou", "où"),
        ("n'importe ou", "où"),
        ("partout ou", "où"),
        ("bien sur", "sûr"),
        ("Bien sur", "sûr"),
        ("celui-la", "là"),
        ("ce jour-la", "là"),
    ])
    func resolvesClearCases(_ sentence: String, _ expected: String) {
        let word = String(sentence.split(whereSeparator: { !$0.isLetter }).last!)
        #expect(AmbiguityRules.replacement(for: word, in: sentence) == expected)
    }

    @Test(arguments: [
        ("il a", "a"),
        ("il y a", "a"),
        ("elle a", "a"),
        ("on a", "a"),
        ("a", "a"),
        ("oui ou", "ou"),
        ("du pain ou", "ou"),
        ("ou", "ou"),
        ("le sur", "sur"),
        ("c'est sur", "sur"),
        ("dans la", "la"),
        ("je la", "la"),
        ("donne-la", "la"),
        ("le chat est sur", "sur"),
    ])
    func staysQuietWhenUnsure(_ sentence: String, _ word: String) {
        #expect(AmbiguityRules.replacement(for: word, in: sentence) == nil)
    }

    @Test func knowsWhichWordsItOwns() {
        #expect(AmbiguityRules.words == ["a", "ou", "la", "sur"])
    }

    // What follows the word (only known once the sentence is complete).

    @Test(arguments: [
        ("nous allons partir ", "a", " l ecole", "à"),
        ("je dois parler ", "a", " mon frere", "à"),
        ("", "a", " bientot", "à"),
        ("", "a", " demain", "à"),
        ("ca commence ", "a", " partir de lundi", "à"),
        ("", "ou", " est le chat", "où"),
        ("dis moi ", "ou", " vas tu", "où"),
        ("", "la", "-bas", "là"),
        ("il habite ", "la", " haut", "là"),
    ])
    func usesWhatFollows(_ before: String, _ word: String, _ after: String, _ expected: String) {
        #expect(AmbiguityRules.replacement(for: word, before: before, after: after) == expected)
    }

    @Test(arguments: [
        ("il ", "a", " la grippe"),
        ("le chat ", "a", " la queue"),
        ("elle ", "a", " demain une reunion"),
        ("il y ", "a", " un probleme"),
        ("du the ", "ou", " du cafe"),
        ("tu veux du the ", "ou", " est-ce que tu preferes de l eau"),
        ("je ", "la", " mange"),
        ("dans ", "la", " bassine"),
    ])
    func staysQuietEvenWithWhatFollows(_ before: String, _ word: String, _ after: String) {
        #expect(AmbiguityRules.replacement(for: word, before: before, after: after) == nil)
    }
}
