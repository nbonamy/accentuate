import AppKit
import NaturalLanguage

public struct Language: Hashable, Identifiable {
    /// Short code, also the name of its frequency table.
    public let id: String
    let naturalLanguageCode: String
    let spellCheckerCode: String

    public var name: String { (Locale.current.localizedString(forLanguageCode: id) ?? id).localizedCapitalized }
    var naturalLanguage: NLLanguage { NLLanguage(rawValue: naturalLanguageCode) }

    private init(_ id: String, spellChecker: String? = nil) {
        self.id = id
        self.naturalLanguageCode = id
        self.spellCheckerCode = spellChecker ?? id
    }

    public static let french = Language("fr")
    public static let all: [Language] = [
        french, Language("es"), Language("pt", spellChecker: "pt_BR"), Language("it"), Language("de"),
    ]

    /// Languages the system can spell check on this Mac, by name.
    public static var available: [Language] {
        let installed = Set(NSSpellChecker.shared.availableLanguages)
        return all.filter { installed.contains($0.spellCheckerCode) }.sorted { $0.name < $1.name }
    }

    public static func withID(_ id: String) -> Language? { all.first { $0.id == id } }
}

public enum LanguageSelection: Equatable {
    /// Work out the language from what is being typed.
    case auto
    /// Always this language, no detection.
    case fixed(Language)
}
