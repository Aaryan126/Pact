// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FocusMirror",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FocusMirror", targets: ["FocusMirror"])
    ],
    targets: [
        .executableTarget(
            name: "FocusMirror",
            path: "FocusMirror",
            exclude: ["Info.plist", "FocusMirror.entitlements"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FocusMirrorTests",
            dependencies: ["FocusMirror"],
            path: "Tests/FocusMirrorTests"
        )
    ]
)
