// swift-tools-version: 6.0
import PackageDescription

// Every Gershwin widget, live, in a window of the chosen theme: `swift run Gallery` from this folder. The pop-ups at
// the top change the theme and its scale without closing the window.
let package = Package(
    name: "Gallery",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(
            name: "Gallery",
            dependencies: [
                .product(name: "GershwinAppKit", package: "gershwin"),
                .product(name: "GershwinChrome", package: "gershwin"),
                .product(name: "GershwinSwiftUI", package: "gershwin"),
            ]),
    ]
)
