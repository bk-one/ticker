import SwiftUI
import TickerKit

struct MenuBarLabel: View {
    @ObservedObject var model: TickerStore

    var body: some View {
        HStack(spacing: 6) {
            Text(model.displaySymbol)
                .font(.system(size: 13, weight: .regular))
                .fontWidth(.condensed)
                .foregroundStyle(.primary)

            Text(priceText)
                .font(.system(size: 13, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(QuoteFormatting.color(for: model.quote))
        }
    }

    private var priceText: String {
        guard let quote = model.quote else {
            return "--"
        }

        return QuoteFormatting.price(quote)
    }
}
