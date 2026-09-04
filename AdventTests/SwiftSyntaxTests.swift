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
    /// Fallback sites the AST converter hit. `.unhandled` = construct not implemented
    /// yet (the phase work queue); `.lookupFailed` = a rule we claim to handle didn't
    /// yield its expected child (a bug). Lets `trees differ` be triaged by cause.
    let generatorDiagnostics: [GeneratorDiagnostic]
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
        // No `withParserIsolation` here: this path uses the shared, load-time
        // immutable `cachedSwiftGrammar` and builds a fresh `MessageParser` per
        // call. The core parser types carry no static mutable state, and
        // `ebnfDot()` no longer uses process-global scratch, so parses run
        // safely in parallel — the whole point of un-`.serialized`ing the
        // SwiftSyntax suites.
        do {
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
            var generatorDiagnostics: [GeneratorDiagnostic] = []

            if matched {
                oraclePruned = Oracle(parser: parser, input: input).disambiguate()
                let builder = DerivationBuilder(parser: parser, input: input)
                if let tree = builder.buildAST() {
                    parseResult = AdventParseResult(tree: tree, builder: builder)
                }
                var generator = SwiftSyntaxGenerator(parser: parser, input: input)
                swiftSyntax = generator.generate()
                generatorDiagnostics = generator.diagnostics
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
            // Only write the baseline CSV when explicitly requested — under parallel
            // execution the row order is nondeterministic, which would churn this
            // tracked file on every run. Set APUS_BASELINE_CSV=1 to regenerate it.
            if ProcessInfo.processInfo.environment["APUS_BASELINE_CSV"] == "1" {
                metricSink.record(label: label, source: source, metrics: metrics)
            }
            return AdventRunSnapshot(
                result: parseResult,
                swiftSyntaxTree: swiftSyntax,
                metrics: metrics,
                generatorDiagnostics: generatorDiagnostics
            )
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

/// Why the converter could not build a faithful tree for this snippet. Empty does NOT
/// imply the tree matches, but a non-empty list names every place it gave up.
func adventGeneratorDiagnostics(_ snippet: SwiftSnippet) -> [GeneratorDiagnostic] {
    runAdventOnce(snippet.source, label: snippet.label).generatorDiagnostics
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

// MARK: - Phase 1 tree fidelity
//
// Phase 1 of `SwiftSyntax Mapping.md`: literals and simple `let`/`var`
// declarations. Unlike the extracted SwiftSyntax suites — where `trees match`
// is an aspirational frontier — every row here is expected to match exactly.
// A failure is a regression in `GenerateSwiftSyntaxAST.swift`.
let phase1Snippets: [SwiftSnippet] = [
    // constantDeclaration / variableDeclaration
    SwiftSnippet(label: "let-int",        source: "let x = 42",        origin: "Phase1", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "var-bool-true",  source: "var b = true",      origin: "Phase1", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "var-bool-false", source: "var b = false",     origin: "Phase1", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "let-nil",        source: "let n = nil",       origin: "Phase1", syntaxVersion: "603.0.1"),

    // integerLiteral in all four radices, plus digit grouping
    SwiftSnippet(label: "let-hex",        source: "let h = 0x1F",      origin: "Phase1", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "let-octal",      source: "let o = 0o17",      origin: "Phase1", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "let-binary",     source: "let b = 0b1010",    origin: "Phase1", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "let-grouped",    source: "let g = 1_000_000", origin: "Phase1", syntaxVersion: "603.0.1"),

    // floatLiteral
    SwiftSnippet(label: "let-float",      source: "let f = 1.5",       origin: "Phase1", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "let-exponent",   source: "let e = 1e10",      origin: "Phase1", syntaxVersion: "603.0.1"),

    // stringLiteral
    SwiftSnippet(label: "let-string",     source: #"let s = "hello""#, origin: "Phase1", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "let-empty-str",  source: #"let s = """#,      origin: "Phase1", syntaxVersion: "603.0.1"),

    // typeAnnotation / typeIdentifier / optionalType
    SwiftSnippet(label: "let-annotated",  source: "let t: Int = 0",    origin: "Phase1", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "let-optional",   source: "let n: Int? = nil", origin: "Phase1", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "var-no-init",    source: "var y: Int",        origin: "Phase1", syntaxVersion: "603.0.1"),

    // patternInitializerList with more than one binding
    SwiftSnippet(label: "let-two-bindings", source: "let a = 1, c = 2", origin: "Phase1", syntaxVersion: "603.0.1"),

    // identifier reference on the right-hand side
    SwiftSnippet(label: "let-ident-rhs",  source: "let y = x",         origin: "Phase1", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 1 literals & simple declarations")
struct Phase1TreeTests {

    @Test("Advent accepts", arguments: phase1Snippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase1Snippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none — the converter believed it handled every node)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    /// Phase 1 sources must be built entirely from rules the converter understands.
    /// A `.lookupFailed` anywhere means a rule comment has drifted from `Swift.apus`;
    /// an `.unhandled` means a Phase 1 construct is silently degrading.
    @Test("converter reports no fallbacks", arguments: phase1Snippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Corpus-wide triage of the AST converter's fallback sites. Not a pass/fail gate on
/// tree fidelity — it answers "WHY can't these trees match?" in one run, so phase work
/// is driven by the biggest cause rather than by whichever label was eyeballed last.
///
/// `.lookupFailed` IS asserted: it means a rule the converter claims to handle didn't
/// yield its expected child, which is a bug regardless of which phase we're in.
/// Phase 3 of `SwiftSyntax Mapping.md`, first slice: function declarations.
/// `functionDeclaration` was the single largest cause of tree mismatch (410 of 3313
/// converter fallbacks), so it leads the tree-fidelity work.
let phase3FunctionSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "func-empty",        source: "func f() {}",                    origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-no-body",      source: "func f()",                       origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-return",       source: "func f() -> Int {}",             origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-one-param",    source: "func f(x: Int) {}",              origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-two-params",   source: "func f(x: Int, y: Int) {}",      origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-wildcard",     source: "func f(_ x: Int) {}",            origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-two-names",    source: "func f(to x: Int) {}",           origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-default",      source: "func f(x: Int = 0) {}",          origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-optional-ret", source: "func f() -> Int? {}",            origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-throws",       source: "func f() throws {}",             origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-async",        source: "func f() async {}",              origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-async-throws", source: "func f() async throws -> Int {}", origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-rethrows",     source: "func f() rethrows {}",           origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-body-stmt",    source: "func f() { let x = 1 }",         origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-param-and-body", source: "func f(x: Int) { let y = x }", origin: "Phase3", syntaxVersion: "603.0.1"),
]

/// Phase 4, fourth slice: attributes and generic parameter clauses. Both hang off every
/// declaration, so they pay off across the corpus rather than at one node type.
let phase4AttrSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "attr-func",       source: "@discardableResult func f() -> Int {}", origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "attr-struct",     source: "@frozen struct S {}",                origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "attr-two",        source: "@objc @MainActor class C {}",         origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "attr-with-modifier", source: "@objc public func f() {}",         origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "attr-var",        source: "@objc var x = 1",                     origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "attr-extension",  source: "@objc extension S {}",                origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "generic-func",    source: "func f<T>(x: T) {}",                  origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "generic-func-2",  source: "func f<T, U>(x: T, y: U) {}",         origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "generic-bound",   source: "func f<T: Equatable>(x: T) {}",       origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "generic-struct",  source: "struct S<T> {}",                      origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "generic-class-bound", source: "class C<T: Equatable> {}",        origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "generic-enum",    source: "enum E<T> { case a(T) }",             origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "generic-and-attr", source: "@objc func f<T>(x: T) {}",           origin: "Phase4", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 4 attributes & generic parameters")
struct Phase4AttrTests {

    @Test("Advent accepts", arguments: phase4AttrSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase4AttrSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase4AttrSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Phase 4, third slice: closures — signatures, capture lists, shorthand vs parenthesised
/// parameters, and trailing-closure calls.
let phase4ClosureSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "closure-empty",     source: "let a = { }",                        origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "closure-body",      source: "let a = { f() }",                    origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "closure-shorthand", source: "let a = { x in x }",                 origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "closure-shorthand2", source: "let a = { x, y in x }",             origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "closure-wildcard",  source: "let a = { _ in 1 }",                 origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "closure-typed",     source: "let a = { (x: Int) in x }",          origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "closure-typed2",    source: "let a = { (x: Int, y: Int) in x }",  origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "closure-result",    source: "let a = { (x: Int) -> Int in x }",   origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "closure-noparams-result", source: "let a = { () -> Int in 1 }",   origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "closure-throws",    source: "let a = { () throws -> Int in 1 }",  origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "closure-async",     source: "let a = { () async -> Int in 1 }",   origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "capture-weak-self", source: "let a = { [weak self] in f() }",     origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "capture-unowned",   source: "let a = { [unowned self] in f() }",  origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "capture-named",     source: "let a = { [x] in x }",               origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "capture-init",      source: "let a = { [x = y] in x }",           origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "capture-empty",     source: "let a = { [] in f() }",              origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "trailing-only",     source: "let a = f { 1 }",                    origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "trailing-with-args", source: "let a = f(1) { 2 }",                origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "trailing-labeled",  source: "let a = f { 1 } g: { 2 }",           origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "closure-in-call",   source: "let a = xs.map { $0 }",              origin: "Phase4", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 4 closures")
struct Phase4ClosureTests {

    @Test("Advent accepts", arguments: phase4ClosureSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase4ClosureSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase4ClosureSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Phase 4, second slice: initializer and operator declarations, and the `->` arrow as an
/// element of a flat operator sequence.
let phase4DeclSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "init-empty",      source: "struct S { init() {} }",                origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "init-params",     source: "struct S { init(x: Int) {} }",          origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "init-failable",   source: "struct S { init?(x: Int) {} }",         origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "init-iuo",        source: "struct S { init!(x: Int) {} }",         origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "init-throws",     source: "struct S { init() throws {} }",         origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "init-async",      source: "struct S { init() async {} }",          origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "init-modifier",   source: "class C { public init() {} }",          origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "init-body",       source: "struct S { init() { x = 1 } }",         origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "op-infix",        source: "infix operator +++",                    origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "op-prefix",       source: "prefix operator +++",                   origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "op-postfix",      source: "postfix operator +++",                  origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "op-precedence",   source: "infix operator +++ : AdditionPrecedence", origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "arrow-in-seq",    source: "let a = (Int) -> Bool",                 origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "arrow-throws",    source: "let a = (Int) throws -> Bool",          origin: "Phase4", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 4 init/operator declarations")
struct Phase4DeclTests {

    @Test("Advent accepts", arguments: phase4DeclSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase4DeclSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase4DeclSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Phase 4: the type grammar — tuple types, function types, generic argument clauses,
/// dot-qualified member types, and `Any`.
let phase4TypeSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "generic-type",    source: "let a: Array<Int> = []",        origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "generic-two",     source: "let a: Dictionary<String, Int> = [:]", origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "generic-nested",  source: "let a: Array<Array<Int>> = []",  origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "member-type",     source: "let a: A.B = x",                origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "member-type-3",   source: "let a: A.B.C = x",              origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "member-generic",  source: "let a: A.B<Int> = x",           origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "any-type",        source: "let a: Any = x",                origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "tuple-type",      source: "let a: (Int, String) = x",      origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "tuple-type-label", source: "let a: (x: Int, y: Int) = p",  origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-type",       source: "let a: () -> Void = f",         origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-type-args",  source: "let a: (Int, String) -> Bool = f", origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-type-throws", source: "let a: () throws -> Int = f",  origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-type-async", source: "let a: () async -> Int = f",    origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-type-nested", source: "let a: (Int) -> (Int) -> Int = f", origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "generic-expr",    source: "let a = f<Int>",                origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "generic-call",    source: "let a = f<Int>()",              origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "optional-generic", source: "let a: Array<Int>? = nil",     origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "func-returns-generic", source: "func f() -> Array<Int> {}", origin: "Phase4", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 4 types & generics")
struct Phase4TypeTests {

    @Test("Advent accepts", arguments: phase4TypeSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase4TypeSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase4TypeSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Phase 3, sixth slice: `if`/`switch` as EXPRESSIONS (swift-syntax models both that way in
/// statement position too), plus `guard`, condition lists, optional binding and match patterns.
let phase3BranchSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "if-simple",      source: "func f() { if c { g() } }",                  origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "if-else",        source: "func f() { if c { g() } else { h() } }",     origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "if-else-if",     source: "func f() { if c { g() } else if d { h() } }", origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "if-let",         source: "func f() { if let x = y { g() } }",          origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "if-var",         source: "func f() { if var x = y { g() } }",          origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "if-two-conds",   source: "func f() { if a, b { g() } }",               origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "if-let-plus",    source: "func f() { if let x = y, x > 0 { g() } }",   origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "guard-let",      source: "func f() { guard let x = y else { return } }", origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "guard-expr",     source: "func f() { guard c else { return } }",       origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "switch-default", source: "func f() { switch x { default: g() } }",     origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "switch-case",    source: "func f() { switch x { case 1: g()\ndefault: h() } }", origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "switch-bind",    source: "func f() { switch x { case let y: g(y) } }", origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "switch-where",   source: "func f() { switch x { case let y where y > 0: g() \ndefault: h() } }", origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "switch-two-items", source: "func f() { switch x { case 1, 2: g()\ndefault: h() } }", origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "if-expression",  source: "let a = if c { 1 } else { 2 }",              origin: "Phase3", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 3 if/switch/guard")
struct Phase3BranchTests {

    @Test("Advent accepts", arguments: phase3BranchSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase3BranchSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase3BranchSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Phase 3, fifth slice: declaration modifiers — `static`, `final`, access levels and the
/// `private(set)` detail form. These feed every declaration's `DeclModifierList`.
let phase3ModifierSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "static-func",     source: "struct S { static func f() {} }",     origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "public-func",     source: "public func f() {}",                  origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "private-let",     source: "private let x = 1",                   origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "public-struct",   source: "public struct S {}",                  origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "final-class",     source: "final class C {}",                    origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "public-final",    source: "public final class C {}",             origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "final-public",    source: "final public class C {}",             origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "private-set",     source: "struct S { private(set) var x = 1 }", origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "static-let",      source: "struct S { static let x = 1 }",       origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "open-class",      source: "open class C {}",                     origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "public-ext",      source: "public extension S {}",               origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "indirect-enum",   source: "indirect enum E { case a }",          origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "mutating-func",   source: "struct S { mutating func f() {} }",   origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "two-modifiers",   source: "struct S { public static func f() {} }", origin: "Phase3", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 3 declaration modifiers")
struct Phase3ModifierTests {

    @Test("Advent accepts", arguments: phase3ModifierSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase3ModifierSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase3ModifierSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Phase 3, fourth slice: enum case declarations — associated values and raw values.
/// swift-syntax uses ONE `EnumCaseDecl` for both styles, matching the merged grammar rule.
let phase3EnumCaseSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "case-one",        source: "enum E { case a }",                   origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "case-list",       source: "enum E { case a, b, c }",             origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "case-separate",   source: "enum E { case a\ncase b }",           origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "case-assoc-one",  source: "enum E { case a(Int) }",              origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "case-assoc-two",  source: "enum E { case a(Int, String) }",      origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "case-assoc-label", source: "enum E { case a(x: Int) }",          origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "case-raw-int",    source: "enum E: Int { case a = 1 }",          origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "case-raw-string", source: #"enum E: String { case a = "x" }"#,   origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "case-raw-list",   source: "enum E: Int { case a = 1, b = 2 }",   origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "case-assoc-optional", source: "enum E { case a(Int?) }",         origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "case-mixed-body", source: "enum E { case a\nfunc f() {} }",      origin: "Phase3", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 3 enum case declarations")
struct Phase3EnumCaseTests {

    @Test("Advent accepts", arguments: phase3EnumCaseSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase3EnumCaseSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase3EnumCaseSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Phase 3, third slice: control-transfer statements, `try`/`await`, collection
/// types and the non-identifier binding patterns.
let phase3StatementSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "return-void",   source: "func f() { return }",           origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "return-value",  source: "func f() -> Int { return 1 }",  origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "return-expr",   source: "func f() -> Int { return 1 + 2 }", origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "throw-stmt",    source: "func f() throws { throw e }",   origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "try-call",      source: "let a = try f()",               origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "try-optional",  source: "let a = try? f()",              origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "try-forced",    source: "let a = try! f()",              origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "await-call",    source: "func f() async { let a = await g() }", origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "try-infix",     source: "let a = try f() + 1",           origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "array-type",    source: "let a: [Int] = []",             origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "dict-type",     source: "let a: [String: Int] = [:]",    origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "nested-array-type", source: "let a: [[Int]] = []",       origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "iuo-type",      source: "let a: Int! = nil",             origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "metatype",      source: "let a = Int.self",              origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "wildcard-bind", source: "let _ = 1",                     origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "tuple-bind",    source: "let (x, y) = (1, 2)",           origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "tuple-bind-wild", source: "let (x, _) = (1, 2)",         origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "tuple-bind-nested", source: "let (x, (y, z)) = (1, (2, 3))", origin: "Phase3", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 3 control transfer, try/await, types & patterns")
struct Phase3StatementTests {

    @Test("Advent accepts", arguments: phase3StatementSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase3StatementSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase3StatementSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Phase 2: collection literals, tuples, implicit members, regex literals.
let phase2LiteralSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "array-empty",     source: "let a = []",             origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "array-one",       source: "let a = [1]",            origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "array-three",     source: "let a = [1, 2, 3]",      origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "array-nested",    source: "let a = [[1], [2]]",     origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "dict-empty",      source: "let a = [:]",            origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "dict-one",        source: #"let a = ["k": 1]"#,     origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "dict-two",        source: #"let a = ["k": 1, "j": 2]"#, origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "tuple-two",       source: "let a = (1, 2)",         origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "tuple-labelled",  source: "let a = (x: 1, y: 2)",   origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "tuple-empty",     source: "let a = ()",             origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "implicit-member", source: "let a: E = .some",       origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "super-member",    source: "class C { func f() { super.g() } }", origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "regex",           source: "let a = /abc/",          origin: "Phase2", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 2 collection literals & tuples")
struct Phase2LiteralTests {

    @Test("Advent accepts", arguments: phase2LiteralSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase2LiteralSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase2LiteralSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Phase 2: flat operator sequences. The interesting rows are assignment and the
/// ternary, where Advent's grammar NESTS a whole `expression` on the right but
/// swift-syntax keeps one flat `SequenceExpr` — the converter has to splice.
let phase2InfixSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "add",             source: "let a = 1 + 2",           origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "add-mul",         source: "let a = 1 + 2 * 3",       origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "compare",         source: "let a = x == 0",          origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "assign",          source: "x = 1",                   origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "assign-expr",     source: "x = 1 + 2",               origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "assign-member",   source: "x.y = 1",                 origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "compound-assign", source: "x += 1",                  origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "ternary",         source: "let a = c ? 1 : 2",       origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "ternary-expr",    source: "let a = c ? 1 + 1 : 2",   origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "is-cast",         source: "let a = x is Int",        origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "as-cast",         source: "let a = x as Int",        origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "as-optional",     source: "let a = x as? Int",       origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "long-chain",      source: "let a = 1 + 2 - 3 * 4",   origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "call-in-infix",   source: "let a = f() + g(1)",      origin: "Phase2", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 2 infix sequences")
struct Phase2InfixTests {

    @Test("Advent accepts", arguments: phase2InfixSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase2InfixSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase2InfixSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Phase 2: postfix expressions — member access, calls, subscripts, force-unwrap and
/// optional chaining. These rules are LEFT-recursive on `postfixExpression`, which maps
/// directly onto swift-syntax's nested base/expression fields.
let phase2PostfixSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "member",          source: "let a = x.y",            origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "member-chain",    source: "let a = x.y.z",          origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "tuple-element",   source: "let a = x.0",            origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "call-noargs",     source: "let a = f()",            origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "call-onearg",     source: "let a = f(1)",           origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "call-twoargs",    source: "let a = f(1, 2)",        origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "call-labelled",   source: "let a = f(x: 1)",        origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "call-mixed",      source: "let a = f(1, y: 2)",     origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "method-call",     source: "let a = x.f()",          origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "call-chain",      source: "let a = f()()",          origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "subscript",       source: "let a = x[0]",           origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "subscript-two",   source: "let a = x[0, 1]",        origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "force-unwrap",    source: "let a = x!",             origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "optional-chain",  source: "let a = x?.y",           origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "self-member",     source: "let a = self.x",         origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "paren-expr",      source: "let a = (x)",            origin: "Phase2", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "mixed-postfix",   source: "let a = x.y[0].z!",      origin: "Phase2", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 2 postfix expressions")
struct Phase2PostfixTests {

    @Test("Advent accepts", arguments: phase2PostfixSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase2PostfixSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase2PostfixSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Phase 3, second slice: the nominal type declarations, which share one
/// member-block shape in `Swift.apus`.
let phase3TypeSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "struct-empty",    source: "struct S {}",                     origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "class-empty",     source: "class C {}",                      origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "enum-empty",      source: "enum E {}",                       origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "protocol-empty",  source: "protocol P {}",                   origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "extension-empty", source: "extension S {}",                  origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "struct-inherit",  source: "struct S: P {}",                  origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "struct-inherit2", source: "struct S: P, Q {}",               origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "extension-inherit", source: "extension S: P {}",             origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "struct-one-member", source: "struct S { let x = 1 }",        origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "struct-two-members", source: "struct S { let x = 1\nvar y = 2 }", origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "struct-func",     source: "struct S { func f() {} }",        origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "class-nested",    source: "class C { struct S {} }",         origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "protocol-func",   source: "protocol P { func f() }",         origin: "Phase3", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "extension-func",  source: "extension S { func f() {} }",     origin: "Phase3", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 3 nominal type declarations")
struct Phase3TypeTests {

    @Test("Advent accepts", arguments: phase3TypeSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase3TypeSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase3TypeSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

@Suite("SwiftSyntax - Phase 3 function declarations")
struct Phase3FunctionTests {

    @Test("Advent accepts", arguments: phase3FunctionSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase3FunctionSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase3FunctionSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// `conditionExpression` is a PARALLEL copy of `expression` that exists only to forbid
/// assignment (assignment returns Void, so it is not a condition). EVERY other difference
/// between the two infix families is drift, because swift draws no other distinction:
/// whatever parses as an expression must parse the same way in a condition.
///
/// Each row is the same operator form in both positions. `adventAccepts` asserts parity of
/// acceptance; `unambiguous` asserts the condition form did not pick up an extra reading.
struct InfixParityCase: CustomTestStringConvertible, Sendable {
    let label: String
    let expressionForm: String
    let conditionForm: String
    var testDescription: String { label }
}

let infixParityCases: [InfixParityCase] = [
    .init(label: "amp-spaced",   expressionForm: "let z = a & b",            conditionForm: "if a & b { g() }"),
    .init(label: "amp-tight",    expressionForm: "let z = a&b",              conditionForm: "if a&b { g() }"),
    .init(label: "div-chain",    expressionForm: "let z = a/b/c",            conditionForm: "if a/b/c { g() }"),
    .init(label: "dot-operator", expressionForm: "let z = a...b",            conditionForm: "if a...b { g() }"),
    .init(label: "force-member", expressionForm: "let z = x!.y",             conditionForm: "if x!.y { g() }"),
    .init(label: "ternary-try-then",  expressionForm: "let z = c ? try f() : g()", conditionForm: "if c ? try f() : g() { h() }"),
    // The FALSE branch is the one that matters: `conditionalOperator` holds the then-branch
    // internally, so the extra `tryOperator? awaitOperator?` in `conditionInfixExpression`
    // sits in front of the false branch — where `expression` already supplies its own.
    .init(label: "ternary-try-else",  expressionForm: "let z = c ? f() : try g()", conditionForm: "if c ? f() : try g() { h() }"),
    .init(label: "ternary-await-else", expressionForm: "let z = c ? f() : await g()", conditionForm: "if c ? f() : await g() { h() }"),
    .init(label: "ternary-try-both",  expressionForm: "let z = c ? try f() : try g()", conditionForm: "if c ? try f() : try g() { h() }"),
]

@Suite("Grammar - condition/expression infix parity")
struct ConditionInfixParityTests {

    /// Why the `conditionExpression` duplication CANNOT simply be replaced by
    /// `infixExpression = @excludedFrom(condition) assignmentOperator expression .`
    ///
    /// `ContainmentRule` is pure SPAN containment — it prunes a reading whose span lies inside any
    /// yield of the container nonterminal (`$0.i <= span.i && span.j <= $0.j`). It is not an
    /// ancestor walk and knows nothing about scope boundaries. An assignment inside a CLOSURE that
    /// is itself inside a condition is lexically contained in the `condition` span, so
    /// `@excludedFrom(condition)` would prune it — even though it is perfectly legal Swift.
    ///
    /// The duplication gets this right for free: a closure body re-enters through
    /// `statements → statement → expression`, i.e. the UNRESTRICTED family, so the restriction
    /// naturally stops at the scope boundary. Any factoring proposed in TODO 25 must keep this
    /// case parsing.
    @Test("assignment inside a closure inside a condition is legal")
    func assignmentInClosureInsideCondition() throws {
        let source = "func f() { if xs.contains(where: { c in count = 1; return true }) { g() } }"
        #expect(!Parser.parse(source: source).hasError, "swift-syntax rejected the premise")
        #expect(try adventParse(source) != nil, """
            Advent rejected an assignment nested in a closure inside a condition. If this broke             after replacing the conditionExpression family with @excludedFrom(condition), that is             the span-containment-vs-scope problem, not a grammar bug in this snippet.
            """)
    }

    @Test("condition position accepts whatever expression position accepts", arguments: infixParityCases)
    func acceptanceParity(_ c: InfixParityCase) throws {
        let exprOK = try adventParse(c.expressionForm) != nil
        let condOK = try adventParse(c.conditionForm) != nil
        #expect(exprOK == condOK, """
            '\(c.label)': expression position \(exprOK ? "accepts" : "REJECTS"),             condition position \(condOK ? "accepts" : "REJECTS") — the two infix families             differ by more than the (deliberate) absence of assignment.
              expr: \(c.expressionForm)
              cond: \(c.conditionForm)
            """)
    }

    @Test("condition position stays unambiguous", arguments: infixParityCases)
    func conditionUnambiguous(_ c: InfixParityCase) throws {
        guard let r = try adventParse(c.conditionForm) else { return }   // acceptance covered above
        #expect(r.isUnambiguous, "'\(c.label)' is ambiguous in condition position: \(r.builder.diagnostics)")
    }
}

/// Phase 4, seventh slice: loops, do/catch, deinitializers and subscripts.
let phase4LoopSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "for-in",        source: "func f() { for x in xs { g(x) } }",                origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "for-in-where",  source: "func f() { for x in xs where x > 0 { g(x) } }",    origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "for-case",      source: "func f() { for case let x in xs { g(x) } }",       origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "for-wildcard",  source: "func f() { for _ in xs { g() } }",                 origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "while",         source: "func f() { while c { g() } }",                     origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "while-let",     source: "func f() { while let x = y { g(x) } }",            origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "repeat-while",  source: "func f() { repeat { g() } while c }",              origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "do-plain",      source: "func f() { do { g() } }",                          origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "do-catch",      source: "func f() { do { g() } catch { h() } }",            origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "do-catch-pat",  source: "func f() { do { g() } catch E.a { h() } }",        origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "do-two-catch",  source: "func f() { do { g() } catch E.a { h() } catch { i() } }", origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "deinit",        source: "class C { deinit {} }",                            origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "deinit-body",   source: "class C { deinit { g() } }",                       origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "subscript",     source: "struct S { subscript(i: Int) -> Int { 0 } }",      origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "subscript-getset", source: "struct S { subscript(i: Int) -> Int { get { 0 } set { } } }", origin: "Phase4", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 4 loops, do/catch, deinit, subscript")
struct Phase4LoopTests {

    @Test("Advent accepts", arguments: phase4LoopSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase4LoopSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase4LoopSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Phase 4, sixth slice: computed properties and accessor blocks. These bypass
/// `patternInitializerList` in the grammar but are still ONE PatternBinding in swift-syntax.
let phase4AccessorSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "computed-shorthand", source: "struct S { var x: Int { 0 } }",                    origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "computed-get",       source: "struct S { var x: Int { get { 0 } } }",            origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "computed-get-set",   source: "struct S { var x: Int { get { 0 } set { y = newValue } } }", origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "protocol-get",       source: "protocol P { var x: Int { get } }",                origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "protocol-get-set",   source: "protocol P { var x: Int { get set } }",            origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "setter-name",        source: "struct S { var x: Int { get { 0 } set(v) { y = v } } }", origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "accessor-modifier",  source: "struct S { var x: Int { mutating get { 0 } } }",   origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "accessor-throws",    source: "protocol P { var x: Int { get throws } }",         origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "accessor-async",     source: "protocol P { var x: Int { get async } }",          origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "computed-static",    source: "struct S { static var x: Int { 0 } }",             origin: "Phase4", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 4 accessors")
struct Phase4AccessorTests {

    @Test("Advent accepts", arguments: phase4AccessorSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase4AccessorSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase4AccessorSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// Phase 4, fifth slice: `typealias`, attributed / specifier-prefixed types, and
/// `#available` conditions.
let phase4MiscSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "typealias",        source: "typealias A = Int",                       origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "typealias-generic", source: "typealias A<T> = Array<T>",              origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "typealias-public", source: "public typealias A = Int",                origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "typealias-func",   source: "typealias A = (Int) -> Bool",             origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "inout-param",      source: "func f(x: inout Int) {}",                 origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "borrowing-param",  source: "func f(x: borrowing Int) {}",             origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "consuming-param",  source: "func f(x: consuming Int) {}",             origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "attr-type",        source: "let a: @Sendable () -> Void = f",         origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "avail-cond",       source: "func f() { if #available(macOS 10.15, *) { g() } }",   origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "unavail-cond",     source: "func f() { if #unavailable(macOS 10.15) { g() } }",    origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "avail-cond-two",   source: "func f() { if #available(macOS 10.15, iOS 13.0, *) { g() } }", origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "avail-cond-guard", source: "func f() { guard #available(macOS 10.15, *) else { return } }", origin: "Phase4", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 4 typealias, attributed types, #available")
struct Phase4MiscTests {

    @Test("Advent accepts", arguments: phase4MiscSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase4MiscSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase4MiscSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// `@available` — the one attribute whose arguments now have a real grammar rather than
/// balanced-token soup.
let phase4AvailableSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "avail-star",        source: "@available(*, deprecated) func f() {}",             origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "avail-platform",    source: "@available(macOS 10.15, *) func f() {}",            origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "avail-two-plat",    source: "@available(macOS 10.15, iOS 13.0, *) func f() {}",  origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "avail-three-part",  source: "@available(macOS 10.15.1, *) func f() {}",          origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "avail-message",     source: #"@available(*, deprecated, message: "use g") func f() {}"#, origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "avail-renamed",     source: #"@available(*, deprecated, renamed: "g") func f() {}"#,     origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "avail-introduced",  source: "@available(macOS, introduced: 10.15) func f() {}",  origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "avail-unavailable", source: "@available(*, unavailable) func f() {}",            origin: "Phase4", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "avail-on-struct",   source: "@available(macOS 10.15, *) struct S {}",            origin: "Phase4", syntaxVersion: "603.0.1"),
]

@Suite("SwiftSyntax - Phase 4 @available")
struct Phase4AvailableTests {

    @Test("Advent accepts", arguments: phase4AvailableSnippets)
    func adventAccepts(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        #expect(try adventParse(snippet) != nil, "Advent failed to parse: \(snippet.source)")
    }

    @Test("trees match", arguments: phase4AvailableSnippets)
    func treesMatch(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let refDump = dumpSwiftSyntaxNode(Syntax(Parser.parse(source: snippet.source)), indent: 0)
        guard let adventTree = try adventSwiftSyntaxTree(snippet) else {
            Issue.record("Advent produced no SwiftSyntax tree for: \(snippet.source)")
            return
        }
        let adventDump = dumpSwiftSyntaxNode(Syntax(adventTree), indent: 0)
        let why = adventGeneratorDiagnostics(snippet)
        #expect(refDump == adventDump, """
            Trees differ for '\(snippet.label)' — \(snippet.source)
            --- swift-syntax ---
            \(refDump)
            --- advent ---
            \(adventDump)
            --- converter fallbacks ---
            \(why.isEmpty ? "(none)" : why.map(\.description).joined(separator: "\n"))
            """)
    }

    @Test("converter reports no fallbacks", arguments: phase4AvailableSnippets)
    func noConverterFallbacks(_ snippet: SwiftSnippet) throws {
        guard snippet.disabledReason == nil else { return }
        let diagnostics = adventGeneratorDiagnostics(snippet)
        #expect(diagnostics.isEmpty, """
            Converter fell back on '\(snippet.label)' — \(snippet.source)
            \(diagnostics.map(\.description).joined(separator: "\n"))
            """)
    }
}

/// `attributeArgumentClause = >s< "(" balancedTokens? ")"` accepts ANY balanced token sequence
/// inside an attribute's parentheses. That is an over-generality question, not just a tree-shape
/// one: these rows are inputs the COMPILER rejects, and the soup lets them through.
///
/// Red rows here are the case for replacing the soup with real argument grammars. `@available`
/// is the interesting one, because the grammar ALREADY has `availabilityArguments` — it is used
/// by `availabilityCondition` (`#available(…)`) and simply not reused by `availableAttribute`.
let attributeSoupSnippets: [SwiftSnippet] = [
    SwiftSnippet(label: "available-garbage",   source: "@available(!!! ??? ***) func f() {}", origin: "AttrSoup", syntaxVersion: "603.0.1"),
    // NOT included: `@available(macOS 10.15)` (no `*`). Probed — swift-syntax ACCEPTS it, so it
    // is not evidence of over-generality here even though the compiler wants the `*`.
    SwiftSnippet(label: "available-nonsense",  source: "@available(1 + 2) func f() {}",       origin: "AttrSoup", syntaxVersion: "603.0.1"),
    SwiftSnippet(label: "objc-garbage",        source: "@objc(+++) func f() {}",              origin: "AttrSoup", syntaxVersion: "603.0.1"),
]

@Suite("Grammar - attribute argument over-generality")
struct AttributeSoupTests {

    @Test("swift-syntax verdict is the premise", .tags(.swiftSyntaxReference), arguments: attributeSoupSnippets)
    func swiftSyntaxRejects(_ snippet: SwiftSnippet) throws {
        #expect(Parser.parse(source: snippet.source).hasError,
                "premise failed — swift-syntax accepts '\(snippet.source)'")
    }

    @Test("Advent rejects too", arguments: attributeSoupSnippets)
    func adventRejects(_ snippet: SwiftSnippet) throws {
        #expect(try adventParse(snippet.source) == nil,
                "attribute token soup accepted invalid input: \(snippet.source)")
    }
}

@Suite("SwiftSyntax - Converter fallback triage")
struct ConverterFallbackTriage {

    static let corpus: [SwiftSnippet] =
        declarationSnippets + expressionSnippets + statementSnippets
        + typeSnippets + patternSnippets + attributeSnippets + translatedSnippets

    @Test("no lookupFailed anywhere in the accept corpus")
    func noLookupFailures() throws {
        var tally: [String: Int] = [:]
        var unhandled: [String: Int] = [:]
        var failures: [String] = []
        var samples: [String: [String]] = [:]

        for snippet in Self.corpus where snippet.disabledReason == nil {
            for d in adventGeneratorDiagnostics(snippet) {
                let key = "\(d.function): \(d.reason)"
                switch d.kind {
                case .lookupFailed:
                    tally[key, default: 0] += 1
                    if failures.count < 20 { failures.append("\(snippet.label): \(d)") }
                case .unhandled:
                    unhandled[key, default: 0] += 1
                }
                if samples[key, default: []].count < 6 {
                    samples[key, default: []].append("\(snippet.label) «\(d.text.prefix(60))»")
                }
            }
        }

        // Printed every run — this is the Phase 2/3/4 work queue, ordered by size.
        print("=== converter .unhandled tally (\(unhandled.values.reduce(0, +)) total) ===")
        for (key, n) in unhandled.sorted(by: { $0.value > $1.value }) {
            print(String(format: "%6d  %@", n, key))
            for s in samples[key] ?? [] { print("          \(s)") }
        }
        print("=== converter .lookupFailed tally (\(tally.values.reduce(0, +)) total) ===")
        for (key, n) in tally.sorted(by: { $0.value > $1.value }) {
            print(String(format: "%6d  %@", n, key))
        }

        #expect(tally.isEmpty, """
            Converter reported \(tally.values.reduce(0, +)) .lookupFailed fallbacks — each one is a
            rule the converter claims to handle that did not yield its expected child.
            \(failures.joined(separator: "\n"))
            """)
    }
}

@Suite("SwiftSyntax Comparison", .serialized)
struct SwiftSyntaxTests {

    @Suite("SwiftSyntax parser probe")
    struct ParserProbe {

        /// Split out of `patternNodeShapeProbe` and SKIPPED: swift-syntax's parser no longer
        /// flags `let let x = 1`, so this reference assertion cannot hold as written. It is
        /// almost certainly the same parser-leniency category as
        /// `SwiftSyntaxRejects.swiftSyntaxLenientLabels` — swift-syntax recovers where the
        /// compiler errors — rather than Advent being wrong; note that the probe's own subject
        /// (pattern node shape) is unaffected and still asserted below.
        ///
        /// REVISIT AT THE SWIFT 6.4 CONVERSION: probe `swiftc -parse` for the compiler's verdict,
        /// and check what ADVENT does with the same input. If swift accepts it and Advent rejects
        /// it, that is a faithfulness gap in the opposite direction and deleting this assertion
        /// would bury it.
        @Test("`let let x = 1` is rejected", .disabled("swift-syntax no longer reports hasError for `let let x = 1`; re-probe against the compiler during the Swift 6.4 conversion"))
        func illegalDoubleLetProbe() {
            #expect(Parser.parse(source: "let let x = 1").hasError)
        }

        @Test("pattern node shape differs between declaration and switch case")
        func patternNodeShapeProbe() {
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

        /// The operator-terminal family, pinned against swift-syntax. Each row below was a
        /// LATENT regression at some point — the grammar had no coverage for any of them, so
        /// two separate refactors broke them silently. Asserting swift's verdict alongside
        /// Advent's keeps the pair locked together.
        ///
        /// The arrow is position-dependent: `->` is punctuation in an expression (reachable
        /// only via `ArrowExprSyntax`) but a legal NAME in an operator declaration, and is
        /// rejected in a function name. The generic-`<` peel-off is a separate axis — see
        /// `functionNameOperator` / `@preempt(openAngle)` in Swift.apus.
        @Test("operator terminals: arrow position and generic peel-off match swift")
        func operatorTerminalFamilyProbe() throws {
            // `->` as a DECLARED operator name: legal.
            #expect(!Parser.parse(source: "infix operator ->").hasError)
            #expect(try adventParse("infix operator ->") != nil)

            // `->` as a FUNCTION name: "expected identifier in function".
            #expect(Parser.parse(source: "func ->(a: Int, b: Int) {}").hasError)
            #expect(try adventParse("func ->(a: Int, b: Int) {}") == nil)

            // Non-arrow operator function names stay legal, including `!`/`?`-led ones.
            for name in ["+", "??", "!!"] {
                let source = "func \(name)(a: Int, b: Int) {}"
                #expect(!Parser.parse(source: source).hasError, "swift rejected \(source)")
                #expect(try adventParse(source) != nil, "Advent rejected \(source)")
            }

            // A `.`-led operator declaration: no operatorHead, so it needs `dotOperator`.
            #expect(!Parser.parse(source: "prefix operator ..<").hasError)
            #expect(try adventParse("prefix operator ..<") != nil)

            // Generic clause peeled off an operator function name (testTry1/testInvalid28).
            let generic = "func %%%%<T, U>(x: T, y: U) -> Int { return 0 }"
            #expect(!Parser.parse(source: generic).hasError)
            #expect(try adventParse(generic) != nil)
        }

    }
}
