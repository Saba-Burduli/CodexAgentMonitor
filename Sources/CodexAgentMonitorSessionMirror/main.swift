import CodexAgentMonitorCore
import Foundation

@main
struct CodexAgentMonitorSessionMirror {
    static func main() throws {
        let sessionURL = try sessionPath().standardizedFileURL
        let eventLogURL = eventLogPath().standardizedFileURL
        try FileManager.default.createDirectory(at: eventLogURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let lines = try String(contentsOf: sessionURL, encoding: .utf8).split(whereSeparator: \.isNewline)
        let events = lines.flatMap { CodexSessionEventMapper.events(from: String($0)) }
        let payload = try events.map { try EventCodec.encodeJSONLine($0) }.joined(separator: "\n")
        if !payload.isEmpty {
            let text = payload + "\n"
            if FileManager.default.fileExists(atPath: eventLogURL.path) {
                let handle = try FileHandle(forWritingTo: eventLogURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(text.utf8))
                try handle.close()
            } else {
                try text.write(to: eventLogURL, atomically: true, encoding: .utf8)
            }
        }

        print("session_mirrored=\(sessionURL.path)")
        print("events_written=\(events.count)")
        print("event_log=\(eventLogURL.path)")
    }

    private static func sessionPath() throws -> URL {
        if let path = argumentValue("--session") {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        let sessionsRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
        guard let latest = latestJSONL(under: sessionsRoot) else {
            throw MirrorError.noSessionFound
        }
        return latest
    }

    private static func eventLogPath() -> URL {
        if let path = argumentValue("--event-log") {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex-agent-monitor", isDirectory: true)
            .appendingPathComponent("events.jsonl")
    }

    private static func latestJSONL(under root: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return nil
        }
        return enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "jsonl" }
            .max { lhs, rhs in
                modificationDate(lhs) < modificationDate(rhs)
            }
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private static func argumentValue(_ name: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: name) else { return nil }
        let valueIndex = CommandLine.arguments.index(after: index)
        guard valueIndex < CommandLine.arguments.endIndex else { return nil }
        return CommandLine.arguments[valueIndex]
    }
}

private enum MirrorError: Error {
    case noSessionFound
}
