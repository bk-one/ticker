import AppKit
import SwiftUI
import TickerKit

struct MenuBarContentView: View {
    @ObservedObject var model: TickerStore
    let onAddInstrument: () -> Void

    init(
        model: TickerStore,
        onAddInstrument: @escaping () -> Void = {}
    ) {
        self._model = ObservedObject(wrappedValue: model)
        self.onAddInstrument = onAddInstrument
    }

    var body: some View {
        ZStack {
            VisualEffectBackdrop(material: .popover)
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.08)

            VStack(alignment: .leading, spacing: 0) {
                header
                actionRow(
                    title: "Add Instrument…",
                    trailingSystemImage: "chevron.right",
                    action: onAddInstrument
                )
                sectionDivider
                trackedSection
                sectionDivider
                actionRow(
                    title: "Refresh Now",
                    action: {
                        Task {
                            await model.refresh()
                        }
                    }
                )
                actionRow(
                    title: "Quit",
                    action: {
                        NSApplication.shared.terminate(nil)
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(width: 356)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Options")
                .font(.system(size: 20, weight: .medium))

            Spacer()

            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if let lastUpdated = model.lastUpdated {
                Text(QuoteFormatting.shortTime(lastUpdated))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var trackedSection: some View {
        if model.trackedSymbols.isEmpty {
            Text("No tracked instruments yet.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 12)
        } else if model.trackedSymbols.count > 10 {
            ScrollView {
                trackedRows
            }
            .frame(maxHeight: trackedRowsHeight)
        } else {
            trackedRows
        }
    }

    private var trackedRows: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(model.trackedSymbols, id: \.self) { symbol in
                trackedRow(for: symbol)
            }
        }
    }

    private func actionRow(
        title: String,
        trailingSystemImage: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func trackedRow(for symbol: String) -> some View {
        let quote = model.quote(for: symbol)
        let visualStyle = QuoteFormatting.visualStyle(for: quote)

        return Button {
            _ = model.removeInstrument(symbol: symbol)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)

                Text(symbol)
                    .font(.custom("HelveticaNeue-CondensedBold", size: 14))
                    .foregroundStyle(Color(nsColor: visualStyle.symbolColor))

                Text(quote?.displayName ?? symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.82))
                    .lineLimit(1)

                Spacer(minLength: 8)

                priceView(for: quote, style: visualStyle)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Remove \(symbol)")
    }

    private var trackedRowsHeight: CGFloat {
        let visibleRows = min(model.trackedSymbols.count, 10)
        guard visibleRows > 0 else {
            return 0
        }

        return CGFloat(visibleRows) * 31
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, 6)
    }

    private func priceText(for quote: MarketQuote?) -> String {
        guard let quote else {
            return "--"
        }

        return QuoteFormatting.price(quote)
    }

    @ViewBuilder
    private func priceView(
        for quote: MarketQuote?,
        style: QuoteVisualStyle
    ) -> some View {
        let price = priceText(for: quote)

        if let backgroundColor = style.priceBackgroundColor {
            Text(price)
                .font(.custom("HelveticaNeue-CondensedBold", size: 14))
                .monospacedDigit()
                .foregroundStyle(Color(nsColor: style.priceTextColor))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(nsColor: backgroundColor))
                )
        } else {
            Text(price)
                .font(.custom("HelveticaNeue-CondensedBold", size: 14))
                .monospacedDigit()
                .foregroundStyle(Color(nsColor: style.priceTextColor))
        }
    }
}
