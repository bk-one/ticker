// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Ticker",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "Ticker",
            targets: ["Ticker"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pocketsvg/PocketSVG.git",
            revision: "b99f8d24cdfe7848566d34f2fd5bef3e00ed709c"
        ),
    ],
    targets: [
        .target(
            name: "TickerKit",
            resources: [
                .process("Resources"),
            ]
        ),
        .executableTarget(
            name: "Ticker",
            dependencies: [
                "TickerKit",
                "PocketSVG",
            ]
        ),
        .testTarget(
            name: "TickerKitTests",
            dependencies: ["TickerKit"]
        ),
        .testTarget(
            name: "TickerAppTests",
            dependencies: ["Ticker", "TickerKit"]
        ),
    ]
)
