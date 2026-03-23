import Foundation
import AppKit
import SwiftUI
import TickerKit

enum QuoteVisualState {
    case live
    case liveAlert
    case marketClosed
    case marketClosedAlert
}

struct QuoteVisualStyle {
    let state: QuoteVisualState
    let symbolColor: NSColor
    let priceTextColor: NSColor
    let priceBackgroundColor: NSColor?
    let accessibilityStateLabel: String?
}

enum QuoteFormatting {
    static func price(_ quote: MarketQuote) -> String {
        QuotePresentation.formattedPrice(for: quote.currentPrice)
    }

    static func toneSummary(_ quote: MarketQuote) -> String? {
        if quote.isMarketClosed {
            return "Market closed"
        }

        guard let tone = quote.tone else {
            return nil
        }

        return "\(QuotePresentation.formattedSignedPercent(tone.percentChange)) vs last close"
    }

    static func color(for quote: MarketQuote?) -> Color {
        Color(nsColor: nsColor(for: quote))
    }

    static func symbolColor(for quote: MarketQuote?) -> Color {
        Color(nsColor: symbolNSColor(for: quote))
    }

    static func nsColor(for quote: MarketQuote?) -> NSColor {
        visualStyle(for: quote).priceTextColor
    }

    static func symbolNSColor(for quote: MarketQuote?) -> NSColor {
        visualStyle(for: quote).symbolColor
    }

    static func stateSummary(for quote: MarketQuote?) -> String? {
        visualStyle(for: quote).accessibilityStateLabel
    }

    static func visualStyle(
        for quote: MarketQuote?,
        alertTriggered: Bool = false
    ) -> QuoteVisualStyle {
        guard let quote else {
            return QuoteVisualStyle(
                state: alertTriggered ? .liveAlert : .live,
                symbolColor: .labelColor,
                priceTextColor: .labelColor,
                priceBackgroundColor: nil,
                accessibilityStateLabel: nil
            )
        }

        if quote.isMarketClosed {
            return closedVisualStyle(alertTriggered: alertTriggered)
        }

        return liveVisualStyle(for: quote, alertTriggered: alertTriggered)
    }

    static func loadingPlaceholder(for symbol: String) -> String {
        "\(symbol) --"
    }

    static func shortTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private static func liveVisualStyle(
        for quote: MarketQuote,
        alertTriggered: Bool
    ) -> QuoteVisualStyle {
        let priceTextColor = livePriceNSColor(for: quote)

        if alertTriggered {
            return QuoteVisualStyle(
                state: .liveAlert,
                symbolColor: .labelColor,
                priceTextColor: contrastingTextColor(for: priceTextColor),
                priceBackgroundColor: priceTextColor,
                accessibilityStateLabel: nil
            )
        }

        return QuoteVisualStyle(
            state: .live,
            symbolColor: .labelColor,
            priceTextColor: priceTextColor,
            priceBackgroundColor: nil,
            accessibilityStateLabel: nil
        )
    }

    private static func closedVisualStyle(alertTriggered: Bool) -> QuoteVisualStyle {
        if alertTriggered {
            return QuoteVisualStyle(
                state: .marketClosedAlert,
                symbolColor: closedMarketNSColor,
                priceTextColor: contrastingTextColor(for: closedMarketNSColor),
                priceBackgroundColor: closedMarketNSColor,
                accessibilityStateLabel: "Market closed"
            )
        }

        return QuoteVisualStyle(
            state: .marketClosed,
            symbolColor: closedMarketNSColor,
            priceTextColor: closedMarketNSColor,
            priceBackgroundColor: nil,
            accessibilityStateLabel: "Market closed"
        )
    }

    private static func livePriceNSColor(for quote: MarketQuote) -> NSColor {
        guard let tone = quote.tone else {
            return .labelColor
        }

        switch tone.direction {
        case .neutral:
            return .labelColor
        case .up:
            return mixedNSColor(
                from: .labelColor,
                to: .systemGreen,
                factor: 0.35 + (tone.intensity * 0.65)
            )
        case .down:
            return mixedNSColor(
                from: .labelColor,
                to: .systemRed,
                factor: 0.35 + (tone.intensity * 0.65)
            )
        }
    }

    private static var closedMarketNSColor: NSColor {
        NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .vibrantDark]) {
            case .darkAqua, .vibrantDark:
                return NSColor(
                    red: 0.70,
                    green: 0.81,
                    blue: 0.92,
                    alpha: 1
                )
            default:
                return NSColor(
                    red: 0.40,
                    green: 0.55,
                    blue: 0.70,
                    alpha: 1
                )
            }
        }
    }

    private static func contrastingTextColor(for color: NSColor) -> NSColor {
        let converted = color.usingColorSpace(.sRGB) ?? color
        let luminance = (0.299 * converted.redComponent)
            + (0.587 * converted.greenComponent)
            + (0.114 * converted.blueComponent)

        return luminance > 0.6 ? .black : .white
    }

    private static func mixedNSColor(from: NSColor, to: NSColor, factor: Double) -> NSColor {
        let clampedFactor = min(max(factor, 0), 1)
        let source = from.usingColorSpace(.sRGB) ?? from
        let target = to.usingColorSpace(.sRGB) ?? to

        let red = source.redComponent + ((target.redComponent - source.redComponent) * clampedFactor)
        let green = source.greenComponent + ((target.greenComponent - source.greenComponent) * clampedFactor)
        let blue = source.blueComponent + ((target.blueComponent - source.blueComponent) * clampedFactor)
        let alpha = source.alphaComponent + ((target.alphaComponent - source.alphaComponent) * clampedFactor)

        return NSColor(
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }
}
