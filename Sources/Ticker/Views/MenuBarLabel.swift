import AppKit
import TickerKit

@MainActor
enum MenuBarLabelRenderer {
    private static let iconPointSize: CGFloat = 10
    private static let iconBoundingSize = NSSize(width: 11, height: 11)

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
                renderedInstrumentIdentity(
                    for: symbol,
                    quote: quote,
                    color: visualStyle.symbolColor
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
        let identity = if let displayName = quote?.displayName,
                          displayName.caseInsensitiveCompare(symbol) != .orderedSame {
            "\(symbol), \(displayName)"
        } else {
            symbol
        }
        let baseLabel = "\(identity), \(priceText(for: quote))"

        if let stateSummary = QuoteFormatting.stateSummary(for: quote) {
            return "\(baseLabel), \(stateSummary.lowercased())"
        }

        return baseLabel
    }

    private static func renderedInstrumentIdentity(
        for symbol: String,
        quote: MarketQuote?,
        color: NSColor
    ) -> NSAttributedString {
        if let icon = InstrumentIconCatalog.icon(for: symbol),
           let iconString = renderedIcon(icon, color: color) {
            let attributed = NSMutableAttributedString(attributedString: iconString)
            attributed.append(
                NSAttributedString(
                    string: " ",
                    attributes: priceAttributes(color: color)
                )
            )
            return attributed
        }

        return NSAttributedString(
            string: "\(symbol) ",
            attributes: symbolAttributes(color: color)
        )
    }

    private static func renderedIcon(
        _ icon: InstrumentIcon,
        color: NSColor
    ) -> NSAttributedString? {
        switch icon.kind {
        case let .asset(name):
            guard let image = renderedBundledAsset(named: name, color: color) else {
                return nil
            }

            return attributedAttachment(for: image)
        case let .glyph(glyph):
            return NSAttributedString(
                string: glyph,
                attributes: glyphAttributes(color: color)
            )
        case let .sfSymbol(name):
            guard let image = renderedSymbolImage(named: name, color: color) else {
                return nil
            }

            return attributedAttachment(for: image)
        }
    }

    private static func symbolAttributes(color: NSColor = .labelColor) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont(name: "HelveticaNeue-CondensedBold", size: 12) ?? .boldSystemFont(ofSize: 12),
            .foregroundColor: color,
        ]
    }

    private static func glyphAttributes(color: NSColor = .labelColor) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
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

    private static func renderedSymbolImage(
        named name: String,
        color: NSColor
    ) -> NSImage? {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return nil
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: iconPointSize, weight: .bold)
        let configuredImage = image.withSymbolConfiguration(configuration) ?? image
        return tintedImage(from: configuredImage, color: color)
    }

    private static func renderedBundledAsset(
        named name: String,
        color: NSColor
    ) -> NSImage? {
        guard let url = InstrumentIconCatalog.assetURL(named: name),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        let fittedImage = resizedImage(image, toFitWithin: iconBoundingSize)
        return maskedAssetImage(from: fittedImage, color: color)
    }

    private static func attributedAttachment(for image: NSImage) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.attachmentCell = BaselineAlignedAttachmentCell(imageCell: image)
        return NSAttributedString(attachment: attachment)
    }

    private static func resizedImage(_ image: NSImage, toFitWithin boundingSize: NSSize) -> NSImage {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else {
            return image
        }

        let scale = min(
            boundingSize.width / originalSize.width,
            boundingSize.height / originalSize.height
        )
        let scaledSize = NSSize(
            width: max(1, floor(originalSize.width * scale)),
            height: max(1, floor(originalSize.height * scale))
        )

        let resized = NSImage(size: scaledSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: scaledSize),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        resized.unlockFocus()
        resized.isTemplate = false
        return resized
    }

    private static func tintedImage(
        from image: NSImage,
        color: NSColor
    ) -> NSImage {
        let tintedImage = NSImage(size: image.size)
        tintedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: image.size))
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceIn)
        tintedImage.unlockFocus()
        tintedImage.isTemplate = false
        return tintedImage
    }

    private static func maskedAssetImage(
        from image: NSImage,
        color: NSColor
    ) -> NSImage {
        guard let cgImage = image.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else {
            return tintedImage(from: image, color: color)
        }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ), let tintColor = color.usingColorSpace(.sRGB) else {
            return tintedImage(from: image, color: color)
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else {
            return tintedImage(from: image, color: color)
        }

        let red = Double(tintColor.redComponent)
        let green = Double(tintColor.greenComponent)
        let blue = Double(tintColor.blueComponent)
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        for offset in stride(from: 0, to: width * height * 4, by: 4) {
            let sourceRed = Double(bytes[offset]) / 255
            let sourceGreen = Double(bytes[offset + 1]) / 255
            let sourceBlue = Double(bytes[offset + 2]) / 255
            let sourceAlpha = Double(bytes[offset + 3]) / 255
            let luminance = (0.2126 * sourceRed) + (0.7152 * sourceGreen) + (0.0722 * sourceBlue)
            let maskedAlpha = max(0, min(1, sourceAlpha * (1 - luminance)))

            bytes[offset] = UInt8((red * maskedAlpha * 255).rounded())
            bytes[offset + 1] = UInt8((green * maskedAlpha * 255).rounded())
            bytes[offset + 2] = UInt8((blue * maskedAlpha * 255).rounded())
            bytes[offset + 3] = UInt8((maskedAlpha * 255).rounded())
        }

        guard let maskedCGImage = context.makeImage() else {
            return tintedImage(from: image, color: color)
        }

        let maskedImage = NSImage(
            cgImage: maskedCGImage,
            size: NSSize(width: width, height: height)
        )
        maskedImage.isTemplate = false
        return maskedImage
    }
}

private final class BaselineAlignedAttachmentCell: NSTextAttachmentCell {
    override func cellBaselineOffset() -> NSPoint {
        let baselineOffset = super.cellBaselineOffset()
        return NSPoint(x: baselineOffset.x, y: baselineOffset.y - 1)
    }
}
