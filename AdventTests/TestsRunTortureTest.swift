#!/usr/bin/env swift

//
//  RunTortureTest.swift
//  Quick script to run individual torture tests
//
//  Usage: swift RunTortureTest.swift S13 "abcd"
//

import Foundation

// This script allows you to quickly test individual grammar rules
// without running the full test suite

guard CommandLine.arguments.count >= 3 else {
    print("""
    Usage: swift RunTortureTest.swift <RULE> <MESSAGE>
    
    Examples:
        swift RunTortureTest.swift S13 "abcd"
        swift RunTortureTest.swift S40 "aaa"
        swift RunTortureTest.swift S93 "aacc"
    
    Tests a specific rule from TortureSyntax.apus with the given message
    """)
    exit(1)
}

let rule = CommandLine.arguments[1]
let message = CommandLine.arguments[2]

print("Testing rule: \(rule)")
print("Message: '\(message)'")
print("---")

// TODO: Implement actual test execution
// This would:
// 1. Load TortureSyntax.apus
// 2. Parse it
// 3. Extract the specific rule
// 4. Run the parser with that rule as start symbol
// 5. Report success/failure

print("Test execution not yet implemented")
print("Use: swift test --filter TortureSyntaxTests")
