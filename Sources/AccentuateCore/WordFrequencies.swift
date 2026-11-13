import Foundation

/// French word frequencies, grouped by accent-stripped key.
///
/// TSV format: `key<TAB>candidate:freq<TAB>candidate:freq...`. The plain (unaccented)
/// word appears as a candidate when it is a valid word too.
public struct WordFrequencies {
    private var groups: [String: [String: Double]] = [:]

    public init(tsv: String) {
        for line in tsv.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: "\t").map(String.init)
            guard fields.count >= 2 else { continue }
            var group: [String: Double] = [:]
            for field in fields.dropFirst() {
                guard let colon = field.lastIndex(of: ":"),
                      let frequency = Double(field[field.index(after: colon)...]) else { continue }
                group[String(field[..<colon]).lowercased()] = frequency
            }
            groups[fields[0]] = group
        }
    }

    public static func bundled() throws -> WordFrequencies {
        guard let url = Bundle.module.url(forResource: "accents", withExtension: "tsv") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return WordFrequencies(tsv: try String(contentsOf: url, encoding: .utf8))
    }

    /// All known spellings sharing `key` (the accent-stripped form), with their frequency.
    public func spellings(forKey key: String) -> [String: Double] {
        groups[key.lowercased()] ?? [:]
    }
}
