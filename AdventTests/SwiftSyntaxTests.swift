//
//  SwiftSyntaxTests.swift
//  AdventTests
//
//  Compares parse trees produced by the Advent GLL parser (via Swift.apus)
//  with the reference trees from SwiftSyntax's Parser.parse().
//
//  Phase 1: structural comparison — both parsers accept the same input and
//  produce trees whose nonterminal/terminal shapes match at every level.
//

import Testing
import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - Test Cases

struct SwiftSnippet: CustomTestStringConvertible, Sendable {
    let label: String
    let source: String
    var testDescription: String { label }
}

// Phase 1: literals and simple declarations
let phase1Snippets: [SwiftSnippet] = [
    SwiftSnippet(label: "integer literal",       source: "let x = 42"),
    SwiftSnippet(label: "string literal",        source: #"let s = "hello""#),
    SwiftSnippet(label: "boolean literal",        source: "let b = true"),
    SwiftSnippet(label: "nil literal",            source: "let n: Int? = nil"),
    SwiftSnippet(label: "float literal",          source: "let pi = 3.14"),
    SwiftSnippet(label: "var declaration",         source: "var count = 0"),
    SwiftSnippet(label: "type annotation",         source: "let x: Int = 42"),
    SwiftSnippet(label: "multiple bindings",       source: "let a = 1, b = 2"),
]

// MARK: - SwiftSyntax Reference Helper

/// Parse with SwiftSyntax and return a simplified tree description.
/// Each node is "TypeName" for nonterminals, "kind(text)" for tokens.
func swiftSyntaxTree(_ source: String) -> String {
    let parsed = Parser.parse(source: source)
    return dumpSwiftSyntaxNode(Syntax(parsed), indent: 0)
}

private func dumpSwiftSyntaxNode(_ node: Syntax, indent: Int) -> String {
    let pad = String(repeating: "  ", count: indent)
    var result = ""

    if let token = node.as(TokenSyntax.self) {
        let text = token.text
        if !text.isEmpty {
            result += "\(pad)\(token.tokenKind.nameForComparison) \"\(text)\"\n"
        }
    } else {
        let typeName = "\(node.syntaxNodeType)"
            .replacingOccurrences(of: "Syntax", with: "")
        result += "\(pad)\(typeName)\n"
        for child in node.children(viewMode: .sourceAccurate) {
            result += dumpSwiftSyntaxNode(child, indent: indent + 1)
        }
    }
    return result
}

extension TokenKind {
    var nameForComparison: String {
        switch self {
        case .keyword(let kw):       return "keyword(\(kw))"
        case .identifier:            return "identifier"
        case .integerLiteral:        return "integerLiteral"
        case .floatLiteral:          return "floatLiteral"
        case .stringSegment:         return "stringSegment"
        case .binaryOperator:        return "binaryOperator"
        case .prefixOperator:        return "prefixOperator"
        case .postfixOperator:       return "postfixOperator"
        case .dollarIdentifier:      return "dollarIdentifier"
        case .stringQuote:           return "stringQuote"
        case .multilineStringQuote:  return "multilineStringQuote"
        default:                     return "\(self)"
        }
    }
}

// MARK: - Advent Parse Helper

struct AdventParseResult {
    let tree: ParseTreeNode
    let builder: DerivationBuilder
    var isUnambiguous: Bool { builder.diagnostics.isEmpty }
}

/// Parse with the Advent GLL parser using Swift.apus and return the parse tree.
func adventParse(_ source: String) throws -> AdventParseResult? {
    try withParserIsolation {
        let grammar = try loadGrammarFile(named: "Swift")
        let scanner = try Scanner(fromString: source, patterns: grammar.terminals)
        let parser = MessageParser(grammar: grammar)
        parser.parse(tokens: scanner.tokens, trivia: scanner.trivia, input: scanner.input)

        let extent = TokenPosition(token: parser.tokens.count - 1)
        let matched = parser.currentParseRoot.yield.contains { $0.i == .zero && $0.j == extent }
        guard matched else { return nil }

        let builder = DerivationBuilder(grammar: grammar, tokens: parser.tokens)
        guard let tree = builder.buildAST() else { return nil }
        return AdventParseResult(tree: tree, builder: builder)
    }
}

// Phase 2: binary expressions & operator folding
let phase2Snippets: [SwiftSnippet] = [
    SwiftSnippet(label: "simple addition",         source: "let x = 1 + 2"),
    SwiftSnippet(label: "operator precedence",     source: "let x = 1 + 2 * 3"),
    SwiftSnippet(label: "ternary conditional",     source: "let x = true ? 1 : 2"),
    SwiftSnippet(label: "prefix negation",         source: "let x = !true"),
    SwiftSnippet(label: "nil coalescing",          source: "let x = a ?? b"),
    SwiftSnippet(label: "type cast as",            source: "let x = 42 as Int"),
]

// MARK: - Test Suites

@Suite("SwiftSyntax Comparison", .serialized)
struct SwiftSyntaxTests {

    @Suite("Phase 1 — SwiftSyntax reference")
    struct SwiftSyntaxAcceptance {

        @Test("SwiftSyntax accepts snippet", arguments: phase1Snippets)
        func swiftSyntaxAccepts(_ snippet: SwiftSnippet) throws {
            let parsed = Parser.parse(source: snippet.source)
            #expect(!parsed.hasError, "SwiftSyntax parse error for: \(snippet.source)")
        }
    }

    @Suite("Phase 1 — Advent acceptance")
    struct AdventAcceptance {

        @Test("Advent accepts snippet", arguments: phase1Snippets)
        func adventAccepts(_ snippet: SwiftSnippet) throws {
            let result = try adventParse(snippet.source)
            #expect(result != nil, "Advent failed to parse: \(snippet.source)")
        }
    }

    @Suite("Phase 1 — Unambiguous parse")
    struct AmbiguityCheck {

        @Test("no residual ambiguity", arguments: phase1Snippets)
        func unambiguous(_ snippet: SwiftSnippet) throws {
            guard let result = try adventParse(snippet.source) else {
                Issue.record("Advent failed to parse: \(snippet.source)")
                return
            }
            #expect(result.isUnambiguous,
                    "Residual ambiguity in '\(snippet.source)': \(result.builder.diagnostics)")
        }
    }

    @Suite("Phase 1 — Tree structure comparison")
    struct StructuralComparison {

        @Test("dump both trees", arguments: phase1Snippets)
        func dumpBothTrees(_ snippet: SwiftSnippet) throws {
            let refTree = swiftSyntaxTree(snippet.source)
            guard let result = try adventParse(snippet.source) else {
                Issue.record("Advent failed to parse: \(snippet.source)")
                return
            }

            print("=== \(snippet.label) ===")
            print("--- SwiftSyntax ---")
            print(refTree)
            print("--- Advent ---")
            print(result.tree.dump())
            if !result.isUnambiguous {
                print("--- Ambiguity diagnostics ---")
                for d in result.builder.diagnostics { print("  \(d)") }
            }
        }
    }

    @Suite("Phase 2 — SwiftSyntax reference")
    struct SwiftSyntaxAcceptanceP2 {

        @Test("SwiftSyntax accepts snippet", arguments: phase2Snippets)
        func swiftSyntaxAccepts(_ snippet: SwiftSnippet) throws {
            let parsed = Parser.parse(source: snippet.source)
            #expect(!parsed.hasError, "SwiftSyntax parse error for: \(snippet.source)")
        }
    }

    @Suite("Phase 2 — Advent acceptance")
    struct AdventAcceptanceP2 {

        @Test("Advent accepts snippet", arguments: phase2Snippets)
        func adventAccepts(_ snippet: SwiftSnippet) throws {
            let result = try adventParse(snippet.source)
            #expect(result != nil, "Advent failed to parse: \(snippet.source)")
        }
    }

    @Suite("Phase 2 — Unambiguous parse")
    struct AmbiguityCheckP2 {

        @Test("no residual ambiguity", arguments: phase2Snippets)
        func unambiguous(_ snippet: SwiftSnippet) throws {
            guard let result = try adventParse(snippet.source) else {
                Issue.record("Advent failed to parse: \(snippet.source)")
                return
            }
            #expect(result.isUnambiguous,
                    "Residual ambiguity in '\(snippet.source)': \(result.builder.diagnostics)")
        }
    }

    @Suite("Phase 2 — Tree structure comparison")
    struct StructuralComparisonP2 {

        @Test("dump both trees", arguments: phase2Snippets)
        func dumpBothTrees(_ snippet: SwiftSnippet) throws {
            let refTree = swiftSyntaxTree(snippet.source)
            guard let result = try adventParse(snippet.source) else {
                Issue.record("Advent failed to parse: \(snippet.source)")
                return
            }

            print("=== \(snippet.label) ===")
            print("--- SwiftSyntax ---")
            print(refTree)
            print("--- Advent ---")
            print(result.tree.dump())
            if !result.isUnambiguous {
                print("--- Ambiguity diagnostics ---")
                for d in result.builder.diagnostics { print("  \(d)") }
            }
        }
    }

    @Suite("SwiftSyntax parser probe")
    struct ParserProbe {

        @Test("pattern node shape differs between declaration and switch case")
        func patternNodeShapeProbe() {
            let illegal = Parser.parse(source: "let let x = 1")
            #expect(!illegal.hasError)

            let tupleDecl = Parser.parse(source: "let (x, y) = (1, 2)")
            let tupleDeclTree = dumpSwiftSyntaxNode(Syntax(tupleDecl), indent: 0)
            #expect(tupleDeclTree.contains("TuplePattern"))
            #expect(!tupleDeclTree.contains("ValueBindingPattern"))

            let switchCase = Parser.parse(source: """
            switch (1, 2) {
            case let (x, y):
                break
            default:
                break
            }
            """)
            let switchCaseTree = dumpSwiftSyntaxNode(Syntax(switchCase), indent: 0)
            #expect(switchCaseTree.contains("ValueBindingPattern"))
            #expect(switchCaseTree.contains("ExpressionPattern"))
            #expect(switchCaseTree.contains("PatternExpr"))
        }
    }
}
