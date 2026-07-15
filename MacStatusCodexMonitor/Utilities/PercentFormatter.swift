import Foundation

enum PercentFormatterUtility {
    static func string(_ percent: Double?) -> String {
        guard let percent else { return "Not reported" }
        return "\(Int(percent.rounded()))%"
    }
}
