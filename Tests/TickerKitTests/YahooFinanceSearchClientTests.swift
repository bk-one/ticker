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
}
