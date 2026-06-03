import Foundation

public struct SessionActivity: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var timestamp: Date
    public var category: String
    public var title: String
    public var detail: String

    public init(
        id: String = UUID().uuidString,
        timestamp: Date,
        category: String,
        title: String,
        detail: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.title = title
        self.detail = detail
    }
}
