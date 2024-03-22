//
//  GenerateDiagrams.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

// https://graphviz.org

import Foundation

let diagramFileURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("diagram")
    .appendingPathExtension("gv")

var diagramContent = #"""
    digraph G {
      fontname = Menlo
      fontsize = 10
      node [fontname = Menlo, fontsize = 10]
      edge [fontname = Menlo, fontsize = 10]
      graph [ordering = out]
    """#

var nonterminalLinks: [(from: GrammarNode, to: GrammarNode)] = []

func generateDiagrams() {
    diagramContent.append("\n  subgraph GSS {")
    diagramContent.append("\n    cluster = true")
    
    var shortMessage = messages[0]
    if shortMessage.count > 20 {
        shortMessage = String(shortMessage.prefix(17))
        shortMessage.append("...")
    }

    diagramContent.append("\n    label = <\(parseMode) \(shortMessage.whitespaceMadeVisible.graphviz)> \(successfullParses > 0 ? "fontcolor = green" : "fontcolor = red" )")
    diagramContent.append("\n    labeljust = l")
    diagramContent.append("\n    node [shape = box, style = rounded, height = 0]")
    if graph.count > 1 {
        for (key, value) in graph.sorted(by: { $0.key > $1.key }) {
            if value.isEmpty {
                diagramContent.append("\n    \"\(key)\" -> \"#\"")
            } else {
                for element in value {
                    diagramContent.append("\n    \"\(key)\" -> \"\(element.towards?.description ?? "●")\"") // "●○"
                }
            }
        }
    }
    diagramContent.append("\n  }")
    

    for (name, node) in nonTerminals.sorted(by: { $0.key < $1.key }) {
        diagramContent.append("\n  subgraph \(name) {")
        diagramContent.append("\n    cluster = true")
        diagramContent.append("\n    label = <\(name) = \(node.ebnf().graphviz)>")
        diagramContent.append("\n    labeljust = l")
        diagramContent.append("\n    node [shape = ellipse, height = 0]")
        addDiagramOf(node)
        diagramContent.append("\n  }")
    }
    
    for (from, to) in nonterminalLinks {
        diagramContent.append("\n  \(from) -> \(to) [style = dotted, constraint = false]")
    }
    
    diagramContent.append("\n}")
    
    do {
        try diagramContent.write(to: diagramFileURL, atomically: true, encoding: .utf8)
    } catch {
        print("error: could not write to \(diagramFileURL.absoluteString)")
        exit(1)
    }
}

func addDiagramOf(_ slot: GrammarNode) {
    switch slot.kind {
    case .SEQ(let children):
        diagramContent.append("\n    \(slot) [label = <\(slot): SEQ>]")
        for child in children {
            diagramContent.append("\n    \(slot) -> \(child)")
            addDiagramOf(child)
        }
    case .ALT(let children):
        diagramContent.append("\n    \(slot) [label = <\(slot): ALT>]")
        for child in children {
            diagramContent.append("\n    \(slot) -> \(child)")
            addDiagramOf(child)
        }
    case .OPT(let child):
        diagramContent.append("\n    \(slot) [label = <\(slot): OPT>]")
        diagramContent.append("\n    \(slot) -> \(child)")
        addDiagramOf(child)
    case .REP(let child):
        diagramContent.append("\n    \(slot) [label = <\(slot): REP>]")
        diagramContent.append("\n    \(slot) -> \(child)")
        addDiagramOf(child)
    case .NTR(let name, let link):
        diagramContent.append("\n    \(slot) [label = <\(slot): \(name)>]")
        nonterminalLinks.append((slot, link!))
    case .TRM(let type):
        diagramContent.append("\n    \(slot) [label = <\(slot): \"\(type.escapesRemoved.graphviz)\"<br/><font color=\"gray\" point-size=\"8.0\"> \(slot.extents) </font> >]")
    }
}

