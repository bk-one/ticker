import Combine
import Foundation

@MainActor
public final class TickerStore: ObservableObject {
    public static let bootstrapSymbol = "AAPL"
    public static let trackedSymbolsDefaultsKey = "tracked_symbols"
    public static let emptyStateLabel = "Click to add ticker"

    @Published public private(set) var trackedSymbols: [String]
    @Published public private(set) var trackedQuotes: [MarketQuote] = []
    @Published public private(set) var quote: MarketQuote?
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastUpdated: Date?
    @Published public private(set) var errorMessage: String?

    private let client: YahooFinanceClientProtocol
    private let defaults: UserDefaults
    private let trackedSymbolsKey: String
    private let refreshInterval: Duration
    private var autoRefreshTask: Task<Void, Never>?
    private var hasStarted = false
    private var trackedQuotesBySymbol: [String: MarketQuote] = [:]

    public init(
        client: YahooFinanceClientProtocol = YahooFinanceClient(),
        refreshInterval: Duration = .seconds(15),
        defaults: UserDefaults = .standard,
        trackedSymbolsKey: String = TickerStore.trackedSymbolsDefaultsKey
    ) {
        self.defaults = defaults
        self.trackedSymbolsKey = trackedSymbolsKey
        self.client = client
        self.refreshInterval = refreshInterval

        let persistedSymbols = defaults.stringArray(forKey: trackedSymbolsKey) ?? []
        let normalizedSymbols = YahooFinanceClient.normalizedSymbols(from: persistedSymbols)

        if defaults.object(forKey: trackedSymbolsKey) == nil {
            self.trackedSymbols = [Self.bootstrapSymbol]
        } else {
            self.trackedSymbols = normalizedSymbols
        }
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    public var displaySymbol: String {
        trackedSymbols.first ?? Self.emptyStateLabel
    }

    public var hasTrackedSymbols: Bool {
        !trackedSymbols.isEmpty
    }

    public var refreshIntervalDescription: String {
        let components = refreshInterval.components

        if components.attoseconds == 0 {
            let seconds = components.seconds
            return seconds == 1 ? "1 second" : "\(seconds) seconds"
        }

        let totalSeconds = Double(components.seconds) + (Double(components.attoseconds) / 1_000_000_000_000_000_000)
        let value = totalSeconds.formatted(.number.precision(.fractionLength(0 ... 1)))
        let usesSingular = abs(totalSeconds - 1) < 0.000_000_1
        return usesSingular ? "\(value) second" : "\(value) seconds"
    }

    public func quote(for symbol: String) -> MarketQuote? {
        let normalizedSymbol = YahooFinanceClient.normalizedSymbols(from: [symbol]).first ?? symbol
        return trackedQuotesBySymbol[normalizedSymbol]
    }

    public func isTracked(symbol: String) -> Bool {
        let normalizedSymbol = YahooFinanceClient.normalizedSymbols(from: [symbol]).first ?? symbol
        return trackedSymbols.contains(normalizedSymbol)
    }

    public func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true

        Task {
            await refresh()
        }

        let refreshInterval = self.refreshInterval
        autoRefreshTask = Task { [weak self, refreshInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: refreshInterval)

                if Task.isCancelled {
                    return
                }

                guard let self else {
                    return
                }

                await self.refresh()
            }
        }
    }

    @discardableResult
    public func addInstrument(symbol: String) async -> Bool {
        guard let normalizedSymbol = YahooFinanceClient.normalizedSymbols(from: [symbol]).first,
              !trackedSymbols.contains(normalizedSymbol) else {
            return false
        }

        trackedSymbols.append(normalizedSymbol)
        persistTrackedSymbols()
        errorMessage = nil

        await refresh()
        return true
    }

    public func refresh() async {
        guard !isLoading else {
            return
        }

        guard hasTrackedSymbols else {
            trackedQuotesBySymbol = [:]
            trackedQuotes = []
            quote = nil
            lastUpdated = nil
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let batch = try await client.fetchQuotes(for: trackedSymbols)
            trackedQuotesBySymbol = Dictionary(
                uniqueKeysWithValues: batch.quotes.map { quote in
                    (quote.symbol, quote)
                }
            )
            trackedQuotes = trackedSymbols.compactMap { symbol in
                trackedQuotesBySymbol[symbol]
            }

            if let displaySymbol = trackedSymbols.first {
                quote = trackedQuotesBySymbol[displaySymbol]
            }

            if let newestQuoteDate = trackedQuotes.map(\.asOf).max() {
                lastUpdated = newestQuoteDate
            }

            if let missingSymbol = batch.missingSymbols.first,
               trackedQuotesBySymbol[missingSymbol] == nil {
                errorMessage = "No live price returned for \(missingSymbol)."
            } else {
                errorMessage = nil
            }
        } catch {
            if quote == nil {
                errorMessage = "Loading live price… \(error.localizedDescription)"
            } else {
                errorMessage = "Refresh failed. Showing cached values. \(error.localizedDescription)"
            }
        }
    }

    private func persistTrackedSymbols() {
        defaults.set(trackedSymbols, forKey: trackedSymbolsKey)
    }
}
