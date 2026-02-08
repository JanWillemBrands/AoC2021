//
//  TortureSyntaxTests.swift
//  Advent Tests
//
//  Created on 02/07/2026.
//

import XCTest
import Foundation

/// Comprehensive test suite for torture syntax grammar rules
/// Tests individual grammar rules (S00-S95) against specific messages
/// to ensure parser handles edge cases, ambiguities, and recursion correctly
final class TortureSyntaxTests: XCTestCase {
    
    // MARK: - Test Case Configuration
    
    /// Defines expected behavior for a specific grammar rule with a message
    struct TortureTestCase: CustomStringConvertible {
        let rule: String              // e.g., "S00", "S13"
        let message: String            // Input to parse
        let shouldSucceed: Bool        // Expected outcome
        let category: TestCategory     // What aspect is being tested
        let notes: String              // Additional context
        
        var description: String {
            "\(rule): '\(message)' → \(shouldSucceed ? "✓" : "✗") (\(category))"
        }
        
        init(rule: String, message: String, shouldSucceed: Bool, category: TestCategory, notes: String = "") {
            self.rule = rule
            self.message = message
            self.shouldSucceed = shouldSucceed
            self.category = category
            self.notes = notes
        }
    }
    
    /// Categories of torture tests for organization
    enum TestCategory: String, CaseIterable {
        case empty = "Empty Constructs"
        case basic = "Basic Constructs"
        case indirection = "Indirection"
        case recursion = "Recursion"
        case ambiguity = "Ambiguity"
        case sequences = "Sequences"
        case nested = "Nested Constructs"
        
        var description: String { rawValue }
    }
    
    // MARK: - Test Data
    
    /// All torture test cases organized by category
    static let allTests: [TortureTestCase] = emptyTests + basicTests + indirectionTests + 
                                              recursionTests + ambiguityTests + sequenceTests + nestedTests
    
    /// S00-S07: Empty construct tests
    static let emptyTests: [TortureTestCase] = [
        // These should all handle empty/epsilon gracefully
        TortureTestCase(rule: "S00", message: "", shouldSucceed: true, category: .empty, notes: "empty sequence"),
        TortureTestCase(rule: "S01", message: "", shouldSucceed: true, category: .empty, notes: "empty selection"),
        TortureTestCase(rule: "S02", message: "", shouldSucceed: true, category: .empty, notes: "empty group"),
        TortureTestCase(rule: "S03", message: "", shouldSucceed: true, category: .empty, notes: "empty option"),
        TortureTestCase(rule: "S04", message: "", shouldSucceed: true, category: .empty, notes: "empty iteration"),
        TortureTestCase(rule: "S05", message: "", shouldSucceed: true, category: .empty, notes: "empty iteration non-zero"),
        TortureTestCase(rule: "S06", message: "a", shouldSucceed: true, category: .empty, notes: "explicit end of input"),
        TortureTestCase(rule: "S07", message: "a", shouldSucceed: false, category: .empty, notes: "indirection not defined"),
    ]
    
    /// S10-S24: Basic construct tests
    static let basicTests: [TortureTestCase] = [
        TortureTestCase(rule: "S10", message: "", shouldSucceed: true, category: .basic, notes: "epsilon"),
        TortureTestCase(rule: "S11", message: "a", shouldSucceed: true, category: .basic, notes: "literal"),
        TortureTestCase(rule: "S11", message: "b", shouldSucceed: false, category: .basic, notes: "literal mismatch"),
        TortureTestCase(rule: "S12", message: "a", shouldSucceed: true, category: .basic, notes: "regex"),
        TortureTestCase(rule: "S13", message: "abcd", shouldSucceed: true, category: .basic, notes: "sequence"),
        TortureTestCase(rule: "S13", message: "abc", shouldSucceed: false, category: .basic, notes: "incomplete sequence"),
        TortureTestCase(rule: "S14", message: "a", shouldSucceed: true, category: .basic, notes: "selection left"),
        TortureTestCase(rule: "S14", message: "b", shouldSucceed: true, category: .basic, notes: "selection right"),
        TortureTestCase(rule: "S14", message: "c", shouldSucceed: false, category: .basic, notes: "selection neither"),
        TortureTestCase(rule: "S15", message: "a", shouldSucceed: true, category: .basic, notes: "decomposed selection a"),
        TortureTestCase(rule: "S15", message: "b", shouldSucceed: true, category: .basic, notes: "decomposed selection b"),
        TortureTestCase(rule: "S20", message: "a", shouldSucceed: true, category: .basic, notes: "group"),
        TortureTestCase(rule: "S21", message: "", shouldSucceed: true, category: .basic, notes: "option empty"),
        TortureTestCase(rule: "S21", message: "a", shouldSucceed: true, category: .basic, notes: "option present"),
        TortureTestCase(rule: "S22", message: "", shouldSucceed: true, category: .basic, notes: "iteration zero"),
        TortureTestCase(rule: "S22", message: "a", shouldSucceed: true, category: .basic, notes: "iteration one"),
        TortureTestCase(rule: "S22", message: "aa", shouldSucceed: true, category: .basic, notes: "iteration many"),
        TortureTestCase(rule: "S23", message: "a", shouldSucceed: true, category: .basic, notes: "iteration+ one"),
        TortureTestCase(rule: "S23", message: "aa", shouldSucceed: true, category: .basic, notes: "iteration+ many"),
        TortureTestCase(rule: "S24", message: "", shouldSucceed: true, category: .basic, notes: "literal or empty - empty"),
        TortureTestCase(rule: "S24", message: "x", shouldSucceed: true, category: .basic, notes: "literal or empty - x"),
    ]
    
    /// S30-S39: Indirection tests
    static let indirectionTests: [TortureTestCase] = [
        TortureTestCase(rule: "S30", message: "a", shouldSucceed: true, category: .indirection, notes: "simple"),
        TortureTestCase(rule: "S31", message: "", shouldSucceed: true, category: .indirection, notes: "nullable option empty"),
        TortureTestCase(rule: "S31", message: "a", shouldSucceed: true, category: .indirection, notes: "nullable option present"),
        TortureTestCase(rule: "S32", message: "", shouldSucceed: true, category: .indirection, notes: "nullable iteration"),
        TortureTestCase(rule: "S32", message: "aaa", shouldSucceed: true, category: .indirection, notes: "nullable iteration many"),
        TortureTestCase(rule: "S33", message: "a", shouldSucceed: true, category: .indirection, notes: "nullable leading"),
        TortureTestCase(rule: "S33", message: "aa", shouldSucceed: true, category: .indirection, notes: "nullable leading both"),
        TortureTestCase(rule: "S34", message: "a", shouldSucceed: true, category: .indirection, notes: "nullable trailing"),
        TortureTestCase(rule: "S35", message: "aa", shouldSucceed: true, category: .indirection, notes: "shared"),
        TortureTestCase(rule: "S36", message: "a", shouldSucceed: true, category: .indirection, notes: "shared selection"),
        TortureTestCase(rule: "S37", message: "", shouldSucceed: true, category: .indirection, notes: "shared nullable selection"),
        TortureTestCase(rule: "S38", message: "aa", shouldSucceed: true, category: .indirection, notes: "shared tail"),
        TortureTestCase(rule: "S39", message: "aa", shouldSucceed: true, category: .indirection, notes: "shared head"),
    ]
    
    /// S40-S57: Recursion tests (left, right, mutual)
    static let recursionTests: [TortureTestCase] = [
        TortureTestCase(rule: "S40", message: "a", shouldSucceed: true, category: .recursion, notes: "left recursion one"),
        TortureTestCase(rule: "S40", message: "aa", shouldSucceed: true, category: .recursion, notes: "left recursion many"),
        TortureTestCase(rule: "S41", message: "a", shouldSucceed: true, category: .recursion, notes: "right recursion one"),
        TortureTestCase(rule: "S41", message: "aa", shouldSucceed: true, category: .recursion, notes: "right recursion many"),
        TortureTestCase(rule: "S50", message: "", shouldSucceed: true, category: .recursion, notes: "right recursion zero"),
        TortureTestCase(rule: "S50", message: "a", shouldSucceed: true, category: .recursion, notes: "right recursion zero one"),
        TortureTestCase(rule: "S51", message: "a", shouldSucceed: true, category: .recursion, notes: "right recursion non-zero"),
        TortureTestCase(rule: "S51", message: "aa", shouldSucceed: true, category: .recursion, notes: "right recursion non-zero many"),
        TortureTestCase(rule: "S53", message: "", shouldSucceed: true, category: .recursion, notes: "left recursion zero"),
        TortureTestCase(rule: "S54", message: "a", shouldSucceed: true, category: .recursion, notes: "left recursion non-zero"),
        TortureTestCase(rule: "S54", message: "aaa", shouldSucceed: true, category: .recursion, notes: "left recursion non-zero many"),
        TortureTestCase(rule: "S56", message: "", shouldSucceed: true, category: .recursion, notes: "even brackets zero"),
        TortureTestCase(rule: "S56", message: "aa", shouldSucceed: true, category: .recursion, notes: "even brackets one pair"),
        TortureTestCase(rule: "S56", message: "aaaa", shouldSucceed: true, category: .recursion, notes: "even brackets two pairs"),
        TortureTestCase(rule: "S57", message: "a", shouldSucceed: true, category: .recursion, notes: "odd brackets one"),
        TortureTestCase(rule: "S57", message: "aaa", shouldSucceed: true, category: .recursion, notes: "odd brackets three"),
    ]
    
    /// S60-S64: Ambiguity tests
    static let ambiguityTests: [TortureTestCase] = [
        TortureTestCase(rule: "S60", message: "a", shouldSucceed: true, category: .ambiguity, notes: "ambiguous selection"),
        TortureTestCase(rule: "S61", message: "", shouldSucceed: true, category: .ambiguity, notes: "ambiguous option empty"),
        TortureTestCase(rule: "S61", message: "a", shouldSucceed: true, category: .ambiguity, notes: "ambiguous option one"),
        TortureTestCase(rule: "S61", message: "aa", shouldSucceed: true, category: .ambiguity, notes: "ambiguous option both"),
        TortureTestCase(rule: "S62", message: "", shouldSucceed: true, category: .ambiguity, notes: "ambiguous iteration"),
        TortureTestCase(rule: "S62", message: "aa", shouldSucceed: true, category: .ambiguity, notes: "ambiguous iteration many"),
        TortureTestCase(rule: "S64", message: "", shouldSucceed: true, category: .ambiguity, notes: "ambiguous selection nullable"),
        TortureTestCase(rule: "S64", message: "a", shouldSucceed: true, category: .ambiguity, notes: "ambiguous selection nullable present"),
    ]
    
    /// S70-S83: Sequence pattern tests
    static let sequenceTests: [TortureTestCase] = [
        TortureTestCase(rule: "S70", message: "a", shouldSucceed: true, category: .sequences, notes: "one or more - one"),
        TortureTestCase(rule: "S70", message: "aa", shouldSucceed: true, category: .sequences, notes: "one or more - many"),
        TortureTestCase(rule: "S72", message: "aa", shouldSucceed: true, category: .sequences, notes: "two or more - two"),
        TortureTestCase(rule: "S72", message: "aaa", shouldSucceed: true, category: .sequences, notes: "two or more - many"),
        TortureTestCase(rule: "S74", message: "a", shouldSucceed: true, category: .sequences, notes: "one or two - one"),
        TortureTestCase(rule: "S74", message: "aa", shouldSucceed: true, category: .sequences, notes: "one or two - two"),
        TortureTestCase(rule: "S80", message: "b", shouldSucceed: true, category: .sequences, notes: "iteration halt - just halt"),
        TortureTestCase(rule: "S80", message: "ab", shouldSucceed: true, category: .sequences, notes: "iteration halt - one"),
        TortureTestCase(rule: "S80", message: "aaab", shouldSucceed: true, category: .sequences, notes: "iteration halt - many"),
        TortureTestCase(rule: "S81", message: "ab", shouldSucceed: true, category: .sequences, notes: "iteration+ halt"),
    ]
    
    /// S90-S95: Complex nested tests
    static let nestedTests: [TortureTestCase] = [
        TortureTestCase(rule: "S93", message: "", shouldSucceed: true, category: .nested, notes: "matched brackets Γ3 empty"),
        TortureTestCase(rule: "S93", message: "b", shouldSucceed: true, category: .nested, notes: "matched brackets Γ3 one b"),
        TortureTestCase(rule: "S93", message: "ac", shouldSucceed: true, category: .nested, notes: "matched brackets Γ3 ac"),
        TortureTestCase(rule: "S93", message: "aac", shouldSucceed: false, category: .nested, notes: "matched brackets Γ3 unmatched"),
        TortureTestCase(rule: "S93", message: "aacc", shouldSucceed: true, category: .nested, notes: "matched brackets Γ3 nested"),
        TortureTestCase(rule: "S93", message: "aaaccc", shouldSucceed: true, category: .nested, notes: "matched brackets Γ3 deeply nested"),
        TortureTestCase(rule: "S94", message: "", shouldSucceed: true, category: .nested, notes: "ambiguous brackets Γ5 empty"),
        TortureTestCase(rule: "S94", message: "aac", shouldSucceed: true, category: .nested, notes: "ambiguous brackets Γ5"),
        TortureTestCase(rule: "S95", message: "a", shouldSucceed: true, category: .nested, notes: "ambiguous brackets Alfroozeh one"),
        TortureTestCase(rule: "S95", message: "aab", shouldSucceed: true, category: .nested, notes: "ambiguous brackets Alfroozeh ab"),
        TortureTestCase(rule: "S95", message: "aac", shouldSucceed: true, category: .nested, notes: "ambiguous brackets Alfroozeh ac"),
    ]
    
    // MARK: - Test Lifecycle
    
    override func setUp() {
        super.setUp()
        // Clear ALL global state before each test
        
        // Core parsing state
        input = ""
        startSymbol = ""
        
        // Grammar structures
        terminals = [:]
        nonTerminals = [:]
        messages = []
        
        // Call-return forest
        crf = []
        
        // Scanner state
        tokens = []
        currentIndex = 0
        
        // Debug flags
        trace = false
        traceIndent = 0
    }
    
    // MARK: - Test Methods
    
    func testTortureSyntaxFileExists() {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let grammarFileURL = projectDir.appendingPathComponent("TortureSyntax").appendingPathExtension("apus")
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: grammarFileURL.path),
            "TortureSyntax.apus should exist"
        )
    }
    
    func testEmptyConstructs() throws {
        try runTortureTests(Self.emptyTests, category: .empty)
    }
    
    func testBasicConstructs() throws {
        try runTortureTests(Self.basicTests, category: .basic)
    }
    
    func testIndirection() throws {
        try runTortureTests(Self.indirectionTests, category: .indirection)
    }
    
    func testRecursion() throws {
        try runTortureTests(Self.recursionTests, category: .recursion)
    }
    
    func testAmbiguity() throws {
        try runTortureTests(Self.ambiguityTests, category: .ambiguity)
    }
    
    func testSequences() throws {
        try runTortureTests(Self.sequenceTests, category: .sequences)
    }
    
    func testNested() throws {
        try runTortureTests(Self.nestedTests, category: .nested)
    }
    
    // MARK: - Test Execution
    
    private func runTortureTests(_ tests: [TortureTestCase], category: TestCategory) throws {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let grammarFileURL = projectDir.appendingPathComponent("TortureSyntax").appendingPathExtension("apus")
        
        // Parse the torture syntax grammar once
        let grammarParser = try GrammarParser(inputFile: grammarFileURL, patterns: apusTerminals)
        let grammarRoot: GrammarNode
        do {
            guard let root = try grammarParser.parseGrammar(explicitStartSymbol: "") else {
                XCTFail("Failed to parse TortureSyntax grammar: Start symbol not found")
                return
            }
            grammarRoot = root
        } catch {
            XCTFail("Failed to parse TortureSyntax grammar: \(error)")
            return
        }
        
        var passCount = 0
        var failCount = 0
        var results: [(test: TortureTestCase, actual: Bool, passed: Bool)] = []
        
        for test in tests {
            // Get the specific rule to test
            guard let ruleNode = nonTerminals[test.rule] else {
                XCTFail("Rule \(test.rule) not found in grammar")
                continue
            }
            
            // Reset state for this test
            crf = []
            tokens = []
            
            // Scan the message
            do {
                try initScanner(fromString: test.message, patterns: terminals)
            } catch {
                XCTFail("Failed to scan message for \(test.rule): \(error)")
                continue
            }
            
            // TODO: Actually run the parser with this specific rule as start symbol
            // For now, we'll just record that we attempted the test
            // You'll need to adapt this based on your actual parser execution
            
            let actualSuccess = attemptParse(rule: ruleNode, message: test.message)
            let testPassed = (actualSuccess == test.shouldSucceed)
            
            results.append((test: test, actual: actualSuccess, passed: testPassed))
            
            if testPassed {
                passCount += 1
            } else {
                failCount += 1
                XCTFail("""
                    \(test.rule) with '\(test.message)': \
                    Expected \(test.shouldSucceed ? "success" : "failure"), \
                    got \(actualSuccess ? "success" : "failure") \
                    (\(test.notes))
                    """)
            }
        }
        
        print("\n\(category.description) Results: \(passCount) passed, \(failCount) failed out of \(tests.count) tests")
    }
    
    /// Attempt to parse a message with a specific rule
    /// Returns true if parsing succeeded (reached end of input), false otherwise
    private func attemptParse(rule: GrammarNode, message: String) -> Bool {
        do {
            let result = try parseWithRule(rule, message: message, terminals: terminals)
            return result.success
        } catch {
            // If scanning fails, treat as parse failure
            return false
        }
    }
}

// MARK: - Test Result Tracking

/// Structure for tracking test results over time (for regression testing)
struct TortureTestResults: Codable {
    let date: Date
    let category: String
    let totalTests: Int
    let passed: Int
    let failed: Int
    let results: [IndividualResult]
    
    struct IndividualResult: Codable {
        let rule: String
        let message: String
        let expected: Bool
        let actual: Bool
        let passed: Bool
    }
}
