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
        )
    ],
    swiftLanguageModes: [.v6]
)
