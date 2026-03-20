import Foundation

struct YahooSparkEnvelope: Decodable {
    let spark: YahooSparkContainer
}

struct YahooSparkContainer: Decodable {
    let result: [YahooSparkResult]
    let error: YahooAPIError?
}

struct YahooSparkResult: Decodable {
    let symbol: String
    let response: [YahooSparkQuotePayload]
}

struct YahooSparkQuotePayload: Decodable {
    let meta: YahooSparkMeta
    let indicators: YahooSparkIndicators
}

struct YahooSparkIndicators: Decodable {
    let quote: [YahooSparkQuoteSeries]
}

struct YahooSparkQuoteSeries: Decodable {
    let close: [Double?]
}

struct YahooSparkMeta: Decodable {
    let symbol: String?
    let shortName: String?
    let longName: String?
    let currency: String?
    let regularMarketPrice: Double?
    let previousClose: Double?
    let chartPreviousClose: Double?
    let regularMarketTime: TimeInterval?
    let fullExchangeName: String?
    let exchangeName: String?
    let instrumentType: String?
    let priceHint: Int?
    let dataGranularity: String?
}

struct YahooErrorEnvelope: Decodable {
    let finance: YahooErrorContainer?
    let spark: YahooErrorContainer?
    let chart: YahooErrorContainer?
}

struct YahooErrorContainer: Decodable {
    let error: YahooAPIError?
}

struct YahooAPIError: Decodable {
    let code: String?
    let description: String?

    var formattedMessage: String? {
        let parts = [code, description]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else {
            return nil
        }

        return parts.joined(separator: ": ")
    }
}
