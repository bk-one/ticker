import Foundation
import Testing
@testable import TickerKit

struct YahooFinanceSearchClientTests {
    @Test
    func decodesSearchResultsAcrossAssetClassesAndDeduplicatesSymbols() throws {
        let payload = """
        {
          "quotes": [
            {
              "exchange": "NGM",
              "shortname": "Apple Inc.",
              "quoteType": "EQUITY",
              "symbol": "AAPL",
              "typeDisp": "equity",
              "longname": "Apple Inc.",
              "exchDisp": "NASDAQ",
              "isYahooFinance": true
            },
            {
              "exchange": "CMX",
              "shortname": "Gold Apr 26",
              "quoteType": "FUTURE",
              "symbol": "GC=F",
              "typeDisp": "future",
              "exchDisp": "New York Commodity Exchange",
              "isYahooFinance": true
            },
            {
              "exchange": "CCC",
              "shortname": "Bitcoin USD",
              "quoteType": "CRYPTOCURRENCY",
              "symbol": "BTC-USD",
              "typeDisp": "cryptocurrency",
              "longname": "Bitcoin USD",
              "exchDisp": "CCC",
              "isYahooFinance": true
            },
            {
              "exchange": "NGM",
              "shortname": "Apple Inc.",
              "quoteType": "EQUITY",
              "symbol": "AAPL",
              "typeDisp": "equity",
              "longname": "Apple Inc.",
              "exchDisp": "NASDAQ",
              "isYahooFinance": true
            }
          ]
        }
        """

        let client = YahooFinanceSearchClient()
        let results = try client.decodeResults(from: Data(payload.utf8))

        #expect(results.map(\.symbol) == ["AAPL", "GC=F", "BTC-USD"])
        #expect(results.map(\.label) == ["NASDAQ", "Commodity", "Crypto"])
        #expect(results.allSatisfy { $0.currentPrice == nil })
    }

    @Test
    func fallsBackToTypeOrExchangeWhenSearchLabelsAreSparse() throws {
        let payload = """
        {
          "quotes": [
            {
              "exchange": "NYQ",
              "shortname": "Gold.com, Inc.",
              "quoteType": "EQUITY",
              "symbol": "GOLD",
              "typeDisp": "equity",
              "isYahooFinance": true
            },
            {
              "exchange": "CME",
              "shortname": "Bitcoin Futures,Mar-2026",
              "quoteType": "FUTURE",
              "symbol": "BTC=F",
              "typeDisp": "future",
              "exchDisp": "Chicago Mercantile Exchange",
              "isYahooFinance": true
            }
          ]
        }
        """

        let client = YahooFinanceSearchClient()
        let results = try client.decodeResults(from: Data(payload.utf8))

        #expect(results.map(\.label) == ["NYQ", "Chicago Mercantile Exchange"])
    }

    @Test
    func appliesPreviewPricesToDecodedResults() {
        let client = YahooFinanceSearchClient()
        let results = [
            InstrumentSearchResult(
                symbol: "AAPL",
                displayName: "Apple Inc.",
                label: "NASDAQ",
                quoteType: "EQUITY"
            ),
            InstrumentSearchResult(
                symbol: "GC=F",
                displayName: "Gold Apr 26",
                label: "Commodity",
                quoteType: "FUTURE"
            ),
        ]
        let batch = MarketBatch(
            quotes: [
                MarketQuote(
                    symbol: "GC=F",
                    displayName: "Gold Apr 26",
                    currentPrice: 4564.5,
                    previousClose: 4555.2,
                    currencyCode: "USD",
                    exchangeName: "COMEX",
                    instrumentType: "FUTURE",
                    asOf: Date(timeIntervalSince1970: 1_774_031_733),
                    intradayCloses: [4550, 4564.5],
                    priceHint: 2
                ),
                MarketQuote(
                    symbol: "AAPL",
                    displayName: "Apple Inc.",
                    currentPrice: 248.02,
                    previousClose: 247.10,
                    currencyCode: "USD",
                    exchangeName: "NasdaqGS",
                    instrumentType: "EQUITY",
                    asOf: Date(timeIntervalSince1970: 1_774_031_733),
                    intradayCloses: [247.5, 248.02],
                    priceHint: 2
                ),
            ],
            missingSymbols: []
        )

        let enrichedResults = client.applyingPrices(from: batch, to: results)

        #expect(enrichedResults.map(\.currentPrice) == [248.02, 4564.5])
    }
}
