import Foundation

// Amounts are stored as Int paisa, never Double.
enum Money {
    static let symbol = "৳"
    static let minorUnitsPerMajor = 100
    static let maxAmountMinor = 100_000_000

    private static let groupingFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func format(_ minor: Int) -> String {
        let sign = minor < 0 ? "-" : ""
        let absolute = abs(minor)
        let major = absolute / minorUnitsPerMajor
        let fraction = absolute % minorUnitsPerMajor
        let majorText = groupingFormatter.string(from: NSNumber(value: major)) ?? String(major)
        let fractionText = fraction == 0 ? "" : "." + String(format: "%02d", fraction)
        return "\(sign)\(symbol)\(majorText)\(fractionText)"
    }

    static func editingText(_ minor: Int, decimalSeparator: String = Locale.current.decimalSeparator ?? ".") -> String {
        guard minor > 0 else { return "" }
        let major = minor / minorUnitsPerMajor
        let fraction = minor % minorUnitsPerMajor
        return fraction == 0 ? String(major) : "\(major)\(decimalSeparator)\(String(format: "%02d", fraction))"
    }

    static func parse(_ text: String, decimalSeparator: String = Locale.current.decimalSeparator ?? ".") -> Int? {
        var cleaned = text
            .replacingOccurrences(of: symbol, with: "")
            .replacingOccurrences(of: " ", with: "")
        if decimalSeparator == "," {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }
        guard !cleaned.isEmpty, cleaned.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }) else { return nil }

        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }

        let wholeText = String(parts[0])
        let fractionText = parts.count == 2 ? String(parts[1]) : ""
        guard !(wholeText.isEmpty && fractionText.isEmpty), fractionText.count <= 2, wholeText.count <= 9 else { return nil }

        let whole = Int(wholeText) ?? 0
        let paddedFraction = fractionText.padding(toLength: 2, withPad: "0", startingAt: 0)
        let fraction = Int(paddedFraction) ?? 0
        let minor = whole * minorUnitsPerMajor + fraction
        return minor <= maxAmountMinor ? minor : nil
    }
}
