import Foundation

public struct InstrumentSearchResult: Identifiable, Equatable, Sendable {
    public let symbol: String
    public let displayName: String
    public let label: String
    public let quoteType: String
    public let currentPrice: Double?

    public var id: String { symbol }

    public init(
        symbol: String,
        displayName: String,
        label: String,
        quoteType: String,
        currentPrice: Double? = nil
    ) {
        self.symbol = symbol
        self.displayName = displayName
        self.label = label
        self.quoteType = quoteType
        self.currentPrice = currentPrice
    }
}
