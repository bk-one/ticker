import Foundation

public struct InstrumentIcon: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case sfSymbol(String)
        case glyph(String)
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }
}
