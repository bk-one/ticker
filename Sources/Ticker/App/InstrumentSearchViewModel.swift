import Foundation
import TickerKit

@MainActor
final class InstrumentSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [InstrumentSearchResult] = []
    @Published private(set) var selectedIndex: Int?
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var confirmationMessage: String?
    @Published private(set) var focusRequestID = 0

    private let store: TickerStore
    private let searchClient: YahooFinanceSearchClientProtocol
    private var searchTask: Task<Void, Never>?
    private var confirmationTask: Task<Void, Never>?
    private let maxResults = 8

    init(
        store: TickerStore,
        searchClient: YahooFinanceSearchClientProtocol
    ) {
        self.store = store
        self.searchClient = searchClient
    }

    func beginSession() {
        cancelTasks()
        query = ""
        results = []
        selectedIndex = nil
        isSearching = false
        errorMessage = nil
        confirmationMessage = nil
        focusRequestID += 1
    }

    func endSession() {
        cancelTasks()
        query = ""
        results = []
        selectedIndex = nil
        isSearching = false
        errorMessage = nil
        confirmationMessage = nil
    }

    func updateQuery(_ query: String) {
        self.query = query
        confirmationMessage = nil
        errorMessage = nil
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            results = []
            selectedIndex = nil
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))

            guard let self,
                  !Task.isCancelled else {
                return
            }

            do {
                let searchResults = try await searchClient.search(query: trimmedQuery, limit: maxResults)

                guard !Task.isCancelled else {
                    return
                }

                results = searchResults
                selectedIndex = firstSelectableIndex(in: searchResults)
                isSearching = false
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                results = []
                selectedIndex = nil
                isSearching = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func moveSelection(by delta: Int) {
        let selectableIndices = results.indices.filter { !isTracked(results[$0]) }
        guard !selectableIndices.isEmpty else {
            selectedIndex = nil
            return
        }

        guard let selectedIndex,
              let currentPosition = selectableIndices.firstIndex(of: selectedIndex) else {
            self.selectedIndex = delta >= 0 ? selectableIndices.first : selectableIndices.last
            return
        }

        let updatedPosition = min(
            max(currentPosition + delta, 0),
            selectableIndices.count - 1
        )
        self.selectedIndex = selectableIndices[updatedPosition]
    }

    func submitSelection() async {
        guard let selectedIndex,
              results.indices.contains(selectedIndex) else {
            return
        }

        await select(results[selectedIndex])
    }

    func select(_ result: InstrumentSearchResult) async {
        guard !isTracked(result) else {
            return
        }

        let wasAdded = await store.addInstrument(symbol: result.symbol)
        guard wasAdded else {
            return
        }

        confirmationTask?.cancel()
        confirmationMessage = "Added \(result.symbol)"
        query = ""
        results = []
        selectedIndex = nil
        errorMessage = nil
        focusRequestID += 1

        confirmationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))

            guard let self,
                  !Task.isCancelled else {
                return
            }

            confirmationMessage = nil
        }
    }

    func isTracked(_ result: InstrumentSearchResult) -> Bool {
        store.isTracked(symbol: result.symbol)
    }

    private func firstSelectableIndex(in results: [InstrumentSearchResult]) -> Int? {
        results.indices.first { !isTracked(results[$0]) }
    }

    private func cancelTasks() {
        searchTask?.cancel()
        confirmationTask?.cancel()
    }
}
