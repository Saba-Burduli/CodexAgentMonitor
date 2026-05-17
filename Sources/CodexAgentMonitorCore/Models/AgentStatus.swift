import Foundation

public enum AgentStatus: String, Codable, CaseIterable, Sendable {
    case idle
    case running
    case blocked
    case completed
    case error

    public var isActive: Bool {
        switch self {
        case .idle, .running, .blocked:
            true
        case .completed, .error:
            false
        }
    }
}
