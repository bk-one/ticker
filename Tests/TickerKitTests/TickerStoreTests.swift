import Foundation
import Testing
@testable import TickerKit

struct TickerStoreTests {
    @Test
    @MainActor
    func refreshPublishesBootstrapQuote() async {
        let quote = MarketQuote(
            symbol: "AAPL",
            displayName: "Apple Inc.",
            currentPrice: 248.02,
            previousClose: 247.10,
            currencyCode: "USD",
            exchangeName: "NasdaqGS",
            instrumentType: "EQUITY",
            asOf: Date(timeIntervalSince1970: 1_774_031_733),
            intradayCloses: [246.8, 247.2, 247.7, 248.02],
            priceHint: 2
        )

        let store = TickerStore(
            client: StubYahooFinanceClient(result: .success(MarketBatch(quotes: [quote], missingSymbols: []))),
            refreshInterval: .seconds(60)
        )

        await store.refresh()

        #expect(store.displaySymbol == "AAPL")
        #expect(store.quote == quote)
        #expect(store.lastUpdated == quote.asOf)
        #expect(store.errorMessage == nil)
    }

    @Test
    @MainActor
    func refreshKeepsCachedQuoteWhenLaterRefreshFails() async {
        let quote = MarketQuote(
            symbol: "AAPL",
            displayName: "Apple Inc.",
            currentPrice: 248.02,
            previousClose: 247.10,
            currencyCode: "USD",
            exchangeName: "NasdaqGS",
            instrumentType: "EQUITY",
            asOf: Date(timeIntervalSince1970: 1_774_031_733),
            intradayCloses: [246.8, 247.2, 247.7, 248.02],
            priceHint: 2
        )

        let client = MutableStubYahooFinanceClient(
            result: .success(MarketBatch(quotes: [quote], missingSymbols: []))
        )

        let store = TickerStore(client: client, refreshInterval: .seconds(60))
        await store.refresh()

        await client.setResult(.failure(YahooFinanceError.api("temporary outage")))
        await store.refresh()

        #expect(store.quote == quote)
        #expect(store.errorMessage == "Refresh failed. Showing cached values. Yahoo Finance returned an API error: temporary outage")
    }
}

private struct StubYahooFinanceClient: YahooFinanceClientProtocol {
    let result: Result<MarketBatch, Error>

    func fetchQuotes(for symbols: [String]) async throws -> MarketBatch {
        try result.get()
    }
}

private actor MutableStubYahooFinanceClient: YahooFinanceClientProtocol {
    private var result: Result<MarketBatch, Error>

    init(result: Result<MarketBatch, Error>) {
        self.result = result
    }

    func setResult(_ result: Result<MarketBatch, Error>) {
        self.result = result
    }

    func fetchQuotes(for symbols: [String]) async throws -> MarketBatch {
        try result.get()
    }
}
