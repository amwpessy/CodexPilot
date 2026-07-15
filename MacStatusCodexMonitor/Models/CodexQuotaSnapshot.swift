import Foundation

struct CodexQuotaSnapshot: Equatable {
    var sourceDescription: String
    var freshness: Date?
    var limitID: String?
    var usedPercent: Double?
    var remainingPercent: Double?
    var resetsAt: Date?
    var windowMinutes: Int?
    var planType: String?
    var creditsDescription: String
    var individualLimitDescription: String
    var rateLimitReachedType: String?

    static let unavailable = CodexQuotaSnapshot(
        sourceDescription: "local Codex log signal",
        freshness: nil,
        limitID: nil,
        usedPercent: nil,
        remainingPercent: nil,
        resetsAt: nil,
        windowMinutes: nil,
        planType: nil,
        creditsDescription: "Not reported",
        individualLimitDescription: "Not reported",
        rateLimitReachedType: nil
    )
}
