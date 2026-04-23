// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "AppInsightSDK",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AppInsightSDK", targets: ["AppInsightSDK"]),
    ],
    targets: [
        .target(
            name: "AppInsightSDK",
            path: "Sources/AppInsightSDK"
        ),
        .testTarget(
            name: "AppInsightSDKTests",
            dependencies: ["AppInsightSDK"],
            path: "Tests/AppInsightSDKTests"
        ),
    ]
)
