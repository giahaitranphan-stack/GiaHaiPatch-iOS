// This file is optional. The Xcode project uses ZIPFoundation as a package dependency.
import PackageDescription
let package = Package(
    name: "GiaHaiPatch",
    platforms: [.iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(name: "GiaHaiPatch", dependencies: ["ZIPFoundation"])
    ]
)
