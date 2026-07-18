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

// MARK: - Tags

extension Tag {
    /// Reference-only tests that verify SwiftSyntax itself parses a snippet.
    /// They don't exercise the Advent parser. Keep them in the suite for the
    /// LCNP Phase 0 baseline run; filter them out of the inner-loop scheme.
    @Tag static var swiftSyntaxReference: Self
}

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

/// Phase 0 baseline metrics captured per parsed source.
/// Written one row per unique source into `baseline-phase0.csv` by `metricSink`.
struct BaselineMetrics {
    let sourceLength: Int
    let tokenCount: Int
    let descriptorCount: Int
    let duplicateDescriptorCount: Int
    let suppressedDescriptorCount: Int
    let crfCount: Int
    let yieldCount: Int
    let matched: Bool
    let oraclePruned: Int
}

/// Everything the SwiftSyntax test surfaces care about for a single source.
/// Produced by `runAdventOnce` and stored in `parseCache` so the four facets
/// (`adventAccepts`, `unambiguous`, `treesMatch`, plus baseline) share work.
struct AdventRunSnapshot {
    let result: AdventParseResult?
    let swiftSyntaxTree: SourceFileSyntax?
    let metrics: BaselineMetrics
}

// MARK: - Grammar load
//
// Cached across snippets. The exclude/Schrödinger order-dependence that
// originally forced fresh-loads retired in LCNP Phase D — exclude is now a
// per-end LCNP filter in `testSelect`/`tokenMatch`, and `yields` moved off
// `GrammarNode` into `MessageParser.yields[node.number]`, so the grammar is
// load-time immutable and safely shareable. Cutting the per-snippet
// reload (ApusParser + first/follow fixpoint + verifyLL1 + populateBitSets)
// dominates wall-clock for the small SwiftSyntax snippets (measured 7–9×
// suite speedup).
private let cachedSwiftGrammar: Grammar = {
    do {
        return try loadGrammarFile(named: "Swift")
    } catch {
        fatalError("Could not load Swift grammar for tests: \(error)")
    }
}()

private func loadFreshSwiftGrammar() -> Grammar { cachedSwiftGrammar }

// MARK: - Per-Source Parse Memoization (#2)

private final class ParseCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: AdventRunSnapshot] = [:]

    func value(for source: String, populate: () -> AdventRunSnapshot) -> AdventRunSnapshot {
        lock.lock()
        if let cached = storage[source] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        // Populate outside the cache lock; under `withParserIsolation` only one
        // parse runs at a time, so racing populates on the same source are
        // already coalesced by the parser lock above us.
        let snapshot = populate()
        lock.lock()
        if let existing = storage[source] {
            lock.unlock()
            return existing
        }
        storage[source] = snapshot
        lock.unlock()
        return snapshot
    }
}

private let parseCache = ParseCache()

// MARK: - Phase 0 Baseline Metrics Sink (#3)

private final class MetricSink: @unchecked Sendable {
    private let lock = NSLock()
    private let url: URL
    private var initialized = false
    private var handle: FileHandle?

    init() {
        url = testProjectDirectory().appendingPathComponent("baseline-phase0.csv")
    }

    func record(label: String, source: String, metrics m: BaselineMetrics) {
        lock.lock()
        defer { lock.unlock() }
        if !initialized {
            let header = "label,sourceLen,tokens,descriptors,duplicateDescriptors,suppressedDescriptors,crfSize,yieldCount,matched,oraclePruned\n"
            try? header.data(using: .utf8)?.write(to: url)
            handle = try? FileHandle(forWritingTo: url)
            _ = try? handle?.seekToEnd()
            initialized = true
        }
        let row = "\(csvEscape(label)),\(m.sourceLength),\(m.tokenCount),\(m.descriptorCount),\(m.duplicateDescriptorCount),\(m.suppressedDescriptorCount),\(m.crfCount),\(m.yieldCount),\(m.matched),\(m.oraclePruned)\n"
        if let data = row.data(using: .utf8) {
            handle?.write(data)
        }
    }

    private func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }
}

private let metricSink = MetricSink()

// MARK: - One-shot parse + ASTs + metrics

/// Run the full Advent pipeline once for `source`:
/// scan → parse → (if matched) Oracle disambiguate, build derivation tree, and
/// generate the SwiftSyntax AST. Records baseline metrics either way.
///
/// `label` is recorded into the baseline CSV; the SwiftSyntax suites pass the
/// snippet label, ad-hoc callers (e.g. the RegexLookbehind probe) pass a short
/// derived label.
///
/// Each populate loads a fresh Swift grammar (see note on `loadFreshSwiftGrammar`).
/// After the first populate the cache returns the stored snapshot directly, so
/// each unique source pays the grammar-load cost exactly once.
private func runAdventOnce(_ source: String, label: String) -> AdventRunSnapshot {
    parseCache.value(for: source) {
        withParserIsolation {
            let grammar = loadFreshSwiftGrammar()
            let input = source

            let parser = MessageParser(grammar: grammar)
            parser.parse(input: input)

            let extent = input.endIndex
            let origin = input.startIndex
            // Accept yields whose end is the input end OR is followed only by trivia —
            // EOS lex at y.j does the trivia skip and matches iff scan reaches `extent`.
            // This lets comment-only sources and trailing-comment sources pass.
            let matched = parser.yield(of: parser.currentParseRoot).contains { y in
                guard y.i == origin else { return false }
                if y.j == extent { return true }
                return !parser.lexer.lex(at: y.j, terminalID: grammar.eosID).isEmpty
            }

            var oraclePruned = 0
            var parseResult: AdventParseResult? = nil
            var swiftSyntax: SourceFileSyntax? = nil

            if matched {
                oraclePruned = Oracle(parser: parser, input: input).disambiguate()
                let builder = DerivationBuilder(parser: parser, input: input)
                if let tree = builder.buildAST() {
                    parseResult = AdventParseResult(tree: tree, builder: builder)
                }
                var generator = SwiftSyntaxGenerator(parser: parser, input: input)
                swiftSyntax = generator.generate()
            }

            let metrics = BaselineMetrics(
                sourceLength: source.count,
                tokenCount: parser.commitsByStart.count,
                descriptorCount: parser.descriptorCount,
                duplicateDescriptorCount: parser.duplicateDescriptorCount,
                suppressedDescriptorCount: parser.suppressedDescriptorCount,
                crfCount: parser.crf.count,
                yieldCount: parser.yieldCount,
                matched: matched,
                oraclePruned: oraclePruned
            )
            metricSink.record(label: label, source: source, metrics: metrics)
            return AdventRunSnapshot(result: parseResult, swiftSyntaxTree: swiftSyntax, metrics: metrics)
        }
    }
}

/// Back-compat entry point used by the SwiftSyntax test suites.
/// `throws` is preserved for API stability; the new path never actually throws.
func adventParse(_ source: String) throws -> AdventParseResult? {
    runAdventOnce(source, label: shortLabel(source)).result
}

/// Variant that also records the snippet's external label (e.g. `testTernary#1`)
/// into the baseline CSV. SwiftSyntax suites call this; older callers use
/// `adventParse` and get a derived label.
func adventParse(_ snippet: SwiftSnippet) throws -> AdventParseResult? {
    runAdventOnce(snippet.source, label: snippet.label).result
}

func adventSwiftSyntaxTree(_ source: String) throws -> SourceFileSyntax? {
    runAdventOnce(source, label: shortLabel(source)).swiftSyntaxTree
}

func adventSwiftSyntaxTree(_ snippet: SwiftSnippet) throws -> SourceFileSyntax? {
    runAdventOnce(snippet.source, label: snippet.label).swiftSyntaxTree
}

private func shortLabel(_ source: String) -> String {
    let oneLine = source.replacingOccurrences(of: "\n", with: " ")
    return String(oneLine.prefix(60))
}

// MARK: - Probes

// Focused snippets that exercise the scanner-level regex lookbehind annotations
// (++N / --N) on plainRegularExpressionLiteral in Swift.apus.
let regexLookbehindSnippets: [SwiftSnippet] = [
    // Division — `--1` blocks regex because the previous token is a value.
    SwiftSnippet(label: "div-int-int",      source: "let x = 1 / 2",            origin: "RegexLookbehind", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "div-ident-ident",  source: "let z = a / b",            origin: "RegexLookbehind", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "div-call-int",     source: "let z = f() / 2",          origin: "RegexLookbehind", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "div-subscript",    source: "let z = arr[0] / 2",       origin: "RegexLookbehind", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "div-chain",        source: "let r = 1 / 2 ; let s = 3 / 4", origin: "RegexLookbehind", syntaxVersion: "603.0.1"),

    // Regex — default allow after expression-starting tokens.
    SwiftSnippet(label: "regex-after-eq",   source: "let r = /abc/",            origin: "RegexLookbehind", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "regex-after-lparen", source: "let r = (/abc/)",        origin: "RegexLookbehind", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "regex-in-array",   source: "let arr = [/abc/]",        origin: "RegexLookbehind", syntaxVersion: "603.0.1"),

    // Compound positive override — eliminates Swift's `preferRegexOverBinaryOperator` hack.
    SwiftSnippet(label: "regex-after-try-bang",
                 source: #"let m = try! /^x/.wholeMatch(in: "hello")"#,
                 origin: "RegexLookbehind", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "regex-after-try-question",
                 source: #"let m = try? /^x/.wholeMatch(in: "hello")"#,
                 origin: "RegexLookbehind", syntaxVersion: "603.0.1"),

    // Ternary — `?` is NOT in the deny list, so the GLL parser finds the ternary parse.
    SwiftSnippet(label: "ternary-with-spaces",
                 source: "let r = b ? /1/ : /2/",
                 origin: "RegexLookbehind", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "ternary-tight",
                 source: "let r = b?/1/:/2/",
                 origin: "RegexLookbehind", syntaxVersion: "603.0.1",
                 disabledReason: "scanner allows regex after '?' (lookbehind works); blocked by Swift.apus conditionalOperator's <s> spacing requirement, a separate grammar policy"),
]

@Suite("Regex Lookbehind (Swift.apus integration)", .serialized)
struct RegexLookbehindIntegration {
    @Test("Advent accepts", arguments: regexLookbehindSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let result = try adventParse(snippet)
        #expect(result != nil, "Advent failed to parse: \(snippet.source)")
    }
}

@Suite("SwiftSyntax Comparison", .serialized)
struct SwiftSyntaxTests {

    @Suite("SwiftSyntax parser probe")
    struct ParserProbe {

        @Test("TEMP ifconfig canImport probe")
        func ifconfigProbe() throws {
            let cases = [
                "#if canImport(A)\nlet a = 1\n#endif",
                "#if canImport(A, _version: 2)\nlet a = 1\n#endif",
                "#if canImport(A, _version: 2.2)\nlet a = 1\n#endif",
                "#if canImport(A, _version: 2.2.2)\nlet a = 1\n#endif",
                "#if canImport(A, _underlyingVersion: 4)\nlet a = 1\n#endif",
                "let x = canImport(A, foo: 2)",
                "f(a, foo: 2)",
                "f(a, foo: 2.2.2)",
            ]
            for src in cases {
                let r = (try? adventParse(src)) ?? nil
                print("IFPROBE \(r != nil ? "ACCEPT" : "reject")  \(src.replacingOccurrences(of: "\n", with: "⏎"))")
            }
        }

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
