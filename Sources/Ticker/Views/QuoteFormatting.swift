import Foundation
import AppKit
import SwiftUI
import TickerKit

enum QuoteFormatting {
    static func price(_ quote: MarketQuote) -> String {
        QuotePresentation.formattedPrice(for: quote.currentPrice)
    }

    static func toneSummary(_ quote: MarketQuote) -> String? {
        guard let tone = quote.tone else {
            return nil
        }

        let basisLabel = tone.basis == .fifteenMinutes ? "vs 15m" : "vs last active day"
        return "\(QuotePresentation.formattedSignedPercent(tone.percentChange)) \(basisLabel)"
    }

    static func color(for quote: MarketQuote?) -> Color {
        guard let tone = quote?.tone else {
            return .primary
        }

        switch tone.direction {
        case .neutral:
            return .primary
        case .up:
            return mixedColor(
                from: .labelColor,
                to: .systemGreen,
                factor: 0.35 + (tone.intensity * 0.65)
            )
        case .down:
            return mixedColor(
                from: .labelColor,
                to: .systemRed,
                factor: 0.35 + (tone.intensity * 0.65)
            )
        }
    }

    static func loadingPlaceholder(for symbol: String) -> String {
        "\(symbol) --"
    }

    static func shortTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private static func mixedColor(from: NSColor, to: NSColor, factor: Double) -> Color {
        let clampedFactor = min(max(factor, 0), 1)
        let source = from.usingColorSpace(.sRGB) ?? from
        let target = to.usingColorSpace(.sRGB) ?? to

        let red = source.redComponent + ((target.redComponent - source.redComponent) * clampedFactor)
        let green = source.greenComponent + ((target.greenComponent - source.greenComponent) * clampedFactor)
        let blue = source.blueComponent + ((target.blueComponent - source.blueComponent) * clampedFactor)
        let alpha = source.alphaComponent + ((target.alphaComponent - source.alphaComponent) * clampedFactor)

        return Color(
            nsColor: NSColor(
                red: red,
                green: green,
                blue: blue,
                alpha: alpha
            )
        )
    }
}
