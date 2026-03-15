import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(AdventMacrosImpl)
import AdventMacrosImpl

nonisolated(unsafe) let testMacros: [String: Macro.Type] = [
    "Trace": TraceMacro.self,
]
#endif

final class TraceMacroTests: XCTestCase {
    #if canImport(AdventMacrosImpl)

    func testSingleArgument() throws {
        assertMacroExpansion(
            """
            #Trace("hello")
            """,
            expandedSource: """
            _traceImpl({
                    [("hello") as Any]
                })
            """,
            macros: testMacros
        )
    }

    func testMultipleArguments() throws {
        assertMacroExpansion(
            """
            #Trace("label:", value)
            """,
            expandedSource: """
            _traceImpl({
                    [("label:") as Any, (value) as Any]
                })
            """,
            macros: testMacros
        )
    }

    func testWithTerminator() throws {
        assertMacroExpansion(
            """
            #Trace("msg", terminator: "\\n")
            """,
            expandedSource: """
            _traceImpl({
                    [("msg") as Any]
                }, terminator: "\\n")
            """,
            macros: testMacros
        )
    }

    func testNoArguments() throws {
        assertMacroExpansion(
            """
            #Trace()
            """,
            expandedSource: """
            _traceImpl({
                    []
                })
            """,
            macros: testMacros
        )
    }

    func testOperatorExpression() throws {
        assertMacroExpansion(
            """
            #Trace(a, b > c)
            """,
            expandedSource: """
            _traceImpl({
                    [(a) as Any, (b > c) as Any]
                })
            """,
            macros: testMacros
        )
    }

    #endif
}
