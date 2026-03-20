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
            refreshInterval: .seconds(60),
            defaults: makeDefaults(),
            trackedSymbolsKey: UUID().uuidString
        )

        await store.refresh()

        #expect(store.trackedSymbols == ["AAPL"])
        #expect(store.trackedQuotes == [quote])
        #expect(store.displaySymbol == "AAPL")
        #expect(store.refreshIntervalDescription == "60 seconds")
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

        let store = TickerStore(
            client: client,
            refreshInterval: .seconds(60),
            defaults: makeDefaults(),
            trackedSymbolsKey: UUID().uuidString
        )
        await store.refresh()

        await client.setResult(.failure(YahooFinanceError.api("temporary outage")))
        await store.refresh()

        #expect(store.quote == quote)
        #expect(store.errorMessage == "Refresh failed. Showing cached values. Yahoo Finance returned an API error: temporary outage")
    }

    @Test
    @MainActor
    func addInstrumentPersistsImmediatelyAndRefreshesTrackedSymbols() async {
        let defaults = makeDefaults()
        let trackedSymbolsKey = UUID().uuidString
        let client = RecordingYahooFinanceClient(
            result: .success(
                MarketBatch(
                    quotes: [
                        MarketQuote(
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
                        ),
                        MarketQuote(
                            symbol: "GC=F",
                            displayName: "Gold Apr 26",
                            currentPrice: 4564.5,
                            previousClose: 4555.2,
                            currencyCode: "USD",
                            exchangeName: "COMEX",
                            instrumentType: "FUTURE",
                            asOf: Date(timeIntervalSince1970: 1_774_031_733),
                            intradayCloses: [4550.0, 4560.1, 4564.5],
                            priceHint: 2
                        ),
                    ],
                    missingSymbols: []
                )
            )
        )

        let store = TickerStore(
            client: client,
            refreshInterval: .seconds(60),
            defaults: defaults,
            trackedSymbolsKey: trackedSymbolsKey
        )

        let added = await store.addInstrument(symbol: " gc=f ")

        #expect(added)
        #expect(store.trackedSymbols == ["AAPL", "GC=F"])
        #expect(defaults.stringArray(forKey: trackedSymbolsKey) == ["AAPL", "GC=F"])
        #expect(store.trackedQuotes.map(\.symbol) == ["AAPL", "GC=F"])
        #expect(await client.recordedSymbols() == ["AAPL", "GC=F"])
    }

    @Test
    @MainActor
    func initializesFromPersistedTrackedSymbolsWithoutReintroducingBootstrap() {
        let defaults = makeDefaults()
        let trackedSymbolsKey = UUID().uuidString
        defaults.set([" gc=f ", "btc-usd", "GC=F"], forKey: trackedSymbolsKey)

        let store = TickerStore(
            client: StubYahooFinanceClient(result: .success(MarketBatch(quotes: [], missingSymbols: []))),
            refreshInterval: .seconds(60),
            defaults: defaults,
            trackedSymbolsKey: trackedSymbolsKey
        )

        #expect(store.trackedSymbols == ["GC=F", "BTC-USD"])
        #expect(store.displaySymbol == "GC=F")
    }
}

private struct StubYahooFinanceClient: YahooFinanceClientProtocol {
    let result: Result<MarketBatch, Error>

    func fetchQuotes(for symbols: [String]) async throws -> MarketBatch {
        try result.get()
    }
}

private actor RecordingYahooFinanceClient: YahooFinanceClientProtocol {
    private let result: Result<MarketBatch, Error>
    private var lastRequestedSymbols: [String] = []

    init(result: Result<MarketBatch, Error>) {
        self.result = result
    }

    func fetchQuotes(for symbols: [String]) async throws -> MarketBatch {
        lastRequestedSymbols = symbols
        return try result.get()
    }

    func recordedSymbols() -> [String] {
        lastRequestedSymbols
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

private func makeDefaults() -> UserDefaults {
    let suiteName = "TickerStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
