import Foundation

public struct PermissionScope: Codable, Equatable, Identifiable, Sendable {
    public var agentId: String
    public var allowedOperations: [String]
    public var rateLimit: RateLimit
    public var warnings: [String]

    public var id: String { agentId }

    public init(
        agentId: String,
        allowedOperations: [String],
        rateLimit: RateLimit,
        warnings: [String] = []
    ) {
        self.agentId = agentId
        self.allowedOperations = allowedOperations
        self.rateLimit = rateLimit
        self.warnings = warnings
    }
}

public struct RateLimit: Codable, Equatable, Sendable {
    public var limit: Int
    public var used: Int
    public var window: String

    public init(limit: Int, used: Int, window: String) {
        self.limit = limit
        self.used = used
        self.window = window
    }

    public var usageRatio: Double {
        guard limit > 0 else { return 1 }
        return Double(used) / Double(limit)
    }
}
