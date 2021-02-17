// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MegicalEasyAccess-SDK-iOS",
    platforms: [.iOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MegicalEasyAccess-SDK-iOS",
            targets: ["MegicalEasyAccess-SDK-iOS"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(name: "JOSESwift", url: "https://github.com/airsidemobile/JOSESwift", .upToNextMajor(from: "2.2.1")),
        .package(name: "SwiftyBeaver", url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", .upToNextMajor(from: "1.9.3")),
        .package(name: "SimpleKeychain", url: "https://github.com/auth0/SimpleKeychain", .upToNextMajor(from: "0.12.2"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MegicalEasyAccess-SDK-iOS",
            dependencies: ["JOSESwift", "SwiftyBeaver", "SimpleKeychain"]),
        .testTarget(
            name: "MegicalEasyAccess-SDK-iOSTests",
            dependencies: ["MegicalEasyAccess-SDK-iOS"]),
    ]
)
