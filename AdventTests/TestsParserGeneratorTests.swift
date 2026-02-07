//
//  ParserGeneratorTests.swift
//  Advent Tests
//
//  Created on 02/07/2026.
//

import XCTest

final class ParserGeneratorTests: XCTestCase {
    
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
    static let basicGrammarTests: [TestCase] = [
        TestCase("apus", description: "Base APUS grammar"),
        TestCase("apusWithAction", description: "APUS grammar with embedded actions"),
        TestCase("apusAmbiguous", description: "Ambiguous APUS grammar"),
    ]
    
    override func setUp() {
        super.setUp()
        // Clear global state before each test
        terminals = [:]
        nonTerminals = [:]
        messages = []
        crf = []
        tokens = []
        symbolTable = []
    }
    
    func testAllGrammarFilesExist() {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
        
        for testCase in Self.basicGrammarTests {
            let grammarFileURL = projectDir
                .appendingPathComponent(testCase.grammarFile)
                .appendingPathExtension("apus")
            
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: grammarFileURL.path),
                "Grammar file should exist: \(testCase.grammarFile).apus"
            )
        }
    }
    
    func testApusGrammarGeneration() throws {
        try testParserGeneration(for: Self.basicGrammarTests[0])
    }
    
    func testApusWithActionGeneration() throws {
        try testParserGeneration(for: Self.basicGrammarTests[1])
    }
    
    func testApusAmbiguousGeneration() throws {
        try testParserGeneration(for: Self.basicGrammarTests[2])
    }
    
    private func testParserGeneration(for testCase: TestCase) throws {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
        
        let grammarFileURL = projectDir
            .appendingPathComponent(testCase.grammarFile)
            .appendingPathExtension("apus")
        
        // Verify grammar file exists
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: grammarFileURL.path),
            "Grammar file should exist: \(grammarFileURL.path)"
        )
        
        // Parse the grammar
        let grammarParser: GrammarParser
        do {
            grammarParser = try GrammarParser(inputFile: grammarFileURL, patterns: apusTerminals)
        } catch {
            XCTFail("Failed to read grammar file: \(error)")
            return
        }
        
        // Parse grammar tree
        let startSymbol = ""  // Empty means use first non-terminal
        guard let _ = grammarParser.parseGrammar(explicitStartSymbol: startSymbol) else {
            if testCase.expectedToComplete {
                XCTFail("Failed to parse grammar: Start symbol not found")
            }
            return
        }
        
        XCTAssertGreaterThan(nonTerminals.count, 0, "Grammar should define at least one non-terminal")
        
        // Check if grammar is within size limits for generation
        guard nonTerminals.count < 1000 && crf.count < 1000 else {
            XCTFail("Grammar too large: \(nonTerminals.count) non-terminals, \(crf.count) CRF nodes")
            return
        }
        
        // Setup output directory
        let outputDir = projectDir.appendingPathComponent("TestOutput")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // Generate parser
        let parserOutputFile = outputDir
            .appendingPathComponent("\(testCase.grammarFile)_output")
            .appendingPathExtension("swift")
        
        let parserGenerator = ParserGenerator(outputFile: parserOutputFile)
        
        do {
            try parserGenerator.generateParser()
            
            if testCase.expectedToComplete {
                // Verify the output file was created
                XCTAssertTrue(
                    FileManager.default.fileExists(atPath: parserOutputFile.path),
                    "Generated parser file should exist"
                )
                
                // Verify the file has content
                let attributes = try FileManager.default.attributesOfItem(atPath: parserOutputFile.path)
                let fileSize = attributes[.size] as? UInt64 ?? 0
                XCTAssertGreaterThan(fileSize, 0, "Generated parser should not be empty")
                
                // Read and validate generated code has basic structure
                let generatedCode = try String(contentsOf: parserOutputFile)
                XCTAssertGreaterThan(generatedCode.count, 50, "Generated parser should have substantial content")
            }
        } catch {
            if testCase.expectedToComplete {
                XCTFail("Parser generation failed: \(error)")
            }
        }
    }
    
    func testGeneratedCodeStructure() throws {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let outputDir = projectDir.appendingPathComponent("TestOutput")
        
        // Test with the base apus grammar
        let grammarFileURL = projectDir
            .appendingPathComponent("apus")
            .appendingPathExtension("apus")
        
        let grammarParser = try GrammarParser(inputFile: grammarFileURL, patterns: apusTerminals)
        guard let _ = grammarParser.parseGrammar(explicitStartSymbol: "") else {
            XCTFail("Failed to parse base grammar")
            return
        }
        
        // Create output directory
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        let parserOutputFile = outputDir
            .appendingPathComponent("apus_validation_test")
            .appendingPathExtension("swift")
        
        let parserGenerator = ParserGenerator(outputFile: parserOutputFile)
        try parserGenerator.generateParser()
        
        // Read the generated file
        let generatedCode = try String(contentsOf: parserOutputFile)
        
        // Validate basic Swift structure
        XCTAssertGreaterThan(generatedCode.count, 100, "Generated code should have substantial content")
        
        // TODO: Add more specific structural checks as the generator evolves
    }
}
