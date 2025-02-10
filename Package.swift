// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Moodify",
    platforms: [
        .iOS(.v16)
    ],
    targets: [
        .target(
            name: "Moodify",
            path: "Moodify",
            resources: [
                .process("Assets.xcassets"),
                .process("Preview Content")
            ],
            swiftSettings: [
                .define("ENABLE_PREVIEWS", .when(configuration: .debug))
            ]
        )
    ]
)
