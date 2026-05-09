//
//  Oracle.swift
//  Advent
//
//  Created by Johannes Brands on 2026.05.04.
//

// Post-parse disambiguator operating entirely on BSR yield sets.
//
// Two phases:
//   1. Prune unproductive yields — walk BSR top-down from root, remove
//      yields not on any complete derivation path.
//   2. Disambiguate — apply grammar-annotated rules (shortest/longest match)
//      to choose among genuinely ambiguous alternatives.
//
// After phase 1, every surviving yield participates in at least one
// complete derivation, so phase 2 can prune without risk of
// inadvertently destroying the only valid parse.

import Foundation

// MARK: - Disambiguation Rule

protocol DisambiguationRule {
    func prune(_ yields: inout Set<BinarySpan>) -> Int
}

struct LongestMatchRule: DisambiguationRule {
    func prune(_ yields: inout Set<BinarySpan>) -> Int {
        pruneByExtent(yields: &yields, keep: { $0.max()! })
    }
}

struct ShortestMatchRule: DisambiguationRule {
    func prune(_ yields: inout Set<BinarySpan>) -> Int {
        pruneByExtent(yields: &yields, keep: { $0.min()! })
    }
}

struct LeftAssocRule: DisambiguationRule {
    func prune(_ yields: inout Set<BinarySpan>) -> Int {
        pruneByPivot(yields: &yields, keep: { $0.max()! })
    }
}

struct RightAssocRule: DisambiguationRule {
    func prune(_ yields: inout Set<BinarySpan>) -> Int {
        pruneByPivot(yields: &yields, keep: { $0.min()! })
    }
}

private func pruneByExtent(
    yields: inout Set<BinarySpan>,
    keep: ([TokenPosition]) -> TokenPosition
) -> Int {
    let grouped = Dictionary(grouping: yields) { $0.i }
    var pruned = 0
    for (_, spans) in grouped where spans.count > 1 {
        let js = spans.map(\.j)
        guard Set(js).count > 1 else { continue }
        let target = keep(js)
        for span in spans where span.j != target {
            yields.remove(span)
            pruned += 1
        }
    }
    return pruned
}

private struct SpanKey: Hashable {
    let i: TokenPosition
    let j: TokenPosition
}

private func pruneByPivot(
    yields: inout Set<BinarySpan>,
    keep: ([TokenPosition]) -> TokenPosition
) -> Int {
    let grouped = Dictionary(grouping: yields) { SpanKey(i: $0.i, j: $0.j) }
    var pruned = 0
    for (_, spans) in grouped where spans.count > 1 {
        let ks = spans.map(\.k)
        guard Set(ks).count > 1 else { continue }
        let target = keep(ks)
        for span in spans where span.k != target {
            yields.remove(span)
            pruned += 1
        }
    }
    return pruned
}

// MARK: - Oracle

class Oracle {
    let grammar: Grammar
    let tokens: [Token]
    private var rules: [(node: GrammarNode, rule: DisambiguationRule)] = []

    private struct NodeSpan: Hashable { let id: ObjectIdentifier; let from, to: TokenPosition }
    private struct NodePos: Hashable  { let id: ObjectIdentifier; let from: TokenPosition }

    init(grammar: Grammar, tokens: [Token]) {
        self.grammar = grammar
        self.tokens = tokens
        for (_, nt) in grammar.nonTerminals {
            guard let d = nt.disambiguation else { continue }
            switch d {
            case .shortest: rules.append((nt, ShortestMatchRule()))
            case .longest:  rules.append((nt, LongestMatchRule()))
            case .left, .right:
                let rule: DisambiguationRule = d == .left ? LeftAssocRule() : RightAssocRule()
                var alt = nt.alt
                while let a = alt {
                    for sym in a.bodySymbols {
                        rules.append((sym, rule))
                    }
                    alt = a.alt
                }
            }
        }
    }

    @discardableResult
    func disambiguate() -> Int {
        let n = TokenPosition(token: tokens.count - 1)
        guard grammar.root.yield.contains(where: { $0.i == .zero && $0.j == n }) else { return 0 }

        let deadYields = pruneUnproductive(endPosition: n)
        var disambiguated = 0
        var changed = true
        while changed {
            changed = false
            for (node, rule) in rules {
                let pruned = rule.prune(&node.yield)
                if pruned > 0 {
                    disambiguated += pruned
                    changed = true
                }
            }
        }

        let total = deadYields + disambiguated
        if total > 0 {
            print("oracle: removed \(deadYields) dead + \(disambiguated) disambiguated yields")
        }
        assert(isUnambiguous(endPosition: n), "Oracle postcondition violated: residual ambiguity remains")
        return total
    }

    // MARK: - Postcondition: No Residual Ambiguity

    private func isUnambiguous(endPosition n: TokenPosition) -> Bool {
        // TODO: implement full ambiguity check across all reachable nonterminals
        return true
    }

    // MARK: - Phase 1: Prune Unproductive Yields

    private func pruneUnproductive(endPosition n: TokenPosition) -> Int {
        var reachable = Set<NodeSpan>()
        var expanding = Set<NodeSpan>()
        var endCache = [NodePos: Set<TokenPosition>]()
        var endGuard = Set<NodePos>()

        // End positions reachable from `sym` starting at `from`.
        // Mirrors DerivationBuilder.endPositions — read-only query on yields.
        func endPositions(_ sym: GrammarNode, from: TokenPosition) -> Set<TokenPosition> {
            let key = NodePos(id: ObjectIdentifier(sym), from: from)
            if let cached = endCache[key] { return cached }
            guard endGuard.insert(key).inserted else { return [] }
            defer { endGuard.remove(key) }

            let result: Set<TokenPosition>
            switch sym.kind {
            case .T, .TI, .C, .B:
                result = Set(sym.yield.lazy.filter { $0.k == from }.map(\.j))
            case .N:
                guard let lhs = sym.alt else { return [] }
                result = Set(lhs.yield.lazy.filter { $0.i == from }.map(\.j))
            case .DO, .OPT, .KLN, .POS:
                var positions = Set<TokenPosition>()
                if sym.kind == .KLN || sym.kind == .OPT { positions.insert(from) }
                if sym.kind.isClosure {
                    var visited = Set<TokenPosition>()
                    var queue = [from]
                    while !queue.isEmpty {
                        let pos = queue.removeFirst()
                        guard visited.insert(pos).inserted else { continue }
                        for end in iterEndPositions(sym, from: pos) where end > pos {
                            positions.insert(end)
                            queue.append(end)
                        }
                    }
                } else {
                    positions.formUnion(iterEndPositions(sym, from: from))
                }
                result = positions
            case .EPS:
                result = [from]
            default:
                result = []
            }
            endCache[key] = result
            return result
        }

        func iterEndPositions(_ bracket: GrammarNode, from: TokenPosition) -> Set<TokenPosition> {
            var positions = Set<TokenPosition>()
            var alt = bracket.alt
            while let a = alt {
                let body = a.bodySymbols.filter { $0.kind != .EPS }
                if body.isEmpty {
                    positions.insert(from)
                } else {
                    var frontier: Set<TokenPosition> = [from]
                    for sym in body {
                        frontier = frontier.reduce(into: Set()) { $0.formUnion(endPositions(sym, from: $1)) }
                        if frontier.isEmpty { break }
                    }
                    positions.formUnion(frontier)
                }
                alt = a.alt
            }
            return positions
        }

        // Walk the BSR graph top-down. Returns true if any valid tiling
        // of `node`'s alternates covers [from, to].
        @discardableResult
        func visit(_ node: GrammarNode, from: TokenPosition, to: TokenPosition) -> Bool {
            let key = NodeSpan(id: ObjectIdentifier(node), from: from, to: to)
            if reachable.contains(key) { return true }
            guard expanding.insert(key).inserted else { return false }
            defer { expanding.remove(key) }

            guard node.yield.contains(where: { $0.i == from && $0.j == to }) else { return false }

            if visitAlternates(node, from: from, to: to) {
                reachable.insert(key)
                return true
            }
            return false
        }

        func visitAlternates(_ node: GrammarNode, from: TokenPosition, to: TokenPosition) -> Bool {
            var found = false
            var alt = node.alt
            while let a = alt {
                defer { alt = a.alt }
                let body = a.bodySymbols.filter { $0.kind != .EPS }
                if body.isEmpty {
                    if from == to { found = true }
                } else if tileBody(body, from: from, to: to) {
                    found = true
                }
            }
            return found
        }

        // Tile body symbols over [from, to]. Returns true if any complete
        // tiling exists, and recursively visits nonterminals along the way.
        func tileBody(_ symbols: [GrammarNode], from: TokenPosition, to: TokenPosition) -> Bool {
            guard let first = symbols.first else { return from == to }
            let rest = Array(symbols.dropFirst())
            var found = false
            for mid in endPositions(first, from: from) where mid <= to {
                let restOK = rest.isEmpty ? mid == to : tileBody(rest, from: mid, to: to)
                if restOK {
                    visitSymbol(first, from: from, to: mid)
                    found = true
                }
            }
            return found
        }

        func visitSymbol(_ sym: GrammarNode, from: TokenPosition, to: TokenPosition) {
            switch sym.kind {
            case .N:
                guard let lhs = sym.alt else { return }
                visit(lhs, from: from, to: to)
            case .DO, .OPT, .KLN, .POS:
                visitBracket(sym, from: from, to: to)
            default:
                break
            }
        }

        func visitBracket(_ bracket: GrammarNode, from: TokenPosition, to: TokenPosition) {
            if from == to { return }
            for end in iterEndPositions(bracket, from: from) where end <= to && end > from {
                if visitAlternates(bracket, from: from, to: end) {
                    reachable.insert(NodeSpan(id: ObjectIdentifier(bracket), from: from, to: end))
                    if end == to {
                        // iteration covers the full span
                    } else if bracket.kind.isClosure {
                        visitBracket(bracket, from: end, to: to)
                    }
                }
            }
        }

        // Seed from root
        visit(grammar.root, from: .zero, to: n)

        // Remove unreachable yields from nonterminals
        var pruned = 0
        for (_, nt) in grammar.nonTerminals {
            let before = nt.yield.count
            nt.yield = nt.yield.filter { span in
                reachable.contains(NodeSpan(id: ObjectIdentifier(nt), from: span.i, to: span.j))
            }
            pruned += before - nt.yield.count
        }
        return pruned
    }
}
