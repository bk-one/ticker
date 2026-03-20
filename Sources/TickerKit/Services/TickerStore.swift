import Combine
import Foundation

@MainActor
public final class TickerStore: ObservableObject {
    public static let bootstrapSymbol = "AAPL"

    @Published public private(set) var quote: MarketQuote?
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastUpdated: Date?
    @Published public var errorMessage: String?

    private let client: YahooFinanceClientProtocol
    private let refreshInterval: Duration
    private var autoRefreshTask: Task<Void, Never>?
    private var hasStarted = false

    public init(
        client: YahooFinanceClientProtocol = YahooFinanceClient(),
        refreshInterval: Duration = .seconds(15)
    ) {
        self.client = client
        self.refreshInterval = refreshInterval
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    public var displaySymbol: String {
        Self.bootstrapSymbol
    }

    public func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true

        Task {
            await refresh()
        }

        autoRefreshTask = Task { [weak self] in
            while let self,
                  !Task.isCancelled {
                try? await Task.sleep(for: refreshInterval)

                if Task.isCancelled {
                    return
                }

                await self.refresh()
            }
        }
    }

    public func refresh() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let batch = try await client.fetchQuotes(for: [Self.bootstrapSymbol])

            if let latestQuote = batch.quotes.first {
                quote = latestQuote
                lastUpdated = latestQuote.asOf
            }

            if let missingSymbol = batch.missingSymbols.first {
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
}
