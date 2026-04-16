import Testing
@testable import TickerKit

struct InstrumentIconCatalogTests {
    @Test
    func returnsConfiguredIconForKnownTicker() {
        let icon = InstrumentIconCatalog.icon(for: "aapl")

        #expect(icon?.kind == .sfSymbol("apple.logo"))
    }

    @Test
    func resolvesAliasesToTheSameIcon() {
        let goog = InstrumentIconCatalog.icon(for: "GOOG")
        let googl = InstrumentIconCatalog.icon(for: "googl")

        #expect(goog == googl)
        #expect(goog?.kind == .asset("google"))
    }

    @Test
    func returnsNilForUnknownTicker() {
        #expect(InstrumentIconCatalog.icon(for: "IAU") == nil)
    }

    @Test
    func returnsBundledAssetURLForAssetBackedTicker() {
        #expect(InstrumentIconCatalog.assetURL(named: "ethereum") != nil)
        #expect(InstrumentIconCatalog.assetURL(named: "solana") != nil)
    }
}
