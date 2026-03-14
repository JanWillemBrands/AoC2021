//
//  GrammarTests.swift
//  AdventTests
//
//  Grammar parsing test suite using Swift Testing.
//  Each test case specifies an inline grammar, messages that should pass, and messages that should fail.
//

import Testing
import Foundation

// MARK: - Test Infrastructure

struct TestCase: CustomTestStringConvertible {
    let grammar: String
    let pass: [String]
    let fail: [String]
    let label: String

    var testDescription: String { label }

    init(
        grammar: String,
        pass: [String] = [],
        fail: [String] = [],
        label: String
    ) {
        self.grammar = grammar
        self.pass = pass
        self.fail = fail
        self.label = label
    }
}

/// Reset all global parser state between tests.
private func resetAllState() {
    crf = [:]
    crfReturnNodes = []
    unique = []
    remaining = []
    yield = []
    tokens = []
    cI = 0
    cU = 0
    trace = false
    traceIndent = 0
    failedParses = 0
    successfullParses = 0
    descriptorCount = 0
    duplicateDescriptorCount = 0
    GrammarNode.count = 0
}

/// Parse a grammar string, run a message through it, return whether it matched.
private func parseMatches(grammar grammarString: String, message: String) throws -> Bool {
    resetAllState()

    let grammarWithWhitespace = "whitespace : /\\s+/.\n" + grammarString
    let parser = try ApusParser(fromString: grammarWithWhitespace)
    guard let grammar = try parser.parseGrammar(explicitStartSymbol: "") else {
        return false
    }

    // Scanner throws when the message contains characters not matched by any terminal.
    // This is a valid parse failure, not a test error.
    let messageScanner: Scanner
    do {
        messageScanner = try Scanner(fromString: message, patterns: grammar.terminals)
    } catch is ScannerFailure {
        return false
    }
    tokens = messageScanner.tokens
    resetMessageParser(root: grammar.root)
    ntAdd(X: grammar.root, k: 0, i: 0)
    parseMessage()

    let extent = tokens.count - 1
    return currentParseRoot.yield.contains { $0.i == 0 && $0.j == extent }
}

/// Run all pass/fail messages for a test case.
private func runTestCase(_ tc: TestCase) throws {
    for message in tc.pass {
        let result = try parseMatches(grammar: tc.grammar, message: message)
        #expect(result == true, "\(tc.label): Expected PASS for '\(message)' with grammar: \(tc.grammar)")
    }
    for message in tc.fail {
        let result = try parseMatches(grammar: tc.grammar, message: message)
        #expect(result == false, "\(tc.label): Expected FAIL for '\(message)' with grammar: \(tc.grammar)")
    }
}

// MARK: - Test Suites

@Suite("Grammar Tests", .serialized)
struct GrammarTests {

    // MARK: - Literals and Sequences

    @Suite("Literals and Sequences", .serialized)
    struct LiteralsAndSequences {
        static let cases: [TestCase] = [
            TestCase(
                grammar: #"S = "x"."#,
                pass: ["x"],
                fail: ["y", "xx", ""],
                label: "single literal"
            ),
            TestCase(
                grammar: #"S = "a" "b"."#,
                pass: ["ab"],
                fail: ["a", "ba", ""],
                label: "two-literal sequence"
            ),
            TestCase(
                grammar: #"S = "a" "b" "c" "d"."#,
                pass: ["abcd"],
                fail: ["abc", "abcde"],
                label: "four-literal sequence"
            ),
            TestCase(
                grammar: #"S = "a" ""."#,
                pass: ["a"],
                label: "literal then epsilon"
            ),
            TestCase(
                grammar: #"S = ""."#,
                pass: [""],
                fail: ["x"],
                label: "epsilon only"
            ),
            TestCase(
                grammar: #"S = "" "" "x"."#,
                pass: ["x"],
                label: "epsilon epsilon literal"
            ),
            TestCase(
                grammar: #"S = "x" "x"."#,
                pass: ["xx"],
                fail: ["x", "xxx"],
                label: "repeated literal sequence"
            ),
        ]

        @Test(arguments: cases)
        func test(_ tc: TestCase) throws {
            try runTestCase(tc)
        }
    }

    // MARK: - Selection (Alternation)

    @Suite("Selection", .serialized)
    struct Selection {
        static let cases: [TestCase] = [
            TestCase(
                grammar: #"S = "a" | "b"."#,
                pass: ["a", "b"],
                fail: ["c", "ab", ""],
                label: "simple alternation"
            ),
            TestCase(
                grammar: #"S = "x" | "x"."#,
                pass: ["x"],
                fail: ["y"],
                label: "ambiguous alternation"
            ),
            TestCase(
                grammar: #"S = "a" | "b". S = "c"."#,
                pass: ["a", "b", "c"],
                fail: ["d"],
                label: "decomposed selection"
            ),
            TestCase(
                grammar: #"S = "a" | "c" "d"."#,
                pass: ["a", "cd"],
                fail: ["c", "d"],
                label: "alternation different lengths"
            ),
            TestCase(
                grammar: #"S = ("a" | "b") | "c"."#,
                pass: ["a", "b", "c"],
                fail: ["d"],
                label: "nested alternation"
            ),
            TestCase(
                grammar: #"S = "x" | ""."#,
                pass: ["x", ""],
                label: "literal or empty"
            ),
            TestCase(
                grammar: #"S = "" | "b"."#,
                pass: ["", "b"],
                label: "empty or literal"
            ),
        ]

        @Test(arguments: cases)
        func test(_ tc: TestCase) throws {
            try runTestCase(tc)
        }
    }

    // MARK: - EBNF Brackets (Groups, Options, Closures)

    @Suite("EBNF Brackets", .serialized)
    struct EBNFBrackets {
        static let cases: [TestCase] = [
            // Groups
            TestCase(
                grammar: #"S = ("a")."#,
                pass: ["a"],
                fail: ["b", ""],
                label: "group"
            ),
            TestCase(
                grammar: #"S = ((("a")))."#,
                pass: ["a"],
                label: "nested groups"
            ),
            TestCase(
                grammar: #"S = "x" ("x" | "x") "x"."#,
                pass: ["xxx"],
                label: "group in sequence"
            ),
            TestCase(
                grammar: #"S = ("x" | "x") "x"."#,
                pass: ["xx"],
                label: "group leading"
            ),
            TestCase(
                grammar: #"S = "x" ("x" | "x")."#,
                pass: ["xx"],
                label: "group trailing"
            ),
            TestCase(
                grammar: #"S = ( "a" "b" | "a" "b" ) "c"."#,
                pass: ["abc"],
                label: "ambiguous group"
            ),

            // Options
            TestCase(
                grammar: #"S = ["x"]."#,
                pass: ["x", ""],
                fail: ["xx"],
                label: "option"
            ),
            TestCase(
                grammar: #"S = [["a"]]."#,
                pass: ["a", ""],
                label: "nested option"
            ),
            TestCase(
                grammar: #"S = ["x"] "a"."#,
                pass: ["xa", "a"],
                label: "option then literal"
            ),
            TestCase(
                grammar: #"S = "x" ["x"]."#,
                pass: ["x", "xx"],
                label: "literal then option"
            ),
            TestCase(
                grammar: #"S = ["x"] "x"."#,
                pass: ["x", "xx"],
                label: "option then same literal"
            ),
            TestCase(
                grammar: #"S = ["a"] ["b"] ["c"]."#,
                pass: ["abc", "ab", "ac", "bc", "a", "b", "c", ""],
                label: "three options"
            ),
            TestCase(
                grammar: #"S = ["a" | "b"] ["c"]."#,
                pass: ["a", "b", "c", "ac", "bc", ""],
                label: "option with alternation"
            ),

            // Kleene closure
            TestCase(
                grammar: #"S = {"x"}."#,
                pass: ["", "x", "xx", "xxx"],
                label: "kleene closure"
            ),
            TestCase(
                grammar: #"S = "x" {"x"}."#,
                pass: ["x", "xx", "xxx"],
                fail: [""],
                label: "literal then closure"
            ),
            TestCase(
                grammar: #"S = {"x"} "x"."#,
                pass: ["x", "xx", "xxx"],
                fail: [""],
                label: "closure then literal"
            ),
            TestCase(
                grammar: #"S = {{"x"}}."#,
                pass: ["", "x", "xx"],
                label: "nested closure"
            ),
            TestCase(
                grammar: #"S = {{"x"}} "a"."#,
                pass: ["a", "xa", "xxa"],
                label: "nested closure then literal"
            ),
            TestCase(
                grammar: #"S = {"x"} {"x"}."#,
                pass: ["", "x", "xx", "xxx"],
                label: "two closures ambiguous"
            ),
            TestCase(
                grammar: #"S = "a" {"x"} "c"."#,
                pass: ["ac", "axc", "axxc"],
                label: "closure in sequence"
            ),
            TestCase(
                grammar: #"S = { "a" } "b"."#,
                pass: ["b", "ab", "aab"],
                label: "closure halt"
            ),
            TestCase(
                grammar: #"S = {"a"} "x" {"b" | "c"}."#,
                pass: ["x", "ax", "xb", "xc", "axbc"],
                label: "two closures with alternation"
            ),

            // Positive closure
            TestCase(
                grammar: #"S = <"x">."#,
                pass: ["x", "xx", "xxx"],
                fail: [""],
                label: "positive closure"
            ),
            TestCase(
                grammar: #"S = <"x" | "x">."#,
                pass: ["x", "xx"],
                label: "positive closure ambiguous"
            ),
            TestCase(
                grammar: #"S = <"x"> <"x">."#,
                pass: ["xx", "xxx"],
                label: "two positive closures"
            ),
            TestCase(
                grammar: #"S = <"a"> "b"."#,
                pass: ["ab", "aab"],
                fail: ["b", ""],
                label: "positive closure halt"
            ),

            // Bracket first/follow tests
            TestCase(
                grammar: #"S = "a" ("b") "c"."#,
                pass: ["abc"],
                label: "group first/follow"
            ),
            TestCase(
                grammar: #"S = "a" ["b"] "c"."#,
                pass: ["abc", "ac"],
                label: "option first/follow"
            ),
            TestCase(
                grammar: #"S = "a" {"b"} "c"."#,
                pass: ["ac", "abc", "abbc"],
                label: "closure first/follow"
            ),
            TestCase(
                grammar: #"S = "a" <"b"> "c"."#,
                pass: ["abc", "abbc"],
                fail: ["ac"],
                label: "positive closure first/follow"
            ),

            // Bracket sequences (fifo tests)
            TestCase(
                grammar: #"S = ["a" "b"]."#,
                pass: ["ab", ""],
                fail: ["a"],
                label: "option sequence"
            ),
            TestCase(
                grammar: #"S = {"a" "b"}."#,
                pass: ["", "ab", "abab"],
                fail: ["a"],
                label: "closure sequence"
            ),
            TestCase(
                grammar: #"S = <"a" "b">."#,
                pass: ["ab", "abab"],
                fail: ["", "a"],
                label: "positive closure sequence"
            ),
            TestCase(
                grammar: #"S = ["a"]."#,
                pass: ["a", ""],
                label: "option single"
            ),
            TestCase(
                grammar: #"S = {"a"}."#,
                pass: ["", "a", "aa"],
                label: "closure single"
            ),
            TestCase(
                grammar: #"S = <"a">."#,
                pass: ["a", "aa"],
                fail: [""],
                label: "positive closure single"
            ),
            TestCase(
                grammar: #"S = {"a" ["b"]}."#,
                pass: ["", "a", "ab", "aab", "abab"],
                label: "closure with optional tail"
            ),

            // Nullable bracket sequences
            TestCase(
                grammar: #"S = ("a") ("b") ("c")."#,
                pass: ["abc"],
                label: "group sequence"
            ),
            TestCase(
                grammar: #"S = {"a"} {"b"} {"c"}."#,
                pass: ["", "a", "b", "c", "abc"],
                label: "closure sequence nullable"
            ),
            TestCase(
                grammar: #"S = <"a"> <"b"> <"c">."#,
                pass: ["abc", "aabbc"],
                fail: ["", "ab", "ac", "bc"],
                label: "positive closure sequence"
            ),
        ]

        @Test(arguments: cases)
        func test(_ tc: TestCase) throws {
            try runTestCase(tc)
        }
    }

    // MARK: - Nonterminal Indirection

    @Suite("Indirection", .serialized)
    struct Indirection {
        static let cases: [TestCase] = [
            TestCase(
                grammar: #"S = N. N = "a"."#,
                pass: ["a"],
                fail: ["b"],
                label: "simple indirection"
            ),
            TestCase(
                grammar: #"S = N. N = ["a"]."#,
                pass: ["", "a"],
                label: "nullable option indirection"
            ),
            TestCase(
                grammar: #"S = N. N = {"a"}."#,
                pass: ["", "a", "aaa"],
                label: "nullable closure indirection"
            ),
            TestCase(
                grammar: #"S = "a" N. N = ["a"]."#,
                pass: ["a", "aa"],
                label: "nullable leading"
            ),
            TestCase(
                grammar: #"S = N "a". N = ["a"]."#,
                pass: ["a", "aa"],
                label: "nullable trailing"
            ),
            TestCase(
                grammar: #"S = N N. N = "a"."#,
                pass: ["aa"],
                label: "shared nonterminal"
            ),
            TestCase(
                grammar: #"S = N | N. N = "a"."#,
                pass: ["a"],
                label: "shared selection"
            ),
            TestCase(
                grammar: #"S = N | N. N = ["a"]."#,
                pass: ["", "a"],
                label: "shared nullable selection"
            ),
            TestCase(
                grammar: #"S = N "a" | N "a". N = "a"."#,
                pass: ["aa"],
                label: "shared tail"
            ),
            TestCase(
                grammar: #"S = "a" N | "a" N. N = "a"."#,
                pass: ["aa"],
                label: "shared head"
            ),
            TestCase(
                grammar: #"S = A B. A = "a". B = "b"."#,
                pass: ["ab"],
                label: "two nonterminals"
            ),
            TestCase(
                grammar: #"S = X X X. X = "x"."#,
                pass: ["xxx"],
                label: "three shared nonterminals"
            ),
            TestCase(
                grammar: #"S = X "x" | X "x". X = "x"."#,
                pass: ["xx"],
                label: "ambiguous shared nonterminal"
            ),
            TestCase(
                grammar: #"S = "x" X | "x" X. X = "x"."#,
                pass: ["xx"],
                label: "ambiguous shared head nonterminal"
            ),
            TestCase(
                grammar: #"S = X | X. X = "x"."#,
                pass: ["x"],
                label: "ambiguous selection nonterminal"
            ),
            TestCase(
                grammar: #"S = X | X. X = ["x"]."#,
                pass: ["x", ""],
                label: "ambiguous nullable selection nonterminal"
            ),
            TestCase(
                grammar: #"S = "x" X "x" | "x" X "x". X = "x"."#,
                pass: ["xxx"],
                label: "ambiguous wrapped nonterminal"
            ),
            TestCase(
                grammar: #"S = ( ["x"] | ["x"] ) "x"."#,
                pass: ["x", "xx"],
                label: "ambiguous optional in group"
            ),
            TestCase(
                grammar: #"S = A "b" | A "c". A = ["a"]."#,
                pass: ["b", "c", "ab", "ac"],
                label: "nullable nonterminal selection"
            ),
            TestCase(
                grammar: #"S = A "b" | A "c". A = "a" | ""."#,
                pass: ["b", "c", "ab", "ac"],
                label: "nullable nonterminal alternation"
            ),
            TestCase(
                grammar: #"S = A "b" | A "c". A = "a"."#,
                pass: ["ab", "ac"],
                fail: ["b", "c"],
                label: "non-nullable nonterminal selection"
            ),
            TestCase(
                grammar: #"S = A B. A = ["a"]. B = ["b"]."#,
                pass: ["", "a", "b", "ab"],
                label: "two nullable nonterminals"
            ),
            TestCase(
                grammar: #"S = X "a" | X "b". X = "x"."#,
                pass: ["xa", "xb"],
                label: "nonterminal instance different follow"
            ),
            TestCase(
                grammar: #"S = X. X = "x"."#,
                pass: ["x"],
                label: "simple nonterminal"
            ),
            TestCase(
                grammar: #"S = A. A = "a" | "b" | "c"."#,
                pass: ["a", "b", "c"],
                fail: ["d"],
                label: "nonterminal with three alternates"
            ),
            TestCase(
                grammar: #"S = { "a" {"b"} "c" }."#,
                pass: ["", "ac", "abc", "abbc", "acabc"],
                label: "nested closure in closure"
            ),
            TestCase(
                grammar: #"S = { "a" B "c" }. B = { "b" }."#,
                pass: ["", "ac", "abc", "abbc", "acabc"],
                label: "nonterminal closure in closure"
            ),
            TestCase(
                grammar: #"S = { "x" X "x" }. X = { "x" }."#,
                pass: ["", "xx", "xxx", "xxxx"],
                label: "ambiguous nested closures"
            ),
            TestCase(
                grammar: #"S = T "t". T = "a" | "b" | "c"."#,
                pass: ["at", "bt", "ct"],
                fail: ["t", "dt"],
                label: "nonterminal prefix"
            ),
            TestCase(
                grammar: #"S = { T ["a"] }. T = "t"."#,
                pass: ["", "t", "ta", "tta", "tata"],
                label: "closure with nullable tail nonterminal"
            ),
            TestCase(
                grammar: #"S = T "a" T "b". T = ["t"]."#,
                pass: ["ab", "tab", "atb", "tatb"],
                label: "nonterminal follow gathering"
            ),
        ]

        @Test(arguments: cases)
        func test(_ tc: TestCase) throws {
            try runTestCase(tc)
        }
    }

    // MARK: - Recursion

    @Suite("Recursion", .serialized)
    struct Recursion {
        static let cases: [TestCase] = [
            TestCase(
                grammar: #"S = "x" | "x" S."#,
                pass: ["x", "xx", "xxx"],
                label: "right recursion"
            ),
            TestCase(
                grammar: #"S = "x" S | "x"."#,
                pass: ["x", "xx", "xxx"],
                label: "right recursion reversed"
            ),
            TestCase(
                grammar: #"S = "x" | S "x"."#,
                pass: ["x", "xx", "xxx"],
                label: "left recursion"
            ),
            TestCase(
                grammar: #"S = S "x" | "x"."#,
                pass: ["x", "xx", "xxx"],
                label: "left recursion reversed"
            ),
            TestCase(
                grammar: #"S = S "x" | ""."#,
                pass: ["", "x", "xx"],
                label: "left recursion nullable"
            ),
            TestCase(
                grammar: #"S = "x" S | ""."#,
                pass: ["", "x", "xx"],
                label: "right recursion nullable"
            ),
            TestCase(
                grammar: #"S = "x" [S]."#,
                pass: ["x", "xx", "xxx"],
                fail: [""],
                label: "right recursion optional"
            ),
            TestCase(
                grammar: #"S = ["x" S]."#,
                pass: ["", "x", "xx"],
                label: "right recursion zero optional"
            ),
            TestCase(
                grammar: #"S = [S "x"]."#,
                pass: ["", "x", "xx"],
                label: "left recursion zero optional"
            ),
            TestCase(
                grammar: #"S = "a" S "a" | "a"."#,
                pass: ["a", "aaa", "aaaaa"],
                fail: ["aa", "aaaa"],
                label: "odd brackets"
            ),
            TestCase(
                grammar: #"S = ["a" S "a"]."#,
                pass: ["", "aa", "aaaa"],
                fail: ["a", "aaa"],
                label: "even brackets"
            ),
            TestCase(
                grammar: #"S = S "a" | S "b" | ""."#,
                pass: ["", "a", "b", "ab", "ba", "aab"],
                label: "left recursion two alts"
            ),
        ]

        @Test(arguments: cases)
        func test(_ tc: TestCase) throws {
            try runTestCase(tc)
        }
    }

    // MARK: - Ambiguity

    @Suite("Ambiguity", .serialized)
    struct Ambiguity {
        static let cases: [TestCase] = [
            TestCase(
                grammar: #"S = "a" | "a"."#,
                pass: ["a"],
                label: "ambiguous selection"
            ),
            TestCase(
                grammar: #"S = ["a"] ["a"]."#,
                pass: ["", "a", "aa"],
                label: "ambiguous option sequence"
            ),
            TestCase(
                grammar: #"S = {"a"} {"a"}."#,
                pass: ["", "a", "aa", "aaa"],
                label: "ambiguous closure sequence"
            ),
            TestCase(
                grammar: #"S = <"a"> <"a">."#,
                pass: ["aa", "aaa"],
                fail: ["", "a"],
                label: "ambiguous positive closure sequence"
            ),
            TestCase(
                grammar: #"S = ["a"] | ["a"]."#,
                pass: ["", "a"],
                label: "ambiguous nullable selection"
            ),
            TestCase(
                grammar: #"S = "b" | S S."#,
                pass: ["b", "bb", "bbb"],
                label: "highly ambiguous (ART torture half)"
            ),
            TestCase(
                grammar: #"S = "x" | S S | S S S."#,
                pass: ["x", "xx", "xxx"],
                label: "highly ambiguous (Binsbergen G3)"
            ),
            TestCase(
                grammar: #"S = "x" | S S."#,
                pass: ["x", "xx", "xxx"],
                label: "Binsbergen G3 two-way"
            ),
            TestCase(
                grammar: #"S = "x" | S S S."#,
                pass: ["x", "xxx"],
                fail: ["xx"],
                label: "Binsbergen G3 three-way"
            ),
            TestCase(
                grammar: #"S = [["a"]]."#,
                pass: ["", "a"],
                label: "nested double option"
            ),
            TestCase(
                grammar: #"S = {{"a"}}."#,
                pass: ["", "a", "aa"],
                label: "nested double closure"
            ),
            TestCase(
                grammar: #"S = <<"a">>."#,
                pass: ["a", "aa"],
                fail: [""],
                label: "nested double positive closure"
            ),
            TestCase(
                grammar: #"S = ["a"] | ["b"] | ["c"]."#,
                pass: ["", "a", "b", "c"],
                fail: ["d"],
                label: "nullable triple alternation"
            ),
        ]

        @Test(arguments: cases)
        func test(_ tc: TestCase) throws {
            try runTestCase(tc)
        }
    }

    // MARK: - Named Grammars from Literature

    @Suite("Named Grammars", .serialized)
    struct NamedGrammars {
        static let cases: [TestCase] = [
            TestCase(
                grammar: #"S = "b" S | A S "d" | "". A = "a"."#,
                pass: ["", "b", "ad", "aadd", "bad", "baadd"],
                label: "Cappers thesis G3"
            ),
            TestCase(
                grammar: #"S = "a" S | "a" S "d" | ""."#,
                pass: ["", "a", "aad", "aa"],
                label: "Cappers thesis G5"
            ),
            TestCase(
                grammar: #"S = "a" S "b" | "a" S "c" | "a"."#,
                pass: ["a", "aab", "aac"],
                fail: ["", "ab"],
                label: "Alfroozeh G0"
            ),
            TestCase(
                grammar: #"S = "a" | S "b" | S ["b"] C. C = "c"."#,
                pass: ["a", "ab", "ac", "abc", "abb"],
                label: "Alfroozeh Hunt"
            ),
            TestCase(
                grammar: #"S = "a" A B | "a" A "b". A = "a" | "c" | "". B = "b" | B "c" | ""."#,
                pass: ["aab"],
                label: "Binsbergen G1"
            ),
            TestCase(
                grammar: #"S = A C "a" B | A B "a" "a". A = "a" A | "a". B = "b" B | "b". C = "b" C | "c"."#,
                pass: ["aabbaa"],
                label: "Binsbergen G2"
            ),
            TestCase(
                grammar: #"S = "a" B "c" | "a" B "c". B = "b"."#,
                pass: ["abc"],
                label: "ambiguous shared prefix nonterminal"
            ),
            TestCase(
                grammar: #"S = "a" ("a" "b" | "a") ("b" "c" | "c")."#,
                pass: ["aabc", "aac"],
                label: "Scott & Johnstone EBNF two derivations"
            ),
            TestCase(
                grammar: #"S = "b" S93 | "a" S93 "c" | "". S93 = "b" S93 | "a" S93 "c" | ""."#,
                pass: ["", "b", "ac", "aacc", "aaaccc"],
                fail: ["aac"],
                label: "matched brackets Cappers G3 (recursive)"
            ),
            TestCase(
                grammar: #"S = "a" S | "a" S "c" | ""."#,
                pass: ["", "a", "aac"],
                label: "ambiguous brackets Cappers G5 (recursive)"
            ),
            TestCase(
                grammar: #"S = "a" S "b" | "a" S "c" | "a"."#,
                pass: ["a", "aab", "aac"],
                label: "Alfroozeh brackets"
            ),
            TestCase(
                grammar: #"S = ( ("a" | "a") | "a" ) | "a"."#,
                pass: ["a"],
                label: "deeply nested ambiguous alternation"
            ),
            TestCase(
                grammar: #"S = ((("a") "a") "a") "a"."#,
                pass: ["aaaa"],
                label: "deeply nested groups"
            ),
        ]

        @Test(arguments: cases)
        func test(_ tc: TestCase) throws {
            try runTestCase(tc)
        }
    }

    // MARK: - Empty Constructs

    @Suite("Empty Constructs", .serialized)
    struct EmptyConstructs {
        static let cases: [TestCase] = [
            TestCase(
                grammar: #"S = ."#,
                pass: [""],
                fail: ["x"],
                label: "empty sequence"
            ),
            TestCase(
                grammar: #"S = |."#,
                pass: [""],
                label: "empty selection"
            ),
            TestCase(
                grammar: #"S = ()."#,
                pass: [""],
                label: "empty group"
            ),
            TestCase(
                grammar: #"S = []."#,
                pass: [""],
                label: "empty option"
            ),
            TestCase(
                grammar: #"S = {}."#,
                pass: [""],
                label: "empty closure"
            ),
            TestCase(
                grammar: #"S = <>."#,
                pass: [""],
                label: "empty positive closure"
            ),
            TestCase(
                grammar: #"S = "a" ""."#,
                pass: ["a"],
                label: "explicit end of input"
            ),
            TestCase(
                grammar: #"S = "x". S = "xx". S = "xxx"."#,
                pass: ["x", "xx", "xxx"],
                label: "multiple definitions"
            ),
        ]

        @Test(arguments: cases)
        func test(_ tc: TestCase) throws {
            try runTestCase(tc)
        }
    }

    // MARK: - Regex Terminals

    @Suite("Regex", .serialized)
    struct Regex {
        static let cases: [TestCase] = [
            TestCase(
                grammar: #"S = "a" /u+/ "b"."#,
                pass: ["aub", "auub", "auuub"],
                fail: ["ab"],
                label: "inline regex"
            ),
        ]

        @Test(arguments: cases)
        func test(_ tc: TestCase) throws {
            try runTestCase(tc)
        }
    }

    // MARK: - Nullable Closures (edge cases)

    @Suite("Nullable Closures", .serialized)
    struct NullableClosures {
        static let cases: [TestCase] = [
            TestCase(
                grammar: #"S = { "x" | "" }."#,
                pass: ["", "x", "xx"],
                label: "kleene with nullable body"
            ),
            TestCase(
                grammar: #"S = < "x" | "" >."#,
                pass: ["x", "xx", ""],
                label: "positive closure with nullable body"
            ),
            TestCase(
                grammar: #"S = A B C. A = "a" | "". B = "b" | "". C = "c" | ""."#,
                pass: ["", "a", "b", "c", "ab", "ac", "bc", "abc"],
                label: "three nullable nonterminals"
            ),
        ]

        @Test(arguments: cases)
        func test(_ tc: TestCase) throws {
            try runTestCase(tc)
        }
    }

    // MARK: - Self-parsing (APUS grammar)

    @Suite("Self-parsing", .serialized)
    struct SelfParsing {
        static let cases: [TestCase] = [
            TestCase(
                grammar: "", // placeholder, handled by custom test
                pass: [],
                label: "APUS parses itself"
            ),
        ]

        @Test("APUS grammar parses itself")
        func apusSelfParse() throws {
            resetAllState()

            let sourceFileURL = URL(fileURLWithPath: #filePath)
            let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
            let grammarFileURL = projectDir
                .appendingPathComponent("apus")
                .appendingPathExtension("apus")

            let parser = try ApusParser(fromFile: grammarFileURL)
            let grammar = try parser.parseGrammar(explicitStartSymbol: "")
            #expect(grammar != nil, "APUS grammar should parse successfully")
            #expect(grammar?.nonTerminals.count ?? 0 > 0, "Should define nonterminals")
        }
    }
}
