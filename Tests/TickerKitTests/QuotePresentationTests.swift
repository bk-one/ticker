import Foundation
import Testing
@testable import TickerKit

struct QuotePresentationTests {
    @Test
    func formatsPricesByMagnitude() {
        let locale = Locale(identifier: "en_US")

        #expect(QuotePresentation.formattedPrice(for: 724_000, locale: locale) == "724,000")
        #expect(QuotePresentation.formattedPrice(for: 3_842, locale: locale) == "3,842")
        #expect(QuotePresentation.formattedPrice(for: 248.02, locale: locale) == "248.02")
        #expect(QuotePresentation.formattedPrice(for: 42.75, locale: locale) == "42.75")
        #expect(QuotePresentation.formattedPrice(for: 4.382, locale: locale) == "4.382")
        #expect(QuotePresentation.formattedPrice(for: 0.0531, locale: locale) == "0.0531")
    }

    @Test
    func derivesToneFromLastClose() {
        let quote = MarketQuote(
            symbol: "AAPL",
            displayName: "Apple Inc.",
            currentPrice: 103,
            previousClose: 98,
            currencyCode: "USD",
            exchangeName: "NasdaqGS",
            instrumentType: "EQUITY",
            asOf: Date(timeIntervalSince1970: 1_774_031_733),
            intradayCloses: [100, 101, 102, 103],
            priceHint: 2
        )

        #expect(quote.tone?.basis == .lastClose)
        #expect(quote.tone?.direction == .up)
        #expect(quote.tone?.percentChange == 5.1020408163265305)
    }

    @Test
    func derivesDownwardToneFromLastClose() {
        let quote = MarketQuote(
            symbol: "BTC-USD",
            displayName: "Bitcoin USD",
            currentPrice: 95,
            previousClose: 100,
            currencyCode: "USD",
            exchangeName: "CCC",
            instrumentType: "CRYPTOCURRENCY",
            asOf: Date(timeIntervalSince1970: 1_774_031_733),
            intradayCloses: [95],
            priceHint: 2
        )

        #expect(quote.tone?.basis == .lastClose)
        #expect(quote.tone?.direction == .down)
        #expect(quote.tone?.percentChange == -5)
        #expect(quote.tone?.intensity == 1)
    }

    @Test
    func keepsNeutralColorInsideCorridor() {
        let quote = MarketQuote(
            symbol: "AAPL",
            displayName: "Apple Inc.",
            currentPrice: 100.4,
            previousClose: 100,
            currencyCode: "USD",
            exchangeName: "NasdaqGS",
            instrumentType: "EQUITY",
            asOf: Date(timeIntervalSince1970: 1_774_031_733),
            intradayCloses: [100.0],
            priceHint: 2
        )

        #expect(quote.tone?.basis == .lastClose)
        #expect(quote.tone?.direction == .neutral)
        #expect(quote.tone?.intensity == 0)
    }
}
