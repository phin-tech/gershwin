// swift-tools-version: 6.0
import PackageDescription

// Gershwin: windows and controls drawn the way the classic Mac OS (System 1 to Mac OS 9, and Copland's themes) and
// BeOS drew them. Named for Copland's planned successor.
//
// - GershwinChrome: the themes' colours and every part's geometry, as plain values; no AppKit, tested headless.
// - GershwinAppKit: a borderless window that draws its own frame, title bar or tabs, boxes, scroll bar and tab bar.
// - GershwinSwiftUI: one root modifier, `.gershwin(theme)`, that restyles SwiftUI's own controls beneath it.
let package = Package(
    name: "Gershwin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GershwinChrome", targets: ["GershwinChrome"]),
        .library(name: "GershwinAppKit", targets: ["GershwinAppKit"]),
        .library(name: "GershwinSwiftUI", targets: ["GershwinSwiftUI"]),
    ],
    targets: [
        .target(name: "GershwinChrome"),
        .target(name: "GershwinAppKit", dependencies: ["GershwinChrome"]),
        .target(name: "GershwinSwiftUI", dependencies: ["GershwinAppKit", "GershwinChrome"]),
        .testTarget(name: "GershwinChromeTests", dependencies: ["GershwinChrome"]),
        .testTarget(name: "GershwinAppKitTests", dependencies: ["GershwinAppKit", "GershwinSwiftUI"]),
    ]
)
