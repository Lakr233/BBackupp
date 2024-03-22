// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MobileBackup",
    platforms: [.macOS(.v11)],
    products: [
        .executable(name: "MobileBackup", targets: ["MobileBackup"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Lakr233/AppleMobileDeviceLibrary", .upToNextMajor(from: .init(1, 0, 0))),
    ],
    targets: [
        .executableTarget(
            name: "MobileBackup",
            dependencies: [
                "MobileBackupEndianness",
                "AppleMobileDeviceLibrary",
            ],
            cSettings: [
                .unsafeFlags(["-w"]),
                .define("PACKAGE_VERSION=\"73b6fd18\""),
                .define("PACKAGE_URL=\"UNAVAILABLE\""),
                .define("PACKAGE_BUGREPORT=\"UNAVAILABLE\""),
            ]
        ),
        .target(name: "MobileBackupEndianness"),
    ]
)
