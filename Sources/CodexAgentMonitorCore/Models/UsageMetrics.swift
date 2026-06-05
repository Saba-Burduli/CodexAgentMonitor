import Foundation

public struct UsageMetrics: Codable, Equatable, Sendable {
    public var window5h: Int
    public var window7d: Int
    public var total: Int
    public var remaining: Int?
    public var contextWindowUsed: Int?
    public var contextWindowLimit: Int?
    public var fiveHourUsedPercent: Double?
    public var weeklyUsedPercent: Double?
    public var fiveHourResetAt: Date?
    public var weeklyResetAt: Date?
    public var trend: UsageTrend
    public var updatedAt: Date

    public init(
        window5h: Int = 0,
        window7d: Int = 0,
        total: Int = 0,
        remaining: Int? = nil,
        contextWindowUsed: Int? = nil,
        contextWindowLimit: Int? = nil,
        fiveHourUsedPercent: Double? = nil,
        weeklyUsedPercent: Double? = nil,
        fiveHourResetAt: Date? = nil,
        weeklyResetAt: Date? = nil,
        trend: UsageTrend = .stable,
        updatedAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.window5h = window5h
        self.window7d = window7d
        self.total = total
        self.remaining = remaining
        self.contextWindowUsed = contextWindowUsed
        self.contextWindowLimit = contextWindowLimit
        self.fiveHourUsedPercent = fiveHourUsedPercent
        self.weeklyUsedPercent = weeklyUsedPercent
        self.fiveHourResetAt = fiveHourResetAt
        self.weeklyResetAt = weeklyResetAt
        self.trend = trend
        self.updatedAt = updatedAt
    }

    public var remainingRatio: Double? {
        guard let remaining else { return nil }
        let consumed = max(total, 0)
        let capacity = consumed + max(remaining, 0)
        guard capacity > 0 else { return nil }
        return Double(remaining) / Double(capacity)
    }
}

public enum UsageTrend: String, Codable, CaseIterable, Sendable {
    case falling
    case stable
    case rising
    case spiking
}
