import Foundation

public enum QuoteColorBasis: String, Equatable, Sendable {
    case lastClose
}

public enum QuoteTrendDirection: Equatable, Sendable {
    case up
    case down
    case neutral
}

public struct QuoteTone: Equatable, Sendable {
    public let direction: QuoteTrendDirection
    public let intensity: Double
    public let percentChange: Double
    public let basis: QuoteColorBasis

    public init(percentChange: Double, basis: QuoteColorBasis) {
        let absolutePercentChange = abs(percentChange)

        if absolutePercentChange <= 0.5 {
            self.direction = .neutral
            self.intensity = 0
        } else {
            self.direction = percentChange >= 0 ? .up : .down
            self.intensity = min(max((min(absolutePercentChange, 5) - 0.5) / 4.5, 0), 1)
        }

        self.percentChange = percentChange
        self.basis = basis
    }
}

public enum MarketSessionState: String, Equatable, Sendable {
    case open
    case closed
    case unknown
}

public enum MarketSessionSource: String, Equatable, Sendable {
    case providerMetadata
    case continuousTradingRule
    case unavailable
}

public struct MarketSessionInfo: Equatable, Sendable {
    public let state: MarketSessionState
    public let exchangeTimeZoneIdentifier: String?
    public let source: MarketSessionSource

    public static let unknown = MarketSessionInfo(
        state: .unknown,
        exchangeTimeZoneIdentifier: nil,
        source: .unavailable
    )

    public var isOpen: Bool { state == .open }
    public var isClosed: Bool { state == .closed }

    public init(
        state: MarketSessionState,
        exchangeTimeZoneIdentifier: String?,
        source: MarketSessionSource
    ) {
        self.state = state
        self.exchangeTimeZoneIdentifier = exchangeTimeZoneIdentifier
        self.source = source
    }
}

public struct MarketQuote: Identifiable, Equatable, Sendable {
    public let symbol: String
    public let displayName: String
    public let currentPrice: Double
    public let previousClose: Double?
    public let currencyCode: String?
    public let exchangeName: String
    public let instrumentType: String
    public let session: MarketSessionInfo
    public let asOf: Date
    public let intradayCloses: [Double]
    public let priceHint: Int?

    public var id: String { symbol }
    public var isMarketOpen: Bool { session.isOpen }
    public var isMarketClosed: Bool { session.isClosed }

    public var absoluteChange: Double? {
        guard let previousClose else {
            return nil
        }

        return currentPrice - previousClose
    }

    public var percentChange: Double? {
        percentageChange(from: previousClose)
    }

    public var tone: QuoteTone? {
        if let percentChange {
            return QuoteTone(percentChange: percentChange, basis: .lastClose)
        }

        return nil
    }

    public init(
        symbol: String,
        displayName: String,
        currentPrice: Double,
        previousClose: Double?,
        currencyCode: String?,
        exchangeName: String,
        instrumentType: String,
        asOf: Date,
        intradayCloses: [Double],
        priceHint: Int?,
        session: MarketSessionInfo = .unknown
    ) {
        self.symbol = symbol
        self.displayName = displayName
        self.currentPrice = currentPrice
        self.previousClose = previousClose
        self.currencyCode = currencyCode
        self.exchangeName = exchangeName
        self.instrumentType = instrumentType
        self.session = session
        self.asOf = asOf
        self.intradayCloses = intradayCloses
        self.priceHint = priceHint
    }

    private func percentageChange(from referencePrice: Double?) -> Double? {
        guard let referencePrice,
              referencePrice != 0 else {
            return nil
        }

        return ((currentPrice - referencePrice) / referencePrice) * 100
    }
}

public struct MarketBatch: Equatable, Sendable {
    public let quotes: [MarketQuote]
    public let missingSymbols: [String]

    public init(quotes: [MarketQuote], missingSymbols: [String]) {
        self.quotes = quotes
        self.missingSymbols = missingSymbols
    }
}
