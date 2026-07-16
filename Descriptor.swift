//
//  Descriptor.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

// Paper: descriptor = (L, k, i) — grammar slot, cluster index, input index
import OSLog
import Foundation
import BitCollections

// MARK: - LCNP source-position model
//
// Per "Multi-Lex Adoption Design 2.md". Positions everywhere (BSR/CRF/
// Descriptor/Oracle) are `String.Index` into the parser's input. Lex queries
// are answered on-demand by `OnDemandLiteralLexer`.

/// Character index into the parser's input string.
/// `String.Index` for the initial implementation — a later perf pass may swap
/// to an interned integer if descriptor pressure justifies the complexity.
typealias CharPosition = String.Index

/// One terminal match returned by the lexer.
/// Empty result from `lex` means the terminal does not match at that position.
///
/// Carries the three positions every consumer needs (mirrors swift-syntax's
/// `positionAfterSkippingLeadingTrivia` / `endPositionBeforeTrailingTrivia`
/// / `endPosition` — the fourth, "start of leading trivia", is just the `pos`
/// argument the caller passed in):
///
///   - `start`      — content start (after leading-trivia skip)
///   - `end`        — content end (before trailing-trivia skip)
///   - `triviaEnd`  — cursor position after trailing-trivia skip; the parser
///                    advances `cI` to this position so subsequent lex calls
///                    sit at a token boundary
///
/// `boundaryMatches` uses `end` vs. `triviaEnd` to answer
/// `<s>`/`>s<`/`<n>`/`>n<` from a single commit record.
struct LexMatch: Hashable {
    let terminalID: Int
    let start: CharPosition
    let end: CharPosition
    let triviaEnd: CharPosition
}

/// Key for the parser's `(pos, terminalID) → [LexMatch]` memoization table.
/// Lex queries are pure given the input; the same (pos, terminalID) gets asked
/// many times during a parse (testSelect iterates `firstBS`, descriptor re-entry
/// revisits positions). Without this cache the per-terminal LCNP path would
/// re-run pattern matching tens of thousands of times.
struct LexCacheKey: Hashable {
    let pos: CharPosition
    let terminalID: Int
}

/// Parser-driven, per-terminal lexer interface.
/// Lifted from the LCNP paper's `lex(u, t)` / `lexLKH(t, i, β, X)` functions.
protocol LCNPLexer {
    /// All valid end positions for `terminalID` starting at `pos`.
    func lex(at pos: CharPosition, terminalID: Int) -> [LexMatch]

    /// `lex` filtered against the parser's next-symbol expectations.
    /// Optimisation step — `lex` remains the semantic base. Default impl just
    /// delegates to `lex`; adapters/recognizers may override to prune.
    func lexLKH(at pos: CharPosition, terminalID: Int, predict: BitSet) -> [LexMatch]
}

extension LCNPLexer {
    func lexLKH(at pos: CharPosition, terminalID: Int, predict: BitSet) -> [LexMatch] {
        lex(at: pos, terminalID: terminalID)
    }
}

/// On-demand `LCNPLexer` covering literal terminals (Phase B Step 2) and regex
/// terminals (Phase C Step 1) directly against `input`. Trivia skipping uses
/// the grammar's `isSkip` patterns plus `=:` non-terminal recognisers.
///
/// Phase E Step 2d (Jun 14, 2026): `LegacyScannerLexAdapter` retired — this
/// lexer is the only path now. Terminals not present in `literalSourceByID`
/// nor `regexByID` simply return no match. `transitions`-annotated terminals
/// (Python's `bracketNewline`) lose their mode-gating; that's a documented
/// regression captured in the design doc.
///
/// Virtual tokens (Phase G, Jun 14, 2026): zero-length matches at source-
/// derived positions. Used for layout-sensitive synthetic tokens like
/// `INDENT` / `DEDENT` (Python, Haskell offside) and EOS. The
/// `virtualTokensAt` table is computed once at parse setup by walking the
/// input lexically; the lex consults it after trivia-skipping the cursor.
/// EOS still has a fallback special-case for grammars that don't populate
/// the table.
///
/// Match `end` is the position **after skipping trailing trivia**, so it
/// coincides with the next visible-token start in well-formed inputs and
/// preserves the parser's "cursor sits at a token boundary" invariant.
struct OnDemandLiteralLexer: LCNPLexer {
    let input: String
    /// `terminalID → literal source text` for every literal terminal in the grammar.
    let literalSourceByID: [Int: String]
    /// `terminalID → compiled regex` for every regex terminal (non-literal,
    /// non-skip). Answered from `input` directly via `prefixMatch`.
    let regexByID: [Int: Regex<AnyRegexOutput>]
    /// `@splitBefore("c")` per terminal: besides the maximal match, also offer the
    /// prefix ending before each internal `c`. Ports swift-syntax's operator
    /// regex-scan (`^^/regex/` → `^^` + `/regex/`). See TODO #0.
    let splitBeforeByID: [Int: Character]
    /// Terminal IDs of `@lexicalClass` regex terminals (identifier, operator, …).
    /// Maximal-munch (default, longest-across): a literal match is suppressed when
    /// any lexical-class terminal has a strictly longer match at the same start
    /// (`for` inside `foreach`, `_` inside `_foo`, `&` inside `&&`). The check is
    /// a runtime prefix-match of the class regex — the ground truth, not a
    /// derived extension class. See TODO #0 / `Multiple Lexicalisation` §4.1.
    let lexicalClassIDs: [Int]
    /// Compiled `isSkip` patterns from the grammar, used to skip whitespace /
    /// comments / etc. between the parser's cursor and the next meaningful
    /// character.
    let triviaRegexes: [Regex<AnyRegexOutput>]
    /// Recognisers for `=:` non-terminal trivia (Phase E Step 2). Each closure
    /// runs a recursive `MessageParser` sub-parse rooted at the `=:` non-
    /// terminal and returns the longest accepting end position at `pos`, or
    /// `nil` if no match. Tried after `triviaRegexes` in `skipTrivia`.
    let triviaRecognisers: [(CharPosition) -> CharPosition?]
    /// `=|` lexical-nonterminal recognisers, keyed by terminal kind ID. Each runs a GLL
    /// sub-parse rooted at the `=|` nonterminal and returns its longest accept end at `pos`.
    /// A terminal in this map is matched by its recogniser (one token) instead of a regex/literal.
    let lexicalTokenRecognisers: [Int: (CharPosition) -> CharPosition?]
    /// Terminal ID of the synthetic EOS sentinel (`"○"`). Matched directly at
    /// `input.endIndex` (after trivia skip), since EOS isn't in
    /// `grammar.terminals` and wouldn't otherwise have a lex source.
    let eosID: Int
    /// Source-derived zero-length tokens keyed by character position. Used by
    /// layout-sensitive grammars (Python's INDENT/DEDENT, etc.). Populated
    /// once at parse setup, gated on `grammar.usesInjectedLayoutTokens`.
    /// Multiple synthetic terminals at the same position appear once each in
    /// the value array (e.g. two DEDENTs at the same column).
    let virtualTokensAt: [CharPosition: [Int]]

    func lex(at pos: CharPosition, terminalID: Int) -> [LexMatch] {
        let scanStart = skipTrivia(from: pos)
        // Virtual zero-length match: registered at this position by the
        // layout-table precompute (e.g. INDENT/DEDENT in Python).
        if let virtuals = virtualTokensAt[scanStart], virtuals.contains(terminalID) {
            return [LexMatch(terminalID: terminalID, start: scanStart, end: scanStart, triviaEnd: scanStart)]
        }
        if terminalID == eosID {
            // EOS matches at end of input (after any trailing trivia).
            guard scanStart == input.endIndex else { return [] }
            return [LexMatch(terminalID: terminalID, start: scanStart, end: scanStart, triviaEnd: scanStart)]
        }
        // `=|` lexical nonterminal: match extent via the GLL sub-parse recogniser. One token
        // spanning the sub-parse's longest accept from `scanStart`; no match → no token.
        if let recognise = lexicalTokenRecognisers[terminalID] {
            guard scanStart < input.endIndex, let end = recognise(scanStart), end > scanStart else { return [] }
            let cursorEnd = skipTrivia(from: end)
            return [LexMatch(terminalID: terminalID, start: scanStart, end: end, triviaEnd: cursorEnd)]
        }
        if let literal = literalSourceByID[terminalID] {
            guard scanStart < input.endIndex else { return [] }
            let remaining = input[scanStart...]
            guard remaining.hasPrefix(literal) else { return [] }
            let literalEnd = input.index(scanStart, offsetBy: literal.count)
            // Maximal munch (longest-across): suppress this literal if any declared
            // `@lexicalClass` terminal has a strictly longer match at the same
            // start — `for` inside `foreach`, `_` inside `_foo`. Runtime prefix-
            // match of the class regex is the faithful test (no extension-class
            // extraction, no probes). TODO #0.
            for classID in lexicalClassIDs where classID != terminalID {
                guard let rx = regexByID[classID] else { continue }
                if let rm = remaining.prefixMatch(of: rx), rm.range.upperBound > literalEnd {
                    return []
                }
            }
            let cursorEnd = skipTrivia(from: literalEnd)
            return [LexMatch(terminalID: terminalID, start: scanStart, end: literalEnd, triviaEnd: cursorEnd)]
        }
        if let regex = regexByID[terminalID] {
            guard scanStart < input.endIndex else { return [] }
            // m.range.upperBound is type-agnostic — works for any Regex<Output>, including AnyRegexOutput
            // which is needed for regexes containing capturing groups (e.g. backreference forms like `(#+)…\1`).
            guard let m = input[scanStart...].prefixMatch(of: regex),
                  m.range.upperBound > scanStart else { return [] }
            let maxEnd = m.range.upperBound
            let cursorEnd = skipTrivia(from: maxEnd)
            var results = [LexMatch(terminalID: terminalID, start: scanStart, end: maxEnd, triviaEnd: cursorEnd)]
            // @splitBefore("c"): besides the maximal match, offer the prefix ending
            // before each internal `c` — ports swift-syntax lexOperatorIdentifier's
            // regex-scan (Cursor.swift:2275), letting `^^/regex/` split into `^^`
            // + `/regex/`. A leading `c` is not a split point. No trivia sits before
            // the split char, so end == triviaEnd.
            if let splitChar = splitBeforeByID[terminalID] {
                var i = input.index(after: scanStart)
                while i < maxEnd {
                    if input[i] == splitChar {
                        results.append(LexMatch(terminalID: terminalID, start: scanStart, end: i, triviaEnd: i))
                    }
                    i = input.index(after: i)
                }
            }
            return results
        }
        return []
    }

    /// Advance past any sequence of trivia matches starting at `pos`. Tries
    /// regex trivia first (fast path), then `=:` non-terminal recognisers
    /// (heavier, for nested constructs that regex can't express). Stops as
    /// soon as nothing advances the cursor.
    private func skipTrivia(from pos: CharPosition) -> CharPosition {
        var cursor = pos
        outer: while cursor < input.endIndex {
            for re in triviaRegexes {
                if let m = input[cursor...].prefixMatch(of: re), m.range.upperBound > cursor {
                    cursor = m.range.upperBound
                    continue outer
                }
            }
            for recognise in triviaRecognisers {
                if let end = recognise(cursor), end > cursor {
                    cursor = end
                    continue outer
                }
            }
            break
        }
        return cursor
    }
}

extension CharPosition {
    /// Locate the token index whose image starts at this position. Returns
    /// `tokens.count` if `self` is at or past `input.endIndex`. Used only for
    /// diagnostics (`recordMismatch`, AST/diagram builders) — the parse loop
    /// never falls off a token boundary.
    func tokenIndex(in tokens: [Token], input: String) -> Int {
        if self >= input.endIndex { return tokens.count }
        // Binary search by image.startIndex.
        var lo = 0, hi = tokens.count
        while lo < hi {
            let mid = (lo + hi) >> 1
            if tokens[mid].image.startIndex < self { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
}

// this is now back to 24 bytes (three 64-bit words)
struct Descriptor: Hashable {
    let L: GrammarNode          // grammar slot
    let k: CharPosition         // cluster index
    let i: CharPosition         // input index
}

// MARK: - MessageParser Descriptor Operations

extension MessageParser {

    // Paper: dscAdd(L, k, i)
    func addDescriptor(L: GrammarNode, k: CharPosition, i: CharPosition) {
        let d = Descriptor(L: L, k: k, i: i)
        if unique.insert(d).inserted {
            remaining.append(d)
            descriptorCount += 1
        } else {
            duplicateDescriptorCount += 1
        }
    }

    // Paper: get next descriptor from R
    func getDescriptor() -> Bool {
        if remaining.isEmpty {
            return false
        } else {
            let d = remaining.removeLast()
            cL = d.L
            cU = d.k
            cI = d.i
            return true
        }
    }
}
