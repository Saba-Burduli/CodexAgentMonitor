import Foundation

public struct AgentTelemetry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var status: AgentStatus
    public var currentTask: String
    public var startedAt: Date
    public var updatedAt: Date
    public var activity: String
    public var sessionId: String?
    public var sessionName: String?
    public var model: String?
    public var reasoningMode: ReasoningMode?

    public init(
        id: String,
        name: String,
        status: AgentStatus,
        currentTask: String,
        startedAt: Date,
        updatedAt: Date,
        activity: String = "Waiting for activity",
        sessionId: String? = nil,
        sessionName: String? = nil,
        model: String? = nil,
        reasoningMode: ReasoningMode? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.currentTask = currentTask
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.activity = activity
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.model = model
        self.reasoningMode = reasoningMode
    }

    public func duration(asOf date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(startedAt))
    }
}
