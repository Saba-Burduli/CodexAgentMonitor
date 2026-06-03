import Foundation

public enum MonitorTabKind: String, Codable, Equatable, Sendable {
    case overview
    case settings

    public var title: String {
        switch self {
        case .overview: "Overview"
        case .settings: "Settings"
        }
    }

    public var isClosable: Bool {
        switch self {
        case .overview: false
        case .settings: true
        }
    }
}

public struct MonitorTab: Identifiable, Equatable, Sendable {
    public var kind: MonitorTabKind

    public var id: MonitorTabKind { kind }
    public var title: String { kind.title }
    public var isClosable: Bool { kind.isClosable }

    public init(kind: MonitorTabKind) {
        self.kind = kind
    }
}

public struct MonitorTabState: Equatable, Sendable {
    public private(set) var tabs: [MonitorTab]
    public private(set) var selected: MonitorTabKind

    public init(tabs: [MonitorTab] = [MonitorTab(kind: .overview)], selected: MonitorTabKind = .overview) {
        let normalized = tabs.isEmpty ? [MonitorTab(kind: .overview)] : tabs
        self.tabs = normalized.contains(where: { $0.kind == .overview }) ? normalized : [MonitorTab(kind: .overview)] + normalized
        self.selected = self.tabs.contains(where: { $0.kind == selected }) ? selected : .overview
    }

    public mutating func open(_ kind: MonitorTabKind) {
        if !tabs.contains(where: { $0.kind == kind }) {
            tabs.append(MonitorTab(kind: kind))
        }
        selected = kind
    }

    public mutating func select(_ kind: MonitorTabKind) {
        guard tabs.contains(where: { $0.kind == kind }) else { return }
        selected = kind
    }

    public mutating func close(_ kind: MonitorTabKind) {
        guard let tab = tabs.first(where: { $0.kind == kind }), tab.isClosable else { return }
        tabs.removeAll { $0.kind == kind }
        if selected == kind {
            selected = tabs.first?.kind ?? .overview
        }
    }
}
