import Foundation

public enum QuoteColorBasis: String, Equatable, Sendable {
    case fifteenMinutes
    case previousCloseFallback
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

public struct MarketQuote: Identifiable, Equatable, Sendable {
    public let symbol: String
    public let displayName: String
    public let currentPrice: Double
    public let previousClose: Double?
    public let currencyCode: String?
    public let exchangeName: String
    public let instrumentType: String
    public let asOf: Date
    public let intradayCloses: [Double]
    public let priceHint: Int?
    public let granularityMinutes: Int?

    public var id: String { symbol }

    public var absoluteChange: Double? {
        guard let previousClose else {
            return nil
        }

        return currentPrice - previousClose
    }

    public var percentChange: Double? {
        percentageChange(from: previousClose)
    }

    public var fifteenMinuteReferencePrice: Double? {
        guard let granularityMinutes,
              granularityMinutes > 0 else {
            return nil
        }

        let stepsBack = 15 / granularityMinutes

        guard stepsBack > 0,
              intradayCloses.count > stepsBack else {
            return nil
        }

        return intradayCloses[intradayCloses.count - 1 - stepsBack]
    }

    public var fifteenMinutePercentChange: Double? {
        percentageChange(from: fifteenMinuteReferencePrice)
    }

    public var tone: QuoteTone? {
        if let fifteenMinutePercentChange {
            return QuoteTone(percentChange: fifteenMinutePercentChange, basis: .fifteenMinutes)
        }

        if let percentChange {
            return QuoteTone(percentChange: percentChange, basis: .previousCloseFallback)
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
        granularityMinutes: Int? = nil
    ) {
        self.symbol = symbol
        self.displayName = displayName
        self.currentPrice = currentPrice
        self.previousClose = previousClose
        self.currencyCode = currencyCode
        self.exchangeName = exchangeName
        self.instrumentType = instrumentType
        self.asOf = asOf
        self.intradayCloses = intradayCloses
        self.priceHint = priceHint
        self.granularityMinutes = granularityMinutes
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
