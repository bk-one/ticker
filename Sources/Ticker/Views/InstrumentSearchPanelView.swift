import AppKit
import SwiftUI
import TickerKit

struct InstrumentSearchPanelView: View {
    @ObservedObject var model: InstrumentSearchViewModel
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            VisualEffectBackdrop(material: .hudWindow)

            VStack(alignment: .leading, spacing: 14) {
                SearchQueryField(
                    text: Binding(
                        get: { model.query },
                        set: { model.updateQuery($0) }
                    ),
                    focusRequestID: model.focusRequestID,
                    placeholder: "Search stocks, commodities and crypto...",
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

                if let confirmationMessage = model.confirmationMessage {
                    Label(confirmationMessage, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if model.isSearching {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching Yahoo Finance...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let errorMessage = model.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !model.results.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                                resultRow(for: result, index: index)
                            }
                        }
                    }
                    .frame(maxHeight: 440)
                }
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 26, y: 10)
        .padding(12)
        .frame(width: 580)
    }

    private func resultRow(for result: InstrumentSearchResult, index: Int) -> some View {
        let isTracked = model.isTracked(result)
        let isSelected = model.selectedIndex == index && !isTracked

        return Button {
            Task {
                await model.select(result)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.symbol)
                        .font(.custom("HelveticaNeue-CondensedBold", size: 18))
                        .foregroundStyle(isTracked ? .secondary : .primary)

                    Text(result.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(result.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.18))
                        )

                    if isTracked {
                        Label("Added", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(isTracked)
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
        searchField.focusRingType = .default
        searchField.font = .systemFont(ofSize: 26, weight: .semibold)
        searchField.placeholderString = placeholder
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.cell?.usesSingleLineMode = true
        searchField.sendsSearchStringImmediately = true
        searchField.lineBreakMode = .byTruncatingTail
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

private struct VisualEffectBackdrop: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}
