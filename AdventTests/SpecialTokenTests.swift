//
//  SpecialTokenTests.swift
//  AdventTests
//
//  Tests for Schrödinger tokens (ambiguous scanner matches), regex lookbehind
//  annotations, and exclusion sets (keyword suppression).
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

    // MARK: - Regex Lookbehind (++N/--N annotations)

    @Suite("Regex Lookbehind", .serialized)
    struct RegexLookbehind {
        static let cases: [TestCase] = [
            // Control: no lookbehind annotation — slash regex always wins by longest match.
            TestCase(
                grammar: #"slash - /\/[a-z]+\// . S = "a" slash ."#,
                pass: ["a /b/"],
                label: "control: no lookbehind, regex wins"
            ),

            // Negative lookbehind blocks regex after 'a' so scanner falls back to single chars.
            TestCase(
                grammar: #"slash - /\/[a-z]+\// . --1("a") S = "a" "/" "b" "/" ."#,
                pass: ["a /b/"],
                label: "--1 blocks regex after 'a', scanner emits single '/'"
            ),

            // Same grammar as above but with slash in production — should now FAIL because
            // the regex is blocked and the alternative path doesn't exist.
            TestCase(
                grammar: #"slash - /\/[a-z]+\// . --1("a") S = "a" slash ."#,
                pass: [],
                fail: ["a /b/"],
                label: "--1 blocks regex, grammar has no fallback → fail"
            ),

            // Default allow: '(' is not in the deny list so the regex matches.
            TestCase(
                grammar: #"slash - /\/[a-z]+\// . --1("a") S = "(" slash ")" ."#,
                pass: ["( /b/ )"],
                label: "default allow: '(' not in deny list"
            ),

            // Multiple operands in a single --1: each blocks independently.
            TestCase(
                grammar: #"slash - /\/[a-z]+\// . --1("a" "b" "c") S = "a" "/" "x" "/" | "b" "/" "x" "/" | "c" "/" "x" "/" ."#,
                pass: ["a /x/", "b /x/", "c /x/"],
                label: "multiple deny operands all block"
            ),

            // Identifier operand: deny list can reference a named terminal by name.
            TestCase(
                grammar: #"slash - /\/[a-z]+\// . --1(id) id - /[a-z]+/. S = id "/" id "/" ."#,
                pass: ["x /b/", "hello /world/"],
                label: "identifier operand blocks after named terminal"
            ),

            // Compound positive override: ++2("try"), ++1("!") overrides --1("!").
            TestCase(
                grammar: #"slash - /\/[a-z]+\// . --1("!") ++2("try"), ++1("!") S = "try" "!" slash ."#,
                pass: ["try ! /a/"],
                label: "compound ++2/++1 overrides --1('!') for try!"
            ),

            // Override does NOT apply when prev2 is not 'try': regex stays blocked.
            TestCase(
                grammar: #"slash - /\/[a-z]+\// . --1("!") ++2("try"), ++1("!") S = "x" "!" "/" "y" "/" ."#,
                pass: ["x ! /y/"],
                label: "compound override does not fire when prev2 != 'try'"
            ),

            // At start of input there is no previous token — deny list cannot match → allow.
            TestCase(
                grammar: #"slash - /\/[a-z]+\// . --1("a") S = slash ."#,
                pass: ["/a/"],
                label: "start of input: lookbehind cannot block"
            ),

            // Whitespace is trivia — lookbehind sees only visible tokens.
            TestCase(
                grammar: #"slash - /\/[a-z]+\// . --1("a") S = "a" "/" "b" "/" ."#,
                pass: ["a    /b/"],
                label: "lookbehind skips whitespace trivia"
            ),

            // Multiple lines OR'd: each --1 line independently blocks.
            TestCase(
                grammar: #"slash - /\/[a-z]+\// . --1("a") --1("b") S = "a" "/" "x" "/" | "b" "/" "x" "/" ."#,
                pass: ["a /x/", "b /x/"],
                label: "multiple --1 lines OR'd together"
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

                let matched = messageParser.yield(of: messageParser.currentParseRoot).contains {
                    $0.i == messageScanner.input.startIndex && $0.j == messageScanner.input.endIndex
                }
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
