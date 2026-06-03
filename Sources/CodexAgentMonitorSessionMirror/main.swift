import CodexAgentMonitorCore
import Foundation

@main
struct CodexAgentMonitorSessionMirror {
    static func main() throws {
        let sessionURL = try sessionPath().standardizedFileURL
        let eventLogURL = eventLogPath().standardizedFileURL
        try FileManager.default.createDirectory(at: eventLogURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        if CommandLine.arguments.contains("--follow") {
            try follow(sessionURL: sessionURL, eventLogURL: eventLogURL)
        } else {
            let lines = try String(contentsOf: sessionURL, encoding: .utf8).split(whereSeparator: \.isNewline)
            let events = lines.flatMap { CodexSessionEventMapper.events(from: String($0)) }
            try append(events, to: eventLogURL)
            print("session_mirrored=\(sessionURL.path)")
            print("events_written=\(events.count)")
            print("event_log=\(eventLogURL.path)")
        }
    }

    private static func follow(sessionURL: URL, eventLogURL: URL) throws {
        let interval = doubleArgumentValue("--poll-interval") ?? 1
        let maxPolls = intArgumentValue("--max-polls")
        var offset: UInt64 = 0
        var pending = ""
        var polls = 0
        var totalEvents = 0

        print("session_following=\(sessionURL.path)")
        print("event_log=\(eventLogURL.path)")

        while maxPolls.map({ polls < $0 }) ?? true {
            let events = try readNewEvents(from: sessionURL, offset: &offset, pending: &pending)
            try append(events, to: eventLogURL)
            totalEvents += events.count
            polls += 1

            if !events.isEmpty {
                print("events_written=\(events.count)")
            }
            if maxPolls.map({ polls < $0 }) ?? true {
                Thread.sleep(forTimeInterval: interval)
            }
        }

        print("total_events_written=\(totalEvents)")
    }

    private static func readNewEvents(from url: URL, offset: inout UInt64, pending: inout String) throws -> [MonitorEvent] {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? UInt64 ?? 0
        if size < offset {
            offset = 0
            pending = ""
        }
        guard size > offset else { return [] }

        let handle = try FileHandle(forReadingFrom: url)
        try handle.seek(toOffset: offset)
        let data = try handle.readToEnd() ?? Data()
        try handle.close()
        offset += UInt64(data.count)

        pending += String(decoding: data, as: UTF8.self)
        let hasTrailingNewline = pending.last.map(\.isNewline) ?? false
        var lines = pending.split(whereSeparator: \.isNewline).map(String.init)
        if !hasTrailingNewline {
            pending = lines.popLast() ?? pending
        } else {
            pending = ""
        }
        return lines.flatMap { CodexSessionEventMapper.events(from: $0) }
    }

    private static func append(_ events: [MonitorEvent], to eventLogURL: URL) throws {
        let payload = try events.map { try EventCodec.encodeJSONLine($0) }.joined(separator: "\n")
        guard !payload.isEmpty else { return }

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

    private static func intArgumentValue(_ name: String) -> Int? {
        argumentValue(name).flatMap(Int.init)
    }

    private static func doubleArgumentValue(_ name: String) -> Double? {
        argumentValue(name).flatMap(Double.init)
    }
}

private enum MirrorError: Error {
    case noSessionFound
}
