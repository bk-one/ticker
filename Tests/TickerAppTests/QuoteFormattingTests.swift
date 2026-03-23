import Foundation
import Testing
@testable import Ticker
@testable import TickerKit

struct QuoteFormattingTests {
    @Test
    func closedQuotesUseClosedVisualState() {
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

        let style = QuoteFormatting.visualStyle(for: quote)

        #expect(style.state == .marketClosed)
        #expect(style.priceBackgroundColor == nil)
        #expect(style.accessibilityStateLabel == "Market closed")
    }

    @Test
    func closedAlertStylePromotesPriceIntoPillState() {
        let quote = MarketQuote(
            symbol: "GC=F",
            displayName: "Gold Apr 26",
            currentPrice: 4564.5,
            previousClose: 4555.2,
            currencyCode: "USD",
            exchangeName: "COMEX",
            instrumentType: "FUTURE",
            asOf: Date(timeIntervalSince1970: 1_774_031_733),
            intradayCloses: [4548.0, 4556.7, 4564.5],
            priceHint: 2,
            session: MarketSessionInfo(
                state: .closed,
                exchangeTimeZoneIdentifier: "America/Chicago",
                source: .providerMetadata
            )
        )

        let style = QuoteFormatting.visualStyle(for: quote, alertTriggered: true)

        #expect(style.state == .marketClosedAlert)
        #expect(style.priceBackgroundColor != nil)
        #expect(style.accessibilityStateLabel == "Market closed")
    }

    @Test
    func unknownSessionFallsBackToLiveRendering() {
        let quote = MarketQuote(
            symbol: "MSFT",
            displayName: "Microsoft Corporation",
            currentPrice: 412.34,
            previousClose: 410.10,
            currencyCode: "USD",
            exchangeName: "NasdaqGS",
            instrumentType: "EQUITY",
            asOf: Date(timeIntervalSince1970: 1_774_031_733),
            intradayCloses: [409.5, 410.8, 412.34],
            priceHint: 2
        )

        let style = QuoteFormatting.visualStyle(for: quote)

        #expect(style.state == .live)
        #expect(style.accessibilityStateLabel == nil)
    }
}
