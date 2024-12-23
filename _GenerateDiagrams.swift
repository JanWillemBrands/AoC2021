//
//  _GenerateDiagrams.swift
//  Advent
//
//  Created by Johannes Brands on 03/10/2024.
//

import Foundation

struct Cell: Hashable, CustomStringConvertible {
    let r, c: Int
    var description: String { "R\(r)C\(c)" }
}

// Draw a regular grid of GrammarNodes with arrow for .seq down and .alt to the right.
func _generateDiagrams() {
    
    let diagramFileURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("ART")
        .appendingPathExtension("gv")
    
    var d = #"""
        digraph G {
          fontname = Menlo
          fontsize = 10
          node [fontname = Menlo, fontsize = 10, color = gray, height = 0, width = 0, margin= 0.04]
          edge [fontname = Menlo, fontsize = 10, color = gray, arrowsize = 0.3]
          graph [ordering = out, ranksep = 0.2]
          rankdir = "TB"
        """#
    
    var endLinks: [(from: _GrammarNode, to: _GrammarNode)] = []
    var ntrLinks: [(from: _GrammarNode, to: _GrammarNode)] = []
    
    // The Graphviz grid is stored in a dictionary with the position as key.
    // A Bool value indicates if the node at that position is a true GrammarNode or a skipped node.
    // Absent nodes are absent from the Dictionary.
    var grid: [Cell:Bool] = [:]
    
    // Draw a pretty picture of a GrammarNode with alt and seq links
    func draw(node: _GrammarNode, row: Int, col: Int) {
        var str = node.str
        if node.kind == .T {
            str = "\"" + str + "\""
        }
        
        node.cell = Cell(r: row, c: col)
        grid[node.cell] = true
        
//        d.append("\n    \(node.number) [label = <\(node.number)<br/><font color=\"gray\" point-size=\"8.0\"> \(node.kind) \(str)</font>>]")
//        d.append("\n    \(node.number) [label = <\(node.number)<br/>\(node.kind) \(str)<br/>fi \(node.first.sorted())<br/>fo \(node.follow.sorted())<br/>am \(node.ambiguous.sorted())>]")
        d.append("\n    \(node.cell) [label = <\(node.cell)<br/>\(node.kind) \(str)<br/>fi \(node.first.sorted())<br/>fo \(node.follow.sorted())<br/>am \(node.ambiguous.sorted())>]")

        if let seq = node.seq {
            if node.kind == .END {
                endLinks.append((from: node, to: seq))
            } else {
                maxRow = max(maxRow, row+1)
                draw(node: seq, row: row+1, col: col)
                d.append("\n    \(node.cell):s -> \(seq.cell) [weight=100000000]")
            }
        }
        
        if let alt = node.alt {
            // .alt can only point to an ALT node
            if node.kind == .END {
                endLinks.append((from: node, to: alt))
            } else if node.kind == .N && node.seq != nil { // rhs nonterminal
                ntrLinks.append((from: node, to: alt))
            } else {
                maxCol = max(maxCol+1, col+1)
                
                // fill the row with empty nodes that should not be drawn or connected
                for c in col+1 ..< maxCol {
                    let c = Cell(r: row, c: c)
                    grid[c] = false
                }
                
                draw(node: alt, row: row, col: maxCol)
                d.append("\n    rank = same {\(node.cell) -> \(alt.cell)}")
                
            }
        }
    }
    
    // add dummy cell and edges to fool Graphviz into maintaining a rectangular grid
    func addScaffolding() {
//        d.append("\n    node [color = red]")
//        d.append("\n    edge [color = red]")
        d.append("\n    node [style = invis]")
        d.append("\n    edge [style = invis]")

        // draw the dummy cells and the arrows that go into them
        for r in 0...maxRow {
            for c in 0...maxCol {
                let cell = Cell(r: r, c: c)
                
                // draw arrows into dummy cell from real cells or dummy cells
                if grid[cell] == nil {
                    if r > 0 {
                        let above = Cell(r: r-1, c: c)
                        if grid[above] != false {
                            d.append("\n    \(above) -> \(cell) [weight=100000000]")
                        }
                    }
                    if c > 0 {
                        let left = Cell(r: r, c: c-1)
                        if grid[left] != false {
                            d.append("\n    rank = same {\(left) -> \(cell)}")
                        }
                    }
                    
                // draw arrows into real nodes from dummy cells
                } else if grid[cell] == true {
                    if r > 0 {
                        let above = Cell(r: r-1, c: c)
                        if grid[above] == nil {
                            d.append("\n    \(above) -> \(cell) [weight=100000000]")
                        }
                    }
                    if c > 0 {
                        let left = Cell(r: r, c: c-1)
                        if grid[left] == nil {
                            d.append("\n    rank = same {\(left) -> \(cell)}")
                        }
                    }

                }
            }
        }
    }
    
    var maxRow: Int
    var maxCol: Int

    for (name, node) in _nonTerminals {
        d.append("\n  subgraph cluster\(name) {")
        //        d.append("\n    cluster = true")
        d.append("\n    node [shape = box]")
        d.append("\n    label = <\(node.ebnf().graphvizHTML)>")
        d.append("\n    labeljust = l")
        maxRow = 0
        maxCol = 0
        draw(node: node, row: 0, col: 0)
        addScaffolding()
        d.append("\n  }")
    }
    
    for (from, to) in endLinks {
        d.append("\n  \(from.cell):s -> \(to.cell) [style = dotted, color = red, constraint = false]")
    }
    for (from, to) in ntrLinks {
        d.append("\n  \(from.cell):e -> \(to.cell) [style = dotted, color = blue, constraint = false]")
    }
    
    d.append("\n}")
    
    do {
        try d.write(to: diagramFileURL, atomically: true, encoding: .utf8)
    } catch {
        print("error: could not write to \(diagramFileURL.absoluteString)")
        exit(6)
    }
}

