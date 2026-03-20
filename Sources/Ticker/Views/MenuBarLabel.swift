import AppKit
import SwiftUI
import TickerKit

struct MenuBarLabel: View {
    @ObservedObject var model: TickerStore

    var body: some View {
        Image(nsImage: labelImage)
            .renderingMode(.original)
            .interpolation(.high)
            .accessibilityLabel("\(model.displaySymbol) \(priceText)")
            .id(refreshIdentity)
    }

    private var priceText: String {
        guard let quote = model.quote else {
            return "--"
        }

        return QuoteFormatting.price(quote)
    }

    private var refreshIdentity: String {
        let timestamp = model.quote?.asOf.timeIntervalSinceReferenceDate ?? 0
        return "\(priceText)-\(timestamp)"
    }

    private var labelImage: NSImage {
        let symbolAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "HelveticaNeue-CondensedBold", size: 12) ?? .boldSystemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor,
        ]

        let priceAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "HelveticaNeue-CondensedBold", size: 13) ?? .systemFont(ofSize: 13),
            .foregroundColor: QuoteFormatting.nsColor(for: model.quote),
        ]

        let attributedString = NSMutableAttributedString(
            string: "\(model.displaySymbol) ",
            attributes: symbolAttributes
        )
        attributedString.append(NSAttributedString(string: priceText, attributes: priceAttributes))

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
}
