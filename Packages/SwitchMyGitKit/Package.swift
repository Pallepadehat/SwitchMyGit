// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwitchMyGitKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SwitchMyGitCore", targets: ["SwitchMyGitCore"]),
    ],
    targets: [
        // Everything that touches Git, the file system or persisted state.
        // Contains no UI code so it can be tested with `swift test`.
        .target(name: "SwitchMyGitCore"),
        .testTarget(
            name: "SwitchMyGitCoreTests",
            dependencies: ["SwitchMyGitCore"]
        ),
    ]
)
