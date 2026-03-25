import AppKit
import SwiftUI
import TickerKit

struct MenuBarContentView: View {
    @ObservedObject var model: TickerStore
    let onAddInstrument: () -> Void

    @State private var editingAlertSymbol: String?

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

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        trackedSection
                        alertsSection
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 286)

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
        .frame(width: 356, height: 440)
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

    private var trackedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Tracked",
                subtitle: model.trackedSymbols.isEmpty ? "No tracked instruments yet." : "\(model.trackedSymbols.count) active"
            )

            if model.trackedSymbols.isEmpty {
                Text("Add an instrument from search, then manage alerts below.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.trackedSymbols, id: \.self) { symbol in
                        trackedRow(for: symbol)
                    }
                }
            }
        }
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Alerts",
                subtitle: "Create and manage price boundaries from the dropdown."
            )

            if model.trackedSymbols.isEmpty {
                Text("Track an instrument to configure an alert.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.trackedSymbols, id: \.self) { symbol in
                        alertRow(for: symbol)
                    }
                }
            }
        }
    }

    private func trackedRow(for symbol: String) -> some View {
        let quote = model.quote(for: symbol)
        let visualStyle = QuoteFormatting.visualStyle(
            for: quote,
            alertTriggered: model.isAlertTriggered(for: symbol)
        )

        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(symbol)
                    .font(.custom("HelveticaNeue-CondensedBold", size: 14))
                    .foregroundStyle(Color(nsColor: visualStyle.symbolColor))

                Text(quote?.displayName ?? symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            priceView(for: quote, style: visualStyle)

            Button {
                if editingAlertSymbol == symbol {
                    editingAlertSymbol = nil
                }

                _ = model.removeInstrument(symbol: symbol)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.9))
            }
            .buttonStyle(.plain)
            .help("Remove \(symbol)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(sectionCardBackground)
    }

    private func alertRow(for symbol: String) -> some View {
        let quote = model.quote(for: symbol)
        let boundary = model.alertBoundary(for: symbol)
        let isEditing = editingAlertSymbol == symbol
        let isTriggered = model.isAlertTriggered(for: symbol)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(symbol)
                            .font(.custom("HelveticaNeue-CondensedBold", size: 14))

                        if isTriggered {
                            statusBadge(
                                title: "Triggered",
                                tint: Color.orange.opacity(0.18),
                                foreground: .orange
                            )
                        } else if boundary != nil {
                            statusBadge(
                                title: "Active",
                                tint: Color.accentColor.opacity(0.16),
                                foreground: .accentColor
                            )
                        }
                    }

                    Text(alertSummary(for: symbol, quote: quote))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button(isEditing ? "Done" : (boundary == nil ? "Set" : "Edit")) {
                    editingAlertSymbol = isEditing ? nil : symbol
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if isEditing {
                AlertEditorCard(
                    symbol: symbol,
                    quote: quote,
                    boundary: boundary,
                    onSave: { upper, lower in
                        _ = model.saveAlertBoundary(symbol: symbol, upper: upper, lower: lower)
                        editingAlertSymbol = nil
                    },
                    onClear: {
                        model.clearAlertBoundary(symbol: symbol)
                        editingAlertSymbol = nil
                    },
                    onCancel: {
                        editingAlertSymbol = nil
                    }
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(sectionCardBackground)
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

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }

    private func statusBadge(
        title: String,
        tint: Color,
        foreground: Color
    ) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(tint)
            )
    }

    private var sectionCardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, 6)
    }

    private func alertSummary(
        for symbol: String,
        quote: MarketQuote?
    ) -> String {
        guard let boundary = model.alertBoundary(for: symbol) else {
            return "No alert configured"
        }

        let upperText = boundary.upper.map {
            "Upper \(formattedBoundaryValue($0, quote: quote))"
        }

        let lowerText = boundary.lower.map {
            "Lower \(formattedBoundaryValue($0, quote: quote))"
        }

        let parts = [upperText, lowerText].compactMap { $0 }

        if parts.isEmpty {
            return "No alert configured"
        }

        let joined = parts.joined(separator: " • ")

        if let currencyCode = quote?.currencyCode {
            return "\(joined) \(currencyCode)"
        }

        return joined
    }

    private func formattedBoundaryValue(
        _ value: Double,
        quote: MarketQuote?
    ) -> String {
        if let quote {
            return AlertEditorCard.formattedInputValue(value, quote: quote)
        }

        return QuotePresentation.formattedPrice(for: value)
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

private struct AlertEditorCard: View {
    let symbol: String
    let quote: MarketQuote?
    let boundary: PriceAlertBoundary?
    let onSave: (Double?, Double?) -> Void
    let onClear: () -> Void
    let onCancel: () -> Void

    @State private var upperInput: String
    @State private var lowerInput: String
    @State private var validationMessage: String?

    init(
        symbol: String,
        quote: MarketQuote?,
        boundary: PriceAlertBoundary?,
        onSave: @escaping (Double?, Double?) -> Void,
        onClear: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.quote = quote
        self.boundary = boundary
        self.onSave = onSave
        self.onClear = onClear
        self.onCancel = onCancel
        _upperInput = State(initialValue: Self.initialInput(for: boundary?.upper, quote: quote))
        _lowerInput = State(initialValue: Self.initialInput(for: boundary?.lower, quote: quote))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(symbol) Price Alert")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text(quote?.currencyCode ?? "N/A")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            boundaryField(
                title: "Upper",
                placeholder: "300.00",
                text: $upperInput
            )

            boundaryField(
                title: "Lower",
                placeholder: "210.00",
                text: $lowerInput
            )

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 8) {
                Button("Clear") {
                    onClear()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
    }

    private func boundaryField(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
        }
    }

    private func save() {
        validationMessage = nil

        guard let upper = parseBoundary(upperInput, label: "upper") else {
            return
        }

        guard let lower = parseBoundary(lowerInput, label: "lower") else {
            return
        }

        if let upper, let lower, upper <= lower {
            validationMessage = "Upper boundary must be greater than lower boundary."
            return
        }

        onSave(upper, lower)
    }

    private func parseBoundary(
        _ input: String,
        label: String
    ) -> Double?? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedInput.isEmpty else {
            return .some(nil)
        }

        if let value = Double(trimmedInput) {
            return .some(value)
        }

        validationMessage = "Enter a valid \(label) boundary."
        return nil
    }

    private static func initialInput(
        for value: Double?,
        quote: MarketQuote?
    ) -> String {
        guard let value else {
            return ""
        }

        if let quote {
            return formattedInputValue(value, quote: quote)
        }

        return QuotePresentation.formattedPrice(for: value)
    }

    static func formattedInputValue(
        _ value: Double,
        quote: MarketQuote
    ) -> String {
        if let priceHint = quote.priceHint {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = max(priceHint, 0)
            formatter.maximumFractionDigits = max(priceHint, 0)
            formatter.usesGroupingSeparator = false
            if let formatted = formatter.string(from: NSNumber(value: value)) {
                return formatted
            }
        }

        return QuotePresentation.formattedPrice(for: value)
    }
}
