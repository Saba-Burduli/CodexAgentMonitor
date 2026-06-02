import CodexAgentMonitorCore
import Foundation
import Network

@main
struct CodexAgentMonitorIngestDaemon {
    static func main() throws {
        let once = CommandLine.arguments.contains("--once")
        let port = NWEndpoint.Port(rawValue: UInt16(argumentValue("--port") ?? "8765") ?? 8765)!
        let eventLogURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex-agent-monitor", isDirectory: true)
            .appendingPathComponent("events.jsonl")

        let server = try HTTPIngestServer(port: port, eventLogURL: eventLogURL, once: once)
        try server.start()
    }

    private static func argumentValue(_ name: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: name) else { return nil }
        let valueIndex = CommandLine.arguments.index(after: index)
        guard valueIndex < CommandLine.arguments.endIndex else { return nil }
        return CommandLine.arguments[valueIndex]
    }
}

private final class HTTPIngestServer: @unchecked Sendable {
    private let listener: NWListener
    private let eventLogURL: URL
    private let once: Bool
    private let queue = DispatchQueue(label: "codex-agent-monitor-ingest")
    private let group = DispatchGroup()

    init(port: NWEndpoint.Port, eventLogURL: URL, once: Bool) throws {
        self.listener = try NWListener(using: .tcp, on: port)
        self.eventLogURL = eventLogURL
        self.once = once
    }

    func start() throws {
        try FileManager.default.createDirectory(at: eventLogURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        group.enter()

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                print("ingest_listening=127.0.0.1:\(self.listener.port?.rawValue ?? 0)")
                fflush(stdout)
            }
        }
        listener.start(queue: queue)
        group.wait()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            guard let self else { return }
            let status: String
            if let data, let request = String(data: data, encoding: .utf8), self.ingest(request) {
                status = "202 Accepted"
            } else {
                status = "400 Bad Request"
            }
            self.respond(status: status, connection: connection)
        }
    }

    private func ingest(_ request: String) -> Bool {
        guard request.hasPrefix("POST /events "), let body = request.components(separatedBy: "\r\n\r\n").last else {
            return false
        }

        guard let event = try? EventCodec.decoder.decode(MonitorEvent.self, from: Data(body.utf8)) else {
            return false
        }

        do {
            let line = try EventCodec.encodeJSONLine(event) + "\n"
            if FileManager.default.fileExists(atPath: eventLogURL.path) {
                let handle = try FileHandle(forWritingTo: eventLogURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } else {
                try line.write(to: eventLogURL, atomically: true, encoding: .utf8)
            }
            print("event_ingested=\(eventLogURL.path)")
            fflush(stdout)
            return true
        } catch {
            return false
        }
    }

    private func respond(status: String, connection: NWConnection) {
        let response = "HTTP/1.1 \(status)\r\nContent-Length: 0\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] _ in
            connection.cancel()
            if self?.once == true {
                self?.listener.cancel()
                self?.group.leave()
            }
        })
    }
}
