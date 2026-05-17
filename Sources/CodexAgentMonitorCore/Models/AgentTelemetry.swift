import Foundation

public struct AgentTelemetry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var status: AgentStatus
    public var currentTask: String
    public var startedAt: Date
    public var updatedAt: Date
    public var activity: String

    public init(
        id: String,
        name: String,
        status: AgentStatus,
        currentTask: String,
        startedAt: Date,
        updatedAt: Date,
        activity: String = "Waiting for activity"
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.currentTask = currentTask
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.activity = activity
    }

    public func duration(asOf date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(startedAt))
    }
}
