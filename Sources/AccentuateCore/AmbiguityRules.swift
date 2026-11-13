/// Words that are valid with and without accent. The spell checker cannot tell them apart,
/// so we only accent them when the words before them make the accented reading obvious.
/// When in doubt we do nothing: a missing accent beats a wrong one.
enum AmbiguityRules {
    static let words: Set<String> = ["a", "ou", "la", "sur"]

    /// - Parameter sentence: the sentence typed so far, ending with `word`.
    static func replacement(for word: String, in sentence: String) -> String? {
        let context = Context(word: word, sentence: sentence)
        guard let previous = context.previousWord else { return nil }
        switch word.lowercased() {
        case "a":
            return prepositionTriggers.contains(previous) ? "à" : nil
        case "ou":
            return whereTriggers.contains(previous) ? "où" : nil
        case "sur":
            return previous == "bien" ? "sûr" : nil
        case "la":
            return context.separators == "-" && thereTriggers.contains(previous) ? "là" : nil
        default:
            return nil
        }
    }

    // "à": after verbs of going, or fixed expressions, `a` cannot be the verb "avoir".
    private static let prepositionTriggers: Set<String> = [
        "vais", "vas", "va", "allons", "allez", "vont", "aller", "allait", "allais", "allaient",
        "irai", "iras", "ira", "irons", "irez", "iront", "alle", "allé", "allee", "allée", "alles", "allés",
        "rapport", "grace", "face", "quant", "jusqu", "suite", "merci", "bienvenue",
        "demain", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche",
        "pense", "penses", "pensons", "pensez", "penser", "habite", "habites", "habitons", "habitez",
        "parle", "parles", "parlons", "parlez", "parler", "pret", "prete", "prets", "pretes",
    ]
    private static let whereTriggers: Set<String> = ["d", "importe", "partout", "jusqu", "par"]
    private static let thereTriggers: Set<String> = [
        "celui", "celle", "ceux", "celles", "jour", "soir", "matin", "moment", "epoque", "annee", "semaine",
    ]

    private struct Context {
        let previousWord: String?
        /// What sits between the previous word and ours (space, apostrophe, hyphen...).
        let separators: String

        init(word: String, sentence: String) {
            var before = Substring(sentence.dropLast(word.count))
            var separators = ""
            while let last = before.last, !last.isLetter {
                separators.insert(last, at: separators.startIndex)
                before.removeLast()
            }
            var letters = ""
            while let last = before.last, last.isLetter {
                letters.insert(last, at: letters.startIndex)
                before.removeLast()
            }
            self.previousWord = letters.isEmpty ? nil : letters.lowercased()
            self.separators = separators
        }
    }
}
