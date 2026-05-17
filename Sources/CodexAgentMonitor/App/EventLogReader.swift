import CodexAgentMonitorCore
import Foundation

struct EventLogReader {
    var url: URL

    func readState() -> MonitorState? {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        let events = EventCodec.decodeJSONLines(text)
        guard !events.isEmpty else { return nil }

        var state = MonitorState()
        state.apply(events)
        return state
    }
}
