import CodexAgentMonitorCore
import Foundation

@main
struct CodexAgentMonitorE2ERunner {
    static func main() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let eventLogURL = home
            .appendingPathComponent(".codex-agent-monitor", isDirectory: true)
            .appendingPathComponent("events.jsonl")
        let validationLogURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("logs", isDirectory: true)
            .appendingPathComponent("e2e-validation.log")

        let report = try AgentSimulation.run(eventLogURL: eventLogURL, validationLogURL: validationLogURL)

        print("CodexAgentMonitorE2ERunner: passed")
        print("events_processed=\(report.eventsProcessed)")
        print("checks_passed=\(report.checksPassed)")
        print("final_health=\(report.finalState.health.rawValue)")
        print("final_agents=\(report.finalState.agents.count)")
        print("active_agents=\(report.finalState.activeAgents.count)")
        print("event_log=\(report.eventLogURL.path)")
        print("validation_log=\(report.logURL.path)")
    }
}
