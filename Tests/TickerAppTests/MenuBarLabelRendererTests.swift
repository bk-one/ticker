import Foundation
import Testing
@testable import Ticker
@testable import TickerKit

struct MenuBarLabelRendererTests {
    @Test
    @MainActor
    func knownTickersRenderAsAttachmentsInsteadOfTextSymbols() async {
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
            priceHint: 2,
            session: MarketSessionInfo(
                state: .closed,
                exchangeTimeZoneIdentifier: "America/New_York",
                source: .providerMetadata
            )
        )

        let store = makeStore(symbols: ["AAPL"], quotes: [quote])
        await store.refresh()

        let attributedTitle = MenuBarLabelRenderer.attributedTitle(for: store)

        #expect(attachmentCount(in: attributedTitle) == 1)
        #expect(!attributedTitle.string.contains("AAPL"))
    }

    @Test
    @MainActor
    func unknownTickersFallBackToTextSymbols() async {
        let quote = MarketQuote(
            symbol: "IAU",
            displayName: "iShares Gold Trust",
            currentPrice: 56.84,
            previousClose: 56.22,
            currencyCode: "USD",
            exchangeName: "NYSEArca",
            instrumentType: "ETF",
            asOf: Date(timeIntervalSince1970: 1_774_031_733),
            intradayCloses: [56.0, 56.3, 56.84],
            priceHint: 2
        )

        let store = makeStore(symbols: ["IAU"], quotes: [quote])
        await store.refresh()

        let attributedTitle = MenuBarLabelRenderer.attributedTitle(for: store)

        #expect(attachmentCount(in: attributedTitle) == 0)
        #expect(attributedTitle.string.contains("IAU"))
    }

    @Test
    @MainActor
    func accessibilityLabelKeepsSymbolNamePriceAndState() async {
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
            priceHint: 2,
            session: MarketSessionInfo(
                state: .closed,
                exchangeTimeZoneIdentifier: "America/New_York",
                source: .providerMetadata
            )
        )

        let store = makeStore(symbols: ["AAPL"], quotes: [quote])
        await store.refresh()

        #expect(
            MenuBarLabelRenderer.accessibilityLabel(for: store)
                == "AAPL, Apple Inc., \(QuoteFormatting.price(quote)), market closed"
        )
    }
}

@MainActor
private func makeStore(symbols: [String], quotes: [MarketQuote]) -> TickerStore {
    let defaults = makeDefaults()
    let trackedSymbolsKey = UUID().uuidString
    defaults.set(symbols, forKey: trackedSymbolsKey)

    return TickerStore(
        client: StaticQuoteClient(
            result: .success(
                MarketBatch(
                    quotes: quotes,
                    missingSymbols: []
                )
            )
        ),
        refreshInterval: .seconds(60),
        defaults: defaults,
        trackedSymbolsKey: trackedSymbolsKey,
        displaySymbolKey: UUID().uuidString
    )
}

private func attachmentCount(in attributedString: NSAttributedString) -> Int {
    var count = 0
    let range = NSRange(location: 0, length: attributedString.length)

    attributedString.enumerateAttribute(.attachment, in: range) { value, _, _ in
        if value != nil {
            count += 1
        }
    }

    return count
}

private func makeDefaults() -> UserDefaults {
    let suiteName = "TickerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

private struct StaticQuoteClient: YahooFinanceClientProtocol {
    let result: Result<MarketBatch, Error>

    func fetchQuotes(for symbols: [String]) async throws -> MarketBatch {
        try result.get()
    }
}
