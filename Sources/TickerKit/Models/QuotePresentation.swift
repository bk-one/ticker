import Foundation

public enum QuotePresentation {
    public static func formattedPrice(
        for price: Double,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let digits = fractionDigits(for: price)
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = price >= 1_000
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits

        if let formatted = formatter.string(from: NSNumber(value: price)) {
            return formatted
        }

        return String(format: "%.\(digits)f", price)
    }

    public static func formattedSignedPercent(
        _ percent: Double,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"

        if let formatted = formatter.string(from: NSNumber(value: percent / 100)) {
            return formatted
        }

        return String(format: "%+.2f%%", percent)
    }

    public static func fractionDigits(for price: Double) -> Int {
        let absolutePrice = abs(price)

        if absolutePrice >= 1_000 {
            return 0
        }

        if absolutePrice >= 10 {
            return 2
        }

        if absolutePrice >= 1 {
            return 3
        }

        return 4
    }
}
