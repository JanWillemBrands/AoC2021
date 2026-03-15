import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftCompilerPlugin

/// Expands #Trace(...) into _traceImpl({ [...] }).
/// The closure defers argument evaluation until _traceImpl checks the trace flag.
/// In release builds, _traceImpl has an empty body and the optimizer eliminates everything.
public struct TraceMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        var itemExprs: [ExprSyntax] = []
        var terminatorExpr: ExprSyntax? = nil

        for argument in node.arguments {
            if argument.label?.text == "terminator" {
                terminatorExpr = argument.expression
            } else {
                itemExprs.append(argument.expression)
            }
        }

        // Parenthesize each expression to avoid operator precedence issues with `as Any`
        let arrayElements = itemExprs.map { expr in "(\(expr)) as Any" }.joined(separator: ", ")

        if let terminator = terminatorExpr {
            return "_traceImpl({ [\(raw: arrayElements)] }, terminator: \(terminator))"
        } else {
            return "_traceImpl({ [\(raw: arrayElements)] })"
        }
    }
}

@main
struct AdventMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [TraceMacro.self]
}
