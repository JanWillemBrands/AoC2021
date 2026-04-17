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
private func parseMatches(grammar grammarString: String, message: String) throws -> Bool {
    GrammarNode.count = 0
    trace = false
    traceIndent = 0

    let grammarWithWhitespace = "whitespace : /\\s+/.\n" + grammarString
    let parser = try ApusParser(fromString: grammarWithWhitespace)
    let grammar = try parser.parse(explicitStartSymbol: "")

    // Scanner throws when the message contains characters not matched by any terminal.
    // This is a valid parse failure, not a test error.
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
private func runTestCase(_ tc: TestCase) throws {
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
            TestCase(
                grammar: #"S = A. A = "a" B | "c". B = "b" A | "d"."#,
                pass: ["c", "ad", "abc", "abad", "ababc"],
                fail: ["", "a", "b", "ab"],
                label: "mutual recursion"
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
                grammar: #""#,
                illegalGrammar: true,
                label: "empty grammar"
            ),
            TestCase(
                grammar: #"."#,
                illegalGrammar: true,
                label: "no rule"
            ),
            TestCase(
                grammar: #"S = ."#,
                illegalGrammar: true,
                label: "empty sequence"
            ),
            TestCase(
                grammar: #"S = |."#,
                illegalGrammar: true,
                label: "empty selection"
            ),
            TestCase(
                grammar: #"S = ()."#,
                illegalGrammar: true,
                label: "empty group"
            ),
            TestCase(
                grammar: #"S = []."#,
                illegalGrammar: true,
                label: "empty option"
            ),
            TestCase(
                grammar: #"S = {}."#,
                illegalGrammar: true,
                label: "empty closure"
            ),
            TestCase(
                grammar: #"S = <>."#,
                illegalGrammar: true,
                label: "empty positive closure"
            ),
            TestCase(
                grammar: #"S = N."#,
                illegalGrammar: true,
                label: "undefined production rule"
            ),
            TestCase(
                grammar: #"S = "a" ""."#,
                pass: ["a"],
                label: "epsilon before end-of-string"
            ),
            TestCase(
                grammar: #"S = "x". S = "xx". S = "xxx"."#,
                pass: ["x", "xx", "xxx"],
                fail: ["", "xxxx"],
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

    // MARK: - LL(1) Detection

    @Suite("LL1 Detection", .serialized)
    struct LL1Detection {

        /// Parse a grammar and return the Grammar object for set inspection.
        private static func parseGrammar(_ grammarString: String) throws -> Grammar {
            GrammarNode.count = 0
            GrammarNode.isLL1 = true
            trace = false
            traceIndent = 0
            let full = "whitespace : /\\s+/.\n" + grammarString
            let parser = try ApusParser(fromString: full)
            return try parser.parse(explicitStartSymbol: "")
        }

        static let ll1Cases: [TestCase] = [
            // Simple literals and sequences
            TestCase(grammar: #"S = "a"."#, label: "single literal"),
            TestCase(grammar: #"S = "a" "b"."#, label: "two-literal sequence"),
            TestCase(grammar: #"S = ""."#, label: "epsilon only"),

            // Disjoint alternation
            TestCase(grammar: #"S = "a" | "b"."#, label: "simple alternation"),
            TestCase(grammar: #"S = "a" | "b" | "c"."#, label: "three alternates"),
            TestCase(grammar: #"S = "a" | ""."#, label: "nullable alternate"),

            // Brackets with disjoint FIRST/FOLLOW
            TestCase(grammar: #"S = "a" ["b"] "c"."#, label: "option disjoint"),
            TestCase(grammar: #"S = ["b"] "c"."#, label: "option then different literal"),
            TestCase(grammar: #"S = {"a"} "b"."#, label: "closure disjoint"),
            TestCase(grammar: #"S = <"a"> "b"."#, label: "positive closure disjoint"),
            TestCase(grammar: #"S = <"a">."#, label: "positive closure"),
            TestCase(grammar: #"S = ("a" | "b") "c"."#, label: "group disjoint alternates"),
            TestCase(grammar: #"S = ["a" | "b"] "c"."#, label: "option with alternation"),

            // Nonterminals
            TestCase(grammar: #"S = A B. A = "a". B = "b"."#, label: "two nonterminals"),
            TestCase(grammar: #"S = A. A = "a" | "b"."#, label: "nonterminal chain"),

            // #1: right-recursive expressions with repetition
            TestCase(
                grammar: #"S = E. E = T {"+" T}. T = "(" E ")" | "num"."#,
                label: "right-recursive expressions"
            ),
            // #5: dangling else resolved with optional tail
            TestCase(
                grammar: ###"""
                    statement = "if" "(" E ")" matched ["else" tail] | "other".
                    matched = "if" "(" E ")" matched "else" matched | "other".
                    tail = "if" "(" E ")" tail | "other".
                    E = "e".
                    """###,
                label: "dangling else resolved"
            ),
            // #6: right-recursive sum with primed tail
            TestCase(
                grammar: #"S = E SP. SP = "" | "+" S. E = "num" | "(" S ")"."#,
                label: "right-recursive sum primed"
            ),
            // #7: EBNF-style sum with repetition
            TestCase(
                grammar: #"S = E {"+" E}. E = "num" | "(" S ")"."#,
                label: "EBNF sum repetition"
            ),
            // #10: precedence via layered repetition
            TestCase(
                grammar: ###"""
                    Expr = Term {("+" | "-") Term}.
                    Term = Factor {("*" | "/") Factor}.
                    Factor = "num" | "(" Expr ")".
                    """###,
                label: "layered precedence"
            ),

            // #13: simple statements with optional expression tail
            TestCase(
                grammar: ###"""
                    Prog = "{" Stmts "}".
                    Stmts = Stmt Stmts | "".
                    Stmt = "id" "=" Expr ";" | "if" "(" Expr ")" Stmt.
                    Expr = "id" Etail.
                    Etail = "+" Expr | "-" Expr | "".
                    """###,
                label: "mini-language statements"
            ),
            // #14: function call with optional argument list (FIRST/FOLLOW disjoint)
            // Claimed not LL(1) but FIRST(option)={"IDENT"} is disjoint from FOLLOW(option)={")"}
            TestCase(
                grammar: #"S = "IDENT" "(" ["IDENT" {"," "IDENT"}] ")"."#,
                label: "func call optional args"
            ),

            // #18: precedence with left-associative repetition
            TestCase(
                grammar: ###"""
                    Expr = Term {"+" Term}.
                    Term = Factor {"*" Factor}.
                    Factor = "INT" | "(" Expr ")".
                    """###,
                label: "left-associative precedence"
            ),
            // #21: signed integer with optional sign
            TestCase(
                grammar: ###"""
                    integer = ["+" | "-"] digit {digit}.
                    digit = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9".
                    """###,
                label: "signed integer"
            ),

            // Three nullable nonterminals with disjoint FIRST/FOLLOW at each position
            TestCase(
                grammar: #"S = A B C. A = "a" | "". B = "b" | "". C = "c" | ""."#,
                label: "three nullable nonterminals"
            ),
            // Two different closures — FIRST({"a"})∩FOLLOW({"a"})=∅, FIRST({"b"})∩FOLLOW({"b"})=∅
            TestCase(grammar: #"S = {"a"} {"b"}."#, label: "two different closures nullable overlap"),

            // #12: multiple nullables in sequence, disjoint via FOLLOW
            // FIRST(B)={"b",ε}, FOLLOW(B)={"d","a"} — disjoint; FIRST(D)={"d",ε}, FOLLOW(D)={"a"} — disjoint
            TestCase(
                grammar: #"S = A "a". A = B D. B = "b" | "". D = "d" | ""."#,
                label: "multiple nullables disjoint"
            ),
            // #22: integer list vs set (each separately LL(1), combined disjoint FIRST)
            // Claimed not LL(1) but FIRST(intlist)=digits, FIRST(intset)="{", disjoint
            TestCase(
                grammar: ###"""
                    S = intlist | intset.
                    intlist = integer {"," integer}.
                    intset = "{" [intlist] "}".
                    integer = "num".
                    """###,
                label: "list vs set"
            ),
            // #23: minimal nullable recursive sequence
            // Claimed not LL(1) but FIRST={"A"}, nullable alt chosen on anything else; no conflict
            TestCase(
                grammar: #"r = "" | "A" r."#,
                label: "nullable recursive sequence"
            ),
            
            // #24: Imaginary Unary/binary operator conflict on the same token (very common real-world trap)
            TestCase(
                grammar: ###"""
                    Expr   = Term {("+"|"-") Term}.
                    Term   = Factor {("*"|"/") Factor}.
                    Factor = "num" | "(" Expr ")" | "-" Factor.
                    """###,
                label: "unary/binary minus overlap"
            ),
            
            // #25: Imaginary conflict: unary/binary at the SAME level + nullable propagation
            TestCase(
                grammar: ###"""
                    Expr = Term {BinOp Term} | UnOp Expr.
                    Term = "num" | "(" Expr ")".
                    BinOp = "+" | "-".
                    UnOp = "-" | "+".
                    """###,
                label: "unary/binary same-level conflict"
            ),
            
            // Sandwich repetitions – same token repeated on both sides of a literal
            // The intervening "b" cleanly separates FIRST/FOLLOW of the two closures
            TestCase(grammar: #"S = {"a"} "b" {"a"}."#, label: "sandwich repetitions"),
            
            // Balanced-parentheses tail (standard right-recursive Dyck-word generator)
            // Recursive alt starts only with "(", epsilon taken exactly on FOLLOW(S) which includes ")"
            TestCase(
                grammar: #"S = "(" S ")" S | ""."#,
                label: "balanced parens with nullable tail"
            ),
            
            // Mutual recursion: A and B call each other. FOLLOW must propagate through the cycle.
            // FOLLOW(A) ⊇ FOLLOW(B) ⊇ FOLLOW(A), both resolve to {"$"}.
            // Requires multiple fixed-point iterations in populateFirstFollowSets.
            TestCase(
                grammar: #"S = A. A = "a" B | "c". B = "b" A | "d"."#,
                label: "mutual recursion LL(1)"
            ),
            
        ]

        static let nonLL1Cases: [TestCase] = [
            // FIRST/FIRST conflicts
            TestCase(grammar: #"S = "a" | "a"."#, label: "duplicate alternate"),
            TestCase(grammar: #"S = "a" "b" | "a" "c"."#, label: "shared prefix"),

            // Recursion (creates FIRST/FIRST overlap)
            TestCase(grammar: #"S = "x" | S "x"."#, label: "left recursion"),
            TestCase(grammar: #"S = "x" | "x" S."#, label: "right recursion"),

            // Nullable nonterminal overlaps
            TestCase(grammar: #"S = A "b" | A "c". A = ["a"]."#, label: "nullable nonterminal selection"),

            // FIRST/FOLLOW conflicts (nullable bracket followed by same token)
            TestCase(grammar: #"S = ["a"] "a"."#, label: "option then same literal"),
            TestCase(grammar: #"S = {"a"} "a"."#, label: "closure then same literal"),

            // Closure overlaps
            TestCase(grammar: #"S = {"a"} {"a"}."#, label: "two same closures"),

            // Literature grammars
            TestCase(grammar: #"S = "b" | S S."#, label: "highly ambiguous (ART torture)"),
            TestCase(grammar: #"S = "x" | S S | S S S."#, label: "Binsbergen G3"),

            // #2: nullable nonterminal propagating to followers
            TestCase(
                grammar: ###"""
                    S = A.
                    A = B D A | "a".
                    B = D | "b".
                    D = "d" | "".
                    """###,
                label: "nullable propagation"
            ),
            // #3: classic dangling else
            TestCase(
                grammar: ###"""
                    S = "if" "(" E ")" S
                      | "if" "(" E ")" S "else" S
                      | "other".
                    E = "e".
                    """###,
                label: "dangling else"
            ),
            // #4: matched/unmatched if-else (still not LL(1))
            TestCase(
                grammar: ###"""
                    statement = matched | unmatched.
                    matched = "if" "(" E ")" matched "else" matched | "other".
                    unmatched = "if" "(" E ")" statement
                             | "if" "(" E ")" matched "else" unmatched.
                    E = "e".
                    """###,
                label: "matched unmatched"
            ),
            // #8: if-then with optional else (FOLLOW conflict on "else")
            TestCase(
                grammar: ###"""
                    Stat = "if" Exp "then" Stat MoreIf.
                    MoreIf = "else" Stat "end" | "".
                    Exp = "e".
                    """###,
                label: "if-then optional else"
            ),
            // #9: direct left-recursive list
            TestCase(
                grammar: #"List = List "," "item" | "item"."#,
                label: "left-recursive list"
            ),
            // #15: statement that can be assignment or call (common prefix)
            TestCase(
                grammar: ###"""
                    stmt = assign ";" | func_call ";".
                    assign = "IDENT" "=" Expr.
                    func_call = "IDENT" "(" arglist ")".
                    Expr = "e".
                    arglist = "a".
                    """###,
                label: "assignment or call"
            ),
            // #16: naturally written left-recursive expression
            TestCase(
                grammar: ###"""
                    Expr = Expr Op Expr | "(" Expr ")" | "Number".
                    Op = "+" | "*".
                    """###,
                label: "natural left-recursive expr"
            ),
            // #19: fully ambiguous operator grammar
            TestCase(
                grammar: #"Expr = Expr "+" Expr | Expr "*" Expr | "INT"."#,
                label: "ambiguous operator"
            ),
            // #20: left-recursive precedence
            TestCase(
                grammar: ###"""
                    Expr = Expr "+" Term | Term.
                    Term = Term "*" Factor | Factor.
                    Factor = "INT" | "(" Expr ")".
                    """###,
                label: "left-recursive precedence"
            ),
            // #24: common left prefix needing factoring
            TestCase(
                grammar: ###"""
                    Stmt = "id" "=" Expr ";" | "id" "(" ArgList ")".
                    Expr = "e".
                    ArgList = "a".
                    """###,
                label: "common prefix needs factoring"
            ),
            // #11: floating-point literal — overlapping alternatives in Float and Fract
            // Rewritten with regex terminal for digits; common prefix on digit sequences
            TestCase(
                grammar: ###"""
                    digit = /[0-9]/.
                    Float = Fract [Exp] [Suffix] | {digit} Exp [Suffix].
                    Fract = {digit} "." <digit> | <digit> ".".
                    Exp = "e" ["+" | "-"] <digit>.
                    Suffix = "f" | "l".
                    """###,
                label: "floating-point overlapping alternatives"
            ),

            // #17: left-recursion eliminated — FIRST(ExprP) ∩ FOLLOW(ExprP) on "*","+";
            // strong LL(1) rejects this, but recursive descent handles it naturally
            // because per-instance FOLLOW at each call site is more restricted than
            // the global union. Fixing this requires per-instance FOLLOW tracking.
            TestCase(
                grammar: ###"""
                    Expr = "(" Expr ")" ExprP | "Number".
                    ExprP = Op Expr ExprP | "".
                    Op = "+" | "*".
                    """###,
                label: "left-recursion eliminated tail conflict"
            ),
            
            // #18: Indirect (cyclic) left recursion – not direct, so simple detectors miss it
            TestCase(
                grammar: #"S = A "z". A = B "y" | "x". B = S "w" | "v"."#,
                label: "indirect left recursion cycle"
            ),
            
            // #19: Minimal shared-prefix + nullable propagation (smaller than #2)
            TestCase(
                grammar: #"S = A "b". A = "b" | ""."#,
                label: "tiny nullable prefix conflict"
            ),
            
            // #21: Symmetric recursion (palindrome-style)
            // "a" appears in FIRST(recursive alt) *and* in FOLLOW(S) because of the closing "a"
            TestCase(
                grammar: #"S = "a" S "a" | "b" | ""."#,
                label: "symmetric recursion conflict"
            ),
            
            // #22: Classic unambiguous-but-not-LL(1) (textbook favourite)
            // Language is unambiguous, but A is nullable *and* "b" ∈ FIRST(A) ∩ FOLLOW(A)
            TestCase(
                grammar: #"S = A "b". A = "b" | ""."#,
                label: "unambiguous but FIRST/FOLLOW overlap"
            ),
            
            // Indirect left recursion cycle — no direct left recursion, so many simple detectors miss it
            TestCase(
                grammar: #"S = A "z". A = B "y" | "x". B = S "w" | "v"."#,
                label: "indirect left recursion"
            ),
            
            // Optional trailing comma — FIRST of the inner list and the trailing "," are both handled inside the brackets
            TestCase(
                grammar: #"S = "(" [E {"," E} [","]] ")" . E = "id"."#,
                label: "optional trailing comma"
            ),
        ]

        @Test("LL(1) grammars detected correctly", arguments: ll1Cases)
        func testLL1(_ tc: TestCase) throws {
            let grammar = try Self.parseGrammar(tc.grammar)
            #expect(grammar.isLL1 == true, "\(tc.label): expected LL(1) for grammar: \(tc.grammar)")
        }

        @Test("Non-LL(1) grammars detected correctly", arguments: nonLL1Cases)
        func testNonLL1(_ tc: TestCase) throws {
            let grammar = try Self.parseGrammar(tc.grammar)
            #expect(grammar.isLL1 == false, "\(tc.label): expected non-LL(1) for grammar: \(tc.grammar)")
        }
    }

    // MARK: - Schrödinger Tokens

    @Suite("Schrödinger Tokens", .serialized)
    struct SchrodingerTokens {
        static let cases: [TestCase] = [
            // Two named terminals matching the same literal create a Schrödinger dual.
            // The parser must try both duals to find the successful parse.
            TestCase(
                grammar: #"t1 : "x". t2 : "x". S = t1 "a" | t2 "b"."#,
                pass: ["x a", "x b"],
                fail: ["x c", "x"],
                label: "basic Schrödinger dual"
            ),
            // Three named terminals on the same literal — three-way Schrödinger.
            TestCase(
                grammar: #"t1 : "x". t2 : "x". t3 : "x". S = t1 "a" | t2 "b" | t3 "c"."#,
                pass: ["x a", "x b", "x c"],
                fail: ["x d"],
                label: "three-way Schrödinger"
            ),
            // Keyword vs regex: "for" matches both kw (literal) and id (regex) at length 3.
            // Only one branch leads to a successful parse depending on the following token.
            TestCase(
                grammar: #"kw : "for". id : /[a-z]+/. S = kw "(" | id ")"."#,
                pass: ["for (", "for )", "hello )"],
                fail: ["for for", "hello ("],
                label: "keyword vs regex Schrödinger"
            ),
            // Schrödinger token in a closure — the dual must be tried on each iteration.
            TestCase(
                grammar: #"t1 : "x". t2 : "x". S = {t1} t2 "a"."#,
                pass: ["x a", "x x a", "x x x a"],
                fail: ["a"],
                label: "Schrödinger in closure"
            ),
            // Schrödinger with nonterminal indirection.
            TestCase(
                grammar: #"t1 : "x". t2 : "x". S = A | B. A = t1 "a". B = t2 "b"."#,
                pass: ["x a", "x b"],
                fail: ["x c"],
                label: "Schrödinger through nonterminals"
            ),
        ]

        @Test(arguments: cases)
        func test(_ tc: TestCase) throws {
            try runTestCase(tc)
        }
    }

    // MARK: - Frankenstein Tokens

    @Suite("Frankenstein Tokens", .serialized)
    struct FrankensteinTokens {
        static let cases: [TestCase] = [
            // Basic two-character split: scanner produces ">>" as longest match,
            // parser splits it into two ">" via Frankenstein prefix matching.
            TestCase(
                grammar: #"shift : ">>". S = ">" =>> ">" =>> | shift."#,
                pass: [">>", "> >"],
                label: "basic Frankenstein split or direct match"
            ),
            // Frankenstein-only path (no direct match for the composite token).
            TestCase(
                grammar: #"shift : ">>". S = ">" =>> ">" =>> ."#,
                pass: [">>", "> >"],
                fail: [">"],
                label: "Frankenstein-only split"
            ),
            // Three-character split: ">>>" split into three ">".
            TestCase(
                grammar: #"tripleShift : ">>>". shift : ">>". S = ">" =>> ">" =>> ">" =>> ."#,
                pass: [">>>", ">> >", "> >>", "> > >"],
                fail: [">>", ">", ">> >>"],
                label: "three-way Frankenstein split"
            ),
            // Frankenstein in the middle of a sequence.
            TestCase(
                grammar: #"shift : ">>". S = "a" ">" =>> ">" =>> "b"."#,
                pass: ["a >> b", "a > > b"],
                fail: ["a > b", "a b"],
                label: "Frankenstein mid-sequence"
            ),
            // Frankenstein with alternation: one alt splits, other matches directly.
            TestCase(
                grammar: #"shift : ">>". S = ">" =>> ">" =>> "a" | shift "b"."#,
                pass: [">> a", ">> b", "> > a"],
                fail: ["> > b"],
                label: "Frankenstein vs direct in alternation"
            ),
            // Frankenstein through a nonterminal boundary:
            // the split ">" pieces are consumed in different nonterminals.
            TestCase(
                grammar: #"shift : ">>". S = A B. A = ">" =>> . B = ">" =>> ."#,
                pass: [">>", "> >"],
                fail: [">"],
                label: "Frankenstein across nonterminals"
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
            GrammarNode.count = 0
            trace = false
            traceIndent = 0

            let sourceFileURL = URL(fileURLWithPath: #filePath)
            let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
            let grammarFileURL = projectDir
                .appendingPathComponent("apus")
                .appendingPathExtension("apus")

            let parser = try ApusParser(fromFile: grammarFileURL)
            let grammar = try parser.parse(explicitStartSymbol: "")
            #expect(grammar.nonTerminals.count > 0, "Should define nonterminals")
        }
    }
}
