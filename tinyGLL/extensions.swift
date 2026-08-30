//
//  extensions.swift
//  tinyGLL
//
//  Created by Johannes Brands on 2026.08.29.
//

import Foundation

extension GrammarNode: CustomStringConvertible {
    var description: String { "\(number) \(name)" }
}

extension GrammarNode {
    func dump() {
        
        func emit(_ node: GrammarNode?) {
            if let node {
                var e = ""
                e += "\(node.number)\t"
                e += "\(node.kind)\t"
                if let s = node.seq { e += "\ts\(s.number)" }
                if let a = node.alt { e += "\ta\(a.number)" }
                print(e)
            }
        }
        var node: GrammarNode? = self
        while node != nil {
            emit(node)
            if node?.kind == .N && node?.seq == nil {
                node = node?.alt
            } else if node?.kind == .END {
                node = node?.alt?.alt
            } else {
                node = node?.seq
            }
        }
    }
}

extension GrammarNode {
    // EBNF dotted-slot rendering (diagnostics only). This used to keep four
    // process-global statics as recursion scratch, which was a data race once
    // tests run in parallel. State is now threaded locally, so `emit`/`ebnfDot`
    // are pure and reentrant — safe to call from any thread.
    enum Exit: Error { case endOfToplevel }
    
    func emit(into ebnf: inout String, dottedSlot: GrammarNode) throws {
        let middleDot = "\u{00B7}"
        switch kind {
        case .EOS, .T, .EPS:
            ebnf.append(name)
            if self == dottedSlot { ebnf += middleDot }
            if let seq { try seq.emit(into: &ebnf, dottedSlot: dottedSlot) }
        case .N:
            if let seq { // rhs
                ebnf.append(name)
                if self == dottedSlot { ebnf += middleDot }
                try seq.emit(into: &ebnf, dottedSlot: dottedSlot)
            } else { // lhs
                ebnf.append(name)
            }
        case .ALT:
            if self == dottedSlot { ebnf += middleDot }
            if let seq { try seq.emit(into: &ebnf, dottedSlot: dottedSlot) }
            if let alt {
                ebnf +=  "|"
                try alt.emit(into: &ebnf, dottedSlot: dottedSlot)
            }
        case .END:
            if self == dottedSlot { ebnf += middleDot }
            if seq?.kind == .N {
                // this is the end of the top level alternate
                throw Exit.endOfToplevel
            }
        }
        
        func toplevels() -> (GrammarNode?, GrammarNode?) {
            // returns the the highest level alternate and the containing nonterminal
            var node = self
            while node.seq != nil {
                if node.kind == .END && node.seq?.kind == .N {
                    return (node.alt, node.seq)
                }
                else {
                    node = node.seq!
                }
            }
            return (nil, nil)
        }
        
        // generates the dotted ebnf for the toplevel containing alternate of the containing nonterminal
        // the dot is placed after the dottedSlot node:
        //   terminal/nonterminal: dot after the symbol  e.g. S="a"·{"a"}
        //   bracket (KLN etc):    dot after closing }   e.g. S="a"{"a"}·
        //   ALT:                  dot at start of body  e.g. S="a"{·"a"}
        //   END:                  dot at end of body    e.g. S="a"{"a"·}
        func ebnfDot() -> String {
            if kind == .N && seq == nil {
                // a lhs nonterminal
                return String(name)
            } else {
                // construct the ebnf for the toplevel alternate production containing the dot
                var ebnf = ""
                let (toplevelAlternate, containingNonterminal) = toplevels()
                if let tla = toplevelAlternate, let cnt = containingNonterminal {
                    try? tla.emit(into: &ebnf, dottedSlot: self)
                    return String(cnt.name) + "=" + ebnf
                } else {
                    return ebnf
                }
            }
        }
    }
}

extension ParsePosition: Comparable, CustomStringConvertible {
    static func < (lhs: ParsePosition, rhs: ParsePosition) -> Bool {
        lhs.description < rhs.description
    }
    var description: String { "\(slot).\(index)" }
}

extension ParseCluster: CustomStringConvertible {
    var description: String { "\(slot).\(index)" }
}

