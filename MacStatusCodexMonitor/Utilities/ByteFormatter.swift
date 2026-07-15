import Foundation

enum ByteFormatterUtility {
    static func string(bytes: UInt64) -> String {
        guard bytes > 0 else { return "0 B" }

        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        let roundedValue = value.rounded(toPlaces: 1)
        let numberText: String
        if roundedValue == roundedValue.rounded() {
            numberText = String(Int(roundedValue))
        } else {
            numberText = String(format: "%.1f", roundedValue)
        }

        return "\(numberText) \(units[unitIndex])"
    }

    static func signedString(bytes: Int64) -> String {
        let sign: String
        if bytes > 0 {
            sign = "+"
        } else if bytes < 0 {
            sign = "-"
        } else {
            sign = ""
        }

        return "\(sign)\(string(bytes: bytes.magnitude))"
    }

    static func rate(bytesPerSecond: UInt64) -> String {
        "\(string(bytes: bytesPerSecond))/s"
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
