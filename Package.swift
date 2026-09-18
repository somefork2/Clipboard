// swift-tools-version: 5.10

import PackageDescription

// The App Store build is produced from the Xcode project (see project.yml /
// `xcodegen generate`). This package exists so the sources can be type-checked
// quickly from the command line; it cannot produce a signed, sandboxed bundle.
let package = Package(
    name: "CopyWell",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CopyWell", targets: ["CopyWell"])
    ],
    targets: [
        .executableTarget(
            name: "CopyWell",
            path: "Sources",
            exclude: [
                "Resources/Info.plist",
                "Resources/CopyWell.entitlements",
                "Resources/PrivacyInfo.xcprivacy"
            ]
        )
    ]
)
