// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Clarity",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Clarity", targets: ["Clarity"])
    ],
    targets: [
        .executableTarget(
            name: "Clarity",
            path: "Clarity",
            exclude: ["Info.plist", "Clarity.entitlements"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ClarityTests",
            dependencies: ["Clarity"],
            path: "Tests/ClarityTests"
        )
    ]
)
