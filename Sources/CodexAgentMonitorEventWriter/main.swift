import CodexAgentMonitorCore
import Foundation

@main
struct CodexAgentMonitorEventWriter {
    static func main() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let eventLogURL = home
            .appendingPathComponent(".codex-agent-monitor", isDirectory: true)
            .appendingPathComponent("events.jsonl")
        try FileManager.default.createDirectory(at: eventLogURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let now = Date()
        let event = MonitorEvent.agentStatusUpdate(AgentTelemetry(
            id: "manual-writer",
            name: "Manual Event Writer",
            status: .running,
            currentTask: "Emit local integration event",
            startedAt: now,
            updatedAt: now,
            activity: "Wrote event through CodexAgentMonitorEventWriter"
        ))

        let line = try EventCodec.encodeJSONLine(event) + "\n"
        if FileManager.default.fileExists(atPath: eventLogURL.path) {
            let handle = try FileHandle(forWritingTo: eventLogURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
            try handle.close()
        } else {
            try line.write(to: eventLogURL, atomically: true, encoding: .utf8)
        }

        print("event_written=\(eventLogURL.path)")
    }
}
