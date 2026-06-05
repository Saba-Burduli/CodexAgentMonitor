import Foundation

public struct LocalSkillStatusProvider: SkillStatusProvider {
    public var skillsRootURL: URL

    public init(skillsRootURL: URL) {
        self.skillsRootURL = skillsRootURL
    }

    public func skillStatus() throws -> SkillStatus {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: skillsRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return SkillStatus(isAvailable: false)
        }

        var enabled: [String] = []
        var disabled: [String] = []

        for entry in entries {
            guard isDirectory(entry), hasSkillFile(entry) else { continue }
            if FileManager.default.fileExists(atPath: entry.appendingPathComponent(".disabled").path) {
                disabled.append(entry.lastPathComponent)
            } else {
                enabled.append(entry.lastPathComponent)
            }
        }

        return SkillStatus(
            enabled: enabled.sorted(),
            disabled: disabled.sorted(),
            isAvailable: !enabled.isEmpty || !disabled.isEmpty
        )
    }

    public func setSkill(_ name: String, enabled: Bool) throws {
        guard isSafeSkillName(name) else {
            throw SkillStatusProviderError.invalidSkillName
        }

        let skillURL = skillsRootURL.appendingPathComponent(name, isDirectory: true)
        guard isDirectory(skillURL), hasSkillFile(skillURL) else {
            throw SkillStatusProviderError.skillNotFound
        }

        let markerURL = skillURL.appendingPathComponent(".disabled")
        if enabled {
            if FileManager.default.fileExists(atPath: markerURL.path) {
                try FileManager.default.removeItem(at: markerURL)
            }
        } else {
            try Data().write(to: markerURL, options: .atomic)
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func hasSkillFile(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("SKILL.md").path)
    }

    private func isSafeSkillName(_ name: String) -> Bool {
        guard !name.isEmpty, !name.contains("/"), !name.contains("..") else { return false }
        return name.allSatisfy { character in
            character.isLetter || character.isNumber || character == "-" || character == "_"
        }
    }
}

public enum SkillStatusProviderError: Error, Equatable {
    case invalidSkillName
    case skillNotFound
}
