// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "CodexAgentMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexAgentMonitor", targets: ["CodexAgentMonitor"]),
        .executable(name: "CodexAgentMonitorTestRunner", targets: ["CodexAgentMonitorTestRunner"]),
        .executable(name: "CodexAgentMonitorE2ERunner", targets: ["CodexAgentMonitorE2ERunner"]),
        .executable(name: "CodexAgentMonitorEventWriter", targets: ["CodexAgentMonitorEventWriter"]),
        .executable(name: "CodexAgentMonitorIngestDaemon", targets: ["CodexAgentMonitorIngestDaemon"]),
        .executable(name: "CodexAgentMonitorSessionMirror", targets: ["CodexAgentMonitorSessionMirror"]),
        .library(name: "CodexAgentMonitorCore", targets: ["CodexAgentMonitorCore"])
    ],
    targets: [
        .target(name: "CodexAgentMonitorCore"),
        .executableTarget(
            name: "CodexAgentMonitor",
            dependencies: ["CodexAgentMonitorCore"]
        ),
        .executableTarget(
            name: "CodexAgentMonitorTestRunner",
            dependencies: ["CodexAgentMonitorCore"]
        ),
        .executableTarget(
            name: "CodexAgentMonitorE2ERunner",
            dependencies: ["CodexAgentMonitorCore"]
        ),
        .executableTarget(
            name: "CodexAgentMonitorEventWriter",
            dependencies: ["CodexAgentMonitorCore"]
        ),
        .executableTarget(
            name: "CodexAgentMonitorIngestDaemon",
            dependencies: ["CodexAgentMonitorCore"]
        ),
        .executableTarget(
            name: "CodexAgentMonitorSessionMirror",
            dependencies: ["CodexAgentMonitorCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
