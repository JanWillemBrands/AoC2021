//
//  LanguageGrammarTests.swift
//  AdventTests
//
//  Tests that load real .apus grammar files and parse their embedded ^^^ messages.
//  Each message is a separate parameterized test case. The grammar is loaded once
//  per suite via static let. Layout token injection is applied when the grammar
//  defines >>| (indent) tokens.
//

import Testing
import Foundation

@Suite("Language Grammar Tests", .serialized)
struct LanguageGrammarTests {

    @Suite("Python Grammar", .serialized)
    struct PythonGrammar {
        static let fixture = loadLanguageFixture("grammars/Python/Python")

        @Test("parse message", arguments: fixture.cases)
        func testMessage(_ tc: LanguageTestCase) throws {
            let matched = try parseLanguageMessage(Self.fixture, message: tc.message)
            #expect(matched, "Message \(tc.index) failed: \(tc.message.prefix(60))")
        }
    }

    @Suite("APUS Grammar", .serialized)
    struct APUSGrammar {
        static let fixture = loadLanguageFixture("apus")

        @Test("parse message", arguments: fixture.cases)
        func testMessage(_ tc: LanguageTestCase) throws {
            let matched = try parseLanguageMessage(Self.fixture, message: tc.message)
            #expect(matched, "Message \(tc.index) failed: \(tc.message.prefix(60))")
        }
    }

    @Suite("Swift Grammar", .serialized)
    struct SwiftGrammar {
        static let fixture = loadLanguageFixture("Swift")

        @Test("parse message", arguments: fixture.cases)
        func testMessage(_ tc: LanguageTestCase) throws {
            let matched = try parseLanguageMessage(Self.fixture, message: tc.message)
            #expect(matched, "Message \(tc.index) failed: \(tc.message.prefix(60))")
        }
    }
}
