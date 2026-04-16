import Foundation

public enum InstrumentIconCatalog {
    public static func icon(for symbol: String) -> InstrumentIcon? {
        storage[normalized(symbol)]
    }

    public static func assetURL(named name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "svg")
            ?? Bundle.module.url(forResource: name, withExtension: "png")
    }

    private static let storage: [String: InstrumentIcon] = loadStorage()

    private static func loadStorage() -> [String: InstrumentIcon] {
        guard let url = Bundle.module.url(forResource: "icon-map", withExtension: "json") else {
            assertionFailure("Missing instrument icon map resource.")
            return [:]
        }

        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([IconEntry].self, from: data)
            return entries.reduce(into: [:]) { result, entry in
                let icon = entry.icon.instrumentIcon

                for symbol in entry.symbols {
                    result[normalized(symbol)] = icon
                }
            }
        } catch {
            assertionFailure("Failed to load instrument icon map: \(error)")
            return [:]
        }
    }

    private static func normalized(_ symbol: String) -> String {
        symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
}

private struct IconEntry: Decodable {
    let symbols: [String]
    let icon: DecodedIcon
}

private struct DecodedIcon: Decodable {
    let type: String
    let value: String

    var instrumentIcon: InstrumentIcon {
        switch type {
        case "asset":
            return InstrumentIcon(kind: .asset(value))
        case "sfSymbol":
            return InstrumentIcon(kind: .sfSymbol(value))
        case "glyph":
            return InstrumentIcon(kind: .glyph(value))
        default:
            return InstrumentIcon(kind: .glyph(value))
        }
    }
}
