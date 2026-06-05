import Foundation

public struct CodexAgentStatus: Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var sessionId: String
    public var sessionName: String?
    public var status: AgentStatus
    public var currentAction: String
    public var model: String?
    public var reasoningMode: ReasoningMode?
    public var files: [CodexFileActivity]
    public var tokenStatus: TokenStatus?
    public var updatedAt: Date

    public init(
        id: String,
        displayName: String,
        sessionId: String,
        sessionName: String? = nil,
        status: AgentStatus,
        currentAction: String,
        model: String? = nil,
        reasoningMode: ReasoningMode? = nil,
        files: [CodexFileActivity] = [],
        tokenStatus: TokenStatus? = nil,
        updatedAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.status = status
        self.currentAction = currentAction
        self.model = model
        self.reasoningMode = reasoningMode
        self.files = files
        self.tokenStatus = tokenStatus
        self.updatedAt = updatedAt
    }
}

public enum ReasoningMode: String, Codable, Equatable, Sendable {
    case low
    case medium
    case high
    case unknown
}

public struct CodexFileActivity: Equatable, Identifiable, Sendable {
    public var path: String
    public var activity: FileActivityKind
    public var updatedAt: Date

    public var id: String { "\(path)-\(activity.rawValue)" }

    public init(path: String, activity: FileActivityKind, updatedAt: Date) {
        self.path = path
        self.activity = activity
        self.updatedAt = updatedAt
    }
}

public enum FileActivityKind: String, Codable, Equatable, Sendable {
    case reading
    case editing
    case staging
    case committing
    case pushing
}

public struct TokenStatus: Equatable, Sendable {
    public var currentTaskTokens: Int?
    public var contextWindowUsed: Int?
    public var contextWindowLimit: Int?
    public var fiveHourUsedPercent: Double?
    public var weeklyUsedPercent: Double?
    public var fiveHourResetAt: Date?
    public var weeklyResetAt: Date?

    public init(
        currentTaskTokens: Int? = nil,
        contextWindowUsed: Int? = nil,
        contextWindowLimit: Int? = nil,
        fiveHourUsedPercent: Double? = nil,
        weeklyUsedPercent: Double? = nil,
        fiveHourResetAt: Date? = nil,
        weeklyResetAt: Date? = nil
    ) {
        self.currentTaskTokens = currentTaskTokens
        self.contextWindowUsed = contextWindowUsed
        self.contextWindowLimit = contextWindowLimit
        self.fiveHourUsedPercent = fiveHourUsedPercent
        self.weeklyUsedPercent = weeklyUsedPercent
        self.fiveHourResetAt = fiveHourResetAt
        self.weeklyResetAt = weeklyResetAt
    }

    public var contextUsedPercent: Double? {
        guard let contextWindowUsed, let contextWindowLimit, contextWindowLimit > 0 else { return nil }
        return Double(contextWindowUsed) / Double(contextWindowLimit) * 100
    }

    public var contextRemaining: Int? {
        guard let contextWindowUsed, let contextWindowLimit else { return nil }
        return max(0, contextWindowLimit - contextWindowUsed)
    }
}

public struct GitCommitStatus: Equatable, Identifiable, Sendable {
    public var shortHash: String
    public var message: String
    public var branch: String
    public var pushedAt: Date?
    public var localCommitAt: Date?
    public var pushStatus: PushStatus

    public var id: String { shortHash }

    public init(
        shortHash: String,
        message: String,
        branch: String,
        pushedAt: Date? = nil,
        localCommitAt: Date? = nil,
        pushStatus: PushStatus
    ) {
        self.shortHash = shortHash
        self.message = message
        self.branch = branch
        self.pushedAt = pushedAt
        self.localCommitAt = localCommitAt
        self.pushStatus = pushStatus
    }
}

public enum PushStatus: String, Codable, Equatable, Sendable {
    case pushed
    case unpushed
    case unavailable
}

public struct PermissionStatus: Equatable, Sendable {
    public var commandExecution: PermissionMode
    public var fileWrites: PermissionMode
    public var gitPush: PermissionMode
    public var pendingApprovals: Int
    public var pendingActions: [String]

    public init(
        commandExecution: PermissionMode = .unavailable,
        fileWrites: PermissionMode = .unavailable,
        gitPush: PermissionMode = .unavailable,
        pendingApprovals: Int = 0,
        pendingActions: [String] = []
    ) {
        self.commandExecution = commandExecution
        self.fileWrites = fileWrites
        self.gitPush = gitPush
        self.pendingApprovals = pendingApprovals
        self.pendingActions = pendingActions
    }
}

public enum PermissionMode: String, Codable, Equatable, Sendable {
    case allowed
    case denied
    case approvalRequired
    case unavailable
}

public struct SkillStatus: Equatable, Sendable {
    public var enabled: [String]
    public var disabled: [String]
    public var isAvailable: Bool

    public init(enabled: [String] = [], disabled: [String] = [], isAvailable: Bool = false) {
        self.enabled = enabled
        self.disabled = disabled
        self.isAvailable = isAvailable
    }
}

public struct CodexSessionStatus: Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String?
    public var agents: [CodexAgentStatus]
    public var updatedAt: Date

    public init(id: String, name: String? = nil, agents: [CodexAgentStatus] = [], updatedAt: Date) {
        self.id = id
        self.name = name
        self.agents = agents
        self.updatedAt = updatedAt
    }
}
