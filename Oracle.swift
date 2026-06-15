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

/// Alternate-level `@unless(X)` predicate: prune yields of this slot whose
/// end position is also the start of a yield of nonterminal `target`.
///
/// Encodes Swift's `canParseAsXxx` pattern at the grammar level — when a
/// "fallback" alternate competes with a "richer" alternate that uses `target`,
/// suppress the fallback whenever the richer interpretation is structurally
/// available.
///
/// Implementation: a yield triple `(i, k, j)` of the annotated slot is pruned
/// iff `target` has a yield with `i == j` — i.e. the richer alternate could
/// have parsed starting where this fallback ended.
struct UnlessPredicateRule: DisambiguationRule {
    let target: GrammarNode
    /// Closure that returns the current yields of an arbitrary grammar node.
    /// Injected by the `Oracle` so the rule can read the *target*'s yields
    /// without coupling to either `MessageParser` or the old `node.yield` field.
    let yieldsOf: (GrammarNode) -> Set<BinarySpan>
    func prune(_ yields: inout Set<BinarySpan>) -> Int {
        let targetStarts = Set(yieldsOf(target).map(\.i))
        var pruned = 0
        for span in yields where targetStarts.contains(span.j) {
            yields.remove(span)
            pruned += 1
        }
        return pruned
    }
}

private func pruneByExtent(
    yields: inout Set<BinarySpan>,
    keep: ([CharPosition]) -> CharPosition
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
    let i: CharPosition
    let j: CharPosition
}

private func pruneByPivot(
    yields: inout Set<BinarySpan>,
    keep: ([CharPosition]) -> CharPosition
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
    let parser: MessageParser
    let grammar: Grammar
    let tokens: [Token]
    let input: String
    private var rules: [(node: GrammarNode, rule: DisambiguationRule)] = []

    private struct NodeSpan: Hashable { let id: ObjectIdentifier; let from, to: CharPosition }
    private struct NodePos: Hashable  { let id: ObjectIdentifier; let from: CharPosition }

    init(parser: MessageParser, tokens: [Token], input: String) {
        self.parser = parser
        self.grammar = parser.grammar
        self.tokens = tokens
        self.input = input
        for (_, nt) in grammar.nonTerminals {
            // LHS-level disambiguation pragmas: @longest, @shortest, @left, @right.
            if let d = nt.disambiguation {
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
            // Alternate-level @unless(X) predicates.
            // The annotation is captured on the .ALT node, but yields live on body symbols.
            // Register the rule on the LAST body symbol of the alternate — its yield's `j` is
            // where the alternate ended, which is where `X` would speculatively start.
            var alt: GrammarNode? = nt.alt
            while let a = alt {
                if let target = a.unlessTarget {
                    if let last = a.bodySymbols.last {
                        let p = parser  // capture for the closure
                        rules.append((last, UnlessPredicateRule(target: target,
                                                                yieldsOf: { p.yield(of: $0) })))
                    }
                }
                alt = a.alt
            }
        }
    }

    @discardableResult
    func disambiguate() -> Int {
        let n = input.endIndex
        let origin = input.startIndex
        guard parser.yield(of: grammar.root).contains(where: { $0.i == origin && $0.j == n }) else { return 0 }

        var deadYields = 0
        while true {
            let pruned = pruneUnproductive(endPosition: n)
            deadYields += pruned
            if pruned == 0 { break }
        }
        var disambiguated = 0
        var changed = true
        while changed {
            changed = false
            for (node, rule) in rules {
                // Copy out / write back instead of `&parser.yields[node.number]`
                // — UnlessPredicateRule's closure reads `parser.yields[target.number]`,
                // and Swift's law of exclusivity forbids a read and a modify on
                // the same parent (the `yields` array) at the same time.
                var spans = parser.yields[node.number]
                let pruned = rule.prune(&spans)
                parser.yields[node.number] = spans
                if pruned > 0 {
                    disambiguated += pruned
                    changed = true
                }
            }
        }
        // Second dead-wood sweep: rules may have pruned body-symbol yields whose
        // parent .N yields are now unreachable. Cascade to a fixed point.
        var secondDead = 0
        while true {
            let pruned = pruneUnproductive(endPosition: n)
            secondDead += pruned
            if pruned == 0 { break }
        }

        let total = deadYields + secondDead + disambiguated
        if total > 0 {
            print("oracle: removed \(deadYields)+\(secondDead) dead + \(disambiguated) disambiguated yields")
        }
        assert(isUnambiguous(endPosition: n), "Oracle postcondition violated: residual ambiguity remains")
        return total
    }

    // MARK: - Postcondition: No Residual Ambiguity

    private func isUnambiguous(endPosition n: CharPosition) -> Bool {
        // TODO: implement full ambiguity check across all reachable nonterminals
        return true
    }

    // MARK: - Phase 1: Prune Unproductive Yields

    private func pruneUnproductive(endPosition n: CharPosition) -> Int {
        var reachable = Set<NodeSpan>()
        var expanding = Set<NodeSpan>()
        var endCache = [NodePos: Set<CharPosition>]()
        var endGuard = Set<NodePos>()

        // End positions reachable from `sym` starting at `from`.
        // Mirrors DerivationBuilder.endPositions — read-only query on yields.
        func endPositions(_ sym: GrammarNode, from: CharPosition) -> Set<CharPosition> {
            let key = NodePos(id: ObjectIdentifier(sym), from: from)
            if let cached = endCache[key] { return cached }
            guard endGuard.insert(key).inserted else { return [] }
            defer { endGuard.remove(key) }

            let result: Set<CharPosition>
            switch sym.kind {
            case .T, .TI, .C, .B:
                result = Set(parser.yield(of: sym).lazy.filter { $0.k == from }.map(\.j))
            case .N:
                if sym.isRHS {
                    guard let lhs = sym.alt else { return [] }
                    let occurrenceEnds = Set(parser.yield(of: sym).lazy.filter { $0.k == from }.map(\.j))
                    let lhsEnds = Set(parser.yield(of: lhs).lazy.filter { $0.i == from }.map(\.j))
                    result = occurrenceEnds.intersection(lhsEnds)
                } else {
                    result = Set(parser.yield(of: sym).lazy.filter { $0.i == from }.map(\.j))
                }
            case .DO, .OPT, .KLN, .POS:
                var positions = Set<CharPosition>()
                if sym.kind == .KLN || sym.kind == .OPT { positions.insert(from) }
                if sym.kind.isClosure {
                    var visited = Set<CharPosition>()
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

        func iterEndPositions(_ bracket: GrammarNode, from: CharPosition) -> Set<CharPosition> {
            var positions = Set<CharPosition>()
            var alt = bracket.alt
            while let a = alt {
                let body = a.bodySymbols.filter { $0.kind != .EPS }
                if body.isEmpty {
                    positions.insert(from)
                } else {
                    var frontier: Set<CharPosition> = [from]
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
        func visit(_ node: GrammarNode, from: CharPosition, to: CharPosition) -> Bool {
            let key = NodeSpan(id: ObjectIdentifier(node), from: from, to: to)
            if reachable.contains(key) { return true }
            guard expanding.insert(key).inserted else { return false }
            defer { expanding.remove(key) }

            guard parser.yield(of: node).contains(where: { $0.i == from && $0.j == to }) else { return false }

            if visitAlternates(node, from: from, to: to) {
                reachable.insert(key)
                return true
            }
            return false
        }

        func visitAlternates(_ node: GrammarNode, from: CharPosition, to: CharPosition) -> Bool {
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
        func tileBody(_ symbols: [GrammarNode], from: CharPosition, to: CharPosition) -> Bool {
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

        func visitSymbol(_ sym: GrammarNode, from: CharPosition, to: CharPosition) {
            if parser.yield(of: sym).contains(where: { ($0.i == from && $0.j == to) || ($0.k == from && $0.j == to) }) {
                reachable.insert(NodeSpan(id: ObjectIdentifier(sym), from: from, to: to))
            }

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

        func visitBracket(_ bracket: GrammarNode, from: CharPosition, to: CharPosition) {
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
        visit(grammar.root, from: input.startIndex, to: n)

        // Remove unreachable yields from every grammar node. Body-symbol yields
        // can otherwise keep stale tilings alive after a parent alternate was pruned.
        var allNodes: [GrammarNode] = [grammar.root]
        var seen = Set<ObjectIdentifier>()

        func collect(_ node: GrammarNode?) {
            guard let node else { return }
            guard seen.insert(ObjectIdentifier(node)).inserted else { return }
            allNodes.append(node)
            if node.kind != .END {
                collect(node.seq)
            }
            collect(node.alt)
        }

        for nt in grammar.nonTerminals.values {
            collect(nt)
        }

        var pruned = 0
        for node in allNodes {
            let before = parser.yields[node.number].count
            parser.yields[node.number] = parser.yields[node.number].filter { span in
                reachable.contains(NodeSpan(id: ObjectIdentifier(node), from: span.i, to: span.j))
                    || reachable.contains(NodeSpan(id: ObjectIdentifier(node), from: span.k, to: span.j))
            }
            pruned += before - parser.yields[node.number].count
        }
        return pruned
    }
}
