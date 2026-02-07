// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Advent",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Advent",
            targets: ["Advent"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.6.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Advent",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
            path: ".",
            exclude: [
                "ParserGeneratorTests.swift",
                "TestOutput",
                "apus.apus",
                "apusWithAction.apus",
                "apusAmbiguous.apus",
                "TortureSyntax.apus",
            ],
            sources: [
                "main.swift",
                "Scanner.swift",
                "GrammarParser.swift",
                "GrammarNode.swift",
                "GenerateParser.swift",
                "GenerateDiagrams.swift",
                "MessageParser.swift",
                "ClusteredNonterminalParser.swift",
                "CallReturnForest.swift",
                "GraphStructuredStack.swift",
                "SymbolTable.swift",
                "Descriptor.swift",
                "BinarySubtreeRepresentation.swift",
                "OutputTools.swift",
            ]
        ),
        .testTarget(
            name: "AdventTests",
            dependencies: [
                "Advent",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests",
            sources: [
                "ParserGeneratorTests.swift",
            ]
        ),
    ]
)
