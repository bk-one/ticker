import Foundation
import Testing
@testable import TickerKit

struct YahooFinanceClientTests {
    @Test
    func normalizesSymbolsAndKeepsFirstOccurrence() {
        let symbols = YahooFinanceClient.normalizedSymbols(
            from: [" aapl ", "GC=F", "AAPL", "", " msft "]
        )

        #expect(symbols == ["AAPL", "GC=F", "MSFT"])
    }

    @Test
    func decodesBatchInRequestedOrderAndMarksMissingSymbols() throws {
        let payload = """
        {
          "spark": {
            "result": [
              {
                "symbol": "AAPL",
                "response": [
                  {
                    "meta": {
                      "symbol": "AAPL",
                      "shortName": "Apple Inc.",
                      "currency": "USD",
                      "regularMarketPrice": 248.25,
                      "previousClose": 248.96,
                      "regularMarketTime": 1774031733,
                      "marketState": "REGULAR",
                      "exchangeTimezoneName": "America/New_York",
                      "fullExchangeName": "NasdaqGS",
                      "instrumentType": "EQUITY",
                      "priceHint": 2
                    },
                    "indicators": {
                      "quote": [
                        {
                          "close": [247.14, 247.68, 248.25]
                        }
                      ]
                    }
                  }
                ]
              },
              {
                "symbol": "GC=F",
                "response": [
                  {
                    "meta": {
                      "symbol": "GC=F",
                      "shortName": "Gold Apr 26",
                      "currency": "USD",
                      "regularMarketPrice": 4564.5,
                      "previousClose": 4994.0,
                      "regularMarketTime": 1774030902,
                      "marketState": "POSTPOST",
                      "exchangeTimezoneName": "America/Chicago",
                      "fullExchangeName": "COMEX",
                      "instrumentType": "FUTURE",
                      "priceHint": 2
                    },
                    "indicators": {
                      "quote": [
                        {
                          "close": [4994.0, 4600.7, 4564.5]
                        }
                      ]
                    }
                  }
                ]
              }
            ],
            "error": null
          }
        }
        """

        let client = YahooFinanceClient()
        let batch = try client.decodeMarketBatch(
            from: Data(payload.utf8),
            requestedSymbols: ["GC=F", "MISSING", "AAPL"]
        )

        #expect(batch.quotes.map(\.symbol) == ["GC=F", "AAPL"])
        #expect(batch.missingSymbols == ["MISSING"])
        #expect(batch.quotes.first?.displayName == "Gold Apr 26")
        #expect(batch.quotes.first?.intradayCloses.last == 4564.5)
        #expect(batch.quotes.first?.session.state == .closed)
        #expect(batch.quotes.first?.session.exchangeTimeZoneIdentifier == "America/Chicago")
        #expect(batch.quotes.first?.session.source == .providerMetadata)
        #expect(batch.quotes.last?.session.state == .open)
        #expect(batch.quotes.last?.session.exchangeTimeZoneIdentifier == "America/New_York")
    }

    @Test
    func usesInjectedMarketSessionResolver() throws {
        let payload = """
        {
          "spark": {
            "result": [
              {
                "symbol": "AAPL",
                "response": [
                  {
                    "meta": {
                      "symbol": "AAPL",
                      "shortName": "Apple Inc.",
                      "currency": "USD",
                      "regularMarketPrice": 248.25,
                      "previousClose": 248.96,
                      "regularMarketTime": 1774031733,
                      "marketState": "REGULAR",
                      "exchangeTimezoneName": "America/New_York",
                      "fullExchangeName": "NasdaqGS",
                      "instrumentType": "EQUITY",
                      "priceHint": 2
                    },
                    "indicators": {
                      "quote": [
                        {
                          "close": [247.14, 247.68, 248.25]
                        }
                      ]
                    }
                  }
                ]
              }
            ],
            "error": null
          }
        }
        """

        let expectedSession = MarketSessionInfo(
            state: .closed,
            exchangeTimeZoneIdentifier: "Injected/Session",
            source: .continuousTradingRule
        )
        let client = YahooFinanceClient(
            marketSessionResolver: StubMarketSessionResolver(session: expectedSession)
        )

        let batch = try client.decodeMarketBatch(
            from: Data(payload.utf8),
            requestedSymbols: ["AAPL"]
        )

        #expect(batch.quotes.first?.session == expectedSession)
    }
}

private struct StubMarketSessionResolver: MarketSessionResolving {
    let session: MarketSessionInfo

    func resolve(instrumentType: String, meta: YahooSparkMeta) -> MarketSessionInfo {
        session
    }
}
