import Foundation

public enum EventCodec {
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    public static func decodeJSONLines(_ text: String) -> [MonitorEvent] {
        text.split(whereSeparator: \ .isNewline).compactMap { line in
            try? decoder.decode(MonitorEvent.self, from: Data(line.utf8))
        }
    }

    public static func encodeJSONLine(_ event: MonitorEvent) throws -> String {
        let data = try encoder.encode(event)
        return String(decoding: data, as: UTF8.self)
    }
}
