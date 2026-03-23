import Foundation

protocol MarketSessionResolving: Sendable {
    func resolve(instrumentType: String, meta: YahooSparkMeta) -> MarketSessionInfo
}

struct YahooMarketSessionResolver: MarketSessionResolving {
    func resolve(instrumentType: String, meta: YahooSparkMeta) -> MarketSessionInfo {
        let exchangeTimeZoneIdentifier = meta.exchangeTimezoneName
        let normalizedInstrumentType = instrumentType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if normalizedInstrumentType == "CRYPTOCURRENCY" || normalizedInstrumentType == "CRYPTO" {
            return MarketSessionInfo(
                state: .open,
                exchangeTimeZoneIdentifier: exchangeTimeZoneIdentifier,
                source: .continuousTradingRule
            )
        }

        guard let providerState = Self.normalizedProviderState(meta.marketState) else {
            return MarketSessionInfo(
                state: .unknown,
                exchangeTimeZoneIdentifier: exchangeTimeZoneIdentifier,
                source: .unavailable
            )
        }

        return MarketSessionInfo(
            state: Self.sessionState(forProviderState: providerState),
            exchangeTimeZoneIdentifier: exchangeTimeZoneIdentifier,
            source: .providerMetadata
        )
    }

    static func sessionState(forProviderState providerState: String) -> MarketSessionState {
        switch providerState {
        case "REGULAR", "OPEN":
            return .open
        case "CLOSED", "HOLIDAY":
            return .closed
        default:
            if providerState.contains("PRE")
                || providerState.contains("POST")
                || providerState.contains("AFTER")
                || providerState.contains("CLOSED")
                || providerState.contains("HOLIDAY") {
                return .closed
            }

            return .unknown
        }
    }

    private static func normalizedProviderState(_ providerState: String?) -> String? {
        guard let providerState else {
            return nil
        }

        let normalized = providerState
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        return normalized.isEmpty ? nil : normalized
    }
}
