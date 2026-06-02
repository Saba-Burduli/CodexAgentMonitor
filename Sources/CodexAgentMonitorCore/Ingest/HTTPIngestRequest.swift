import Foundation

public enum HTTPIngestRequest {
    public static func decodeEvent(from request: String) throws -> MonitorEvent {
        let parts = request.components(separatedBy: "\r\n\r\n")
        guard parts.count >= 2 else { throw HTTPIngestRequestError.missingBody }

        let headerBlock = parts[0]
        let body = parts.dropFirst().joined(separator: "\r\n\r\n")
        let headerLines = headerBlock.components(separatedBy: "\r\n")
        guard let requestLine = headerLines.first else { throw HTTPIngestRequestError.invalidRequestLine }

        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count >= 2 else { throw HTTPIngestRequestError.invalidRequestLine }
        guard requestParts[0] == "POST" else { throw HTTPIngestRequestError.unsupportedMethod }
        guard requestParts[1] == "/events" else { throw HTTPIngestRequestError.unsupportedPath }

        let headers = Dictionary(uniqueKeysWithValues: headerLines.dropFirst().compactMap { line -> (String, String)? in
            guard let separator = line.firstIndex(of: ":") else { return nil }
            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            return (key, value)
        })

        if let contentLength = headers["content-length"].flatMap(Int.init) {
            guard Data(body.utf8).count == contentLength else { throw HTTPIngestRequestError.contentLengthMismatch }
        }

        guard let event = try? EventCodec.decoder.decode(MonitorEvent.self, from: Data(body.utf8)) else {
            throw HTTPIngestRequestError.invalidEventJSON
        }
        return event
    }
}

public enum HTTPIngestRequestError: Error, Equatable, Sendable {
    case missingBody
    case invalidRequestLine
    case unsupportedMethod
    case unsupportedPath
    case contentLengthMismatch
    case invalidEventJSON
}
