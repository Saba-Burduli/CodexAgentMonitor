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
        )
    ],
    swiftLanguageModes: [.v6]
)
