// swift-tools-version:5.7
//
// NotchPrompter — a MacBook teleprompter that tucks itself just under the notch.
//
// Build & run:
//     swift run NotchPrompter
//
// Requires macOS 13 (Ventura) or newer and Swift 5.7+ (Xcode 14+).

import PackageDescription

let package = Package(
    name: "NotchPrompter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NotchPrompter", targets: ["NotchPrompter"])
    ],
    targets: [
        .executableTarget(
            name: "NotchPrompter",
            path: "Sources/NotchPrompter"
        )
    ]
)
