import Foundation

public protocol YahooFinanceClientProtocol: Sendable {
    func fetchQuotes(for symbols: [String]) async throws -> MarketBatch
}

public enum YahooFinanceError: LocalizedError, Equatable {
    case invalidRequest
    case invalidResponse
    case httpStatus(Int, String?)
    case api(String)
    case noData([String])

    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Failed to build the Yahoo Finance request."
        case .invalidResponse:
            return "Yahoo Finance returned an unreadable response."
        case let .httpStatus(statusCode, message):
            if let message,
               !message.isEmpty {
                return "Yahoo Finance request failed with HTTP \(statusCode): \(message)"
            }

            return "Yahoo Finance request failed with HTTP \(statusCode)."
        case let .api(message):
            return "Yahoo Finance returned an API error: \(message)"
        case let .noData(symbols):
            return "Yahoo Finance returned no data for \(symbols.joined(separator: ", "))."
        }
    }
}

public struct YahooFinanceClient: YahooFinanceClientProtocol, Sendable {
    private let session: URLSession
    private let marketSessionResolver: YahooMarketSessionResolver

    public init(session: URLSession = .shared) {
        self.session = session
        self.marketSessionResolver = YahooMarketSessionResolver()
    }

    public func fetchQuotes(for symbols: [String]) async throws -> MarketBatch {
        let normalizedSymbols = Self.normalizedSymbols(from: symbols)
        guard !normalizedSymbols.isEmpty else {
            return MarketBatch(quotes: [], missingSymbols: [])
        }

        guard var components = URLComponents(string: "https://query1.finance.yahoo.com/v7/finance/spark") else {
            throw YahooFinanceError.invalidRequest
        }

        components.queryItems = [
            URLQueryItem(name: "symbols", value: normalizedSymbols.joined(separator: ",")),
            URLQueryItem(name: "range", value: "1d"),
            URLQueryItem(name: "interval", value: "1m"),
            URLQueryItem(name: "indicators", value: "close"),
            URLQueryItem(name: "includeTimestamps", value: "false"),
            URLQueryItem(name: "includePrePost", value: "true"),
        ]

        guard let url = components.url else {
            throw YahooFinanceError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw YahooFinanceError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw YahooFinanceError.httpStatus(
                httpResponse.statusCode,
                Self.extractErrorMessage(from: data)
            )
        }

        let batch = try decodeMarketBatch(from: data, requestedSymbols: normalizedSymbols)

        if batch.quotes.isEmpty {
            throw YahooFinanceError.noData(
                batch.missingSymbols.isEmpty ? normalizedSymbols : batch.missingSymbols
            )
        }

        return batch
    }

    static func normalizedSymbols(from rawSymbols: [String]) -> [String] {
        var seen = Set<String>()

        return rawSymbols.compactMap { rawSymbol in
            let symbol = rawSymbol
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()

            guard !symbol.isEmpty,
                  seen.insert(symbol).inserted else {
                return nil
            }

            return symbol
        }
    }

    func decodeMarketBatch(from data: Data, requestedSymbols: [String]) throws -> MarketBatch {
        let decoder = JSONDecoder()
        let envelope = try decoder.decode(YahooSparkEnvelope.self, from: data)

        if let errorMessage = envelope.spark.error?.formattedMessage {
            throw YahooFinanceError.api(errorMessage)
        }

        let resultsBySymbol = Dictionary(
            uniqueKeysWithValues: envelope.spark.result.map { result in
                (result.symbol.uppercased(), result)
            }
        )

        var quotes: [MarketQuote] = []
        var missingSymbols: [String] = []

        for symbol in requestedSymbols {
            guard let payload = resultsBySymbol[symbol]?.response.first,
                  let quote = marketQuote(from: payload, symbol: symbol) else {
                missingSymbols.append(symbol)
                continue
            }

            quotes.append(quote)
        }

        return MarketBatch(quotes: quotes, missingSymbols: missingSymbols)
    }

    private func marketQuote(from payload: YahooSparkQuotePayload, symbol: String) -> MarketQuote? {
        let intradayCloses = payload.indicators.quote.first?.close.compactMap { $0 } ?? []
        let currentPrice = payload.meta.regularMarketPrice ?? intradayCloses.last

        guard let currentPrice else {
            return nil
        }

        let instrumentType = payload.meta.instrumentType ?? "UNKNOWN"
        let marketSession = marketSessionResolver.resolve(
            instrumentType: instrumentType,
            meta: payload.meta
        )

        return MarketQuote(
            symbol: symbol,
            displayName: payload.meta.shortName ?? payload.meta.longName ?? symbol,
            currentPrice: currentPrice,
            previousClose: payload.meta.previousClose ?? payload.meta.chartPreviousClose,
            currencyCode: payload.meta.currency,
            exchangeName: payload.meta.fullExchangeName ?? payload.meta.exchangeName ?? "Yahoo Finance",
            instrumentType: instrumentType,
            asOf: payload.meta.regularMarketTime.map(Date.init(timeIntervalSince1970:)) ?? Date(),
            intradayCloses: intradayCloses,
            priceHint: payload.meta.priceHint,
            session: marketSession
        )
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        let decoder = JSONDecoder()

        if let envelope = try? decoder.decode(YahooErrorEnvelope.self, from: data) {
            return envelope.finance?.error?.formattedMessage
                ?? envelope.spark?.error?.formattedMessage
                ?? envelope.chart?.error?.formattedMessage
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
