/// French words that are valid with and without accent. The spell checker cannot tell them
/// apart, so we only accent them when the words around them make the accented reading obvious.
/// When in doubt we do nothing: a missing accent beats a wrong one.
enum AmbiguityRules {
    static let frenchWords: Set<String> = ["a", "ou", "la", "sur"]

    static func words(for language: Language) -> Set<String> { language == .french ? frenchWords : [] }

    /// - Parameters:
    ///   - before: the sentence up to `word`.
    ///   - after: the rest of the sentence, when it is known (end-of-sentence pass).
    static func replacement(for word: String, before: String, after: String = "") -> String? {
        let previous = Neighbour(before: before)
        let next = Neighbour(after: after)
        switch word.lowercased() {
        case "a":
            if let previous = previous.word, prepositionTriggers.contains(previous) { return "à" }
            if let number = next.number, !subjects.contains(previous.word ?? "") {
                // "c'est à 31:26", "la réunion est à 10 heures", "on se voit à 18h30"; but "Paul a 31 ans".
                if number.isTime || beingForms.contains(previous.word ?? "") { return "à" }
            }
            if let following = next.word, !subjects.contains(previous.word ?? "") {
                if prepositionFollowers.contains(following) { return "à" }
                if determiners.contains(following), let previous = previous.word, isInfinitive(previous) { return "à" }
            }
            return nil
        case "ou":
            if let previous = previous.word, whereTriggers.contains(previous) { return "où" }
            if let following = next.word, whereFollowers.contains(following),
               !(following == "est" && next.remainder.hasPrefix("-ce")) { return "où" }
            return nil
        case "sur":
            return previous.word == "bien" ? "sûr" : nil
        case "la":
            if let previous = previous.word, before.hasSuffix("-"), thereTriggers.contains(previous) { return "là" }
            if let following = next.word, thereFollowers.contains(following) { return "là" }
            return nil
        default:
            return nil
        }
    }

    /// Convenience: `sentence` is the text so far, ending with `word`.
    static func replacement(for word: String, in sentence: String) -> String? {
        replacement(for: word, before: String(sentence.dropLast(word.count)))
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

    // "à" before a place, a time or a fixed expression; never after a subject ("il a demain...").
    private static let prepositionFollowers: Set<String> = [
        "bientot", "demain", "cause", "propos", "partir", "present", "condition", "travers", "cote",
    ]
    private static let beingForms: Set<String> = [
        "est", "sont", "sera", "seront", "etait", "etaient", "serait", "seraient", "soit",
    ]
    private static let subjects: Set<String> = [
        "il", "elle", "on", "qui", "y", "n", "l", "m", "t", "s", "c", "ce", "ca", "cela", "tout", "rien",
        "personne", "chacun", "je", "j", "tu", "nous", "vous", "ils", "elles",
    ]
    private static let determiners: Set<String> = [
        "la", "le", "l", "les", "un", "une", "mon", "ma", "mes", "ton", "ta", "tes", "son", "sa", "ses",
        "notre", "votre", "leur", "cette", "ce", "cet", "ces",
    ]
    private static let whereFollowers: Set<String> = [
        "est", "sont", "es", "etes", "vas", "va", "allez", "vont", "allons", "habites", "habitez", "habitent",
    ]
    private static let thereFollowers: Set<String> = ["bas", "haut", "dedans", "dessus"]

    /// An infinitive is a safe sign that the next "a" is a preposition: "partir à l'école".
    private static func isInfinitive(_ word: String) -> Bool {
        word.count >= 5 && (word.hasSuffix("er") || word.hasSuffix("ir")) && !word.hasSuffix("ier")
    }

    /// The word next to ours, and what lies between.
    private struct Neighbour {
        var word: String?
        var remainder = ""
        /// The next token when it starts with a digit.
        var number: Number?

        struct Number {
            let token: String
            /// 10h, 10h30, 18:45
            var isTime: Bool {
                let digits = token.prefix { $0.isNumber }
                guard (1...2).contains(digits.count) else { return false }
                let rest = token.dropFirst(digits.count)
                return rest.hasPrefix(":") && rest.dropFirst().first?.isNumber == true || rest.lowercased().hasPrefix("h")
            }
        }

        /// The last word of `before`.
        init(before: String) {
            var rest = Substring(before)
            while let last = rest.last, !last.isLetter { rest.removeLast() }
            var letters = ""
            while let last = rest.last, last.isLetter {
                letters.insert(last, at: letters.startIndex)
                rest.removeLast()
            }
            word = letters.isEmpty ? nil : letters.lowercased()
        }

        /// The first word of `after`; `remainder` is whatever follows it.
        init(after: String) {
            var rest = Substring(after)
            while let first = rest.first, !first.isLetter { rest.removeFirst() }
            var letters = ""
            while let first = rest.first, first.isLetter {
                letters.append(first)
                rest.removeFirst()
            }
            word = letters.isEmpty ? nil : letters.lowercased()
            remainder = rest.lowercased()
            let token = after.drop { $0.isWhitespace }.prefix { !$0.isWhitespace }
            if token.first?.isNumber == true { number = Number(token: String(token)) }
        }
    }
}
