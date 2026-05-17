import Foundation

public enum SystemHealth: String, Codable, Equatable, Sendable {
    case healthy
    case warning
    case critical

    public var label: String {
        switch self {
        case .healthy: "Healthy"
        case .warning: "High Usage"
        case .critical: "Critical"
        }
    }
}
