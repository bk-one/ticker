import AppKit
import TickerKit

@MainActor
enum MenuBarLabelRenderer {
    static func image(for model: TickerStore) -> NSImage {
        let attributedString = renderedTitle(for: model)

        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).integral

        let image = NSImage(size: boundingRect.size)
        image.isTemplate = false
        image.lockFocus()
        attributedString.draw(at: NSPoint(x: -boundingRect.origin.x, y: -boundingRect.origin.y))
        image.unlockFocus()
        return image
    }

    static func attributedTitle(for model: TickerStore) -> NSAttributedString {
        renderedTitle(for: model)
    }

    static func accessibilityLabel(for model: TickerStore) -> String {
        guard model.hasTrackedSymbols else {
            return TickerStore.emptyStateLabel
        }

        return model.trackedSymbols
            .map { symbol in
                accessibilityLabel(for: symbol, quote: model.quote(for: symbol))
            }
            .joined(separator: ", ")
    }

    private static func renderedTitle(for model: TickerStore) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString()

        guard model.hasTrackedSymbols else {
            attributedString.append(
                NSAttributedString(
                    string: TickerStore.emptyStateLabel,
                    attributes: symbolAttributes()
                )
            )
            return attributedString
        }

        for (index, symbol) in model.trackedSymbols.enumerated() {
            if index > 0 {
                attributedString.append(
                    NSAttributedString(
                        string: "  •  ",
                        attributes: separatorAttributes
                    )
                )
            }

            let quote = model.quote(for: symbol)
            let visualStyle = QuoteFormatting.visualStyle(for: quote)

            attributedString.append(
                NSAttributedString(
                    string: "\(symbol) ",
                    attributes: symbolAttributes(color: visualStyle.symbolColor)
                )
            )
            attributedString.append(
                NSAttributedString(
                    string: priceText(for: quote),
                    attributes: priceAttributes(color: visualStyle.priceTextColor)
                )
            )
        }

        return attributedString
    }

    private static func priceText(for quote: MarketQuote?) -> String {
        guard let quote else {
            return "--"
        }

        return QuoteFormatting.price(quote)
    }

    private static func accessibilityLabel(for symbol: String, quote: MarketQuote?) -> String {
        let baseLabel = "\(symbol) \(priceText(for: quote))"

        if let stateSummary = QuoteFormatting.stateSummary(for: quote) {
            return "\(baseLabel), \(stateSummary.lowercased())"
        }

        return baseLabel
    }

    private static func symbolAttributes(color: NSColor = .labelColor) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont(name: "HelveticaNeue-CondensedBold", size: 12) ?? .boldSystemFont(ofSize: 12),
            .foregroundColor: color,
        ]
    }

    private static var separatorAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
    }

    private static func priceAttributes(color: NSColor) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont(name: "HelveticaNeue-CondensedBold", size: 13) ?? .systemFont(ofSize: 13),
            .foregroundColor: color,
        ]
    }
}
