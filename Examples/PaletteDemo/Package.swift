// swift-tools-version: 6.0
import PackageDescription

// A small app to try Gershwin's command palette in: `swift run PaletteDemo` from this folder. ⇧⌘P opens it; its entries
// are the app's menu items, some tabs, the themes, and a few "scripts", one of which arrives late, as a script's would.
//
//     swift run PaletteDemo --snapshot palette.png --theme "Platinum" --query "sp"
//
// writes the palette's window to a PNG and quits, for looking at a theme without a screen.
let package = Package(
    name: "PaletteDemo",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(
            name: "PaletteDemo",
            dependencies: [
                .product(name: "GershwinAppKit", package: "gershwin"),
                .product(name: "GershwinChrome", package: "gershwin"),
            ]),
    ]
)
