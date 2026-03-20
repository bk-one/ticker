import AppKit
import TickerKit

@MainActor
enum MenuBarLabelRenderer {
    static func image(for model: TickerStore) -> NSImage {
        let attributedString = NSMutableAttributedString()

        if model.hasTrackedSymbols {
            attributedString.append(
                NSAttributedString(
                    string: "\(model.displaySymbol) ",
                    attributes: [
                        .font: NSFont(name: "HelveticaNeue-CondensedBold", size: 12) ?? .boldSystemFont(ofSize: 12),
                        .foregroundColor: NSColor.labelColor,
                    ]
                )
            )
            attributedString.append(
                NSAttributedString(
                    string: priceText(for: model),
                    attributes: [
                        .font: NSFont(name: "HelveticaNeue-CondensedBold", size: 13) ?? .systemFont(ofSize: 13),
                        .foregroundColor: QuoteFormatting.nsColor(for: model.quote),
                    ]
                )
            )
        } else {
            attributedString.append(
                NSAttributedString(
                    string: TickerStore.emptyStateLabel,
                    attributes: [
                        .font: NSFont(name: "HelveticaNeue-CondensedBold", size: 12) ?? .boldSystemFont(ofSize: 12),
                        .foregroundColor: NSColor.labelColor,
                    ]
                )
            )
        }

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

        return "\(model.displaySymbol) \(priceText(for: model))"
    }

    private static func priceText(for model: TickerStore) -> String {
        guard let quote = model.quote else {
            return "--"
        }

        return QuoteFormatting.price(quote)
    }
}
