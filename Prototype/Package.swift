// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TempMailProbe",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/Cocoanetics/SwiftMail.git",
                 revision: "f8469b14f7620ef7b1105eccbfa19271448819d5")
    ],
    targets: [
        .executableTarget(
            name: "TempMailProbe",
            dependencies: [.product(name: "SwiftMail", package: "SwiftMail")]
        )
    ]
)
