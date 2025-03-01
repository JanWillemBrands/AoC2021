//
//  GenerateDiagrams.swift
//  Advent
//
//  Created by Johannes Brands on 03/10/2024.
//

// https://graphviz.org

import Foundation

struct Cell: Hashable, CustomStringConvertible {
    let name: String
    let r, c: Int
    var description: String { "\(name)R\(r)C\(c)" }
}

class DiagramsGenerator {
    
    let diagramFile: URL
    
    init(outputFile: URL) {
        self.diagramFile = outputFile
    }

    var content = #"""
        digraph G {
          fontname = Menlo
          fontsize = 10
          node [fontname = Menlo, fontsize = 10, color = gray, height = 0, width = 0, margin= 0.04]
          edge [fontname = Menlo, fontsize = 10, color = gray, arrowsize = 0.3]
          graph [ranksep = 0.1]
          rankdir = "TB"
        """#
//    graph [ordering = out, ranksep = 0.2]

    var endSeqLinks: [(from: GrammarNode, to: GrammarNode)] = []
    var endAltLinks: [(from: GrammarNode, to: GrammarNode)] = []
    var ntrAltLinks: [(from: GrammarNode, to: GrammarNode)] = []
    
    // The Graphviz grammar node grid is stored in a dictionary with the position as key.
    // A Bool value indicates if the node at that position is a true GrammarNode or a skipped node.
    // Absent nodes are absent from the Dictionary.
    var grid: [Cell:Bool] = [:]
    var maxRow = 0
    var maxCol = 0

    // Draw a regular grid of GrammarNodes with arrows for .seq down and .alt to the right.
    func generateDiagrams() throws {
        
        // generate GSS graph
        content.append("\n  subgraph GSS {")
        content.append("\n    cluster = true")
        
        var shortMessage = messages[0]
        if shortMessage.count > 20 {
            shortMessage = String(shortMessage.prefix(17))
            shortMessage.append("...")
        }

        content.append("\n    label = <\(shortMessage.whitespaceMadeVisible.graphvizHTML)> \(successfullParses > 0 ? "fontcolor = green" : "fontcolor = red" )")
        content.append("\n    labeljust = l")
        content.append("\n    node [shape = box, style = rounded, height = 0]")
        for node in gss.sorted() {
            for edge in node.edges {
                let poppedIndexes = node.pops.sorted().description.dropFirst().dropLast()
                content.append("\n    \(node) [label = <\(node)<br/><font color=\"gray\" point-size=\"8.0\"> \(poppedIndexes)</font>>]")
                content.append("\n    \(node) -> \(edge)")
            }
        }
        content.append("\n  }")

        // generate syntax graph for each non-terminal
        for (name, node) in nonTerminals {
            content.append("\n  subgraph cluster\(name) {")
            //        d.append("\n    cluster = true")
            content.append("\n    node [shape = box]")
            content.append("\n    label = <\(node.ebnf().graphvizHTML)>")
            content.append("\n    labeljust = l")
            
            maxRow = 0
            maxCol = 0
            grid = [:]
            
            draw(name: name, node: node, row: 0, col: 0)
            
            addScaffolding(name: name)
            
            content.append("\n  }")
        }
        
        for (from, to) in endSeqLinks {
            content.append("\n  \(from.cell):w -> \(to.cell):s [style = solid, color = red, constraint = false]")
        }
        for (from, to) in endAltLinks {
            content.append("\n  \(from.cell):e -> \(to.cell) [style = dotted, color = green, constraint = false]")
        }
        for (from, to) in ntrAltLinks {
            content.append("\n  \(from.cell):e -> \(to.cell) [style = dotted, color = blue, constraint = false]")
        }
        
        content.append("\n}")
        
        try content.write(to: diagramFile, atomically: true, encoding: .utf8)
    }

    // Draw a pretty picture of a GrammarNode with alt and seq links
    func draw(name: String, node: GrammarNode, row: Int, col: Int) {
        var str = node.str
        if node.kind == .T {
            str = "\"" + str + "\""
        }
        
        node.cell = Cell(name: name, r: row, c: col)
        grid[node.cell] = true
        
        content.append("\n    \(node.cell) [label = <\(node)<br/>\(node.kind.rawValue.description.graphvizHTML) \(str.graphvizHTML)<br/>fi \(node.first.sorted().description.graphvizHTML)<br/>fo \(node.follow.sorted().description.graphvizHTML)<br/>am \(node.ambiguous.sorted().description.graphvizHTML)>]")

        if let seq = node.seq {
            if node.kind == .END {
                endSeqLinks.append((from: node, to: seq))
            } else {
                maxRow = max(maxRow, row+1)
                draw(name: name, node: seq, row: row+1, col: col)
//                content.append("\n    \(node.cell):s -> \(seq.cell) [weight=100000000]")
                content.append("\n    \(node.cell) -> \(seq.cell) [weight=100000000]")
            }
        }
        
        if let alt = node.alt {
            // .alt can only point to an ALT node
            if node.kind == .END {
                endAltLinks.append((from: node, to: alt))
            } else if node.kind == .N && node.seq != nil { // rhs nonterminal
                ntrAltLinks.append((from: node, to: alt))
            } else {
                maxCol = max(maxCol+1, col+1)
                
                // fill the row with empty nodes that should not be drawn or connected
                for c in col+1 ..< maxCol {
                    let c = Cell(name: name, r: row, c: c)
                    grid[c] = false
                }
                
                draw(name: name, node: alt, row: row, col: maxCol)
                content.append("\n    rank = same {\(node.cell) -> \(alt.cell)}")
                
            }
        }
    }
    
    // add dummy cells and edges to fool Graphviz into maintaining a rectangular grid
    func addScaffolding(name: String) {
//        d.append("\n    node [color = red]")
//        d.append("\n    edge [color = red]")
        content.append("\n    node [style = invis]")
        content.append("\n    edge [style = invis]")

        // draw the dummy cells and the arrows that go into them
        for r in 0...maxRow {
            for c in 0...maxCol {
                let cell = Cell(name: name, r: r, c: c)
                
                // draw arrows into dummy cell from real cells or dummy cells
                if grid[cell] == nil {
                    if r > 0 {
                        let above = Cell(name: name, r: r-1, c: c)
                        if grid[above] != false {
                            content.append("\n    \(above) -> \(cell) [weight=100000000]")
                        }
                    }
                    if c > 0 {
                        let left = Cell(name: name, r: r, c: c-1)
                        if grid[left] != false {
                            content.append("\n    rank = same {\(left) -> \(cell)}")
                        }
                    }
                    
                // draw arrows into real nodes from dummy cells
                } else if grid[cell] == true {
                    if r > 0 {
                        let above = Cell(name: name, r: r-1, c: c)
                        if grid[above] == nil {
                            content.append("\n    \(above) -> \(cell) [weight=100000000]")
                        }
                    }
                    if c > 0 {
                        let left = Cell(name: name, r: r, c: c-1)
                        if grid[left] == nil {
                            content.append("\n    rank = same {\(left) -> \(cell)}")
                        }
                    }

                }
            }
        }
    }
}
