import Foundation
import Testing
@testable import AccentuateCore

/// End-to-end checks with the real macOS French spell checker (so they depend on the
/// machine's French dictionary) and the real language detector.
@MainActor
struct AcceptanceTests {
    private func restoreAccents(_ text: String, warmUp: Bool = true) throws -> String {
        let suggester = AccentSuggester(spellChecker: SystemSpellChecker(), frequencies: try WordFrequencies.bundled())
        var engine = CorrectionEngine(suggester: suggester, detector: NLLanguageDetector())
        var output = ""
        // Real typing carries context over from earlier sentences.
        if warmUp {
            for character in "Salut tout le monde, comment allez vous aujourd'hui ? " { _ = engine.process(.character(character)) }
        }
        for character in text {
            if case .replace(let original, let replacement)? = engine.process(.character(character)) {
                output.removeLast(original.count)
                output += replacement
            }
            output.append(character)
        }
        return output
    }

    private func stripped(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: nil)
            .replacingOccurrences(of: "œ", with: "oe")
    }

    @Test func restoresTheReportedParagraph() throws {
        let typed = """
        Pour information, nous avons decide que nous allions mettre en vente notre bien. \
        Nous respecterons bien evidemment les contraintes legales par rapport a votre bail. \
        Nous vous enverrons une notification par recommande avec AR fin decembre, debut janvier.\u{20}
        """
        let expected = """
        Pour information, nous avons décidé que nous allions mettre en vente notre bien. \
        Nous respecterons bien évidemment les contraintes légales par rapport à votre bail. \
        Nous vous enverrons une notification par recommandé avec AR fin décembre, début janvier.\u{20}
        """
        let result = try restoreAccents(typed)
        #expect(result == expected)
    }

    /// Typed as a French speaker would on a US keyboard: every sentence below is correct
    /// French, so the output must match it exactly once accents are stripped from the input.
    @Test(arguments: [
        "Je suis allé à l'école ce matin avec les enfants.",
        "Il fait très beau et j'ai déjà fini mon travail.",
        "Nous avons mangé au restaurant hier soir, c'était délicieux.",
        "Elle est très fatiguée mais elle a décidé de continuer.",
        "Peut-être que nous irons à la plage demain, ça dépend de la météo.",
        "Il va à Paris la semaine prochaine pour une réunion importante.",
        "Bien sûr, nous pouvons déjeuner ensemble lundi à midi.",
        "Je mange une pomme et il mange du pain.",
        "Le chat est sur la table et le chien dort dans le salon.",
        "Tu préfères le café ou le chocolat ?",
        "C'est une très bonne idée, merci beaucoup pour tout.",
        "Les élèves ont fini leurs devoirs avant la fin du cours.",
        "Nous habitons près de la forêt depuis longtemps.",
        "Je pense à toi et j'espère que tout va bien.",
        "Il y a beaucoup de monde dans la rue aujourd'hui.",
        "Merci à tous pour votre présence et votre soutien.",
        "J'ai réservé une table pour demain à huit heures.",
        "Cette année, l'été a été très chaud.",
    ])
    func restoresCommonFrench(_ sentence: String) throws {
        let result = try restoreAccents(stripped(sentence) + " ")
        #expect(result.trimmingCharacters(in: .whitespaces) == sentence)
    }

    @Test func picksTheFormThatFitsTheSentence() throws {
        #expect(try restoreAccents("nous avons decide de partir ").hasPrefix("nous avons décidé"))
        #expect(try restoreAccents("il decide de partir ").hasPrefix("il décide"))
    }

    @Test(arguments: [
        "We went to the school this morning and the weather was great, so we decided to stay.",
        "Please send me the report before the end of the day, the team is waiting for the cafe order.",
        "I think the best option is to schedule a meeting next week to review the plan and decide.",
    ])
    func leavesEnglishAlone(_ sentence: String) throws {
        let result = try restoreAccents(sentence + " ")
        #expect(result.trimmingCharacters(in: .whitespaces) == sentence)
    }

    /// The event tap waits for each decision, so it has to stay quick.
    @Test(arguments: [
        ("Elle est tres contente.", "Elle est très contente."),
        ("Je suis alle a l ecole.", "Je suis allé à l école."),
        ("Nous allons partir a la plage demain.", "Nous allons partir à la plage demain."),
        ("A bientot, je te rappelle demain.", "À bientôt, je te rappelle demain."),
        ("Ou est le chat ?", "Où est le chat ?"),
    ])
    func finalPassFixesWhatLiveCorrectionsMissed(_ typed: String, _ expected: String) throws {
        // Fresh engine, no warm-up: the first words are only judged at the final dot.
        #expect(try restoreAccents(typed, warmUp: false) == expected)
    }

    @Test func decisionsAreFast() throws {
        let suggester = AccentSuggester(spellChecker: SystemSpellChecker(), frequencies: try WordFrequencies.bundled())
        let sentence = "nous avons decide que nous allions mettre en vente notre bien"
        var worst = 0.0
        var soFar = ""
        for word in sentence.split(separator: " ") {
            soFar += (soFar.isEmpty ? "" : " ") + word
            let start = Date()
            _ = suggester.replacement(for: String(word), in: soFar)
            worst = max(worst, Date().timeIntervalSince(start))
        }
        #expect(worst < 0.15, "slowest decision took \(Int(worst * 1000)) ms")
    }

    /// Judging the whole sentence at every word must not make typing feel stuck.
    @Test func everyKeystrokeIsQuick() throws {
        let suggester = AccentSuggester(spellChecker: SystemSpellChecker(), frequencies: try WordFrequencies.bundled())
        var engine = CorrectionEngine(suggester: suggester, detector: NLLanguageDetector())
        let text = "Pour information, nous avons decide que nous allions mettre en vente notre bien depuis longtemps. Nous respecterons bien evidemment les contraintes legales par rapport a votre bail et nous vous enverrons une notification par recommande avec AR fin decembre, debut janvier. "
        var worst = 0.0
        var total = 0.0
        for character in text {
            let start = Date()
            _ = engine.process(.character(character))
            let elapsed = Date().timeIntervalSince(start)
            worst = max(worst, elapsed)
            total += elapsed
        }
        print("worst keystroke: \(Int(worst * 1000)) ms, total: \(Int(total * 1000)) ms")
        #expect(worst < 0.25, "slowest keystroke took \(Int(worst * 1000)) ms")
    }
}
