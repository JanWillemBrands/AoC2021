//
//  SpecialTokenTests.swift
//  AdventTests
//
//  Tests for Schrödinger tokens (ambiguous scanner matches), Frankenstein tokens
//  (partial token splitting), and exclusion sets (keyword suppression).
//

import Testing
import Foundation

@Suite("Special Token Tests", .serialized)
struct SpecialTokenTests {

    // MARK: - Schrödinger Tokens

    @Suite("Schrödinger Tokens", .serialized)
    struct SchrodingerTokens {
        static let cases: [TestCase] = [
            TestCase(
                grammar: #"t1 - /x/. t2 - /x/. S = t1 "a" | t2 "b"."#,
                pass: ["x a", "x b"],
                fail: ["x c", "x"],
                label: "basic Schrödinger dual"
            ),
            TestCase(
                grammar: #"t1 - /x/. t2 - /x/. t3 - /x/. S = t1 "a" | t2 "b" | t3 "c"."#,
                pass: ["x a", "x b", "x c"],
                fail: ["x d"],
                label: "three-way Schrödinger"
            ),
            TestCase(
                grammar: #"id - /[a-z]+/. S = "for" "(" | id ")"."#,
                pass: ["for (", "for )", "hello )"],
                fail: ["for for", "hello ("],
                label: "keyword vs regex Schrödinger"
            ),
            TestCase(
                grammar: #"t1 - /x/. t2 - /x/. S = {t1} t2 "a"."#,
                pass: ["x a", "x x a", "x x x a"],
                fail: ["a"],
                label: "Schrödinger in closure"
            ),
            TestCase(
                grammar: #"t1 - /x/. t2 - /x/. S = A | B. A = t1 "a". B = t2 "b"."#,
                pass: ["x a", "x b"],
                fail: ["x c"],
                label: "Schrödinger through nonterminals"
            ),
            TestCase(
                grammar: #"id - /[a-z]+/. S = {stmt}. stmt = "if" id "do" stmt "end" | id "=" id."#,
                pass: ["if x do y = z end", "x = y", "if x do if y do z = w end end"],
                fail: ["if", "x ="],
                label: "keyword–identifier Schrödinger language"
            ),
            TestCase(
                grammar: #"id - /[a-z]+/. S = id."#,
                pass: ["foo", "if", "do"],
                label: "keyword matches identifier regex"
            ),
            TestCase(
                grammar: #"id - /[a-z]+/. S = ["if"] id."#,
                pass: ["if foo", "foo", "if"],
                label: "Schrödinger in optional"
            ),
            TestCase(
                grammar: #"word - /[a-z]+/. alnum - /[a-z0-9]+/. S = word | alnum."#,
                pass: ["foo", "foo123"],
                label: "regex–regex Schrödinger"
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
            TestCase(
                grammar: #"shift - ">>". S = ">" ~~~ ">" ~~~ | ">>"."#,
                pass: [">>", "> >"],
                label: "basic Frankenstein split or direct match"
            ),
            TestCase(
                grammar: #"shift - ">>". S = ">" ~~~ ">" ~~~ ."#,
                pass: [">>", "> >"],
                fail: [">"],
                label: "Frankenstein-only split"
            ),
            TestCase(
                grammar: #"tripleShift - ">>>". shift - ">>". S = ">" ~~~ ">" ~~~ ">" ~~~ ."#,
                pass: [">>>", ">> >", "> >>", "> > >"],
                fail: [">>", ">", ">> >>"],
                label: "three-way Frankenstein split"
            ),
            TestCase(
                grammar: #"shift - ">>". S = "a" ">" ~~~ ">" ~~~ "b"."#,
                pass: ["a >> b", "a > > b"],
                fail: ["a > b", "a b"],
                label: "Frankenstein mid-sequence"
            ),
            TestCase(
                grammar: #"shift - ">>". S = ">" ~~~ ">" ~~~ "a" | ">>" "b"."#,
                pass: [">> a", ">> b", "> > a"],
                fail: ["> > b"],
                label: "Frankenstein vs direct in alternation"
            ),
            TestCase(
                grammar: #"shift - ">>". S = A B. A = ">" ~~~ . B = ">" ~~~ ."#,
                pass: [">>", "> >"],
                fail: [">"],
                label: "Frankenstein across nonterminals"
            ),
            TestCase(
                grammar: #"shift - ">>". id - /[a-z]+/. S = id ["<" tlist ">" ~~~]. tlist = S {"," S}."#,
                pass: ["foo", "foo < bar >", "foo < bar < baz > >", "foo < bar < baz >>"],
                label: "nested generics Frankenstein"
            ),
            TestCase(
                grammar: #"shift - ">>". S = "<" "x" ">" ~~~ [">" ~~~]."#,
                pass: ["< x >", "< x >>"],
                fail: ["< x"],
                label: "Frankenstein in optional"
            ),
            TestCase(
                grammar: #"doubleeq - "==". S = "x" "=" ~~~ "=" ~~~ "y"."#,
                pass: ["x == y", "x = = y"],
                fail: ["x = y"],
                label: "Frankenstein non-angle-bracket"
            ),
        ]

        @Test(arguments: cases)
        func test(_ tc: TestCase) throws {
            try runTestCase(tc)
        }
    }

    // MARK: - Exclusion Sets (---() annotation)

    @Suite("Exclusion Sets", .serialized)
    struct ExclusionSets {

        /// Parse a grammar and run a message, returning (matched, descriptorCount).
        private static func parseWithStats(grammar grammarString: String, message: String) throws -> (matched: Bool, descriptors: Int) {
            try withParserIsolation {
                trace = false
                traceIndent = 0

                let grammarWithWhitespace = "whitespace : /\\s+/.\n" + grammarString
                let parser = try ApusParser(fromString: grammarWithWhitespace)
                let grammar = try parser.parse(explicitStartSymbol: "")

                let messageScanner: Scanner
                do {
                    messageScanner = try Scanner(fromString: message, patterns: grammar.terminals)
                } catch is ScannerFailure {
                    return (false, 0)
                }
                let messageParser = MessageParser(grammar: grammar)
                messageParser.parse(tokens: messageScanner.tokens, trivia: messageScanner.trivia, input: messageScanner.input)

                let extent = TokenPosition(token: messageParser.tokens.count - 1)
                let matched = messageParser.currentParseRoot.yield.contains { $0.i == .zero && $0.j == extent }
                return (matched, messageParser.descriptorCount)
            }
        }

        static let cases: [TestCase] = [
            TestCase(
                grammar: #"id - /[a-z]+/. S = "if" safeId "end" | safeId. safeId = id ---("if" "end")."#,
                pass: ["if foo end", "foo"],
                fail: ["if", "end"],
                label: "basic exclusion suppresses keyword as identifier"
            ),
            TestCase(
                grammar: #"id - /[a-z]+/. S = "if" id "end" | id."#,
                pass: ["if foo end", "foo", "if", "end"],
                label: "without exclusion keywords match as identifiers"
            ),
            TestCase(
                grammar: #"id - /[a-z]+/. S = "if" safeId | safeId "!". safeId = id ---("if")."#,
                pass: ["if foo", "foo !"],
                fail: ["if !"],
                label: "exclusion blocks keyword in one context"
            ),
            TestCase(
                grammar: #"id - /[a-z]+/. S = ["if"] safeId. safeId = id ---("if")."#,
                pass: ["if foo", "foo"],
                fail: ["if if"],
                label: "exclusion in optional context"
            ),
            TestCase(
                grammar: #"id - /[a-z]+/. S = {"do" safeId}. safeId = id ---("do")."#,
                pass: ["do foo do bar", "do foo", ""],
                fail: ["do do"],
                label: "exclusion in repetition"
            ),
            TestCase(
                grammar: #"id - /[a-z]+/. S = "if" bareId | bareId. bareId = id ---()."#,
                pass: ["foo", "if", "if foo"],
                label: "empty exclusion list"
            ),
            TestCase(
                grammar: #"id - /[a-z]+/. S = "if" | safeId. safeId = id ---("if")."#,
                pass: ["if", "foo"],
                label: "exclusion does not suppress keyword terminal"
            ),
            TestCase(
                grammar: #"id - /[a-z]+/. S = "if" atom "end" | atom. atom = safeId. safeId = id ---("if" "end")."#,
                pass: ["if foo end", "foo"],
                fail: ["if", "end"],
                label: "exclusion through nonterminal"
            ),
            TestCase(
                grammar: #"id - /[a-z]+/. S = "if" safeId | "do" safeId | "for" safeId | safeId. safeId = id ---("if" "do" "for")."#,
                pass: ["foo", "if foo", "do foo", "for foo"],
                fail: ["if", "do", "for"],
                label: "multiple keywords all excluded"
            ),
            TestCase(
                grammar: #"id - /[a-z]+/. S = "if" safeId | safeId | S "+" safeId. safeId = id ---("if")."#,
                pass: ["foo", "foo + bar", "if foo"],
                fail: ["if", "foo + if"],
                label: "exclusion in left-recursive rule"
            ),
        ]

        @Test(arguments: cases)
        func test(_ tc: TestCase) throws {
            try runTestCase(tc)
        }

        @Test("exclusion reduces descriptors")
        func testDescriptorReduction() throws {
            let grammarWithout = #"id - /[a-z]+/. S = "if" safeId "end" | safeId. safeId = id ---()."#
            let grammarWith    = #"id - /[a-z]+/. S = "if" safeId "end" | safeId. safeId = id ---("if" "end")."#

            let (matchedWithout, descWithout) = try Self.parseWithStats(grammar: grammarWithout, message: "if foo end")
            let (matchedWith, descWith) = try Self.parseWithStats(grammar: grammarWith, message: "if foo end")

            #expect(matchedWithout == true, "should parse without exclusion")
            #expect(matchedWith == true, "should parse with exclusion")
            #expect(descWith < descWithout, "exclusion should reduce descriptor count (\(descWith) < \(descWithout))")
        }
    }
}
