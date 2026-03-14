//
//  ParserGeneratorTests.swift
//  Advent
//
//  Created on 02/07/2026.
//

import Testing
import Foundation

@Suite("Parser Generator Tests", .serialized)
struct ParserGeneratorTests {
    
    /// Reset all global state before each test
    static func resetGlobalState() {
        // Call-return forest
        crf = [:]
        crfReturnNodes = []
        unique = []
        remaining = []
        yield = []
        
        // Scanner state
        tokens = []
        cI = 0
        cU = 0
        
        // Debug flags
        trace = false
        traceIndent = 0
        
        // Parse statistics
        failedParses = 0
        successfullParses = 0
        descriptorCount = 0
        duplicateDescriptorCount = 0
        
        // Reset static counters
        GrammarNode.count = 0
    }
    
    /// Test case configuration
    struct TestCase: CustomStringConvertible {
        let grammarFile: String
        let expectedToComplete: Bool
        let testDescription: String
        
        var description: String {
            testDescription.isEmpty ? grammarFile : testDescription
        }
        
        init(_ grammarFile: String, shouldComplete: Bool = true, description: String = "") {
            self.grammarFile = grammarFile
            self.expectedToComplete = shouldComplete
            self.testDescription = description.isEmpty ? grammarFile : description
        }
    }
    
    /// All test cases to run
    static let testCases: [TestCase] = [
        TestCase("apus", description: "Base APUS grammar"),
        // TestCase("apusWithAction", description: "APUS grammar with embedded actions"),
        // TestCase("apusAmbiguous", description: "Ambiguous APUS grammar"),
    ]
    
    @Test("Parser generation completes successfully", arguments: testCases)
    func testParserGeneration(testCase: TestCase) async throws {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        // Go up two levels: from test file -> Tests directory -> project root
        let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
        
        let grammarFileURL = projectDir
            .appendingPathComponent(testCase.grammarFile)
            .appendingPathExtension("apus")
        
        // Verify grammar file exists
        #expect(FileManager.default.fileExists(atPath: grammarFileURL.path),
                "Grammar file should exist: \(grammarFileURL.path)")
        
        // Clear ALL global state before test
        Self.resetGlobalState()
        
        // Parse the grammar
        let grammarParser = try ApusParser(fromFile: grammarFileURL)
        
        // Parse grammar tree
        let grammar = try grammarParser.parseGrammar(explicitStartSymbol: "") // "" means use first non-terminal
        #expect(grammar != nil, "Start symbol not found")
        guard let grammar else { return }
        
        #expect(grammar.nonTerminals.count > 0, "Grammar should define at least one non-terminal")
        
        // Check if grammar is within size limits for generation
        guard grammar.nonTerminals.count < 1000 && crf.count < 1000 else {
            Issue.record("Grammar too large: \(grammar.nonTerminals.count) non-terminals, \(crf.count) CRF nodes")
            return
        }
        
        // Setup output directory
        let outputDir = projectDir.appendingPathComponent("TestOutput")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // Generate parser
        let parserOutputFile = outputDir
            .appendingPathComponent("\(testCase.grammarFile)_output")
            .appendingPathExtension("swift")
        
        let parserGenerator = ParserGenerator(outputFile: parserOutputFile, grammar: grammar)
        
        do {
            try parserGenerator.generateParser()
            
            if testCase.expectedToComplete {
                // Verify the output file was created
                #expect(FileManager.default.fileExists(atPath: parserOutputFile.path),
                        "Generated parser file should exist")
                
                // Verify the file has content
                let fileSize = try FileManager.default.attributesOfItem(atPath: parserOutputFile.path)[.size] as? UInt64
                #expect((fileSize ?? 0) > 0, "Generated parser should not be empty")
                
                // Read and validate generated code has basic structure
                let generatedCode = try String(contentsOf: parserOutputFile, encoding: .utf8)
                #expect(generatedCode.count > 50, "Generated parser should have substantial content")
            }
        } catch {
            if testCase.expectedToComplete {
                Issue.record("Parser generation failed: \(error)")
            }
        }
    }
    
    @Test("All grammar files are accessible")
    func testGrammarFilesExist() {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        // Go up two levels: from test file -> Tests directory -> project root
        let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
        
        for testCase in Self.testCases {
            let grammarFileURL = projectDir
                .appendingPathComponent(testCase.grammarFile)
                .appendingPathExtension("apus")
            
            #expect(FileManager.default.fileExists(atPath: grammarFileURL.path),
                    "Grammar file should exist: \(testCase.grammarFile).apus")
        }
    }
    
    @Test("Generated parser contains expected structure")
    func testGeneratedCodeStructure() async throws {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        // Go up two levels: from test file -> Tests directory -> project root
        let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let outputDir = projectDir.appendingPathComponent("TestOutput")
        
        // Clear ALL global state
        Self.resetGlobalState()
        
        // Test with the base apus grammar
        let grammarFileURL = projectDir
            .appendingPathComponent("apus")
            .appendingPathExtension("apus")
        
        let grammar: Grammar?
        do {
            let grammarParser = try ApusParser(fromFile: grammarFileURL)
            grammar = try grammarParser.parseGrammar(explicitStartSymbol: "")
        } catch {
            Issue.record("Failed to parse base grammar: \(error)")
            return
        }
        
        guard let grammar else {
            Issue.record("Failed to parse base grammar: Start symbol not found")
            return
        }
        
        // Create output directory
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        let parserOutputFile = outputDir
            .appendingPathComponent("apus_validation_test")
            .appendingPathExtension("swift")
        
        let parserGenerator = ParserGenerator(outputFile: parserOutputFile, grammar: grammar)
        try parserGenerator.generateParser()
        
        // Read the generated file
        let generatedCode = try String(contentsOf: parserOutputFile, encoding: .utf8)
        
        // Validate basic Swift structure
        #expect(generatedCode.count > 100, "Generated code should have substantial content")
        
        // TODO: Add more specific structural checks as the generator evolves
        // For example:
        // - Check for specific function names
        // - Verify import statements
        // - Validate non-terminal productions are present
    }
}
