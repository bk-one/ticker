import AppKit
import SwiftUI
import TickerKit

struct MenuBarContentView: View {
    @ObservedObject var model: TickerStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.97, blue: 0.94),
                    Color.white,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.96, green: 0.74, blue: 0.33).opacity(0.22))
                .frame(width: 180, height: 180)
                .blur(radius: 30)
                .offset(x: 120, y: -170)

            VStack(alignment: .leading, spacing: 16) {
                header
                statusBanner
                quoteCard
                footer
            }
            .padding(16)
        }
        .frame(width: 340)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ticker")
                    .font(.system(size: 22, weight: .black, design: .rounded))

                Text("Bootstrapped menu bar display for the default AAPL ticker.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                Task {
                    await model.refresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let message = model.errorMessage,
           model.quote != nil {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(Color(red: 0.66, green: 0.26, blue: 0.08))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.99, green: 0.95, blue: 0.87))
                )
        } else if let lastUpdated = model.lastUpdated {
            Label("Last update \(QuoteFormatting.shortTime(lastUpdated))", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                )
        } else {
            Label("Loading live price for AAPL", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                )
        }
    }

    @ViewBuilder
    private var quoteCard: some View {
        if let quote = model.quote {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.displaySymbol)
                    .font(.system(size: 20, weight: .semibold))
                    .fontWidth(.condensed)

                Text(quote.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(QuoteFormatting.price(quote))
                    .font(.system(size: 30, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(QuoteFormatting.color(for: quote))

                if let toneSummary = QuoteFormatting.toneSummary(quote) {
                    Text(toneSummary)
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(QuoteFormatting.color(for: quote))
                }

                Text(colorBasisLine(for: quote))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(quote.exchangeName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.04))
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(QuoteFormatting.loadingPlaceholder(for: model.displaySymbol))
                    .font(.system(size: 28, weight: .semibold))
                    .fontWidth(.condensed)
                    .monospacedDigit()

                Text("Loading the first live quote. The menu bar stays populated instead of showing a blank state.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let message = model.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.66, green: 0.26, blue: 0.08))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.04))
            )
        }
    }

    private var footer: some View {
        HStack {
            Text("Refreshes every 60 seconds")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
    }

    private func colorBasisLine(for quote: MarketQuote) -> String {
        switch quote.tone?.basis {
        case .fifteenMinutes:
            return "Color intensity is based on the last 15 minutes."
        case .previousCloseFallback:
            return "15-minute data unavailable. Color uses the last active trading day."
        case nil:
            return "Color stays neutral until comparison data is available."
        }
    }
}
