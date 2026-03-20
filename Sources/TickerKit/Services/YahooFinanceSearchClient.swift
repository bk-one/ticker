import Foundation

public protocol YahooFinanceSearchClientProtocol: Sendable {
    func search(query: String, limit: Int) async throws -> [InstrumentSearchResult]
}

public enum YahooFinanceSearchError: LocalizedError, Equatable {
    case invalidRequest
    case invalidResponse
    case httpStatus(Int, String?)

    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Failed to build the Yahoo Finance search request."
        case .invalidResponse:
            return "Yahoo Finance returned unreadable search results."
        case let .httpStatus(statusCode, message):
            if let message,
               !message.isEmpty {
                return "Yahoo Finance search failed with HTTP \(statusCode): \(message)"
            }

            return "Yahoo Finance search failed with HTTP \(statusCode)."
        }
    }
}

public struct YahooFinanceSearchClient: YahooFinanceSearchClientProtocol, Sendable {
    private let session: URLSession
    private let quoteClient: any YahooFinanceClientProtocol

    public init(
        session: URLSession = .shared,
        quoteClient: any YahooFinanceClientProtocol = YahooFinanceClient()
    ) {
        self.session = session
        self.quoteClient = quoteClient
    }

    public func search(query: String, limit: Int = 8) async throws -> [InstrumentSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }

        guard var components = URLComponents(string: "https://query1.finance.yahoo.com/v1/finance/search") else {
            throw YahooFinanceSearchError.invalidRequest
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: trimmedQuery),
            URLQueryItem(name: "quotesCount", value: String(max(limit, 1))),
            URLQueryItem(name: "newsCount", value: "0"),
            URLQueryItem(name: "listsCount", value: "0"),
            URLQueryItem(name: "enableFuzzyQuery", value: "false"),
        ]

        guard let url = components.url else {
            throw YahooFinanceSearchError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw YahooFinanceSearchError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw YahooFinanceSearchError.httpStatus(
                httpResponse.statusCode,
                String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        let decodedResults = try decodeResults(from: data)

        guard !decodedResults.isEmpty else {
            return []
        }

        do {
            let marketBatch = try await quoteClient.fetchQuotes(for: decodedResults.map(\.symbol))
            return applyingPrices(from: marketBatch, to: decodedResults)
        } catch {
            return decodedResults
        }
    }

    func decodeResults(from data: Data) throws -> [InstrumentSearchResult] {
        let decoder = JSONDecoder()
        let envelope = try decoder.decode(YahooSearchEnvelope.self, from: data)

        var seenSymbols = Set<String>()
        var results: [InstrumentSearchResult] = []

        for quote in envelope.quotes {
            guard quote.isYahooFinance != false,
                  let rawSymbol = quote.symbol else {
                continue
            }

            let symbol = rawSymbol
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()

            guard !symbol.isEmpty,
                  seenSymbols.insert(symbol).inserted else {
                continue
            }

            let displayName = quote.shortName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackName = quote.longName?.trimmingCharacters(in: .whitespacesAndNewlines)

            results.append(
                InstrumentSearchResult(
                    symbol: symbol,
                    displayName: displayName?.isEmpty == false ? displayName! : (fallbackName?.isEmpty == false ? fallbackName! : symbol),
                    label: Self.label(for: quote, symbol: symbol),
                    quoteType: quote.quoteType?.uppercased() ?? "UNKNOWN"
                )
            )
        }

        return results
    }

    func applyingPrices(
        from batch: MarketBatch,
        to results: [InstrumentSearchResult]
    ) -> [InstrumentSearchResult] {
        let quotesBySymbol = Dictionary(
            uniqueKeysWithValues: batch.quotes.map { quote in
                (quote.symbol, quote)
            }
        )

        return results.map { result in
            InstrumentSearchResult(
                symbol: result.symbol,
                displayName: result.displayName,
                label: result.label,
                quoteType: result.quoteType,
                currentPrice: quotesBySymbol[result.symbol]?.currentPrice
            )
        }
    }

    private static func label(for quote: YahooSearchQuotePayload, symbol: String) -> String {
        let uppercasedType = quote.quoteType?.uppercased()
        let normalizedShortName = quote.shortName?.lowercased() ?? ""
        let normalizedLongName = quote.longName?.lowercased() ?? ""

        switch uppercasedType {
        case "CRYPTOCURRENCY":
            return "Crypto"
        case "FUTURE":
            if symbol.hasSuffix("=F"),
               !normalizedShortName.contains("bitcoin"),
               !normalizedShortName.contains("ethereum"),
               !normalizedLongName.contains("bitcoin"),
               !normalizedLongName.contains("ethereum") {
                return "Commodity"
            }
        default:
            break
        }

        if let exchangeDisplayName = quote.exchangeDisplayName,
           !exchangeDisplayName.isEmpty {
            return exchangeDisplayName
        }

        if let exchangeCode = quote.exchangeCode,
           !exchangeCode.isEmpty {
            return exchangeCode
        }

        if let typeDisplayName = quote.typeDisplayName,
           !typeDisplayName.isEmpty {
            return typeDisplayName.capitalized
        }

        return "Yahoo Finance"
    }
}
