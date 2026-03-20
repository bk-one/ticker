import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Ticker
@testable import TickerKit

struct VisualSnapshotTests {
    @Test
    @MainActor
    func rendersLightModeSnapshots() async throws {
        let outputDirectory = URL(fileURLWithPath: "/tmp/ticker-visual-snapshots")
        try? FileManager.default.removeItem(at: outputDirectory)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let store = try await configuredStore()
        let searchModel = await configuredSearchModel(store: store)

        try writePNG(
            MenuBarLabelRenderer.image(for: store),
            to: outputDirectory.appending(path: "menu-bar-label-light.png")
        )

        try writePNG(
            snapshot(
                of: MenuBarContentView(model: store),
                width: 360,
                appearance: .aqua
            ),
            to: outputDirectory.appending(path: "popover-light.png")
        )

        try writePNG(
            snapshot(
                of: InstrumentSearchPanelView(
                    model: searchModel,
                    onDismiss: {}
                ),
                width: 548,
                appearance: .aqua
            ),
            to: outputDirectory.appending(path: "search-panel-light.png")
        )

        #expect(FileManager.default.fileExists(atPath: outputDirectory.appending(path: "menu-bar-label-light.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDirectory.appending(path: "popover-light.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDirectory.appending(path: "search-panel-light.png").path))
    }

    @Test
    @MainActor
    func rendersDarkModeSnapshots() async throws {
        let outputDirectory = URL(fileURLWithPath: "/tmp/ticker-visual-snapshots")
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let store = try await configuredStore()
        let searchModel = await configuredSearchModel(store: store)

        try writePNG(
            snapshot(
                of: MenuBarContentView(model: store),
                width: 360,
                appearance: .darkAqua
            ),
            to: outputDirectory.appending(path: "popover-dark.png")
        )

        try writePNG(
            snapshot(
                of: InstrumentSearchPanelView(
                    model: searchModel,
                    onDismiss: {}
                ),
                width: 548,
                appearance: .darkAqua
            ),
            to: outputDirectory.appending(path: "search-panel-dark.png")
        )

        #expect(FileManager.default.fileExists(atPath: outputDirectory.appending(path: "popover-dark.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDirectory.appending(path: "search-panel-dark.png").path))
    }

    @MainActor
    private func configuredStore() async throws -> TickerStore {
        let defaults = makeDefaults()
        let trackedSymbolsKey = UUID().uuidString
        defaults.set(["AAPL", "GC=F"], forKey: trackedSymbolsKey)

        let batch = MarketBatch(
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
                    intradayCloses: [4548.0, 4556.7, 4564.5],
                    priceHint: 2
                ),
            ],
            missingSymbols: []
        )

        let store = TickerStore(
            client: SnapshotQuoteClient(result: .success(batch)),
            refreshInterval: .seconds(15),
            defaults: defaults,
            trackedSymbolsKey: trackedSymbolsKey
        )
        await store.refresh()
        return store
    }

    @MainActor
    private func configuredSearchModel(store: TickerStore) async -> InstrumentSearchViewModel {
        let model = InstrumentSearchViewModel(
            store: store,
            searchClient: SnapshotSearchClient(
                results: [
                    InstrumentSearchResult(
                        symbol: "GC=F",
                        displayName: "Gold Apr 26",
                        label: "Commodity",
                        quoteType: "FUTURE",
                        currentPrice: 4564.5
                    ),
                    InstrumentSearchResult(
                        symbol: "GLD",
                        displayName: "SPDR Gold Shares",
                        label: "NYSEArca",
                        quoteType: "ETF",
                        currentPrice: 284.08
                    ),
                    InstrumentSearchResult(
                        symbol: "BTC-USD",
                        displayName: "Bitcoin USD",
                        label: "Crypto",
                        quoteType: "CRYPTOCURRENCY",
                        currentPrice: 86970
                    ),
                    InstrumentSearchResult(
                        symbol: "GOLD",
                        displayName: "Gold.com, Inc.",
                        label: "NYSE",
                        quoteType: "EQUITY",
                        currentPrice: 11.42
                    ),
                    InstrumentSearchResult(
                        symbol: "IAU",
                        displayName: "iShares Gold Trust",
                        label: "NYSEArca",
                        quoteType: "ETF",
                        currentPrice: 56.84
                    ),
                    InstrumentSearchResult(
                        symbol: "MGC=F",
                        displayName: "Micro Gold Futures, Apr-2026",
                        label: "Commodity",
                        quoteType: "FUTURE",
                        currentPrice: 4565.2
                    ),
                    InstrumentSearchResult(
                        symbol: "SGU=F",
                        displayName: "Shanghai Gold (USD) Futures",
                        label: "Commodity",
                        quoteType: "FUTURE",
                        currentPrice: 4562.9
                    ),
                    InstrumentSearchResult(
                        symbol: "AEM",
                        displayName: "Agnico Eagle Mines Limited",
                        label: "NYSE",
                        quoteType: "EQUITY",
                        currentPrice: 101.83
                    ),
                ]
            )
        )

        model.beginSession()
        model.updateQuery("gold")
        try? await Task.sleep(for: .milliseconds(300))
        return model
    }

    @MainActor
    private func snapshot<V: View>(
        of view: V,
        width: CGFloat,
        appearance: NSAppearance.Name
    ) -> NSImage {
        let hostingView = NSHostingView(rootView: view)
        hostingView.appearance = NSAppearance(named: appearance)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: 10)
        hostingView.layoutSubtreeIfNeeded()

        let fittingSize = hostingView.fittingSize
        let size = NSSize(
            width: max(width, fittingSize.width),
            height: max(1, fittingSize.height)
        )

        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)!
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

        let image = NSImage(size: size)
        image.addRepresentation(bitmapRep)
        return image
    }

    private func writePNG(_ image: NSImage, to url: URL) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw SnapshotError.encodingFailed
        }

        try pngData.write(to: url)
    }
}

private struct SnapshotQuoteClient: YahooFinanceClientProtocol {
    let result: Result<MarketBatch, Error>

    func fetchQuotes(for symbols: [String]) async throws -> MarketBatch {
        try result.get()
    }
}

private struct SnapshotSearchClient: YahooFinanceSearchClientProtocol {
    let results: [InstrumentSearchResult]

    func search(query: String, limit: Int) async throws -> [InstrumentSearchResult] {
        Array(results.prefix(limit))
    }
}

private enum SnapshotError: Error {
    case encodingFailed
}

private func makeDefaults() -> UserDefaults {
    let suiteName = "TickerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
