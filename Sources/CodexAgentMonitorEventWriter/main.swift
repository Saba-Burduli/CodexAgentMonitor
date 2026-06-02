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
        let status = AgentStatus(rawValue: argumentValue("--status") ?? "running") ?? .running
        let event = MonitorEvent.agentStatusUpdate(AgentTelemetry(
            id: argumentValue("--id") ?? "manual-writer",
            name: argumentValue("--name") ?? "Manual Event Writer",
            status: status,
            currentTask: argumentValue("--task") ?? "Emit local integration event",
            startedAt: now,
            updatedAt: now,
            activity: argumentValue("--activity") ?? "Wrote event through CodexAgentMonitorEventWriter"
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

    private static func argumentValue(_ name: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: name) else { return nil }
        let valueIndex = CommandLine.arguments.index(after: index)
        guard valueIndex < CommandLine.arguments.endIndex else { return nil }
        return CommandLine.arguments[valueIndex]
    }
}
