import Foundation

public struct LocalGitStatusProvider: GitStatusProvider {
    public var repositoryURL: URL

    public init(repositoryURL: URL) {
        self.repositoryURL = repositoryURL
    }

    public func recentGitActivity(limit: Int) throws -> [GitCommitStatus] {
        let safeLimit = max(1, min(limit, 10))
        let branch = try runGit(["rev-parse", "--abbrev-ref", "HEAD"]).trimmingCharacters(in: .whitespacesAndNewlines)
        let output = try runGit([
            "log",
            "-n", "\(safeLimit)",
            "--date=iso-strict",
            "--pretty=format:%h%x1f%s%x1f%cI"
        ])

        return output
            .split(separator: "\n")
            .compactMap { Self.parseLogLine(String($0), branch: branch) }
    }

    public static func parseLogLine(_ line: String, branch: String) -> GitCommitStatus? {
        let parts = line.split(separator: "\u{1f}", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }

        return GitCommitStatus(
            shortHash: String(parts[0]),
            message: String(parts[1]),
            branch: branch,
            pushedAt: nil,
            localCommitAt: ISO8601DateFormatter().date(from: String(parts[2])),
            pushStatus: .unavailable
        )
    }

    private func runGit(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = repositoryURL

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = error.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "git command failed"
            throw GitStatusProviderError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

public enum GitStatusProviderError: Error, Equatable {
    case commandFailed(String)
}
