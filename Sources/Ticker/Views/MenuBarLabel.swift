import AppKit
import TickerKit

@MainActor
enum MenuBarLabelRenderer {
    static func image(for model: TickerStore) -> NSImage {
        let attributedString = attributedTitle(for: model)

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

    static func accessibilityLabel(for model: TickerStore) -> String {
        guard model.hasTrackedSymbols else {
            return TickerStore.emptyStateLabel
        }

        return model.trackedSymbols
            .map { symbol in
                "\(symbol) \(priceText(for: model.quote(for: symbol)))"
            }
            .joined(separator: ", ")
    }

    private static func attributedTitle(for model: TickerStore) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString()

        guard model.hasTrackedSymbols else {
            attributedString.append(
                NSAttributedString(
                    string: TickerStore.emptyStateLabel,
                    attributes: symbolAttributes
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

            attributedString.append(
                NSAttributedString(
                    string: "\(symbol) ",
                    attributes: symbolAttributes
                )
            )
            attributedString.append(
                NSAttributedString(
                    string: priceText(for: quote),
                    attributes: priceAttributes(color: QuoteFormatting.nsColor(for: quote))
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

    private static var symbolAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont(name: "HelveticaNeue-CondensedBold", size: 12) ?? .boldSystemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor,
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
