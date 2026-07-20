//
//  TestInfrastructure.swift
//  AdventTests
//
//  Shared test types and helpers for grammar parsing tests.
//

import Testing
import Foundation

private let parserIsolationLock = NSRecursiveLock()

@discardableResult
func withParserIsolation<T>(_ work: () throws -> T) rethrows -> T {
    parserIsolationLock.lock()
    defer { parserIsolationLock.unlock() }
    return try work()
}

enum TestInfrastructureError: Error, CustomStringConvertible {
    case grammarFileNotFound(name: String, candidates: [String])

    var description: String {
        switch self {
        case .grammarFileNotFound(let name, let candidates):
            return """
            Could not locate grammar '\(name)'.
            Checked:
            \(candidates.joined(separator: "\n"))
            """
        }
    }
}

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

func testProjectDirectory() -> URL {
    let sourceFileURL = URL(fileURLWithPath: #filePath)
    return sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
}

func resolveGrammarFileURL(named name: String) throws -> URL {
    let projectDir = testProjectDirectory()
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let withoutLeadingSlash = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
    let pathWithExtension = withoutLeadingSlash.hasSuffix(".apus")
        ? withoutLeadingSlash
        : withoutLeadingSlash + ".apus"

    var candidates: [URL] = []
    if pathWithExtension.contains("/") {
        candidates.append(projectDir.appendingPathComponent(pathWithExtension))
        if !pathWithExtension.hasPrefix("apus grammars/") {
            candidates.append(
                projectDir
                    .appendingPathComponent("apus grammars")
                    .appendingPathComponent(pathWithExtension)
            )
        }
    } else {
        candidates.append(
            projectDir
                .appendingPathComponent("apus grammars")
                .appendingPathComponent(pathWithExtension)
        )
        candidates.append(projectDir.appendingPathComponent(pathWithExtension))
    }

    var seen = Set<String>()
    for candidate in candidates where seen.insert(candidate.path).inserted {
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
    }

    throw TestInfrastructureError.grammarFileNotFound(name: name, candidates: Array(seen).sorted())
}

/// Parse a grammar string, run a message through it, return whether it matched.
func parseMatches(grammar grammarString: String, message: String) throws -> Bool {
    try withParserIsolation {
        trace = false
        traceIndent = 0

        let grammarWithWhitespace = "whitespace : /\\s+/.\n" + grammarString
        let parser = try ApusParser(fromString: grammarWithWhitespace)
        let grammar = try parser.parse(explicitStartSymbol: "")

        let messageParser = MessageParser(grammar: grammar)
        messageParser.parse(input: message)

        return messageParser.yield(of: messageParser.currentParseRoot).contains {
            $0.i == message.startIndex && $0.j == message.endIndex
        }
    }
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
    try withParserIsolation {
        trace = false
        traceIndent = 0

        let grammarFileURL = try resolveGrammarFileURL(named: name)
        let parser = try ApusParser(fromFile: grammarFileURL)
        return try parser.parse(explicitStartSymbol: "")
    }
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

func loadLanguageFixture(_ path: String) throws -> LanguageFixture {
    try withParserIsolation {
        trace = false
        traceIndent = 0

        let grammarFileURL = try resolveGrammarFileURL(named: path)
        let grammarDir = grammarFileURL.deletingLastPathComponent()

        let apusParser = try ApusParser(fromFile: grammarFileURL)
        let grammar = try apusParser.parse(explicitStartSymbol: "")
        let needsLayout = grammar.usesInjectedLayoutTokens

        let cases = grammar.messages.enumerated().map { (i, msg) in
            LanguageTestCase(index: i + 1, message: String(msg))
        }

        return LanguageFixture(grammar: grammar, grammarDir: grammarDir, cases: cases, needsLayout: needsLayout)
    }
}

func parseLanguageMessage(_ fixture: LanguageFixture, message: String) throws -> Bool {
    try withParserIsolation {
        let input: String
        if message.hasPrefix("#") {
            let fileName = message.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            let projectDir = testProjectDirectory()

            let candidateURLs: [URL]
            if fileName.hasPrefix("/") {
                candidateURLs = [URL(fileURLWithPath: String(fileName))]
            } else {
                candidateURLs = [
                    fixture.grammarDir.appendingPathComponent(fileName),
                    projectDir.appendingPathComponent(fileName)
                ]
            }

            guard let fileURL = candidateURLs.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
                throw TestInfrastructureError.grammarFileNotFound(
                    name: "message file \(fileName)",
                    candidates: candidateURLs.map(\.path)
                )
            }

            input = try String(contentsOf: fileURL, encoding: .utf8)
        } else {
            input = message
        }

        let parser = MessageParser(grammar: fixture.grammar)
        parser.parse(input: input)

        return parser.yield(of: parser.currentParseRoot).contains {
            $0.i == input.startIndex && $0.j == input.endIndex
        }
    }
}

/// Parse a grammar string and return the Grammar object for inspection.
func parseGrammar(_ grammarString: String) throws -> Grammar {
    try withParserIsolation {
        trace = false
        traceIndent = 0
        let full = "whitespace : /\\s+/.\n" + grammarString
        let parser = try ApusParser(fromString: full)
        return try parser.parse(explicitStartSymbol: "")
    }
}

/// Parse a grammar string, run a message through it, run the Oracle, return match status and prune count.
func parseAndDisambiguate(grammar grammarString: String, message: String) throws -> (matches: Bool, oraclePruned: Int) {
    try withParserIsolation {
        trace = false
        traceIndent = 0

        let grammarWithWhitespace = "whitespace : /\\s+/.\n" + grammarString
        let parser = try ApusParser(fromString: grammarWithWhitespace)
        let grammar = try parser.parse(explicitStartSymbol: "")

        let messageParser = MessageParser(grammar: grammar)
        messageParser.parse(input: message)

        let matches = messageParser.yield(of: messageParser.currentParseRoot).contains {
            $0.i == message.startIndex && $0.j == message.endIndex
        }
        let pruned = Oracle(parser: messageParser, input: message).disambiguate()
        return (matches, pruned)
    }
}

/// Parse, run the Oracle, and report whether a full-span parse SURVIVES disambiguation.
/// Unlike `parseAndDisambiguate` (which reports the pre-Oracle match), this checks the
/// root's full-span yield BOTH before and after the Oracle — the only way to catch an
/// over-pruning disambiguation rule that removes the sole valid derivation.
func parsePostOracle(grammar grammarString: String, message: String) throws -> (rawMatch: Bool, postMatch: Bool, pruned: Int) {
    try withParserIsolation {
        trace = false
        traceIndent = 0
        let grammarWithWhitespace = "whitespace : /\\s+/.\n" + grammarString
        let parser = try ApusParser(fromString: grammarWithWhitespace)
        let grammar = try parser.parse(explicitStartSymbol: "")
        let mp = MessageParser(grammar: grammar)
        mp.parse(input: message)
        func fullSpan() -> Bool {
            mp.yield(of: mp.currentParseRoot).contains { $0.i == message.startIndex && $0.j == message.endIndex }
        }
        let raw = fullSpan()
        let pruned = Oracle(parser: mp, input: message).disambiguate()
        return (raw, fullSpan(), pruned)
    }
}
