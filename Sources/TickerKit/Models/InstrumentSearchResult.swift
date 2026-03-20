import Foundation

public struct InstrumentSearchResult: Identifiable, Equatable, Sendable {
    public let symbol: String
    public let displayName: String
    public let label: String
    public let quoteType: String

    public var id: String { symbol }

    public init(
        symbol: String,
        displayName: String,
        label: String,
        quoteType: String
    ) {
        self.symbol = symbol
        self.displayName = displayName
        self.label = label
        self.quoteType = quoteType
    }
}
