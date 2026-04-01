//
//  ParserGeneratorTests.swift
//  Advent
//
//  Created on 02/07/2026.
//

import Testing
import Foundation

@Suite("Parser Generator Tests")
struct ParserGeneratorTests {
    
    /// Reset global state before each test
    static func resetGlobalState() {
        // Debug flags
        trace = false
        traceIndent = 0
        
        // Reset static counters
        GrammarNode.count = 0
    }
    
    /// Grammar files to test
    static let grammarFiles = ["apus", "apusUnicode"]
    
    @Test("Generates parser for all grammar files")
    func testGenerateParser() throws {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
        
        for grammarFile in Self.grammarFiles {
            let grammarFileURL = projectDir
                .appendingPathComponent(grammarFile)
                .appendingPathExtension("apus")
            
            #expect(FileManager.default.fileExists(atPath: grammarFileURL.path),
                    "Grammar file should exist: \(grammarFileURL.path)")
            
            Self.resetGlobalState()
            
            let grammarParser = try ApusParser(fromFile: grammarFileURL)
            let grammar = try grammarParser.parse(explicitStartSymbol: "")
            
            #expect(grammar.nonTerminals.count > 0, "Grammar should define at least one non-terminal")
            
            let outputDir = projectDir.appendingPathComponent("TestOutput")
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            
            let parserOutputFile = outputDir
                .appendingPathComponent("\(grammarFile)_output")
                .appendingPathExtension("swift")
            
            let parserGenerator = ParserGenerator(outputFile: parserOutputFile, grammar: grammar)
            try parserGenerator.generate()
            
            #expect(FileManager.default.fileExists(atPath: parserOutputFile.path),
                    "Generated parser file should exist")
            
            let generatedCode = try String(contentsOf: parserOutputFile, encoding: .utf8)
            #expect(generatedCode.count > 50, "Generated parser should have substantial content")
        }
    }
    
    @Test("All grammar files are accessible")
    func testGrammarFilesExist() {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
        
        for grammarFile in Self.grammarFiles {
            let grammarFileURL = projectDir
                .appendingPathComponent(grammarFile)
                .appendingPathExtension("apus")
            
            #expect(FileManager.default.fileExists(atPath: grammarFileURL.path),
                    "Grammar file should exist: \(grammarFile).apus")
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
        
        let grammar: Grammar
        do {
            let grammarParser = try ApusParser(fromFile: grammarFileURL)
            grammar = try grammarParser.parse(explicitStartSymbol: "")
        } catch {
            Issue.record("Failed to parse base grammar: \(error)")
            return
        }
        
        // Create output directory
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        let parserOutputFile = outputDir
            .appendingPathComponent("apus_validation_test")
            .appendingPathExtension("swift")
        
        let parserGenerator = ParserGenerator(outputFile: parserOutputFile, grammar: grammar)
        try parserGenerator.generate()
        
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
