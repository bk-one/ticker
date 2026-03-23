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
    targets: [
        .target(
            name: "TickerKit"
        ),
        .executableTarget(
            name: "Ticker",
            dependencies: ["TickerKit"]
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
