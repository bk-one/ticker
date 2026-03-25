import Foundation

public struct PriceAlertBoundary: Codable, Equatable, Sendable {
    public let upper: Double?
    public let lower: Double?

    public var isConfigured: Bool {
        upper != nil || lower != nil
    }

    public init(upper: Double?, lower: Double?) {
        self.upper = upper
        self.lower = lower
    }

    public func isTriggered(by price: Double) -> Bool {
        if let upper, price >= upper {
            return true
        }

        if let lower, price <= lower {
            return true
        }

        return false
    }
}
