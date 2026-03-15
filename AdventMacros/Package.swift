// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "AdventMacros",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "AdventMacros",
            targets: ["AdventMacros"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .macro(
            name: "AdventMacrosImpl",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "AdventMacros",
            dependencies: ["AdventMacrosImpl"]
        ),
        .testTarget(
            name: "AdventMacrosTests",
            dependencies: [
                "AdventMacrosImpl",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
