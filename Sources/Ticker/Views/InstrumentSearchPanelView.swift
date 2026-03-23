import AppKit
import SwiftUI
import TickerKit

struct InstrumentSearchPanelView: View {
    @ObservedObject var model: InstrumentSearchViewModel
    let onDismiss: () -> Void
    private let panelCornerRadius: CGFloat = 22

    var body: some View {
        ZStack {
            VisualEffectBackdrop(material: .hudWindow)
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.12)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.16),
                    Color.white.opacity(0.04),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.46, blue: 0.50).opacity(0.18),
                    .clear,
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )

            VStack(alignment: .leading, spacing: 14) {
                header
                searchFieldSection
                contentSection
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
        )
        .frame(width: 548)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Instrument")
                    .font(.system(size: 18, weight: .semibold))

                Text("Search by ticker or name across stocks, commodities, and crypto.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack(spacing: 6) {
                keycap("ESC")

                Text("Close")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var searchFieldSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                SearchQueryField(
                    text: Binding(
                        get: { model.query },
                        set: { model.updateQuery($0) }
                    ),
                    focusRequestID: model.focusRequestID,
                    placeholder: "Search stocks, commodities, or crypto",
                    onMoveUp: {
                        model.moveSelection(by: -1)
                    },
                    onMoveDown: {
                        model.moveSelection(by: 1)
                    },
                    onSubmit: {
                        Task {
                            await model.submitSelection()
                        }
                    },
                    onEscape: onDismiss
                )
                .frame(height: 24)

                if model.isSearching {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(searchFieldBackground)

            helperLine
        }
    }

    @ViewBuilder
    private var helperLine: some View {
        if let confirmationMessage = model.confirmationMessage {
            statusLine(
                text: confirmationMessage,
                systemImage: "checkmark.circle.fill",
                tint: Color.green.opacity(0.74)
            )
        } else if let errorMessage = model.errorMessage {
            statusLine(
                text: errorMessage,
                systemImage: "exclamationmark.triangle.fill",
                tint: Color.orange.opacity(0.74)
            )
        } else if model.isSearching {
            statusLine(
                text: "Searching Yahoo Finance…",
                systemImage: "waveform.and.magnifyingglass",
                tint: Color.accentColor.opacity(0.72)
            )
        } else {
            HStack(spacing: 8) {
                keycap("RETURN")
                Text("adds highlighted")
                dotDivider
                keycap("ESC")
                Text("closes")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if !model.results.isEmpty {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                        resultRow(for: result, index: index)
                    }
                }
            }
            .frame(maxHeight: resultListHeight)
            .padding(6)
            .background(resultsBackground)
        } else if model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            emptyStateCard(
                title: "Start with a ticker or name",
                message: "Try a stock, commodity future, ETF, or crypto pair.",
                examples: ["AAPL", "GC=F", "BTC-USD", "GLD"]
            )
        } else if !model.isSearching,
                  model.errorMessage == nil,
                  model.confirmationMessage == nil {
            emptyStateCard(
                title: "No matches",
                message: "Try a shorter symbol or broader instrument name.",
                examples: ["Gold", "Bitcoin", "Apple", "Silver"]
            )
        }
    }

    private func statusLine(
        text: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var resultListHeight: CGFloat {
        let visibleRows = min(model.results.count, 8)
        guard visibleRows > 0 else {
            return 0
        }

        return (CGFloat(visibleRows) * 40) + (CGFloat(max(visibleRows - 1, 0)) * 4) + 8
    }

    private var searchFieldBackground: some View {
        GlassCardBackground(
            material: .sidebar,
            cornerRadius: 16
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var resultsBackground: some View {
        GlassCardBackground(
            material: .popover,
            cornerRadius: 18
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.08))
        )
    }

    private func emptyStateCard(
        title: String,
        message: String,
        examples: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(examples, id: \.self) { example in
                    exampleChip(example)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(resultsBackground)
    }

    private func resultRow(for result: InstrumentSearchResult, index: Int) -> some View {
        let isTracked = model.isTracked(result)
        let isSelected = model.selectedIndex == index && !isTracked

        return Button {
            Task {
                await model.select(result)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(result.symbol)
                            .font(.custom("HelveticaNeue-CondensedBold", size: 16))
                            .foregroundStyle(isTracked ? .secondary : .primary)

                        resultTag(
                            text: isTracked ? "Added" : result.label,
                            isTracked: isTracked
                        )
                    }

                    Text(result.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let currentPrice = result.currentPrice {
                    Text(QuotePresentation.formattedPrice(for: currentPrice))
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(isTracked ? .secondary : .primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.accentColor.opacity(0.14)
                        : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected
                        ? Color.accentColor.opacity(0.24)
                        : Color.white.opacity(0.04),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isTracked)
    }

    private func resultTag(
        text: String,
        isTracked: Bool
    ) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(isTracked ? Color.green.opacity(0.85) : .secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isTracked
                        ? Color.green.opacity(0.12)
                        : Color(nsColor: .quaternaryLabelColor).opacity(0.16)
                    )
            )
    }

    private func exampleChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func keycap(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private var dotDivider: some View {
        Circle()
            .fill(Color.secondary.opacity(0.45))
            .frame(width: 3, height: 3)
    }
}

private struct SearchQueryField: NSViewRepresentable {
    @Binding var text: String
    let focusRequestID: Int
    let placeholder: String
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onSubmit: () -> Void
    let onEscape: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> SpotlightSearchField {
        let searchField = SpotlightSearchField(frame: .zero)
        searchField.delegate = context.coordinator
        searchField.focusRingType = .none
        searchField.font = .systemFont(ofSize: 18, weight: .medium)
        searchField.placeholderString = placeholder
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.cell?.usesSingleLineMode = true
        searchField.sendsSearchStringImmediately = true
        searchField.lineBreakMode = .byTruncatingTail
        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.font = searchField.font
            cell.searchButtonCell = nil
            cell.cancelButtonCell = nil
        }
        searchField.onMoveUp = onMoveUp
        searchField.onMoveDown = onMoveDown
        searchField.onSubmit = onSubmit
        searchField.onEscape = onEscape
        searchField.stringValue = text
        return searchField
    }

    func updateNSView(_ searchField: SpotlightSearchField, context: Context) {
        if searchField.stringValue != text {
            searchField.stringValue = text
        }

        searchField.onMoveUp = onMoveUp
        searchField.onMoveDown = onMoveDown
        searchField.onSubmit = onSubmit
        searchField.onEscape = onEscape

        guard context.coordinator.lastFocusRequestID != focusRequestID else {
            return
        }

        context.coordinator.lastFocusRequestID = focusRequestID

        DispatchQueue.main.async {
            searchField.window?.makeFirstResponder(searchField)
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        var lastFocusRequestID = 0

        init(text: Binding<String>) {
            self._text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else {
                return
            }

            text = textField.stringValue
        }
    }
}

private final class SpotlightSearchField: NSSearchField {
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 126:
            onMoveUp?()
        case 125:
            onMoveDown?()
        case 36, 76:
            onSubmit?()
        case 53:
            onEscape?()
        default:
            super.keyDown(with: event)
        }
    }
}

struct VisualEffectBackdrop: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active
    var emphasized = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = state
        visualEffectView.isEmphasized = emphasized
        return visualEffectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.isEmphasized = emphasized
    }
}

struct GlassCardBackground: View {
    let material: NSVisualEffectView.Material
    let cornerRadius: CGFloat

    var body: some View {
        VisualEffectBackdrop(
            material: material,
            blendingMode: .withinWindow
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
