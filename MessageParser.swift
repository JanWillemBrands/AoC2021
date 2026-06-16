//
//  MessageParser.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.15.
//

// GLL message parser encapsulating all parsing state.
// Paper: cL = current grammar slot
// Paper: cI — current input position (the current active token)
// Paper: cU — current cluster index (identifies a CRF cluster node together with the nonterminal; its value is the input position where the nonterminal was called)
// Paper: R = pending descriptors, U = processed descriptors
// Paper: dscAdd/dscGet = descriptor operations, ntAdd = nonterminal alternates
// Paper: call = enter nonterminal, rtn = return from nonterminal
// Paper: bsrAdd = add BSR element

import OSLog
import Foundation
import BitCollections
//import AdventMacros

/// Parser-side resolved form of a `LookbehindRule`. The `kinds: [String]` from
/// the grammar are translated into a `BitSet` of `terminalID` once at parse
/// setup, so the evaluator runs purely on integer IDs.
struct ResolvedLookbehindRule {
    let polarity: LookbehindPolarity
    let distance: Int
    let kindsBitSet: BitSet
}

/// A line of AND'd rules (matches the original `LookbehindLine`).
struct ResolvedLookbehindLine {
    let rules: [ResolvedLookbehindRule]
}

/// Parser-side resolved form of `LookbehindSpec` keyed by terminal ID.
struct ResolvedLookbehindSpec {
    let positiveLines: [ResolvedLookbehindLine]
    let negativeLines: [ResolvedLookbehindLine]
    var isEmpty: Bool { positiveLines.isEmpty && negativeLines.isEmpty }
}

/// One terminal commit recorded by the parse loop's `.T`/`.TI`/`.C` arm. Used
/// to evaluate `++N`/`--N` lookbehind annotations and `<s>`/`>s<`/`<n>`/`>n<`
/// boundary annotations from parser state.
///
/// `rawEnd` is the literal/regex content's end position **before** trailing
/// trivia skipping; `end` (the dictionary key in `terminalCommitsByEnd`) is
/// the cursor position **after** trivia skipping. The two differ exactly when
/// the lexer skipped trivia after the match, which is what `boundaryMatches`
/// needs to know to answer "is there whitespace between previous emit and
/// current cursor?".
struct TerminalCommit {
    let kindID: Int
    let start: CharPosition
    let rawEnd: CharPosition
}

class MessageParser {

    // MARK: - Per-construction (immutable after init)
    let grammar: Grammar

    // MARK: - Per-parse input
    var input: String = ""

    // MARK: - GLL algorithm state (paper variables)
    var currentParseRoot: GrammarNode!
    var cL: GrammarNode!                    // current grammar slot
    var cI: CharPosition = "".startIndex    // current input position
    var cU: CharPosition = "".startIndex    // current cluster index

    // MARK: - LCNP lex API
    /// Per-terminal lex queries the parser issues at every `.T`/`.TI`/`.C` slot
    /// and every `testSelect` / `followCheck` / `continuationViable` callsite.
    /// Backed by `OnDemandLiteralLexer` against `input` directly: literals via
    /// `hasPrefix`, regex via `prefixMatch`, trivia (whitespace + `=:`
    /// non-terminal recognisers) via `skipTrivia`.
    var lexer: LCNPLexer!

    // MARK: - Lex memoization
    /// `(pos, terminalID) → [LexMatch]` cache. Lex queries are pure given the
    /// input; the same (pos, terminalID) is asked many times during a parse
    /// (one query per terminal in `firstBS` per `testSelect` invocation; plus
    /// dual visits to the same position via descriptor re-entry). Without
    /// memoization the per-terminal LCNP migration would re-run pattern
    /// matching tens of thousands of times.
    var lexCache: [LexCacheKey: [LexMatch]] = [:]

    @inline(__always)
    func cachedLex(at pos: CharPosition, terminalID: Int) -> [LexMatch] {
        let key = LexCacheKey(pos: pos, terminalID: terminalID)
        if let cached = lexCache[key] { return cached }
        let result = lexer.lex(at: pos, terminalID: terminalID)
        lexCache[key] = result
        return result
    }

    // MARK: - Lookbehind (parser-side evaluation)

    /// Resolve a `LookbehindSpec` (kinds as strings) into a
    /// `ResolvedLookbehindSpec` (kinds as `BitSet<Int>`) by looking each kind
    /// name up via `grammar.symbolToID`. Unknown kind names are dropped — same
    /// semantic as the original `Scanner.matchesLine` falling through on a
    /// missing match.
    private func resolveLookbehindSpec(_ spec: LookbehindSpec) -> ResolvedLookbehindSpec {
        func resolveLine(_ line: LookbehindLine) -> ResolvedLookbehindLine {
            let rules = line.rules.map { rule -> ResolvedLookbehindRule in
                var bs = BitSet()
                for kind in rule.kinds {
                    if let id = grammar.symbolToID[kind] { bs.insert(id) }
                }
                return ResolvedLookbehindRule(polarity: rule.polarity, distance: rule.distance, kindsBitSet: bs)
            }
            return ResolvedLookbehindLine(rules: rules)
        }
        return ResolvedLookbehindSpec(
            positiveLines: spec.positiveLines.map(resolveLine),
            negativeLines: spec.negativeLines.map(resolveLine)
        )
    }

    /// `BitSet` of terminal kindIDs whose commit ends exactly at `pos`. Reads
    /// the parser's per-parse `terminalCommitsByEnd` log.
    private func terminalKindIDs(endingAt pos: CharPosition) -> BitSet {
        guard let commits = terminalCommitsByEnd[pos] else { return BitSet() }
        var bs = BitSet()
        for c in commits { bs.insert(c.kindID) }
        return bs
    }

    /// "N visible terminals back from `pos`" expressed over the parser's
    /// commit log. `distance == 1` → kindIDs committed ending at `pos`;
    /// `distance == 2` → kindIDs committed ending at the start of any commit
    /// ending at `pos`; etc. Walks set-unions when multiple histories arrive
    /// at the same position (the GLL-multi-history equivalent of the original
    /// Schrödinger-dual chain walk in `Scanner.matchesLine`).
    func previousKindIDs(at pos: CharPosition, distance: Int) -> BitSet {
        var endPositions: Set<CharPosition> = [pos]
        for _ in 1..<distance {
            var next: Set<CharPosition> = []
            for p in endPositions {
                if let commits = terminalCommitsByEnd[p] {
                    for c in commits { next.insert(c.start) }
                }
            }
            if next.isEmpty { return BitSet() }
            endPositions = next
        }
        var result = BitSet()
        for p in endPositions {
            result.formUnion(terminalKindIDs(endingAt: p))
        }
        return result
    }

    /// Evaluate a resolved lookbehind spec at parser position `pos`. Mirrors
    /// `Scanner.lookbehindAllows`:
    ///   - positive lines OR'd; any match → allow (overrides negatives)
    ///   - negative lines OR'd; any match → block
    ///   - whitelist mode (positives only, none match) → block
    ///   - otherwise → allow
    /// Each rule's `kinds` comparison walks the parser's per-position kindID
    /// union; under GLL-multi-history this means "the rule fires if any path
    /// arrived at this position via a matching terminal" — the same OR-walk
    /// the original implementation did across Schrödinger duals.
    func lookbehindAllows(_ spec: ResolvedLookbehindSpec, at pos: CharPosition) -> Bool {
        if spec.isEmpty { return true }
        if spec.positiveLines.contains(where: { matchesLine($0, at: pos) }) { return true }
        if spec.negativeLines.contains(where: { matchesLine($0, at: pos) }) { return false }
        if !spec.positiveLines.isEmpty && spec.negativeLines.isEmpty { return false }
        return true
    }

    private func matchesLine(_ line: ResolvedLookbehindLine, at pos: CharPosition) -> Bool {
        for rule in line.rules {
            let prev = previousKindIDs(at: pos, distance: rule.distance)
            if prev.intersection(rule.kindsBitSet).isEmpty {
                return false
            }
        }
        return true
    }

    // MARK: - Descriptor management (Paper: R, U)
    var remaining: [Descriptor] = []
    var unique: Set<Descriptor> = []

    // MARK: - Parse statistics
    var failedParses = 0
    var successfullParses = 0
    var descriptorCount = 0
    var duplicateDescriptorCount = 0
    var suppressedDescriptorCount = 0

    // MARK: - Call Return Forest (Paper: CRF)
    var crf: [ParsePosition: ParseCluster] = [:]

    // MARK: - Binary Subtree Representation (Paper: Υ)
    /// Per-node BSR yields, indexed by `node.number`. Replaces the per-node
    /// `var yield: Set<BinarySpan>` that used to live on `GrammarNode`. With
    /// yields parser-side, the grammar is load-time-immutable: a recursive
    /// sub-parse can run on the same grammar by spinning up a separate
    /// `MessageParser` instance with its own `yields` array.
    var yields: [Set<BinarySpan>] = []

    /// Read accessor for consumers (Oracle, diagrams, tests). Inside the
    /// parser/BSR hot path we use direct `yields[node.number]` access.
    @inline(__always)
    func yield(of node: GrammarNode) -> Set<BinarySpan> {
        yields[node.number]
    }

    var yieldCount = 0

    // MARK: - Lookbehind (Phase E Step 1: parser-side lookbehind evaluation)
    /// `terminalID → resolved lookbehind` for every terminal with a non-empty
    /// `LookbehindSpec` in the grammar. Resolved at parse setup: kind-name
    /// strings are translated to BitSets keyed by `grammar.symbolToID`, so the
    /// evaluator runs entirely on integer IDs.
    var lookbehindByTerminalID: [Int: ResolvedLookbehindSpec] = [:]

    /// Per-parse record of every terminal commit, dual-indexed by end and
    /// start position. Each `.T`/`.TI`/`.C` arm in the main parse loop
    /// appends to both. `byEnd` powers `previousKindIDs(at:distance:)` for
    /// `++N`/`--N` lookbehind; `byStart` powers `terminalImage(startingAt:)`
    /// for diagnostic/AST readers that need the exact grammar-defined
    /// literal content at a given source position.
    var terminalCommitsByEnd: [CharPosition: [TerminalCommit]] = [:]
    var terminalCommitsByStart: [CharPosition: [TerminalCommit]] = [:]

    /// Exact source slice of the terminal that committed starting at `start`,
    /// or `nil` if no terminal started at this position. Multiple commits at
    /// the same start position (e.g. an ambiguous parse where two different
    /// terminals matched the same opening character) are resolved by
    /// returning the longest match — the grammar-authoritative span. Replaces
    /// the eager-scanner's `tokens[idx].image` lookup.
    func terminalImage(startingAt start: CharPosition) -> Substring? {
        guard let commits = terminalCommitsByStart[start], !commits.isEmpty else { return nil }
        let longestRawEnd = commits.map(\.rawEnd).max()!
        return input[start..<longestRawEnd]
    }

    // MARK: - Error reporting, captures the furthest the parse has progressed before a mismatch occurred
    var furthestMismatchIndex: CharPosition = "".startIndex
    var furthestMismatchSlot: GrammarNode!
    var furthestMismatchExpected: Set<String> = []

    // MARK: - Initialization

    init(grammar: Grammar) {
        self.grammar = grammar
    }

    // MARK: - Parse API

    /// `root` defaults to `grammar.root` (full parse); pass a `=:` non-terminal
    /// to run a sub-parse for trivia recognition. `start` defaults to
    /// `input.startIndex`; pass a `CharPosition` to seed the GLL at a different
    /// position. Yields end up in `self.yields` indexed by `node.number`;
    /// callers read accepting end positions via `yield(of: root)`.
    ///
    /// Composed of `prepareInput` (per-input setup, runs once per input) and
    /// `runGLL` (per-call state reset + GLL loop, can run many times against
    /// the same prepared input). Trivia recogniser closures use exactly this
    /// split: their sub-parser is prepared once, then `runGLL` is called per
    /// recogniser invocation — that's what keeps the per-call cost minimal.
    func parse(input: String, root: GrammarNode? = nil, start: CharPosition? = nil) {
        prepareInput(input: input, isSubParser: root != nil)
        runGLL(root: root ?? grammar.root, start: start ?? input.startIndex)
    }

    /// Per-input setup: builds the lex stack, resolves lookbehind specs,
    /// constructs sub-parsers for `=:` non-terminals, precomputes layout
    /// virtual tokens when the grammar uses them. Idempotent for repeated
    /// calls on the same `input`; the expectation is that callers (including
    /// sub-parsers) call this once per input and then `runGLL` many times
    /// against the prepared state.
    func prepareInput(input: String, isSubParser: Bool = false) {
        self.input = input
        // LCNP lex stack: `OnDemandLiteralLexer` only (Phase E Step 2d retired
        // `LegacyScannerLexAdapter`). All literals and regex terminals serve
        // from `input` directly; lookbehind (`++N`/`--N`) is enforced
        // parser-side in `tokenMatch`. `transitions`-annotated terminals lose
        // their mode-gating — documented Python regression.
        var literalSourceByID: [Int: String] = [:]
        var regexByID: [Int: Regex<Substring>] = [:]
        var triviaRegexes: [Regex<Substring>] = []
        lookbehindByTerminalID.removeAll(keepingCapacity: true)
        for (name, pat) in grammar.terminals {
            guard let id = grammar.symbolToID[name] else { continue }
            if pat.isLiteral {
                literalSourceByID[id] = pat.source
            } else if !pat.isSkip {
                // Regex terminal: answer from input directly. Any lookbehind
                // annotation is enforced at `tokenMatch` via parser state.
                regexByID[id] = pat.regex
            }
            if pat.isSkip, !isSubParser {
                // Trivia (whitespace, line comment, etc.) applies only to the
                // full parse. Sub-parsers running a `=:` body don't strip
                // outer trivia — inside a multiline comment, what would
                // otherwise be skipped whitespace IS comment content.
                triviaRegexes.append(pat.regex)
            }
            if !pat.lookbehind.isEmpty {
                lookbehindByTerminalID[id] = resolveLookbehindSpec(pat.lookbehind)
            }
        }
        // Build trivia non-terminal recognisers for each `=:` LHS in the
        // grammar. Each recogniser owns a sub-parser instance prepared on the
        // *same* input as the outer parser; the closure calls `sub.runGLL`
        // (cheap) rather than `sub.parse` (rebuilds everything). Skipped for
        // sub-parsers themselves — they'd recurse infinitely.
        var triviaRecognisers: [(CharPosition) -> CharPosition?] = []
        if !isSubParser {
            for (_, nt) in grammar.nonTerminals where nt.isTrivia {
                let sub = MessageParser(grammar: grammar)
                sub.prepareInput(input: input, isSubParser: true)
                let recogniser: (CharPosition) -> CharPosition? = { pos in
                    sub.runGLL(root: nt, start: pos)
                    let ends = sub.yield(of: nt).lazy.filter { $0.i == pos }.map(\.j)
                    return ends.max()
                }
                triviaRecognisers.append(recogniser)
            }
        }
        // Phase G: synthetic layout tokens (Python INDENT/DEDENT, etc.) are
        // resolved by `OnDemandLiteralLexer` from a precomputed source-position
        // table instead of being injected into `tokens[]`. Gated on
        // `grammar.usesInjectedLayoutTokens` so non-layout grammars allocate
        // nothing. Sub-parsers (`=:` bodies) skip the precompute — synthetic
        // tokens live at the outer parse level only.
        var virtualTokensAt: [CharPosition: [Int]] = [:]
        if grammar.usesInjectedLayoutTokens, !isSubParser,
           let indentKindID = grammar.symbolToID[">>|"],
           let dedentKindID = grammar.symbolToID["|<<"] {
            virtualTokensAt = computeVirtualLayoutTokens(
                input: input,
                indentKindID: indentKindID,
                dedentKindID: dedentKindID,
                bracketPairs: [("(", ")"), ("[", "]"), ("{", "}")]
            )
        }
        lexer = OnDemandLiteralLexer(
            input: input,
            literalSourceByID: literalSourceByID,
            regexByID: regexByID,
            triviaRegexes: triviaRegexes,
            triviaRecognisers: triviaRecognisers,
            eosID: grammar.eosID,
            virtualTokensAt: virtualTokensAt
        )
        lexCache.removeAll(keepingCapacity: true)
    }

    /// Per-call: reset GLL state, seed root cluster, run the GLL loop. Reads
    /// from the already-prepared lex stack. Multiple invocations on the same
    /// prepared input are cheap — only this routine runs per recogniser call.
    func runGLL(root: GrammarNode, start: CharPosition) {
        currentParseRoot = root
        terminalCommitsByEnd.removeAll(keepingCapacity: true)
        terminalCommitsByStart.removeAll(keepingCapacity: true)
        let origin = start
        cL = nil; cI = origin; cU = origin
        unique = []; remaining = []
        failedParses = 0; successfullParses = 0
        descriptorCount = 0; duplicateDescriptorCount = 0; suppressedDescriptorCount = 0
        crf = [:]; yieldCount = 0
        // Size the BSR yields array to the global node count (each grammar's
        // node numbers are unique in `GrammarNode.count`'s monotonic counter,
        // so this is large enough to index any node in the current grammar).
        // Reset to empty sets — cheaper than reallocating every parse since
        // `Set<BinarySpan>.removeAll(keepingCapacity:)` retains backing buffers.
        if yields.count < GrammarNode.count {
            yields = Array(repeating: [], count: GrammarNode.count)
        } else {
            for i in yields.indices { yields[i].removeAll(keepingCapacity: true) }
        }
        furthestMismatchIndex = origin
        furthestMismatchSlot = currentParseRoot
        furthestMismatchExpected = []

        // Set up root cluster (root may be a `=:` non-terminal for a sub-parse)
        let rootNode = currentParseRoot!
        let rootCluster = ParseCluster(slot: rootNode, index: origin)
        crf[ParsePosition(slot: rootNode, index: origin)] = rootCluster

        // Seed initial descriptors (Paper: ntAdd for start symbol)
        addDecscriptorsForAlternates(X: rootNode, k: origin, i: origin)

        // Run GLL algorithm
        var progressCounter = 0
        let progressInterval = 10_000
        nextDescriptor: while getDescriptor() {
            progressCounter += 1
            if progressCounter % progressInterval == 0 {
//                print("  progress: \(progressCounter) descriptors processed, token \(cI.tokenIndex)/\(totalTokens), pending \(remaining.count), crf \(crf.count)")
            }

            while true {

                trace = false
                trace("slot: \(String(format: "%2d", cL.number)) \(cL.ebnfDot()) first \(cL.first) follow \(cL.follow) at: \(input.linePosition(of: cI))")

                switch cL.kind {
                case .EPS:
                    addYield(L: cL, i: cU, k: cI, j: cI)
                    cL = cL.seq!
                case .B:
                    if boundaryMatches(cL.name, at: cI) {
                        addYield(L: cL, i: cU, k: cI, j: cI)
                        cL = cL.seq!
                    } else {
                        recordMismatch(expected: cL.name)
                        continue nextDescriptor
                    }
                case .T, .TI, .C:
                    let matches = tokenMatch()
                    if matches.isEmpty {
                        recordMismatch(expected: cL.name)
                        continue nextDescriptor
                    }
                    if matches.count == 1 {
                        // Single match — continue in place (hot path).
                        let m = matches[0]
                        addYield(L: cL, i: cU, k: cI, j: m.end)
                        let commit = TerminalCommit(kindID: cL.nameID, start: cI, rawEnd: m.rawEnd)
                        terminalCommitsByEnd[m.end, default: []].append(commit)
                        terminalCommitsByStart[cI, default: []].append(commit)
                        cI = m.end
                        cL = cL.seq!
                    } else {
                        // Multi-match fork: one continuation descriptor per
                        // distinct end position. Doesn't fire today (lex sources
                        // produce at most one distinct end per terminal at a
                        // position), but lets the parse loop handle variable-
                        // length matches when Phase C/E lexers start returning
                        // multiple ends.
                        for m in matches {
                            addYield(L: cL, i: cU, k: cI, j: m.end)
                            let commit = TerminalCommit(kindID: cL.nameID, start: cI, rawEnd: m.rawEnd)
                            terminalCommitsByEnd[m.end, default: []].append(commit)
                            terminalCommitsByStart[cI, default: []].append(commit)
                            addDescriptor(L: cL.seq!, k: cU, i: m.end)
                        }
                        continue nextDescriptor
                    }
                case .N:
                    call()
                    continue nextDescriptor
                case .ALT:
                    trace("ERROR: Unexpected .ALT node in cL")
                    trace("  cL.number: \(cL.number)")
                    trace("  cL.name: '\(cL.name)'")
                    trace("  cL.seq: \(String(describing: cL.seq))")
                    trace("  cL.alt: \(String(describing: cL.alt))")
                    fatalError(#function + ": ALT should not happen here")
                case .DO, .POS:
                    bracketCall(bracket: cL)
                    continue nextDescriptor
                case .OPT, .KLN:
                    // OPT/KLN: also offer skip-past-bracket path (they're nullable)
                    if testSelect(slot: cL.seq!, bracket: cL) {
                        addDescriptor(L: cL.seq!, k: cU, i: cI)
                        addYield(L: cL, i: cU, k: cI, j: cI)  // empty bracket BSR
                    }
                    bracketCall(bracket: cL)
                    continue nextDescriptor
                case .END:
                    // the seq link of an END node always points back to a starting bracket node (N, DO, OPT, POS, KLN)
                    let bracket = cL.seq!

                    switch bracket.kind {
                    case .N:
                        if let seq = bracket.seq {
                            // the bracket is a RHS nonterminal
                            cL = seq
                        } else {
                            // the bracket is a LHS nonterminal
                            if followCheck(bracket: bracket) {
                                addYield(L: bracket, i: cU, k: cU, j: cI)
                                rtn(X: bracket)
                            } else {
                                failedParses += 1
                                if cI > furthestMismatchIndex {
                                    furthestMismatchIndex = cI
                                    furthestMismatchSlot = cL
                                    furthestMismatchExpected = bracket.follow
                                } else if cI == furthestMismatchIndex {
                                    furthestMismatchExpected.formUnion(bracket.follow)
                                }
                            }
                            continue nextDescriptor
                        }
                    case .DO, .OPT, .KLN, .POS:
                        bracketRtn(bracket: bracket)
                        continue nextDescriptor
                   default:
                        fatalError("\(#function) unexpected bracket kind at END seq link \(bracket.kind)")
                    }
                case .EOS:
                    break
                }
            }
        }

        // For a full parse this counts root yields covering [origin..input.endIndex].
        // For a sub-parse (root != grammar.root), the caller will read yield(of: root)
        // directly to discover accepting end positions.
        successfullParses = yield(of: currentParseRoot).filter { y in y.i == origin && y.j == input.endIndex }.count
        trace = false
        // Skip the diagnostic prints for sub-parses (`=:` recogniser runs);
        // they fire at every trivia-skip position and drown out the console.
        guard root === grammar.root else { return }
        print(
            "\nmatched:", successfullParses,
            "  failed:", failedParses,
            "  crf size:", crf.count,
            "  descriptors:", descriptorCount,
            "  duplicateDescriptors:", duplicateDescriptorCount,
            "  suppressedDescriptors:", suppressedDescriptorCount
        )
        if successfullParses == 0 {
            let position = input.linePosition(of: furthestMismatchIndex)
            let foundSnippet = sourceSnippet(at: furthestMismatchIndex)
            let expected = furthestMismatchExpected.sorted().joined(separator: ", ")
            print("""
                no parse found at \(position)
                found content: '\(foundSnippet)'
                grammar context: \(furthestMismatchSlot.ebnfDot())
                expected: \(expected)
                """)
        }
    }

    // MARK: - Internal helpers

    func recordMismatch(expected: String) {
        failedParses += 1
        if cI > furthestMismatchIndex {
            furthestMismatchIndex = cI
            furthestMismatchSlot = cL
            furthestMismatchExpected = [expected]
        } else if cI == furthestMismatchIndex {
            furthestMismatchExpected.insert(expected)
        }
    }

    /// Short slice of `input` starting at `pos` for diagnostic output when
    /// the parse failed at `pos`. The parser never committed a terminal
    /// there (that's why the parse failed), so there's no grammar-authoritative
    /// boundary to use — fall back to a Unicode-whitespace stop or a 30-char
    /// cap. This heuristic is intentionally limited to the failure-report
    /// path; everything that runs on a *successful* parse should use
    /// `terminalImage(startingAt:)` for exact boundaries.
    private func sourceSnippet(at pos: CharPosition) -> Substring {
        guard pos < input.endIndex else { return "" }
        var end = pos
        var count = 0
        while end < input.endIndex, count < 30 {
            let ch = input[end]
            if ch.isWhitespace || ch.isNewline { break }
            end = input.index(after: end)
            count += 1
        }
        if end == pos, end < input.endIndex { end = input.index(after: end) }
        return input[pos..<end]
    }

    /// Evaluate a boundary operator at a parser cursor position.
    /// Boundaries are predicates over the *trivia gap* between the previous
    /// consumed terminal's raw end and the current cursor — i.e. they ask
    /// "what (if anything) did `skipTrivia` skip to get the cursor here?".
    ///
    /// Each commit in `terminalCommitsByEnd[position]` carries the literal/
    /// regex end position *before* trivia skipping. The slice
    /// `input[rawEnd..<position]` is exactly the trivia text the lexer
    /// skipped, and the boundary semantics reduce to predicates on that slice.
    /// Multi-history GLL can produce multiple commits at the same position;
    /// the answer must be consistent across them. We require unanimity:
    ///   - `<s>`/`<n>` (require trivia) → true iff *every* commit has trivia
    ///     of the required shape
    ///   - `>s<`/`>n<` (require none)   → true iff *every* commit has no
    ///     trivia of the forbidden shape
    ///
    /// End-of-input rule for `<n>`: when `position == input.endIndex`, treat
    /// the boundary as satisfied unconditionally. Languages that use `<n>` as
    /// a statement terminator typically also accept end-of-file in lieu of a
    /// final newline (Python, JS ASI, many others); CPython's tokenizer
    /// emits a synthetic NEWLINE before EOF for exactly this reason. The rule
    /// holds for any grammar — `<n>` at EOS never has anything legitimate to
    /// follow.
    func boundaryMatches(_ boundary: String, at position: CharPosition) -> Bool {
        if boundary == "<n>", position == input.endIndex { return true }
        let commits = terminalCommitsByEnd[position] ?? []
        // No previous commit at this position — happens at the very start of
        // a (sub-)parse before any terminal has been consumed. Treat the
        // boundary as failing; in well-formed grammars `<s>` doesn't appear
        // before any terminal has been consumed.
        guard !commits.isEmpty else { return false }
        for commit in commits {
            let gap = input[commit.rawEnd..<position]
            let satisfied: Bool
            switch boundary {
            case "<s>": satisfied = !gap.isEmpty
            case ">s<": satisfied = gap.isEmpty
            case "<n>": satisfied = gap.contains(where: isLineBreak)
            case ">n<": satisfied = !gap.contains(where: isLineBreak)
            default: fatalError("\(#function): unexpected boundary \(boundary)")
            }
            if !satisfied { return false }
        }
        return true
    }

    @inline(__always)
    private func isLineBreak(_ ch: Character) -> Bool {
        ch == "\n" || ch == "\r"
    }

    /// Test whether the current token is in the selection set for a grammar slot.
    /// Returns true if some terminal that LCNP can lex at `cI` is in
    ///   FIRST(slot)  ∨  (ε ∈ FIRST(slot) ∧ FOLLOW(bracket))
    ///
    /// Phase D Step 3: the Schrödinger `---(…)` exclude semantic is now a
    /// per-end LCNP filter — for each candidate terminal in the predict set,
    /// suppress its matches whose end coincides with an excluded terminal's
    /// match at this position. Retires the `tokens[idx].kindID` head lookup
    /// that the eager scanner used to canonicalise same-span ambiguity.
    func testSelect(slot: GrammarNode, bracket: GrammarNode) -> Bool {
        func anyTerminalMatches(in bs: BitSet) -> Bool {
            for kID in bs {
                if kID == grammar.epsilonID { continue }
                let matches = cachedLex(at: cI, terminalID: kID)
                if matches.isEmpty { continue }
                if slot.excludeBS.isEmpty { return true }
                let survives = matches.contains { m in
                    for eID in slot.excludeBS where eID != kID && eID != grammar.epsilonID {
                        for em in cachedLex(at: cI, terminalID: eID) where em.end == m.end {
                            return false
                        }
                    }
                    return true
                }
                if survives { return true }
            }
            return false
        }

        if anyTerminalMatches(in: slot.firstBS) { return true }
        if slot.firstBS.contains(grammar.epsilonID),
           anyTerminalMatches(in: bracket.followBS) { return true }
        return false
    }

    /// Match the current terminal against the input at cI.
    ///
    /// Asks the memoizing lex cache for matches of `cL.nameID` at `cI`, then
    /// applies the two parser-level filters the LCNP API doesn't see:
    ///   - `---(…)` exclusion: if the head token's kindID is in `cL.excludeBS`,
    ///     suppress matches whose terminalID differs from the head's kindID.
    ///   - `>>1(…)` followAhead: when set, the NEXT token must satisfy the
    ///     followAhead bitset (or be EOS).
    ///
    /// Phase C Step 2: returns the full set of distinct matches so the main
    /// parse loop can fork descriptors over them. Each match carries both
    /// `end` (cursor after trivia skip) and `rawEnd` (literal end, before
    /// trivia skip) — the parse loop logs `rawEnd` into `terminalCommitsByEnd`
    /// so boundary checks (`<s>`/`>s<`/`<n>`/`>n<`) can answer trivia-gap
    /// questions without a scanner-produced token stream.
    func tokenMatch() -> [LexMatch] {
        var matches = cachedLex(at: cI, terminalID: cL.nameID)
        guard !matches.isEmpty else { return [] }

        // Lookbehind: `++N(…)` / `--N(…)` — evaluate against parser-side
        // commit history (Phase E Step 1). Filters out matches whose context
        // doesn't satisfy the grammar's lookbehind annotation. Cheap when the
        // terminal has no lookbehind (most do not).
        if let lookbehind = lookbehindByTerminalID[cL.nameID],
           !lookbehindAllows(lookbehind, at: cI) {
            return []
        }

        // Exclude: `---(…)` — for each candidate end, if any excluded terminal
        // also lexes at this position with the same end, suppress the match.
        // Phase D Step 2: per-end LCNP query, retiring the `tokens[idx].kindID`
        // head lookup that the eager scanner used to canonicalise same-span
        // ambiguity. Relies on the lexer's keyword-boundary guard so e.g.
        // literal "let" doesn't over-match "letx".
        if !cL.excludeBS.isEmpty {
            matches = matches.filter { m in
                for eID in cL.excludeBS where eID != cL.nameID && eID != grammar.epsilonID {
                    for em in cachedLex(at: cI, terminalID: eID) where em.end == m.end {
                        return false
                    }
                }
                return true
            }
            if matches.isEmpty { return [] }
        }

        // Predict-set lookahead — Phase F's `lexLKH`. For each candidate end,
        // some terminal that can legally follow this slot must lex at the end
        // (or we're at EOS / past the input). Prunes matches whose end has no
        // viable continuation, saving the descriptor that would otherwise die
        // one slot later.
        //
        // The predict set is the grammar-computed `cL.followBS` ("FIRST of the
        // suffix after this slot, with epsilon look-through") — except when
        // the grammar author wrote a manual `>>1(…)` annotation, in which
        // case `cL.followAheadBS` is a stricter override and wins. Skip the
        // filter when:
        //   - the predict set is empty (no follow info), or
        //   - the predict set contains ε (suffix fully nullable — anything
        //     can be a valid end including end-of-input).
        let predictBS = cL.followAheadBS.isEmpty ? cL.followBS : cL.followAheadBS
        if !predictBS.isEmpty && !predictBS.contains(grammar.epsilonID) {
            matches = matches.filter { m in
                // Past the end of input acts as EOS — always allowed.
                if m.end >= input.endIndex { return true }
                for fID in predictBS where fID != grammar.epsilonID {
                    if !cachedLex(at: m.end, terminalID: fID).isEmpty { return true }
                }
                return false
            }
            if matches.isEmpty { return [] }
        }

        // Distinct end positions, first-seen order for determinism. Today the
        // lex sources mostly return one match (or duplicates with the same end
        // via Schrödinger duals); the deduped vector keeps the API ready for
        // variable-length regex matches without changing behaviour now.
        var seen: Set<CharPosition> = []
        var result: [LexMatch] = []
        result.reserveCapacity(matches.count)
        for m in matches where seen.insert(m.end).inserted {
            result.append(m)
        }
        return result
    }

    /// Test whether some terminal in the bracket's FOLLOW set can be lexed at `cI`.
    /// Phase B Step 3: per-terminal LCNP iteration through the lex cache.
    func followCheck(bracket: GrammarNode) -> Bool {
        for fID in bracket.followBS {
            if fID == grammar.epsilonID { continue }
            if !cachedLex(at: cI, terminalID: fID).isEmpty { return true }
        }
        return false
    }

    /// Test whether a continuation grammar slot can proceed with input at the
    /// given position. Used to suppress descriptors in rtn/bracketRtn/pop replay
    /// when the continuation cannot match. Conservative: returns true for
    /// nullable, END, EPS to avoid false rejections.
    func continuationViable(continuation: GrammarNode, at position: CharPosition) -> Bool {
        // Structural nodes that don't consume input are always viable
        if continuation.kind == .END || continuation.kind == .EPS { return true }
        // Nullable continuation: can't determine without enclosing FOLLOW context
        if continuation.firstBS.contains(grammar.epsilonID) { return true }
        // Per-terminal LCNP iteration over FIRST(continuation)
        for kID in continuation.firstBS {
            if kID == grammar.epsilonID { continue }
            if !cachedLex(at: position, terminalID: kID).isEmpty { return true }
        }
        return false
    }

}
