import Testing
@testable import TickerKit

struct YahooMarketSessionResolverTests {
    @Test
    func treatsCryptoAsAlwaysOpen() {
        let resolver = YahooMarketSessionResolver()
        let session = resolver.resolve(
            instrumentType: "CRYPTOCURRENCY",
            meta: makeMeta(marketState: "CLOSED", exchangeTimezoneName: nil)
        )

        #expect(session.state == .open)
        #expect(session.source == .continuousTradingRule)
    }

    @Test
    func mapsRegularSessionToOpen() {
        let resolver = YahooMarketSessionResolver()
        let session = resolver.resolve(
            instrumentType: "EQUITY",
            meta: makeMeta(marketState: "REGULAR", exchangeTimezoneName: "America/New_York")
        )

        #expect(session.state == .open)
        #expect(session.source == .providerMetadata)
        #expect(session.exchangeTimeZoneIdentifier == "America/New_York")
    }

    @Test
    func mapsPreAndPostMarketToClosed() {
        #expect(YahooMarketSessionResolver.sessionState(forProviderState: "PRE") == .closed)
        #expect(YahooMarketSessionResolver.sessionState(forProviderState: "POSTPOST") == .closed)
        #expect(YahooMarketSessionResolver.sessionState(forProviderState: "HOLIDAY") == .closed)
    }

    @Test
    func returnsUnknownWhenProviderMetadataIsMissingOrUnrecognized() {
        let resolver = YahooMarketSessionResolver()
        let missingSession = resolver.resolve(
            instrumentType: "EQUITY",
            meta: makeMeta(marketState: nil, exchangeTimezoneName: "America/New_York")
        )
        let unknownSession = resolver.resolve(
            instrumentType: "EQUITY",
            meta: makeMeta(marketState: "HALTED", exchangeTimezoneName: "America/New_York")
        )

        #expect(missingSession.state == .unknown)
        #expect(missingSession.source == .unavailable)
        #expect(unknownSession.state == .unknown)
        #expect(unknownSession.source == .providerMetadata)
    }

    private func makeMeta(
        marketState: String?,
        exchangeTimezoneName: String?
    ) -> YahooSparkMeta {
        YahooSparkMeta(
            symbol: nil,
            shortName: nil,
            longName: nil,
            currency: nil,
            regularMarketPrice: nil,
            previousClose: nil,
            chartPreviousClose: nil,
            regularMarketTime: nil,
            fullExchangeName: nil,
            exchangeName: nil,
            instrumentType: nil,
            priceHint: nil,
            marketState: marketState,
            exchangeTimezoneName: exchangeTimezoneName,
            exchangeTimezoneShortName: nil,
            gmtOffSetMilliseconds: nil
        )
    }
}
