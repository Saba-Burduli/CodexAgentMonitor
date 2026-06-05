import Foundation

public struct CodexCLIStateReader {
    public var sessionsRootURL: URL
    public var historyURL: URL

    public init(
        sessionsRootURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions"),
        historyURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/history.jsonl")
    ) {
        self.sessionsRootURL = sessionsRootURL
        self.historyURL = historyURL
    }

    public func readLatestState() -> MonitorState? {
        guard let rolloutURL = latestRolloutURL(),
              let text = try? String(contentsOf: rolloutURL, encoding: .utf8)
        else {
            return nil
        }

        let events = text.split(separator: "\n").flatMap { line in
            CodexSessionEventMapper.events(from: String(line))
        }
        guard !events.isEmpty else { return nil }

        var state = MonitorState()
        state.apply(events)

        if let sessionID = sessionID(from: rolloutURL),
           let name = sessionName(for: sessionID) {
            applySessionName(name, sessionID: sessionID, to: &state)
        }

        return state
    }

    private func latestRolloutURL() -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsRootURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
        ) else {
            return nil
        }

        var latest: (url: URL, modified: Date)?
        for case let url as URL in enumerator {
            guard url.lastPathComponent.hasPrefix("rollout-"),
                  url.pathExtension == "jsonl",
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            else {
                continue
            }

            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? Date(timeIntervalSince1970: 0)
            if latest == nil || modified > latest!.modified {
                latest = (url, modified)
            }
        }
        return latest?.url
    }

    private func sessionID(from rolloutURL: URL) -> String? {
        let name = rolloutURL.deletingPathExtension().lastPathComponent
        return name.split(separator: "-").suffix(5).joined(separator: "-")
    }

    private func sessionName(for sessionID: String) -> String? {
        guard let text = try? String(contentsOf: historyURL, encoding: .utf8) else {
            return nil
        }

        var latest: (timestamp: Double, text: String)?
        for line in text.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["session_id"] as? String == sessionID,
                  let timestamp = object["ts"] as? Double,
                  let text = object["text"] as? String
            else {
                continue
            }

            if latest == nil || timestamp > latest!.timestamp {
                latest = (timestamp, text)
            }
        }

        return latest.map { excerpt($0.text) }
    }

    private func applySessionName(_ name: String, sessionID: String, to state: inout MonitorState) {
        for index in state.agents.indices {
            if state.agents[index].sessionId == sessionID || state.agents[index].id == sessionID {
                state.agents[index].sessionName = name
            }
        }
    }

    private func excerpt(_ value: String, limit: Int = 64) -> String {
        let singleLine = value.replacingOccurrences(of: "\n", with: " ")
        guard singleLine.count > limit else { return singleLine }
        let end = singleLine.index(singleLine.startIndex, offsetBy: limit)
        return String(singleLine[..<end])
    }
}
