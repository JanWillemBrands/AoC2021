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
    let input: String
    func prune(_ yields: inout Set<BinarySpan>) -> Int {
        pruneByExtent(yields: &yields, input: input, keepLongest: true)
    }
}

struct ShortestMatchRule: DisambiguationRule {
    let input: String
    func prune(_ yields: inout Set<BinarySpan>) -> Int {
        pruneByExtent(yields: &yields, input: input, keepLongest: false)
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

/// The optional-skip rule — compiled from an `@avoid` alternate inside an OPT/KLN: prefer NOT
/// taking the optional whenever skipping still yields a complete parse. Registered on the
/// symbol immediately FOLLOWING the bracket. Competing readings reach the same enclosing span
/// `(i, j)` and differ only in the pivot `k` = where the bracket ended / the follower began.
/// The pivot uniformly encodes HOW MUCH the bracket consumed: `k = i` (bracket start) is the
/// skip, larger `k` are progressively longer takes. Keep the min-`k` (least consumption) and
/// prune the rest — so this prefers the skip, and, where the skip is not viable, the SHORTEST
/// take. That uniformity is exactly why the decision lives on the follower's pivot and not on
/// the avoided alternate's own yields: "skip" is the *absence* of an avoided-alternate yield,
/// observable only here. When skipping does not complete, phase-1 has already removed the skip
/// yield, so the lone take survives (e.g. `-x`).
///
/// ALTERNATE-AWARE: the bare pivot `k` cannot say WHICH alternate produced a taken reading, so a
/// non-avoided sibling `B` sharing `A`'s pivot would be collateral-pruned. `protectedLast` holds
/// the non-avoided siblings' last body symbols; any pivot they reach from the bracket start is
/// exempted. `A`'s same-span removal is `PreferRule`'s job. Single-body `[ @avoid X ]` has no
/// siblings, so `protectedLast` is empty and this is the classic keep-min-pivot.
struct AvoidOptionalRule: DisambiguationRule {
    let protectedLast: [GrammarNode]
    let yieldsOf: (GrammarNode) -> Set<BinarySpan>
    func prune(_ yields: inout Set<BinarySpan>) -> Int {
        let grouped = Dictionary(grouping: yields) { SpanKey(i: $0.i, j: $0.j) }
        var pruned = 0
        for (_, spans) in grouped where spans.count > 1 {
            let ks = spans.map(\.k)
            guard let minK = ks.min(), Set(ks).count > 1 else { continue }
            var protected = Set<CharPosition>()
            for sym in protectedLast {
                for y in yieldsOf(sym) where y.i == minK { protected.insert(y.j) }
            }
            for span in spans where span.k != minK && !protected.contains(span.k) {
                yields.remove(span)
                pruned += 1
            }
        }
        return pruned
    }
}

/// Alternate-level `@prefer` — same-span (flavor-3) preference. Only the *preferred*
/// alternate is annotated in the grammar; the Oracle registers this rule on each
/// NON-preferred sibling's last body symbol and prunes its completion yield `(i, j)`
/// wherever a preferred sibling covers the EXACT same span `(i, j)`. `@prefer` chooses
/// among alternates that tile the same extent — it is NOT an extent tool. Prefer-the-
/// longer is `@longest`'s job (see the note in `prune`).
struct PreferRule: DisambiguationRule {
    let preferredLastSymbols: [GrammarNode]
    let yieldsOf: (GrammarNode) -> Set<BinarySpan>
    func prune(_ yields: inout Set<BinarySpan>) -> Int {
        // Flavor-3 (same-span) ONLY: prune a non-preferred loser `(i, j)` iff a preferred sibling
        // covers the EXACT same span `(i, j)`. `@prefer` chooses among alternates that tile the same
        // extent — it is NOT an extent tool. Different-extent preference ("prefer the longer
        // alternate") is `@longest`'s job. Keying on start alone (the old behaviour) conflated the
        // two and wrongly pruned genuinely LONGER same-start neighbours (broke `a?.b`, multi-arg
        // subscripts, etc.). `span.i` = alternate start, `span.j` = alternate end.
        var preferredSpans = Set<SpanKey>()
        for sym in preferredLastSymbols {
            for y in yieldsOf(sym) { preferredSpans.insert(SpanKey(i: y.i, j: y.j)) }
        }
        var pruned = 0
        for span in yields where preferredSpans.contains(SpanKey(i: span.i, j: span.j)) {
            yields.remove(span)
            pruned += 1
        }
        return pruned
    }
}

private func pruneByExtent(
    yields: inout Set<BinarySpan>,
    input: String,
    keepLongest: Bool
) -> Int {
    // Extent compares interval LENGTH `j - k`, not the end `j`. For an `.N` LHS yield
    // `i == k`, so length ↔ `j` and this matches the classic behaviour. For a bracket
    // (yield `(alternate-start i, k = bracket-start, j)`), the competing readings of one
    // occurrence share `i`; they may differ in `j` (same start, S1) OR in `k` (start
    // moved by a variable-length prefix, so `j` is pinned — S2). Comparing `j` alone
    // can't see the S2 case; length can. Group by the alternate anchor `i`, keep the
    // min/max-length reading, prune the rest. `pruneUnproductive` then propagates the
    // kill backward/forward along the sequence.
    let grouped = Dictionary(grouping: yields) { $0.i }
    var pruned = 0
    for (_, spans) in grouped where spans.count > 1 {
        let lengths = spans.map { input.distance(from: $0.k, to: $0.j) }
        guard Set(lengths).count > 1 else { continue }
        let target = keepLongest ? lengths.max()! : lengths.min()!
        for span in spans where input.distance(from: span.k, to: span.j) != target {
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

/// `@within(ContextNT)` — a HARD, context-scoped faithfulness filter (see `Within Filter
/// Design.md`). Compiled from an `@within(Ctx…) LHS = rhs .` FILTER production: for each `anchor`
/// yield whose span lies inside ALL of `contexts`' extents (BSR span-containment = the GLL
/// substitute for the inherited `ExprFlavor`), evaluate the boundary `gate` declared in the filter
/// RHS; if it fails, REMOVE that yield. Unlike a preference this may leave the forest empty — the
/// second dead-wood sweep then cascades the removal up to the root (→ reject).
///
/// The gate is whatever the filter RHS declared, so there is NO Swift-side disc-1/disc-3 logic —
/// the grammar is the predicate:
///   • `.followExclude` / `.followInclude` — the source word after the anchor's end `j` (a `>->`/
///     `>+>` on a body symbol).
///   • `.openBraceNoNewline` — a `<n>` after the anchor's opening `{` (line break in the trivia
///     between `{` and the first body token — same computation as the `>n<` boundary gate).
struct WithinRule: DisambiguationRule {
    enum Gate {
        case followExclude(Set<String>)
        case followInclude(Set<String>)
        case openBraceNoNewline
    }
    let gate: Gate
    let contexts: [() -> Set<BinarySpan>]      // ALL must contain the anchor span (conjunction)
    let input: String
    /// The engine's trivia skipper (`lexer.triviaSkipEnd`) — so the gate uses the SAME trivia +
    /// line-break notion as the `<n>`/`>n<` boundary gates, not a parallel hand-rolled scan.
    let triviaSkipEnd: (CharPosition) -> CharPosition

    func prune(_ yields: inout Set<BinarySpan>) -> Int {
        let ctxYields = contexts.map { $0() }
        guard ctxYields.allSatisfy({ !$0.isEmpty }) else { return 0 }
        var pruned = 0
        for y in yields {
            // Conjunction of containments: the anchor span [y.i, y.j] must lie inside EACH context.
            guard ctxYields.allSatisfy({ cy in cy.contains { $0.i <= y.i && y.j <= $0.j } }) else { continue }
            if gateFails(at: y) { yields.remove(y); pruned += 1 }
        }
        return pruned
    }

    private func gateFails(at y: BinarySpan) -> Bool {
        switch gate {
        case .followExclude(let set):
            let follow = wordAt(triviaSkipEnd(y.j))
            return follow.map { set.contains($0) } ?? false            // EOF never excluded
        case .followInclude(let set):
            let follow = wordAt(triviaSkipEnd(y.j))
            return !(follow.map { set.contains($0) } ?? true)          // EOF allowed
        case .openBraceNoNewline:
            return openBraceStartsNewLine(at: y.i)
        }
    }

    /// A `<n>` after `{`: is there a line break in the trivia between an opening `{` at `bracePos`
    /// and the first body token? Returns false unless `input[bracePos] == "{"` (self-guard).
    private func openBraceStartsNewLine(at bracePos: CharPosition) -> Bool {
        guard bracePos < input.endIndex, input[bracePos] == "{" else { return false }
        let afterBrace = input.index(after: bracePos)
        let contentStart = triviaSkipEnd(afterBrace)            // engine trivia skip (comments too)
        return input[afterBrace..<contentStart].contains { $0 == "\n" || $0 == "\r" }
    }

    /// The source token at `pos` (already trivia-skipped): an identifier-shaped word, or a single
    /// punctuation character; `nil` at end-of-input.
    private func wordAt(_ pos: CharPosition) -> String? {
        guard pos < input.endIndex else { return nil }
        let c = input[pos]
        if c.isLetter || c == "_" {
            var j = pos
            while j < input.endIndex, input[j].isLetter || input[j].isNumber || input[j] == "_" {
                j = input.index(after: j)
            }
            return String(input[pos..<j])
        }
        return String(c)
    }
}

// MARK: - Oracle

class Oracle {
    let parser: MessageParser
    let grammar: Grammar
    let input: String
    private var rules: [(node: GrammarNode, rule: DisambiguationRule)] = []

    private struct NodeSpan: Hashable { let id: ObjectIdentifier; let from, to: CharPosition }
    private struct NodePos: Hashable  { let id: ObjectIdentifier; let from: CharPosition }

    init(parser: MessageParser, input: String) {
        self.parser = parser
        self.grammar = parser.grammar
        self.input = input
        for (_, nt) in grammar.nonTerminals {
            // Node-level extent/associativity (@longest/@shortest/@left/@right),
            // read off the owner node — for a nonterminal that is the production-start
            // form `@longest X = …` stored on `nt.disambiguation`.
            registerNodeDisambiguation(owner: nt)
            // Alternate-level @prefer / @avoid on the nonterminal's own alt chain.
            registerPrefer(altChainHead: nt.alt)
        }

        // Full-graph walk for the pragmas that live on a NESTED node — every ALT-bearing
        // node is treated exactly like a nonterminal:
        //   - node-level extent/assoc: `registerNodeDisambiguation` reads the pragma off
        //     the bracket node (`@longest ( … )` / `@left < … >`, parsed in `factor()`).
        //   - alternate-level @prefer / @avoid: `registerPrefer` reads `isPreferred` /
        //     `isAvoided` off the cluster's ALT nodes (a bracket owns its alternates via
        //     `.alt` exactly like a nonterminal LHS — `factor()` → `GrammarNode(.DO/…,
        //     alt: selection())`). Run per BRACKET node (not per ALT node, whose `.alt`
        //     is a sibling continuation), so each group is registered exactly once.
        //   - the optional-skip: an `@avoid` alternate inside an OPT/KLN competes against
        //     that group's implicit empty (skip) branch — the ε rival that `registerPrefer`
        //     can't key on. `registerOptionalSkip` compiles it to an alternate-aware
        //     follower-pivot rule (`AvoidOptionalRule`).
        var seen = Set<ObjectIdentifier>()
        func walk(_ node: GrammarNode?) {
            guard let node, seen.insert(ObjectIdentifier(node)).inserted else { return }
            if node.kind.isBracket {
                registerNodeDisambiguation(owner: node)
                registerPrefer(altChainHead: node.alt)
                registerOptionalSkip(bracket: node)
            }
            if node.kind != .END { walk(node.seq) }
            walk(node.alt)
        }
        for nt in grammar.nonTerminals.values { walk(nt) }

        // `@within(Ctx…) LHS = rhs .` filter productions (post-parse; see `Within Filter Design.md`).
        for filter in grammar.filters { registerFilter(filter) }
    }

    /// Register node-level extent/associativity for an ALT-bearing `owner` (a
    /// nonterminal LHS or an inline `( )`/`[ ]`/`{ }`/`< >` cluster), reading the pragma
    /// off `owner.disambiguation` (set before the LHS in `production()` or before the
    /// bracket in `factor()`):
    ///   - extent (`@longest`/`@shortest`): register on the owner itself. Its yields from
    ///     a common start are what an extent rule prunes, and `endPositions` reads those
    ///     yields for `.N` nonterminals AND (now) `.OPT` brackets, so the prune propagates
    ///     through both the phase-1 cascade and the DerivationBuilder. (Closures still
    ///     recompute their transitive extent from the body, so extent on a `{ }`/`< >`
    ///     closure is not yet honored — a separate carrier problem.)
    ///   - associativity (`@left`/`@right`): register a pivot rule on every alternate's
    ///     body symbols (associativity governs the whole node's self-ambiguity).
    private func registerNodeDisambiguation(owner: GrammarNode) {
        guard let d = owner.disambiguation else { return }
        switch d {
        case .shortest, .longest:
            // BRACKET extent is handled in the phase-1 walk (`tileBody` keeps the min/max
            // feasible span per enclosing context). A NONTERMINAL keeps the classic global
            // extent on its own yields.
            if !owner.kind.isBracket {
                rules.append((owner, d == .shortest ? ShortestMatchRule(input: input) : LongestMatchRule(input: input)))
            }
        case .left, .right:
            let rule: DisambiguationRule = d == .left ? LeftAssocRule() : RightAssocRule()
            var alt = owner.alt
            while let a = alt {
                for sym in a.bodySymbols { rules.append((sym, rule)) }
                alt = a.alt
            }
        }
    }

    /// Register the same-span, last-symbol-keyed alternate preferences for one alternate
    /// group (a chain of `.ALT` nodes reachable from `altChainHead`). Level-agnostic: the
    /// head may be a nonterminal's `nt.alt` or an inline cluster's `bracket.alt`.
    ///   - `@prefer` names WINNERS: every non-preferred sibling is pruned where a
    ///     preferred sibling covers the same `(i, j)` span.
    ///   - `@avoid` names a LOSER: it is the dual — an avoided alternate is pruned where ANY
    ///     of its siblings covers the same `(i, j)`, i.e. `@avoid A` ≡ `@prefer` on all of
    ///     A's (non-empty) siblings. This handles only the EXPLICIT-sibling rivalry; the
    ///     avoided alternate's other rival — an OPT/KLN's implicit empty (skip) branch — is
    ///     compiled separately by `registerOptionalSkip`, because ε has no last body symbol
    ///     to key a same-span rule on.
    /// Both key on last body symbols, so a winner must be non-empty to be keyable.
    private func registerPrefer(altChainHead: GrammarNode?) {
        var alts: [GrammarNode] = []
        var scan = altChainHead
        while let a = scan { alts.append(a); scan = a.alt }
        let p = parser

        // @prefer: preferred alternates prune their non-preferred siblings.
        let preferredLast = alts.filter { $0.isPreferred }.compactMap { $0.bodySymbols.last }
        if !preferredLast.isEmpty {
            for a in alts where !a.isPreferred {
                if let last = a.bodySymbols.last {
                    rules.append((last, PreferRule(preferredLastSymbols: preferredLast,
                                                   yieldsOf: { p.yield(of: $0) })))
                }
            }
        }

        // @avoid (alt-prefix): an avoided alternate loses to all its (non-empty) siblings.
        for a in alts where a.isAvoided {
            let siblingsLast = alts.filter { $0 !== a }.compactMap { $0.bodySymbols.last }
            if let last = a.bodySymbols.last, !siblingsLast.isEmpty {
                rules.append((last, PreferRule(preferredLastSymbols: siblingsLast,
                                               yieldsOf: { p.yield(of: $0) })))
            }
        }
    }

    /// The optional-skip: an `@avoid` alternate inside an OPT (`[ … ]`) or KLN (`{ … }`)
    /// competes against the group's **implicit empty (skip) branch** — the ε rival that
    /// `registerPrefer` can't key on (ε has no last body symbol). Register an
    /// `AvoidOptionalRule` on EACH avoided alternate's own `lastContentSymbol`: it reads the
    /// bracket's follower to detect the take-vs-skip competition and removes the avoided
    /// alternate's own "taken" completions. POS (`< … >`) and DO (`( … )`) have no skip
    /// branch and are excluded.
    private func registerOptionalSkip(bracket: GrammarNode) {
        guard bracket.kind == .OPT || bracket.kind == .KLN else { return }
        var alts: [GrammarNode] = []
        var scan = bracket.alt
        while let a = scan { alts.append(a); scan = a.alt }
        guard alts.contains(where: { $0.isAvoided }) else { return }
        guard let next = bracket.seq, next.kind != .END else { return }
        let protectedLast = alts.filter { !$0.isAvoided }.compactMap { $0.bodySymbols.last }
        let p = parser
        rules.append((next, AvoidOptionalRule(protectedLast: protectedLast,
                                              yieldsOf: { p.yield(of: $0) })))
    }

    /// Compile one `@within(Ctx…) LHS = rhs .` filter production into `WithinRule`s (see
    /// `Within Filter Design.md`). Resolve the contexts and the BASE nonterminal `LHS`, then read the
    /// extra gates off the filter `rhs` and key each rule on the corresponding BASE node (whose yields
    /// the parse actually produced) — so pruning cascades through the second dead-wood sweep exactly
    /// like a `PreferRule` on a body symbol. Two gate shapes are recognised:
    ///   • a `>->`/`>+>` on a referenced body symbol S → anchor = LHS's own body symbol named S;
    ///   • a `<n>`/`>n<` immediately after a `"{"` literal → anchor = the LHS node (open-brace no-newline).
    private func registerFilter(_ filter: Grammar.FilterProduction) {
        let p = parser
        var contexts: [() -> Set<BinarySpan>] = []
        for name in filter.contextNames {
            guard let ctx = grammar.nonTerminals[name] else {
                assertionFailure("@within(\(name)): unknown context nonterminal"); return
            }
            contexts.append({ p.yield(of: ctx) })
        }
        guard let baseLHS = grammar.nonTerminals[filter.lhsName] else {
            assertionFailure("@within filter references unknown nonterminal \(filter.lhsName)"); return
        }
        let trivia: (CharPosition) -> CharPosition = { p.lexer.triviaSkipEnd(from: $0) }
        func bare(_ s: Set<String>) -> Set<String> {
            Set(s.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) })
        }
        var alt: GrammarNode? = filter.rhs
        while let a = alt {
            let body = a.bodySymbols
            for (idx, n) in body.enumerated() {
                // Case A — follow gate (`>->`/`>+>`) on a referenced body symbol.
                if !n.followAheadExclude.isEmpty || !n.followAhead.isEmpty {
                    if let anchor = baseBodySymbol(named: n.name, of: baseLHS) {
                        let gate: WithinRule.Gate = !n.followAheadExclude.isEmpty
                            ? .followExclude(bare(n.followAheadExclude))
                            : .followInclude(bare(n.followAhead))
                        rules.append((anchor, WithinRule(gate: gate, contexts: contexts, input: input, triviaSkipEnd: trivia)))
                    } else {
                        assertionFailure("@within \(filter.lhsName): no base body symbol named \(n.name)")
                    }
                }
                // Case B — a `<n>`/`>n<` right after a `"{"` literal → open-brace-no-newline on the LHS.
                if n.kind == .B, n.name == "<n>" || n.name == ">n<",
                   idx > 0, body[idx - 1].name == "\"{\"" {
                    rules.append((baseLHS, WithinRule(gate: .openBraceNoNewline, contexts: contexts, input: input, triviaSkipEnd: trivia)))
                }
            }
            alt = a.alt
        }
    }

    /// The first body symbol named `name` across all of `lhs`'s production alternates.
    private func baseBodySymbol(named name: String, of lhs: GrammarNode) -> GrammarNode? {
        var alt = lhs.alt
        while let a = alt {
            if let sym = a.bodySymbols.first(where: { $0.name == name }) { return sym }
            alt = a.alt
        }
        return nil
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
                // — a rule's `yieldsOf` closure reads other nodes' yields out of the
                // same `parser.yields` array, and Swift's law of exclusivity forbids a
                // read and a modify on the same parent at the same time.
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
                if sym.disambiguation != nil {
                    // ANNOTATED bracket (@longest/@shortest): read its OWN (Oracle-prunable)
                    // yields so the extent prune is honored here. A bracket is an RHS
                    // occurrence — yields are `(alternate-start, k = bracket-start, j)`,
                    // filtered by `k == from` like a terminal; a closure's shared cluster
                    // accumulates its transitive ends the same way.
                    result = Set(parser.yield(of: sym).lazy.filter { $0.k == from }.map(\.j))
                } else {
                    // UNANNOTATED bracket: original body-recompute path, untouched — so the
                    // global operator/regex machinery keeps its exact phase-1 reachability.
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
                }
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

        // Pure (side-effect-free) feasibility: can `symbols` tile exactly `[from, to]`?
        // Threads `endPositions` (itself read-only + memoised) as a frontier fold. Used to
        // decide, per enclosing context, which end positions of an EXTENT-annotated node keep
        // the parse complete — WITHOUT marking anything reachable.
        func bodyTiles(_ symbols: [GrammarNode], from: CharPosition, to: CharPosition) -> Bool {
            var frontier: Set<CharPosition> = [from]
            for sym in symbols {
                var next = Set<CharPosition>()
                for f in frontier { next.formUnion(endPositions(sym, from: f).filter { $0 <= to }) }
                if next.isEmpty { return false }
                frontier = next
            }
            return frontier.contains(to)
        }

        // Extent objective for a BRACKET (`@shortest`/`@longest [ … ]`): among the feasible
        // spans this node can take in THIS enclosing context, keep only the shortest/longest.
        // Per-context (not per-start) is the whole point — it's the constraint-solver reading:
        // minimise/maximise this node's span *subject to a complete parse existing*. Both
        // flavors collapse here: siblings absorb the slack (`[x][x]`, `{x}{x}{x}`), or the
        // follower does (optional-skip). Nonterminal extent stays on the classic global rule.
        func bracketExtent(_ node: GrammarNode) -> Disambiguation? {
            guard node.kind.isBracket, let d = node.disambiguation,
                  d == .shortest || d == .longest else { return nil }
            return d
        }

        // Tile body symbols over [from, to]. Returns true if any complete
        // tiling exists, and recursively visits nonterminals along the way.
        func tileBody(_ symbols: [GrammarNode], from: CharPosition, to: CharPosition) -> Bool {
            guard let first = symbols.first else { return from == to }
            let rest = Array(symbols.dropFirst())
            // Feasible end positions of `first` in this context.
            var mids = endPositions(first, from: from).filter { mid in
                mid <= to && (rest.isEmpty ? mid == to : bodyTiles(rest, from: mid, to: to))
            }
            guard !mids.isEmpty else { return false }
            // Extent objective: an annotated bracket keeps only its shortest/longest feasible span.
            if let d = bracketExtent(first) {
                let target = d == .longest ? mids.max()! : mids.min()!
                mids = [target]
            }
            for mid in mids {
                visitSymbol(first, from: from, to: mid)
                if !rest.isEmpty { _ = tileBody(rest, from: mid, to: to) }
            }
            return true
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
            // For a non-closure bracket, iterate the bracket's OWN (Oracle-pruned) end
            // positions — so an extent prune on the bracket is honored by the reachability
            // walk and dead sibling/prefix yields get removed ("walk the rest of the
            // sequence to kill dead paths"). Using `iterEndPositions` (body recompute) here
            // re-marked extent-pruned spans reachable, leaving stale readings that kept an
            // enclosing pivot ambiguous. Closures still step per-iteration (their own ends
            // are transitive, not single-step) and recurse below.
            let ends = bracket.kind.isClosure
                ? iterEndPositions(bracket, from: from)
                : endPositions(bracket, from: from)
            for end in ends where end <= to && end > from {
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
