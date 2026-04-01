//
//  ApusParserBuilder.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.27.
//

// =============================================================================
// YOUR EXISTING GrammarNode.swift — paste your full file here UNCHANGED
// =============================================================================
// (The code you showed me goes here exactly as-is.)

import OSLog
import Foundation
import RegexBuilder

// =============================================================================
// DSL — regular ChoiceOf style (exactly the syntax you want)
// =============================================================================

@resultBuilder
public struct GLLBuilder {

    // buildBlock exactly mirrors your manual sequence() function:
    //   - starts with a dummy .ALT
    //   - chains components via .seq
    //   - always ends with .END (your resolveEndNodeLinks will set the back-pointers)
    public static func buildBlock(_ components: GrammarNode...) -> GrammarNode {
        let startOfSequence = GrammarNode(kind: .ALT, name: "")
        var termNode = startOfSequence

        for component in components {
            termNode.seq = component
            termNode = component
        }

        termNode.seq = GrammarNode(kind: .END, name: "")
        return startOfSequence
    }

    // Primitives
    public static func buildExpression(_ literal: String) -> GrammarNode {
        GrammarNode(kind: .T, name: literal)
    }

    public static func buildExpression(_ node: GrammarNode) -> GrammarNode {
        node
    }

    public static func buildExpression(_ nt: NonTerminal) -> GrammarNode {
        GrammarNode(kind: .N, name: nt.name)
    }

    // buildArray exactly mirrors your manual selection() function:
    //   - first component becomes the start of the ALT chain
    //   - subsequent components are linked via .alt
    //   - each component is already a full sequence (with its own .END)
    public static func buildArray(_ components: [GrammarNode]) -> GrammarNode {
        guard !components.isEmpty else {
            return GrammarNode(kind: .EPS, name: "ε")
        }

        let startOfAlternates = components[0]
        var tmp = startOfAlternates

        for next in components.dropFirst() {
            tmp.alt = next
            tmp = next
        }
        return startOfAlternates
    }
}

// =============================================================================
// DSL helpers (exactly the style you showed)
// =============================================================================

public struct NonTerminal {
    public let name: String
    private let builder: () -> GrammarNode

    public init(_ name: String, @GLLBuilder _ content: @escaping () -> GrammarNode) {
        self.name = name
        self.builder = content
    }

    public var rhs: GrammarNode { builder() }

    public var node: GrammarNode {
        GrammarNode(kind: .N, name: name, alt: rhs, seq: nil)
    }
}

public struct Group {          // ( … )  → .DO
    public let node: GrammarNode
    public init(@GLLBuilder _ content: () -> GrammarNode) {
        let body = content()                     // body is already a full sequence (.ALT + END)
        self.node = GrammarNode(kind: .DO, name: "", alt: body, seq: nil)
    }
}

public struct OneOrMore {      // < … >  → .POS
    public let node: GrammarNode
    public init(@GLLBuilder _ content: () -> GrammarNode) {
        let body = content()
        self.node = GrammarNode(kind: .POS, name: "", alt: body, seq: nil)
    }
}

public struct ZeroOrMore {     // { … }  → .KLN
    public let node: GrammarNode
    public init(@GLLBuilder _ content: () -> GrammarNode) {
        let body = content()
        self.node = GrammarNode(kind: .KLN, name: "", alt: body, seq: nil)
    }
}

public struct Optionally {     // [ … ]  → .OPT
    public let node: GrammarNode
    public init(@GLLBuilder _ content: () -> GrammarNode) {
        let body = content()
        self.node = GrammarNode(kind: .OPT, name: "", alt: body, seq: nil)
    }
}

public struct ChoiceOf {
    public let node: GrammarNode
    public init(@GLLBuilder _ content: () -> GrammarNode) {
        self.node = content()
    }
}

// =============================================================================
// Terminal factory (silent = .B, visible = .T)
// =============================================================================
public struct Terminal {
    public static func silent(_ regex: Regex<Substring>) -> GrammarNode {
        GrammarNode(kind: .B, name: regex.description)
    }
    public static func visible(_ regex: Regex<Substring>) -> GrammarNode {
        GrammarNode(kind: .T, name: regex.description)
    }
}

// =============================================================================
// YOUR META-GRAMMAR — exactly the style you asked for
// =============================================================================
struct ParserMetaGrammar {

    // Lexer tokens
    let whitespace   = Terminal.silent(#/\s+/#)
    let linecomment  = Terminal.silent(#/\/\/.*/#)
    let blockcomment = Terminal.silent(#/\/\*(?s).*?\*\//#)

    let identifier   = Terminal.visible(#/\p{XID_Start}\p{XID_Continue}*/#)
    let literal      = Terminal.visible(#/\"(?:[^\"\\]|\\.)*\"/#)
    let epsilon      = Terminal.visible(#/[εϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄]/#)
    let regex        = Terminal.visible(#/\/(?:[^\/\\]|\\.)+\//#)
    let action       = Terminal.visible(#/@(?:[^@\\]|\\.)+@/#)
    let message      = Terminal.visible(#/\^\^\^(?:(?s).*?)(?=\^\^\^|$)/#)

    // Grammar productions — exactly as you showed
    let grammar = NonTerminal("grammar") {
        OneOrMore { production }
        ZeroOrMore { message }
    }

    let production = NonTerminal("production") {
        identifier
        ChoiceOf {
            Group { ":"; regex }      // silent terminal
            Group { "-"; regex }      // visible terminal
            Group { "="; selection }  // production rule
        }
        "."
    }

    let selection = NonTerminal("selection") {
        sequence
        ZeroOrMore {
            "|"
            sequence
        }
    }

    let sequence = NonTerminal("sequence") {
        ZeroOrMore { action }
        factor
        Optionally {
            ChoiceOf { "?"; "*"; "+" }
        }
        ZeroOrMore { action }
    }

    let factor = NonTerminal("factor") {
        ChoiceOf {
            terminal
            Group { "["; selection; "]" }
            Group { "{"; selection; "}" }
            Group { "<"; selection; ">" }
            Group { "("; selection; ")" }
        }
    }

    let terminal = NonTerminal("terminal") {
        ChoiceOf {
            identifier
            literal
            regex
            epsilon
        }
    }
}

// =============================================================================
// Convenience — ready for your existing GLL engine
// =============================================================================
extension ParserMetaGrammar {
    var productions: [GrammarNode] {
        [
            grammar.node,
            production.node,
            selection.node,
            sequence.node,
            factor.node,
            terminal.node
        ]
    }
}

// File: MyGrammarExample.swift
// (Put this in the same module as your GrammarNode.swift + the DSL file)

import Foundation
import RegexBuilder

// =============================================================================
// 1. Define your grammar using the exact DSL style you wanted
// =============================================================================
struct ArithmeticGrammar {

    // Lexer / terminals (you can add more later)
    let number   = Terminal.visible(#/\d+/#)
    let plus     = Terminal.visible(#/\+/#)
    let minus    = Terminal.visible(#/-/#)
    let times    = Terminal.visible(#/\*/#)
    let divide   = Terminal.visible(#/\//#)
    let lParen   = Terminal.visible(#/\(/#)
    let rParen   = Terminal.visible(#/\)/#)

    // Productions — exactly the style you showed
    let expr = NonTerminal("expr") {
        term
        ZeroOrMore {
            ChoiceOf {
                Group { plus; term }
                Group { minus; term }
            }
        }
    }

    let term = NonTerminal("term") {
        factor
        ZeroOrMore {
            ChoiceOf {
                Group { times; factor }
                Group { divide; factor }
            }
        }
    }

    let factor = NonTerminal("factor") {
        ChoiceOf {
            number
            Group { lParen; expr; rParen }
        }
    }
}

// =============================================================================
// 2. Turn the DSL into the exact nodes your GLL engine expects
// =============================================================================
extension ArithmeticGrammar {
    var productions: [GrammarNode] {
        [
            expr.node,
            term.node,
            factor.node
            // (add any extra non-terminals you define)
        ]
    }
}

// =============================================================================
// 3. How you actually use it in your existing code
// =============================================================================
func buildGrammarWithDSL() throws -> Grammar {
    GrammarNode.count = 0

    let dsl = ArithmeticGrammar()
    let nodes = dsl.productions

    let grammar = Grammar()                     // your existing Grammar class
    grammar.startSymbol = "expr"

    // Register every production exactly like your ApusParser does
    for node in nodes {
        grammar.nonTerminals[node.name] = node
    }

    // Run the exact same post-processing steps your parser already does
    for (name, node) in grammar.nonTerminals.sorted(by: { $0.key > $1.key }) {
        #Trace("Processing END nodes for:", name)
        node.resolveEndNodeLinks(parent: node, alternate: node.alt)
    }

    grammar.root = grammar.nonTerminals[grammar.startSymbol]!
    grammar.finalizeSymbolTable()
    grammar.assignNameIDs()

    // First/Follow propagation (exactly as in your parse() method)
    var oldSize = 0
    var newSize = 0
    repeat {
        oldSize = newSize
        newSize = 0
        for (_, node) in grammar.nonTerminals {
            GrammarNode.sizeofSets = 0
            try grammar.populateFirstFollowSets(for: node)
            newSize += GrammarNode.sizeofSets
        }
    } while newSize != oldSize
    GrammarNode.sizeofSets = newSize

    grammar.populateBitSets()

    GrammarNode.isLL1 = true
    for (_, node) in grammar.nonTerminals {
        node.detectAmbiguity()
    }
    grammar.isLL1 = GrammarNode.isLL1

    return grammar
}

// =============================================================================
// 4. Quick test — parse a string with your existing GLL parser
// =============================================================================
do {
    let grammar = try buildGrammarWithDSL()

    // Now feed the grammar into your GLL parser (exactly as before)
    let gll = GLLParser(grammar: grammar)   // whatever your GLL class is called
    let input = "2 + 3 * (4 - 1)"

    if let bsrSet = gll.parse(input) {
        print("✅ Parsed successfully!")
        print("BSR records: \(bsrSet.count)")
        // bsrSet contains the exact same BinarySpan / GrammarNode references you already use
    } else {
        print("❌ Parse failed")
    }
} catch {
    print("Error building grammar: \(error)")
}
