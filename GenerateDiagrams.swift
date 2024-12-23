//
//  GenerateDiagrams.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

// https://graphviz.org

import Foundation

func generateDiagrams() {
    
    let diagramFileURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("diagram")
        .appendingPathExtension("gv")
    
    var d = #"""
    digraph G {
      fontname = Menlo
      fontsize = 10
      node [fontname = Menlo, fontsize = 10, color = gray]
      edge [fontname = Menlo, fontsize = 10, color = gray, arrowsize = 0.5]
    
      graph [ordering = out]
    """#
    
    var nonterminalLinks: [(from: GrammarNode, to: GrammarNode)] = []
    
    func draw(_ node: GrammarNode) {
//        let sortedYield = node.yield.sorted(by: { lhs, rhs in lhs.i < rhs.i }).description.dropFirst().dropLast()
//        let info = "<br/><font color=\"gray\" point-size=\"8.0\"> \(sortedYield)</font>"
        let info = "<br/>fi \(node.first.sorted())<br/>fo \(node.follow.sorted())<br/>am \(node.ambiguous.sorted())"

        switch node.kind {
        case .SEQ(let children):
            d.append("\n    \(node) [label = <\(node): SEQ\(info)>]")
            for child in children {
                d.append("\n    \(node) -> \(child)")
                draw(child)
            }
        case .ALT(let children):
            d.append("\n    \(node) [label = <\(node): ALT\(info)>]")
            for child in children {
                d.append("\n    \(node) -> \(child)")
                draw(child)
            }
        case .OPT(let child):
            d.append("\n    \(node) [label = <\(node): OPT\(info)>]")
            d.append("\n    \(node) -> \(child)")
            draw(child)
        case .REP(let child):
            d.append("\n    \(node) [label = <\(node): REP\(info)>]")
            d.append("\n    \(node) -> \(child)")
            draw(child)
        case .NTR(let name, let link):
            d.append("\n    \(node) [label = <\(node): \(name)\(info)>]")
            nonterminalLinks.append((node, link!))
        case .TRM(let type):
            d.append("\n    \(node) [label = <\(node): \"\(type.escapesRemoved.graphvizHTML)\"\(info)>]")
        }
    }

    d.append("\n  subgraph GSS {")
    d.append("\n    cluster = true")
    
    var shortMessage = messages[0]
    if shortMessage.count > 20 {
        shortMessage = String(shortMessage.prefix(17))
        shortMessage.append("...")
    }

    d.append("\n    label = <\(shortMessage.whitespaceMadeVisible.graphvizHTML)> \(successfullParses > 0 ? "fontcolor = green" : "fontcolor = red" )")
    d.append("\n    labeljust = l")
    d.append("\n    node [shape = box, style = rounded, height = 0]")
    if graph.count > 1 {
        for (key, value) in graph.sorted(by: { $0.key > $1.key }) {
            if value.isEmpty {
                d.append("\n    \"\(key)\" -> \"#\"") // use '#' or '●○' as the root label?
            } else {
                for element in value {
                    let poppedIndexes = element.towards.popped.sorted().description.dropFirst().dropLast()
                    d.append("\n    \(key) [label = <\(key)<br/><font color=\"gray\" point-size=\"8.0\"> \(poppedIndexes)</font>>]")
                    d.append("\n    \(key) -> \(element.towards.description)")
                }
            }
        }
    }
    d.append("\n  }")
    

    for (name, node) in nonTerminals.sorted(by: { $0.key < $1.key }) {
        d.append("\n  subgraph \(name) {")
        d.append("\n    cluster = true")
        d.append("\n    label = <\(name) = \(node.ebnf().graphvizHTML)>")
        d.append("\n    labeljust = l")
        d.append("\n    node [shape = ellipse, height = 0]")
        draw(node)
        d.append("\n  }")
    }
    
    for (from, to) in nonterminalLinks {
        d.append("\n  \(from) -> \(to) [style = dotted, constraint = false]")
    }
    
    d.append("\n}")
    
    do {
        try d.write(to: diagramFileURL, atomically: true, encoding: .utf8)
    } catch {
        print("error: could not write to \(diagramFileURL.absoluteString)")
        exit(6)
    }
}
