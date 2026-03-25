import Combine
import Foundation

@MainActor
public final class TickerStore: ObservableObject {
    public static let bootstrapSymbol = "AAPL"
    public static let trackedSymbolsDefaultsKey = "tracked_symbols"
    public static let displaySymbolDefaultsKey = "display_symbol"
    public static let alertBoundariesDefaultsKey = "alert_boundaries"
    public static let emptyStateLabel = "Click to add ticker"

    @Published public private(set) var trackedSymbols: [String]
    @Published public private(set) var trackedQuotes: [MarketQuote] = []
    @Published public private(set) var quote: MarketQuote?
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastUpdated: Date?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var alertBoundariesBySymbol: [String: PriceAlertBoundary]

    private let client: YahooFinanceClientProtocol
    private let defaults: UserDefaults
    private let trackedSymbolsKey: String
    private let displaySymbolKey: String
    private let alertBoundariesKey: String
    private let refreshInterval: Duration
    private var autoRefreshTask: Task<Void, Never>?
    private var hasStarted = false
    private var trackedQuotesBySymbol: [String: MarketQuote] = [:]
    private var selectedDisplaySymbol: String?

    public init(
        client: YahooFinanceClientProtocol = YahooFinanceClient(),
        refreshInterval: Duration = .seconds(15),
        defaults: UserDefaults = .standard,
        trackedSymbolsKey: String = TickerStore.trackedSymbolsDefaultsKey,
        displaySymbolKey: String = TickerStore.displaySymbolDefaultsKey,
        alertBoundariesKey: String = TickerStore.alertBoundariesDefaultsKey
    ) {
        self.defaults = defaults
        self.trackedSymbolsKey = trackedSymbolsKey
        self.displaySymbolKey = displaySymbolKey
        self.alertBoundariesKey = alertBoundariesKey
        self.client = client
        self.refreshInterval = refreshInterval

        let persistedSymbols = defaults.stringArray(forKey: trackedSymbolsKey) ?? []
        let normalizedSymbols = YahooFinanceClient.normalizedSymbols(from: persistedSymbols)

        let initialTrackedSymbols: [String]
        if defaults.object(forKey: trackedSymbolsKey) == nil {
            initialTrackedSymbols = [Self.bootstrapSymbol]
        } else {
            initialTrackedSymbols = normalizedSymbols
        }
        self.trackedSymbols = initialTrackedSymbols

        let persistedDisplaySymbol = YahooFinanceClient.normalizedSymbols(
            from: defaults.string(forKey: displaySymbolKey).map { [$0] } ?? []
        ).first

        if let persistedDisplaySymbol,
           initialTrackedSymbols.contains(persistedDisplaySymbol) {
            self.selectedDisplaySymbol = persistedDisplaySymbol
        } else {
            self.selectedDisplaySymbol = initialTrackedSymbols.first
        }

        self.alertBoundariesBySymbol = Self.filteredAlertBoundaries(
            Self.loadAlertBoundaries(from: defaults.data(forKey: alertBoundariesKey)),
            trackedSymbols: initialTrackedSymbols
        )

        persistAlertBoundaries()
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    public var displaySymbol: String {
        selectedDisplaySymbol ?? trackedSymbols.first ?? Self.emptyStateLabel
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

    public func alertBoundary(for symbol: String) -> PriceAlertBoundary? {
        guard let normalizedSymbol = Self.normalizedSymbol(from: symbol) else {
            return nil
        }

        return alertBoundariesBySymbol[normalizedSymbol]
    }

    public func hasAlertBoundary(for symbol: String) -> Bool {
        alertBoundary(for: symbol) != nil
    }

    public func isAlertTriggered(for symbol: String) -> Bool {
        guard let normalizedSymbol = Self.normalizedSymbol(from: symbol),
              let boundary = alertBoundariesBySymbol[normalizedSymbol],
              let quote = trackedQuotesBySymbol[normalizedSymbol] else {
            return false
        }

        return boundary.isTriggered(by: quote.currentPrice)
    }

    @discardableResult
    public func saveAlertBoundary(
        symbol: String,
        upper: Double?,
        lower: Double?
    ) -> PriceAlertBoundary? {
        guard let normalizedSymbol = Self.normalizedSymbol(from: symbol),
              trackedSymbols.contains(normalizedSymbol) else {
            return nil
        }

        let boundary = PriceAlertBoundary(upper: upper, lower: lower)

        if boundary.isConfigured {
            alertBoundariesBySymbol[normalizedSymbol] = boundary
        } else {
            alertBoundariesBySymbol.removeValue(forKey: normalizedSymbol)
        }

        persistAlertBoundaries()
        return alertBoundariesBySymbol[normalizedSymbol]
    }

    public func clearAlertBoundary(symbol: String) {
        guard let normalizedSymbol = Self.normalizedSymbol(from: symbol),
              alertBoundariesBySymbol.removeValue(forKey: normalizedSymbol) != nil else {
            return
        }

        persistAlertBoundaries()
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
        selectedDisplaySymbol = normalizedSymbol
        quote = trackedQuotesBySymbol[normalizedSymbol]
        persistTrackedSymbols()
        persistDisplaySymbol()
        errorMessage = nil

        await refresh()
        return true
    }

    @discardableResult
    public func removeInstrument(symbol: String) -> Bool {
        guard let normalizedSymbol = YahooFinanceClient.normalizedSymbols(from: [symbol]).first,
              let index = trackedSymbols.firstIndex(of: normalizedSymbol) else {
            return false
        }

        trackedSymbols.remove(at: index)
        trackedQuotesBySymbol.removeValue(forKey: normalizedSymbol)
        trackedQuotes.removeAll { $0.symbol == normalizedSymbol }
        alertBoundariesBySymbol.removeValue(forKey: normalizedSymbol)

        if selectedDisplaySymbol == normalizedSymbol {
            selectedDisplaySymbol = trackedSymbols.first
        }

        quote = trackedQuotesBySymbol[displaySymbol]
        errorMessage = nil

        if trackedSymbols.isEmpty {
            lastUpdated = nil
            selectedDisplaySymbol = nil
        }

        persistTrackedSymbols()
        persistDisplaySymbol()
        persistAlertBoundaries()
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
            selectedDisplaySymbol = nil
            persistDisplaySymbol()
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

            syncDisplaySymbol()
            quote = trackedQuotesBySymbol[displaySymbol]

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

    private func persistDisplaySymbol() {
        defaults.set(selectedDisplaySymbol, forKey: displaySymbolKey)
    }

    private func persistAlertBoundaries() {
        guard let data = try? JSONEncoder().encode(alertBoundariesBySymbol) else {
            return
        }

        defaults.set(data, forKey: alertBoundariesKey)
    }

    private func syncDisplaySymbol() {
        if let selectedDisplaySymbol,
           trackedSymbols.contains(selectedDisplaySymbol) {
            return
        }

        selectedDisplaySymbol = trackedSymbols.first
        persistDisplaySymbol()
    }

    private static func normalizedSymbol(from symbol: String) -> String? {
        YahooFinanceClient.normalizedSymbols(from: [symbol]).first
    }

    private static func loadAlertBoundaries(from data: Data?) -> [String: PriceAlertBoundary] {
        guard let data,
              let decoded = try? JSONDecoder().decode([String: PriceAlertBoundary].self, from: data) else {
            return [:]
        }

        return decoded.reduce(into: [:]) { partialResult, entry in
            guard let normalizedSymbol = normalizedSymbol(from: entry.key),
                  entry.value.isConfigured else {
                return
            }

            partialResult[normalizedSymbol] = entry.value
        }
    }

    private static func filteredAlertBoundaries(
        _ boundaries: [String: PriceAlertBoundary],
        trackedSymbols: [String]
    ) -> [String: PriceAlertBoundary] {
        boundaries.reduce(into: [:]) { partialResult, entry in
            guard trackedSymbols.contains(entry.key) else {
                return
            }

            partialResult[entry.key] = entry.value
        }
    }
}
