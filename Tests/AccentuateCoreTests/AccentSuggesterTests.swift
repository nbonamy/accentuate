import Testing
@testable import AccentuateCore

private final class FakeSpellChecker: SpellChecking {
    var misspelled: Set<String> = []
    var guessTable: [String: [String]] = [:]
    var guessCalls = 0
    var lastAfter = ""

    func isMisspelled(_ word: String) -> Bool { misspelled.contains(word.lowercased()) }
    func guesses(for word: String, before: String, after: String) -> [String] {
        guessCalls += 1
        lastAfter = after
        return guessTable[word.lowercased()] ?? []
    }
}

private let frequencies = WordFrequencies(tsv: """
mange\tmange:24014\tmangé:17787
pomme\tpomme:30000\tpommé:50
foret\tforêt:9450\tforet:426
cote\tcôté:80162\tcôte:8720\tcote:1744
""")

private func makeSuggester(_ configure: (FakeSpellChecker) -> Void) -> (AccentSuggester, FakeSpellChecker) {
    let checker = FakeSpellChecker()
    configure(checker)
    return (AccentSuggester(spellChecker: checker, frequencies: frequencies), checker)
}

struct AccentSuggesterTests {
    @Test func usesTopAccentedGuessForMisspelledWords() {
        let (suggester, _) = makeSuggester {
            $0.misspelled = ["decide"]
            $0.guessTable["decide"] = ["décidé", "décide"]
        }
        #expect(suggester.replacement(for: "decide", in: "nous avons decide") == "décidé")
    }

    @Test func ignoresGuessesThatAreNotJustAccents() {
        let (suggester, _) = makeSuggester {
            $0.misspelled = ["ecole"]
            $0.guessTable["ecole"] = ["Cole", "école"]
        }
        #expect(suggester.replacement(for: "ecole", in: "ecole") == "école")

        let (other, _) = makeSuggester {
            $0.misspelled = ["helo"]
            $0.guessTable["helo"] = ["hello", "hélo"]
        }
        #expect(other.replacement(for: "helo", in: "helo") == "hélo")
    }

    @Test func ignoresGuessesWithoutAccentDifference() {
        let (suggester, _) = makeSuggester {
            $0.misspelled = ["ecolle"]
            $0.guessTable["ecolle"] = ["ecolle", "école"]
        }
        #expect(suggester.replacement(for: "ecolle", in: "ecolle") == nil)
    }

    @Test func handlesLigatures() {
        let (suggester, _) = makeSuggester {
            $0.misspelled = ["coeur"]
            $0.guessTable["coeur"] = ["cœur"]
        }
        #expect(suggester.replacement(for: "coeur", in: "mon coeur") == "cœur")
    }

    @Test func preservesCapitalization() {
        let (suggester, _) = makeSuggester {
            $0.misspelled = ["ecole", "decembre"]
            $0.guessTable["ecole"] = ["école"]
            $0.guessTable["decembre"] = ["décembre"]
        }
        #expect(suggester.replacement(for: "Ecole", in: "Ecole") == "École")
        #expect(suggester.replacement(for: "ECOLE", in: "ECOLE") == "ÉCOLE")
        #expect(suggester.replacement(for: "DECEMBRE", in: "fin DECEMBRE") == "DÉCEMBRE")
    }

    @Test func skipsWordsThatAlreadyHaveAccents() {
        let (suggester, checker) = makeSuggester { $0.misspelled = ["école"] }
        #expect(suggester.replacement(for: "école", in: "école") == nil)
        #expect(checker.guessCalls == 0)
    }

    @Test func skipsNamesInTheMiddleOfASentence() {
        let (suggester, _) = makeSuggester {
            $0.misspelled = ["rene"]
            $0.guessTable["rene"] = ["René"]
        }
        #expect(suggester.replacement(for: "Rene", in: "je vois Rene") == nil)
        #expect(suggester.replacement(for: "Rene", in: "Rene") == "René")
    }

    @Test func skipsSingleLettersDigitsAndUnknownWords() {
        let (suggester, checker) = makeSuggester { $0.misspelled = ["x", "abc12", "zzz"] }
        #expect(suggester.replacement(for: "x", in: "x") == nil)
        #expect(suggester.replacement(for: "abc12", in: "abc12") == nil)
        #expect(suggester.replacement(for: "zzz", in: "zzz") == nil)
        #expect(checker.guessCalls == 1)
    }

    // Valid words: the checker would "fix" almost anything, so we want evidence.

    @Test func leavesValidWordsAloneWithoutEvidence() {
        let (suggester, _) = makeSuggester {
            $0.guessTable["mange"] = ["mangé"]
            $0.guessTable["pomme"] = ["pommé"]
        }
        #expect(suggester.replacement(for: "mange", in: "je mange") == nil)
        #expect(suggester.replacement(for: "pomme", in: "une pomme") == nil)
        #expect(suggester.replacement(for: "inconnu", in: "inconnu") == nil)
    }

    @Test func acceptsValidWordWhenAccentedFormDominates() {
        let (suggester, _) = makeSuggester { $0.guessTable["foret"] = ["forêt"] }
        #expect(suggester.replacement(for: "foret", in: "la foret") == "forêt")
    }

    @Test func acceptsValidWordWhenContextPointsToParticiple() {
        let (suggester, _) = makeSuggester { $0.guessTable["mange"] = ["mangé"] }
        #expect(suggester.replacement(for: "mange", in: "il a mange") == "mangé")
        #expect(suggester.replacement(for: "mange", in: "nous avons mange") == "mangé")
    }

    @Test func requiresCloseFrequenciesEvenWithContext() {
        let (suggester, _) = makeSuggester { $0.guessTable["pomme"] = ["pommé"] }
        #expect(suggester.replacement(for: "pomme", in: "il a pomme") == nil)
    }

    @Test func requiresAClearWinnerWhenNoContext() {
        let (suggester, _) = makeSuggester { $0.guessTable["cote"] = ["côté"] }
        #expect(suggester.replacement(for: "cote", in: "le cote") == nil)
    }

    // Ambiguous words go through the explicit rules, never through the checker.

    @Test func ambiguousWordsFollowRules() {
        let (suggester, checker) = makeSuggester { $0.guessTable["a"] = ["à"] }
        #expect(suggester.replacement(for: "a", in: "par rapport a") == "à")
        #expect(suggester.replacement(for: "a", in: "il a") == nil)
        #expect(suggester.replacement(for: "A", in: "A") == nil)
        #expect(checker.guessCalls == 0)
    }

    @Test func ambiguousRulesKeepCapitalization() {
        let (suggester, _) = makeSuggester { _ in }
        #expect(suggester.replacement(for: "Sur", in: "Bien Sur") == nil) // mid-sentence capital: a name or a title
        #expect(suggester.replacement(for: "SUR", in: "BIEN SUR") == "SÛR")
    }

    @Test func cachesRepeatedLookups() {
        let (suggester, checker) = makeSuggester {
            $0.misspelled = ["ecole"]
            $0.guessTable["ecole"] = ["école"]
        }
        _ = suggester.replacement(for: "ecole", in: "a l ecole")
        _ = suggester.replacement(for: "ecole", in: "a l ecole")
        #expect(checker.guessCalls == 1)
    }

    // The end-of-sentence pass also knows what follows the word.

    @Test func passesWhatFollowsToTheSpellChecker() {
        let (suggester, checker) = makeSuggester {
            $0.misspelled = ["decide"]
            $0.guessTable["decide"] = ["décidé"]
        }
        _ = suggester.replacement(for: "decide", before: "nous avons ", after: " de partir")
        #expect(checker.lastAfter == " de partir")
    }

    @Test func ambiguousWordsUseWhatFollows() {
        let (suggester, _) = makeSuggester { _ in }
        #expect(suggester.replacement(for: "a", before: "nous allons partir ", after: " l ecole") == "à")
        #expect(suggester.replacement(for: "a", before: "il ", after: " la grippe") == nil)
    }

    @Test func cacheDistinguishesWhatFollows() {
        let (suggester, checker) = makeSuggester {
            $0.misspelled = ["decide"]
            $0.guessTable["decide"] = ["décidé"]
        }
        _ = suggester.replacement(for: "decide", before: "il ", after: "")
        _ = suggester.replacement(for: "decide", before: "il ", after: " de partir")
        #expect(checker.guessCalls == 2)
    }
}
