//
//  SwiftSyntaxTests.swift
//  AdventTests
//
//  Shared infrastructure for SwiftSyntax comparison tests.
//
//  Compares parse trees produced by the Advent GLL parser (via Swift.apus)
//  with the reference trees from SwiftSyntax's Parser.parse().
//
//  Each domain file (SwiftSyntaxDeclarations.swift, SwiftSyntaxExpressions.swift, etc.)
//  provides a snippet catalog and test suite. Snippets carry provenance metadata
//  linking back to the SwiftSyntax test they were extracted from.
//

import Testing
import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - Snippet Type

struct SwiftSnippet: CustomTestStringConvertible, Sendable {
    let label: String
    let source: String
    let origin: String
    let syntaxVersion: String
    var disabledReason: String?
    var testDescription: String { label }
}

// MARK: - SwiftSyntax Reference Helper

func swiftSyntaxTree(_ source: String) -> String {
    let parsed = Parser.parse(source: source)
    return dumpSwiftSyntaxNode(Syntax(parsed), indent: 0)
}

func dumpSwiftSyntaxNode(_ node: Syntax, indent: Int) -> String {
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

// MARK: - Advent Parse Helpers

struct AdventParseResult {
    let tree: ParseTreeNode
    let builder: DerivationBuilder
    var isUnambiguous: Bool { builder.diagnostics.isEmpty }
}

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

func adventSwiftSyntaxTree(_ source: String) throws -> SourceFileSyntax? {
    try withParserIsolation {
        let grammar = try loadGrammarFile(named: "Swift")
        let scanner = try Scanner(fromString: source, patterns: grammar.terminals)
        let parser = MessageParser(grammar: grammar)
        parser.parse(tokens: scanner.tokens, trivia: scanner.trivia, input: scanner.input)

        var generator = SwiftSyntaxGenerator(grammar: grammar, tokens: parser.tokens)
        return generator.generate()
    }
}

// MARK: - Probes

@Suite("SwiftSyntax Comparison", .serialized)
struct SwiftSyntaxTests {

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
