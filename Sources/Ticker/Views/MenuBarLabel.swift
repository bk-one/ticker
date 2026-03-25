import AppKit
import SwiftUI
import TickerKit

@MainActor
enum MenuBarLabelRenderer {
    static func image(for model: TickerStore) -> NSImage {
        snapshot(of: MenuBarLabelView(model: model))
    }

    static func attributedTitle(for model: TickerStore) -> NSAttributedString {
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
            let visualStyle = QuoteFormatting.visualStyle(
                for: quote,
                alertTriggered: model.isAlertTriggered(for: symbol)
            )

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

    static func accessibilityLabel(for model: TickerStore) -> String {
        guard model.hasTrackedSymbols else {
            return TickerStore.emptyStateLabel
        }

        return model.trackedSymbols
            .map { symbol in
                accessibilityLabel(for: symbol, quote: model.quote(for: symbol), model: model)
            }
            .joined(separator: ", ")
    }

    private static func priceText(for quote: MarketQuote?) -> String {
        guard let quote else {
            return "--"
        }

        return QuoteFormatting.price(quote)
    }

    private static func accessibilityLabel(
        for symbol: String,
        quote: MarketQuote?,
        model: TickerStore
    ) -> String {
        let baseLabel = "\(symbol) \(priceText(for: quote))"
        var states: [String] = []

        if model.isAlertTriggered(for: symbol) {
            states.append("alert active")
        }

        if let stateSummary = QuoteFormatting.stateSummary(for: quote) {
            states.append(stateSummary.lowercased())
        }

        guard !states.isEmpty else {
            return baseLabel
        }

        return "\(baseLabel), \(states.joined(separator: ", "))"
    }

    private static func snapshot<V: View>(of view: V) -> NSImage {
        let hostingView = NSHostingView(rootView: view)
        hostingView.appearance = NSApp.effectiveAppearance
        hostingView.frame = NSRect(x: 0, y: 0, width: 10, height: 10)
        hostingView.layoutSubtreeIfNeeded()

        let fittingSize = hostingView.fittingSize
        let size = NSSize(
            width: max(1, fittingSize.width),
            height: max(1, fittingSize.height)
        )

        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)!
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

        let image = NSImage(size: size)
        image.isTemplate = false
        image.addRepresentation(bitmapRep)
        return image
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

private struct MenuBarLabelView: View {
    let model: TickerStore

    var body: some View {
        HStack(spacing: 0) {
            if model.hasTrackedSymbols {
                ForEach(Array(model.trackedSymbols.enumerated()), id: \.offset) { index, symbol in
                    if index > 0 {
                        Text("  •  ")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    labelSegment(for: symbol)
                }
            } else {
                Text(TickerStore.emptyStateLabel)
                    .font(.custom("HelveticaNeue-CondensedBold", size: 12))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 1)
        .padding(.vertical, 1)
        .fixedSize()
    }

    @ViewBuilder
    private func labelSegment(for symbol: String) -> some View {
        let quote = model.quote(for: symbol)
        let visualStyle = QuoteFormatting.visualStyle(
            for: quote,
            alertTriggered: model.isAlertTriggered(for: symbol)
        )

        HStack(spacing: 4) {
            Text(symbol)
                .font(.custom("HelveticaNeue-CondensedBold", size: 12))
                .foregroundStyle(Color(nsColor: visualStyle.symbolColor))

            if let backgroundColor = visualStyle.priceBackgroundColor {
                Text(priceText(for: quote))
                    .font(.custom("HelveticaNeue-CondensedBold", size: 13))
                    .monospacedDigit()
                    .foregroundStyle(Color(nsColor: visualStyle.priceTextColor))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(nsColor: backgroundColor))
                    )
            } else {
                Text(priceText(for: quote))
                    .font(.custom("HelveticaNeue-CondensedBold", size: 13))
                    .monospacedDigit()
                    .foregroundStyle(Color(nsColor: visualStyle.priceTextColor))
            }
        }
    }

    private func priceText(for quote: MarketQuote?) -> String {
        guard let quote else {
            return "--"
        }

        return QuoteFormatting.price(quote)
    }
}
