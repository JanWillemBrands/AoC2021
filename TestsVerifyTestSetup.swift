#!/usr/bin/env swift

//
//  VerifyTestSetup.swift
//  Quick verification that test infrastructure is ready
//
//  Usage: swift Tests/VerifyTestSetup.swift
//

import Foundation

print("🔍 Verifying Advent Test Setup...\n")

let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath
var allGood = true

// Test files that should exist
let testFiles = [
    "Tests/ParserGeneratorTests.swift",
    "Tests/TortureSyntaxTests.swift",
    "Tests/TestHelpers.swift",
    "Tests/README.md",
    "Tests/SETUP.md",
    "Tests/TortureTestExpectations.md",
]

// Grammar files that should exist
let grammarFiles = [
    "apus.apus",
    "apusWithAction.apus",
    "apusAmbiguous.apus",
    "TortureSyntax.apus",
]

// Source files needed for tests
let sourceFiles = [
    "Scanner.swift",
    "GrammarParser.swift",
    "GrammarNode.swift",
    "ClusteredNonterminalParser.swift",
    "CallReturnForest.swift",
    "BinarySubtreeRepresentation.swift",
    "Descriptor.swift",
    "SymbolTable.swift",
    "GenerateParser.swift",
    "GenerateDiagrams.swift",
]

print("📝 Checking test files...")
for file in testFiles {
    if fileManager.fileExists(atPath: file) {
        print("  ✅ \(file)")
    } else {
        print("  ❌ \(file) - MISSING")
        allGood = false
    }
}

print("\n📖 Checking grammar files...")
for file in grammarFiles {
    if fileManager.fileExists(atPath: file) {
        print("  ✅ \(file)")
    } else {
        print("  ❌ \(file) - MISSING")
        allGood = false
    }
}

print("\n💻 Checking source files...")
for file in sourceFiles {
    if fileManager.fileExists(atPath: file) {
        print("  ✅ \(file)")
    } else {
        print("  ⚠️  \(file) - Not found (may need to be added to test target)")
    }
}

print("\n📦 Checking for TestOutput directory...")
if fileManager.fileExists(atPath: "TestOutput") {
    print("  ℹ️  TestOutput/ already exists (will store test results here)")
} else {
    print("  ℹ️  TestOutput/ will be created when tests run")
}

print("\n" + String(repeating: "=", count: 60))
if allGood {
    print("✅ Test setup looks good!")
    print("\nNext steps:")
    print("1. Open project in Xcode")
    print("2. Create a new Unit Testing Bundle target")
    print("3. Add test files to that target")
    print("4. Press ⌘U to run tests")
    print("\nSee Tests/SETUP.md for detailed instructions")
} else {
    print("❌ Some files are missing!")
    print("\nPlease ensure all test files are present.")
}
print(String(repeating: "=", count: 60) + "\n")

exit(allGood ? 0 : 1)
