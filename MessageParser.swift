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

/// One terminal commit recorded by the parse loop's `.T`/`.TI`/`.C` arm.
/// Carries the four positions that fully describe the commit's span in the
/// source (modeled on swift-syntax's per-token position quartet):
///
///   - `triviaStart` — start of leading trivia (= previous commit's
///                     `triviaEnd`, or parse origin for the first commit)
///   - `start`       — content start (after leading trivia)
///   - `end`         — content end (before trailing trivia)
///   - `triviaEnd`   — past trailing trivia; the parser cursor advances here
///                     and the next commit's `triviaStart` equals this
///
/// Image of the terminal:   `input[start ..< end]`
/// Leading trivia text:     `input[triviaStart ..< start]`
/// Trailing trivia text:    `input[end ..< triviaEnd]`
///
/// Used by `terminalImage(startingAt:)`, `previousKindIDs(at:distance:)`
/// (`++N`/`--N` lookbehind), and `boundaryMatches` (`<s>`/`>s<`/`<n>`/`>n<`).
struct TerminalCommit {
    let terminalID: Int
    let triviaStart: CharPosition
    let start: CharPosition
    let end: CharPosition
    let triviaEnd: CharPosition
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

    /// True when this parser instance is a recogniser sub-parser (a `=:` trivia or `=|` lexical
    /// nonterminal, prepared with `isSubParser: true`). Such a root is a RECOGNISER: it may
    /// complete at any position (the outer parser supplies the "next token" context), so its
    /// root completion is not gated on FOLLOW/EOF. See `followCheck`.
    var isSubParser = false

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

    /// `BitSet` of terminal kindIDs whose commit ends exactly at `pos`.
    private func terminalKindIDs(endingAt pos: CharPosition) -> BitSet {
        guard let idxs = commitsByEnd[pos] else { return BitSet() }
        var bs = BitSet()
        for i in idxs { bs.insert(commits[i].terminalID) }
        return bs
    }

    /// "N visible terminals back from `pos`" expressed over the parser's
    /// commit log. `distance == 1` → kindIDs committed ending at `pos`;
    /// `distance == 2` → kindIDs committed ending at the `triviaStart` of any
    /// commit ending at `pos` (since `commit.triviaStart` is the previous
    /// commit's `end` in steady state); etc. Walks set-unions when multiple
    /// histories arrive at the same position.
    func previousKindIDs(at pos: CharPosition, distance: Int) -> BitSet {
        var endPositions: Set<CharPosition> = [pos]
        for _ in 1..<distance {
            var next: Set<CharPosition> = []
            for p in endPositions {
                if let idxs = commitsByEnd[p] {
                    for i in idxs { next.insert(commits[i].triviaStart) }
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

    /// Per-parse flat log of every terminal commit. Each `.T`/`.TI`/`.C` arm
    /// in the main parse loop appends to `commits` and indexes the new entry
    /// in both `commitsByStart` (content start → commit indices) and
    /// `commitsByEnd` (content end → commit indices). Two indices into one
    /// store keep the commit data single-sourced; the indices are pointers,
    /// not copies. `commitsByEnd` powers `previousKindIDs(at:distance:)` for
    /// `++N`/`--N` lookbehind; `commitsByStart` powers
    /// `terminalImage(startingAt:)` for diagnostic / AST readers.
    var commits: [TerminalCommit] = []
    var commitsByStart: [CharPosition: [Int]] = [:]
    var commitsByEnd: [CharPosition: [Int]] = [:]

    /// Exact source slice of the terminal that committed starting at the
    /// given position, or `nil` if no terminal committed there. The argument
    /// is the BSR-aligned start (= parser cursor at lex time = `triviaStart`
    /// of the commit), matching what AST/diagram traversal hands out. The
    /// returned slice spans `[triviaStart, contentEnd)` — i.e. leading trivia
    /// plus content, but no trailing trivia — preserving the pre-refactor
    /// contract. Multiple commits at the same start (ambiguous parses) are
    /// resolved by returning the longest. Replaces the eager-scanner's
    /// `tokens[idx].image` lookup.
    func terminalImage(startingAt triviaStart: CharPosition) -> Substring? {
        guard let idxs = commitsByStart[triviaStart], !idxs.isEmpty else { return nil }
        let longestEnd = idxs.map { commits[$0].end }.max()!
        return input[triviaStart..<longestEnd]
    }

    @inline(__always)
    func recordCommit(terminalID: Int, triviaStart: CharPosition, start: CharPosition, end: CharPosition, triviaEnd: CharPosition) {
        let idx = commits.count
        commits.append(TerminalCommit(terminalID: terminalID, triviaStart: triviaStart, start: start, end: end, triviaEnd: triviaEnd))
        // Index by `triviaStart` — the position the parser cursor was at when
        // this commit started. This matches the BSR yield's `k` (= cI at lex
        // time), so AST/diagram consumers that get a position from the BSR
        // can look up the commit directly. `commitsByEnd` is keyed by
        // `triviaEnd` — the position the parser cursor advances to.
        commitsByStart[triviaStart, default: []].append(idx)
        commitsByEnd[triviaEnd, default: []].append(idx)
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
        self.isSubParser = isSubParser
        self.input = input
        // LCNP lex stack: `OnDemandLiteralLexer` only (Phase E Step 2d retired
        // `LegacyScannerLexAdapter`). All literals and regex terminals serve
        // from `input` directly; lookbehind (`++N`/`--N`) is enforced
        // parser-side in `tokenMatch`. `transitions`-annotated terminals lose
        // their mode-gating — documented Python regression.
        var literalSourceByID: [Int: String] = [:]
        var regexByID: [Int: Regex<AnyRegexOutput>] = [:]
        var triviaRegexes: [Regex<AnyRegexOutput>] = []
        lookbehindByTerminalID.removeAll(keepingCapacity: true)
        for (name, pat) in grammar.terminals {
            guard let id = grammar.symbolToID[name] else { continue }
            if pat.isLexicalToken {
                // `=|` lexical nonterminal — match computed by a GLL sub-parse below, not a
                // regex/literal. Skip the regex/literal registration.
                continue
            }
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
        // Lexical-nonterminal recognisers for each `=|` LHS. Same sub-parse machinery as the
        // `=:` trivia recognisers, but keyed by the terminal kind ID and used by the lexer to
        // emit ONE token spanning the sub-parse's longest accept from `pos`. Skipped for
        // sub-parsers (would recurse). The sub-parser strips no trivia (isSubParser), so the
        // body is matched character-tight — right for whitespace-sensitive constructs like regex.
        var lexicalTokenRecognisers: [Int: (CharPosition) -> CharPosition?] = [:]
        if !isSubParser {
            for (name, nt) in grammar.nonTerminals where nt.isLexicalToken {
                guard let id = grammar.symbolToID[name] else { continue }
                let sub = MessageParser(grammar: grammar)
                sub.prepareInput(input: input, isSubParser: true)
                lexicalTokenRecognisers[id] = { pos in
                    sub.runGLL(root: nt, start: pos)
                    return sub.yield(of: nt).lazy.filter { $0.i == pos }.map(\.j).max()
                }
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
        // Maximal-munch default (longest-across; see TODO #0). The grammar
        // declares its lexical classes with `@lexicalClass` (identifier,
        // operator, …); a literal is suppressed when a class terminal has a
        // strictly longer match at the same start. Collect the class terminal
        // IDs; the runtime prefix-match lives in `OnDemandLiteralLexer.lex`.
        var lexicalClassIDs: [Int] = []
        var splitBeforeByID: [Int: Character] = [:]
        for (name, pat) in grammar.terminals {
            guard let id = grammar.symbolToID[name] else { continue }
            if pat.isLexicalClass { lexicalClassIDs.append(id) }
            if let sc = pat.splitBefore { splitBeforeByID[id] = sc }
        }
        lexer = OnDemandLiteralLexer(
            input: input,
            literalSourceByID: literalSourceByID,
            regexByID: regexByID,
            splitBeforeByID: splitBeforeByID,
            lexicalClassIDs: lexicalClassIDs,
            triviaRegexes: triviaRegexes,
            triviaRecognisers: triviaRecognisers,
            lexicalTokenRecognisers: lexicalTokenRecognisers,
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
        commits.removeAll(keepingCapacity: true)
        commitsByStart.removeAll(keepingCapacity: true)
        commitsByEnd.removeAll(keepingCapacity: true)
        let origin = start
        cL = nil; cI = origin; cU = origin
        unique = []; remaining = []
        failedParses = 0; successfullParses = 0
        descriptorCount = 0; duplicateDescriptorCount = 0; suppressedDescriptorCount = 0
        crf = [:]; yieldCount = 0
        // Size the BSR yields array to THIS grammar's node count. Node numbers
        // are compact per grammar ([0, nodeCount)), assigned by a per-load
        // `GrammarBuild` counter, so this array is exactly large enough to index
        // any node in `grammar` and never grows with the number of grammars loaded.
        // Reset to empty sets — cheaper than reallocating every parse since
        // `Set<BinarySpan>.removeAll(keepingCapacity:)` retains backing buffers.
        if yields.count < grammar.nodeCount {
            yields = Array(repeating: [], count: grammar.nodeCount)
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

//                trace = false
//                trace("slot: \(String(format: "%2d", cL.number)) \(cL.ebnfDot()) first \(cL.first) follow \(cL.follow) at: \(input.linePosition(of: cI))")

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
                        addYield(L: cL, i: cU, k: cI, j: m.triviaEnd)
                        recordCommit(terminalID: cL.nameID, triviaStart: cI, start: m.start, end: m.end, triviaEnd: m.triviaEnd)
                        cI = m.triviaEnd
                        cL = cL.seq!
                    } else {
                        // Multi-match fork: one continuation descriptor per
                        // distinct end position. Doesn't fire today (lex sources
                        // produce at most one distinct end per terminal at a
                        // position), but lets the parse loop handle variable-
                        // length matches when Phase C/E lexers start returning
                        // multiple ends.
                        for m in matches {
                            addYield(L: cL, i: cU, k: cI, j: m.triviaEnd)
                            recordCommit(terminalID: cL.nameID, triviaStart: cI, start: m.start, end: m.end, triviaEnd: m.triviaEnd)
                            addDescriptor(L: cL.seq!, k: cU, i: m.triviaEnd)
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
                    // OPT/KLN: also offer skip-past-bracket path (they're nullable).
                    // Use the same viability predicate as return replay so an optional
                    // at the end of a production can skip to END.
                    if continuationViable(continuation: cL.seq!, at: cI) {
                        addDescriptor(L: cL.seq!, k: cU, i: cI)
                        addYield(L: cL, i: cU, k: cI, j: cI)  // empty bracket BSR
                    } else {
                        recordSuppressedContinuation(cL.seq!, at: cI)
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
        // A yield ending at `y.j` also counts when only trivia separates `y.j` from
        // `input.endIndex`: ask the lexer for EOS at `y.j`, which internally trivia-skips
        // and returns a match iff the scan reaches `input.endIndex`. This makes
        // comment-only / trailing-comment inputs succeed against rules like
        // `topLevelDeclaration = statements?`.
        successfullParses = yield(of: currentParseRoot).filter { y in
            guard y.i == origin else { return false }
            if y.j == input.endIndex { return true }
            return !lexer.lex(at: y.j, terminalID: grammar.eosID).isEmpty
        }.count
//        trace = false
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
            explainNoMatch(slot: furthestMismatchSlot, at: furthestMismatchIndex)
            dumpRecentCommits()
        }
    }

    /// Re-run lex + the `tokenMatch` filters for the failed terminal slot and
    /// print which step zeroed out the match list. This catches diagnostics
    /// like "found '(' / expected '('" where raw lex succeeded, but parser-side
    /// lookbehind, exclusion, or predict-set pruning rejected the branch.
    func explainNoMatch(slot: GrammarNode, at pos: CharPosition) {
        guard [.T, .TI, .C].contains(slot.kind) else { return }
        let id = slot.nameID!
        let posStr = input.linePosition(of: pos)
        print("Match explanation for '\(slot.name)' (id=\(id)) at \(posStr):")

        let raw = cachedLex(at: pos, terminalID: id)
        print("  lex: \(raw.count) match(es)")
        for m in raw {
            print("    start=\(input.linePosition(of: m.start)) end=\(input.linePosition(of: m.end)) triviaEnd=\(input.linePosition(of: m.triviaEnd)) image='\(input[m.start..<m.end])'")
        }
        if raw.isEmpty {
            print("  -> lex returned nothing; input does not match this terminal here")
            return
        }

        var survivors = raw
        if let lookbehind = lookbehindByTerminalID[id] {
            let allowed = lookbehindAllows(lookbehind, at: pos)
            print("  after lookbehind: \(allowed ? survivors.count : 0)  (allowed=\(allowed))")
            if !allowed { return }
        } else {
            print("  after lookbehind: \(survivors.count)  (no lookbehind on this terminal)")
        }

        if !slot.excludeBS.isEmpty {
            survivors = survivors.filter { m in
                for eID in slot.excludeBS where eID != id && eID != grammar.epsilonID {
                    for em in cachedLex(at: pos, terminalID: eID) where em.triviaEnd == m.triviaEnd {
                        return false
                    }
                }
                return true
            }
            print("  after exclude:    \(survivors.count)")
            if survivors.isEmpty { return }
        } else {
            print("  after exclude:    \(survivors.count)  (no exclude on this terminal)")
        }

        let predictBS = slot.followAheadBS.isEmpty ? slot.followBS : slot.followAheadBS
        let predictKind = slot.followAheadBS.isEmpty ? "followBS" : "followAheadBS (>>1)"
        if !predictBS.isEmpty && !predictBS.contains(grammar.epsilonID) {
            let idToName = Dictionary(uniqueKeysWithValues: grammar.symbolToID.map { ($0.value, $0.key) })
            let names = predictBS.compactMap { idToName[$0] }.sorted()
            print("  predict (\(predictKind)): \(names.joined(separator: ","))")
            survivors = survivors.filter { m in
                if m.triviaEnd >= input.endIndex { return true }
                for fID in predictBS where fID != grammar.epsilonID {
                    if !cachedLex(at: m.triviaEnd, terminalID: fID).isEmpty { return true }
                }
                return false
            }
            print("  after predict:    \(survivors.count)")
            if survivors.isEmpty {
                let triedAt = raw.first.map { input.linePosition(of: $0.triviaEnd) } ?? "?"
                let next = raw.first.map { sourceSnippet(at: $0.triviaEnd) } ?? ""
                print("    -> nothing in predict set lexes at \(triedAt); next content is '\(next)'")
            }
        } else {
            print("  predict: skipped (empty or nullable)")
        }

        if !survivors.isEmpty {
            print("  -> terminal survives tokenMatch filters; failure is probably in a later slot or nonterminal return")
        }
    }

//    /// Convenience probe for interactive debugging. Prefer the slot-based
//    /// overload in parser diagnostics because exclude/follow filters are
//    /// position-specific in the grammar graph.
//    func explainNoMatch(terminalName: String, at pos: CharPosition) {
//        guard let slot = findTerminalSlot(named: terminalName, in: grammar.root) else {
//            print("explainNoMatch: terminal '\(terminalName)' not found in grammar")
//            return
//        }
//        explainNoMatch(slot: slot, at: pos)
//    }
//
    private func findTerminalSlot(named name: String, in root: GrammarNode) -> GrammarNode? {
        var visited: Set<ObjectIdentifier> = []

        func visit(_ node: GrammarNode?) -> GrammarNode? {
            guard let node else { return nil }
            let oid = ObjectIdentifier(node)
            guard visited.insert(oid).inserted else { return nil }
            if [.T, .TI, .C].contains(node.kind), node.name == name {
                return node
            }
            if let found = visit(node.seq) { return found }
            if let found = visit(node.alt) { return found }
            return nil
        }

        return visit(root)
    }

    /// Print the last `count` terminal commits in append order. Each line
    /// shows source position, terminal ID, terminal name, and the image
    /// slice (no surrounding trivia). Intended for failure diagnostics —
    /// gives a quick view of what the parser most recently consumed before
    /// getting stuck.
    func dumpRecentCommits(_ count: Int = 10) {
        let start = max(0, commits.count - count)
        guard start < commits.count else {
            print("Recent commits: (none — parse failed before committing any terminal)")
            return
        }
        let idToName = Dictionary(uniqueKeysWithValues: grammar.symbolToID.map { ($0.value, $0.key) })
        print("Recent \(commits.count - start) of \(commits.count) terminal commits:")
        for c in commits[start...] {
            let image = input[c.start..<c.end]
            let pos = input.linePosition(of: c.start)
            let name = idToName[c.terminalID] ?? "?"
            print("  \(pos)  id=\(c.terminalID) '\(name)'  image='\(image)'")
        }
    }

    // MARK: - Internal helpers

    func recordMismatch(expected: String) {
        recordMismatch(expected: [expected])
    }

    func recordMismatch(expected: Set<String>) {
        guard let slot = cL else { return }
        recordMismatch(expected: expected, at: cI, slot: slot)
    }

    func recordSuppressedContinuation(_ continuation: GrammarNode, at position: CharPosition) {
        recordMismatch(expected: continuation.first, at: position, slot: continuation)
    }

    func recordMismatch(expected: Set<String>, at position: CharPosition, slot: GrammarNode) {
        let expected = expected.subtracting([""])
        guard !expected.isEmpty else { return }
        failedParses += 1
        if position > furthestMismatchIndex {
            furthestMismatchIndex = position
            furthestMismatchSlot = slot
            furthestMismatchExpected = expected
        } else if position == furthestMismatchIndex {
            furthestMismatchExpected.formUnion(expected)
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
    /// committed terminal's content end and the current cursor — i.e. they
    /// ask "what (if anything) did `skipTrivia` skip to get the cursor here?".
    ///
    /// Each commit in `commitsByEnd[position]` carries `end` (literal/regex
    /// end before trailing-trivia skipping). The slice
    /// `input[end..<position]` is exactly the trivia text the lexer skipped,
    /// and the boundary semantics reduce to predicates on that slice. Multi-history GLL can produce multiple commits at the same
    /// position; the answer must be consistent across them. We require
    /// unanimity:
    ///   - `<s>`/`<n>` (require trivia) → true iff every commit has trivia
    ///     of the required shape
    ///   - `>s<`/`>n<` (require none)   → true iff every commit has no trivia
    ///     of the forbidden shape
    ///
    /// End-of-input rule for `<n>`: when `position == input.endIndex`, treat
    /// the boundary as satisfied unconditionally — languages that use `<n>`
    /// as a statement terminator accept end-of-file in lieu of a final
    /// newline.
    func boundaryMatches(_ boundary: String, at position: CharPosition) -> Bool {
        if boundary == "<n>", position == input.endIndex { return true }
        guard let idxs = commitsByEnd[position] else { return false }
        for i in idxs {
            let c = commits[i]
            let gap = input[c.end..<position]
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
                        for em in cachedLex(at: cI, terminalID: eID) where em.triviaEnd == m.triviaEnd {
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
    /// parse loop can fork descriptors over them. Each match carries `start`
    /// (content start after leading-trivia skip), `end` (content end), and
    /// `triviaEnd` (post trailing-trivia, where the parser cursor advances).
    /// The parse loop records all of these in the commit log so boundary
    /// checks (`<s>`/`>s<`/`<n>`/`>n<`) can answer trivia-gap questions and
    /// image extraction can recover the exact source slice.
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
                    for em in cachedLex(at: cI, terminalID: eID) where em.triviaEnd == m.triviaEnd {
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
                if m.triviaEnd >= input.endIndex { return true }
                for fID in predictBS where fID != grammar.epsilonID {
                    if !cachedLex(at: m.triviaEnd, terminalID: fID).isEmpty { return true }
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
        for m in matches where seen.insert(m.triviaEnd).inserted {
            result.append(m)
        }
        return result
    }

    /// Test whether some terminal in the bracket's FOLLOW set can be lexed at `cI`.
    /// Phase B Step 3: per-terminal LCNP iteration through the lex cache.
    func followCheck(bracket: GrammarNode) -> Bool {
        // A standalone sub-parse root (e.g. a `=:` trivia recogniser like
        // `multilineComment`) may legitimately complete at end-of-input — there is
        // no "next token" requirement for a recogniser invoked by `skipTrivia`.
        // Such non-terminals aren't referenced in any production, so their FOLLOW
        // set never received `○` (EOS); without this allowance a comment whose
        // closing `*/` lands exactly at EOF would fail to yield. Mirrors the EOF
        // allowance in `boundaryMatches` and the parse-success criterion. The main
        // parse root already carries `○` in its follow, so it's unaffected.
        // A recogniser sub-parse root (a `=:`/`=|` nonterminal) may complete at ANY position:
        // it is a lexical recogniser and the OUTER parser supplies the following context. A
        // lexical-token recogniser (`=|`) whose match ends mid-input (e.g. a `/regex/` followed
        // by `.member`) would otherwise never yield, because its FOLLOW is empty (no productions
        // reference it — they resolve to a terminal). The main parse root keeps the FOLLOW/EOF gate.
        if bracket === currentParseRoot && (isSubParser || cI == input.endIndex) { return true }
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
