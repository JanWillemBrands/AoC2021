//
//  TestInfrastructure.swift
//  AdventTests
//
//  Shared test types and helpers for grammar parsing tests.
//

import Testing
import Foundation

struct TestCase: CustomTestStringConvertible {
    let grammar: String
    let pass: [String]
    let fail: [String]
    let illegalGrammar: Bool
    let label: String

    var testDescription: String { label }

    init(
        grammar: String,
        pass: [String] = [],
        fail: [String] = [],
        illegalGrammar: Bool = false,
        label: String
    ) {
        self.grammar = grammar
        self.pass = pass
        self.fail = fail
        self.illegalGrammar = illegalGrammar
        self.label = label
    }
}

/// Parse a grammar string, run a message through it, return whether it matched.
func parseMatches(grammar grammarString: String, message: String) throws -> Bool {
    GrammarNode.count = 0
    trace = false
    traceIndent = 0

    let grammarWithWhitespace = "whitespace : /\\s+/.\n" + grammarString
    let parser = try ApusParser(fromString: grammarWithWhitespace)
    let grammar = try parser.parse(explicitStartSymbol: "")

    let messageScanner: Scanner
    do {
        messageScanner = try Scanner(fromString: message, patterns: grammar.terminals)
    } catch is ScannerFailure {
        return false
    }
    let messageParser = MessageParser(grammar: grammar)
    messageParser.parse(tokens: messageScanner.tokens)

    let extent = TokenPosition(token: messageParser.tokens.count - 1)
    return messageParser.currentParseRoot.yield.contains { $0.i == .zero && $0.j == extent }
}

/// Run all pass/fail messages for a test case.
func runTestCase(_ tc: TestCase) throws {
    if tc.illegalGrammar {
        let grammarWithWhitespace = "whitespace : /\\s+/.\n" + tc.grammar
        #expect(throws: (any Error).self, "\(tc.label): Expected grammar to be illegal: \(tc.grammar)") {
            let parser = try ApusParser(fromString: grammarWithWhitespace)
            _ = try parser.parse(explicitStartSymbol: "")
        }
        return
    }
    for message in tc.pass {
        let result = try parseMatches(grammar: tc.grammar, message: message)
        #expect(result == true, "\(tc.label): Expected PASS for '\(message)' with grammar: \(tc.grammar)")
    }
    for message in tc.fail {
        let result = try parseMatches(grammar: tc.grammar, message: message)
        #expect(result == false, "\(tc.label): Expected FAIL for '\(message)' with grammar: \(tc.grammar)")
    }
}

/// Load a .apus grammar file from the project directory.
func loadGrammarFile(named name: String) throws -> Grammar {
    GrammarNode.count = 0
    trace = false
    traceIndent = 0

    let sourceFileURL = URL(fileURLWithPath: #filePath)
    let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
    let grammarFileURL = projectDir
        .appendingPathComponent(name)
        .appendingPathExtension("apus")

    let parser = try ApusParser(fromFile: grammarFileURL)
    return try parser.parse(explicitStartSymbol: "")
}

// MARK: - Language Grammar Test Support

struct LanguageTestCase: CustomTestStringConvertible, Sendable {
    let index: Int
    let message: String
    var testDescription: String { String(message.prefix(60)) }
}

struct LanguageFixture {
    let grammar: Grammar
    let grammarDir: URL
    let cases: [LanguageTestCase]
    let needsLayout: Bool
}

func loadLanguageFixture(_ path: String) -> LanguageFixture {
    GrammarNode.count = 0
    trace = false
    traceIndent = 0

    let sourceFileURL = URL(fileURLWithPath: #filePath)
    let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
    let grammarFileURL = projectDir.appendingPathComponent(path).appendingPathExtension("apus")
    let grammarDir = grammarFileURL.deletingLastPathComponent()

    let apusParser = try! ApusParser(fromFile: grammarFileURL)
    let grammar = try! apusParser.parse(explicitStartSymbol: "")
    let needsLayout = grammar.symbolToID[">>|"] != nil

    let cases = grammar.messages.enumerated().map { (i, msg) in
        LanguageTestCase(index: i + 1, message: String(msg))
    }

    return LanguageFixture(grammar: grammar, grammarDir: grammarDir, cases: cases, needsLayout: needsLayout)
}

func parseLanguageMessage(_ fixture: LanguageFixture, message: String) throws -> Bool {
    let messageScanner: Scanner
    if message.hasPrefix("#") {
        let fileName = message.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        let fileURL = fixture.grammarDir.appendingPathComponent(fileName)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        messageScanner = try Scanner(fromString: content, patterns: fixture.grammar.terminals)
    } else {
        messageScanner = try Scanner(fromString: message, patterns: fixture.grammar.terminals)
    }

    if fixture.needsLayout {
        injectLayoutTokens(
            tokens: &messageScanner.tokens,
            trivia: &messageScanner.trivia,
            gaps: messageScanner.gaps,
            bracketPairs: [("(", ")"), ("[", "]"), ("{", "}")]
        )
    }

    let parser = MessageParser(grammar: fixture.grammar)
    parser.parse(tokens: messageScanner.tokens)

    let extent = TokenPosition(token: parser.tokens.count - 1)
    return parser.currentParseRoot.yield.contains { $0.i == .zero && $0.j == extent }
}

/// Parse a grammar string and return the Grammar object for inspection.
func parseGrammar(_ grammarString: String) throws -> Grammar {
    GrammarNode.count = 0
    trace = false
    traceIndent = 0
    let full = "whitespace : /\\s+/.\n" + grammarString
    let parser = try ApusParser(fromString: full)
    return try parser.parse(explicitStartSymbol: "")
}
