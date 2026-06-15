//
//  LayoutTokenInjection.swift
//  Advent
//
//  Created by Johannes Brands on 2026.04.25.
//

// Layer 2 of the layout-sensitive parsing architecture (see "Layout Sensitive Parsing.md").
//
// Injects synthetic >>| (INDENT) and |<< (DEDENT) tokens into the token stream before parsing.
// The GLL parser sees these as ordinary terminals — no parser modifications required.
//
// Bracket suppression: indent tracking is suspended inside matched bracket pairs (e.g. Python's
// implicit line continuation inside (), [], {}).
//
// Newline-only tokens (visible NEWLINE terminals whose image is purely \n/\r) are passed through
// without triggering indent/dedent. This prevents blank lines and comment-only lines — which
// appear at column 0 — from causing premature dedent inside indented blocks.

import OSLog

/// Phase G (Jun 14, 2026): parser-side variant of `injectLayoutTokens`.
///
/// Walks the scanner-produced token stream once and returns a
/// `[CharPosition: [kindID]]` table of zero-length synthetic tokens
/// (`>>|` / `|<<`) keyed by the source position where each fires. Used by
/// `OnDemandLiteralLexer.lex` to answer `INDENT`/`DEDENT` queries on-demand
/// without mutating the scanner's `tokens[]`.
///
/// The algorithm mirrors `injectLayoutTokens` exactly: track an indent stack
/// and bracket depth, compare line columns, emit `>>|` on indent and `|<<`
/// on each dedent level closed. Multiple dedents at the same position become
/// a multi-element value in the table.
///
/// Gating: caller is responsible for checking `grammar.usesInjectedLayoutTokens`
/// before invoking this. With the flag off the parser allocates nothing.
func computeVirtualLayoutTokens(
    tokens: [Token],
    input: String,
    indentKindID: Int,
    dedentKindID: Int,
    tabWidth: Int = 8,
    bracketPairs: [(open: String, close: String)] = []
) -> [CharPosition: [Int]] {
    var result: [CharPosition: [Int]] = [:]
    let openers = Set(bracketPairs.map(\.open))
    let closers = Set(bracketPairs.map(\.close))

    var indentStack: [Int] = [0]
    var bracketDepth = 0

    for i in tokens.indices {
        let tok = tokens[i]

        if openers.contains(tok.kind) { bracketDepth += 1 }
        if closers.contains(tok.kind), bracketDepth > 0 { bracketDepth -= 1 }

        if tok.kind == "○" {
            while indentStack.count > 1 {
                indentStack.removeLast()
                result[tok.image.startIndex, default: []].append(dedentKindID)
            }
            continue
        }

        let isNewlineToken = !tok.image.isEmpty && tok.image.allSatisfy { $0 == "\n" || $0 == "\r" }
        if isNewlineToken { continue }

        let lineBreaks: Int
        if i == 0 {
            lineBreaks = 1
        } else {
            let span = input[tokens[i - 1].image.startIndex..<tok.image.startIndex]
            var breaks = 0
            var prevWasCR = false
            for ch in span {
                let isCR = ch == "\r"
                let isLF = ch == "\n"
                if isCR || (isLF && !prevWasCR) { breaks += 1 }
                prevWasCR = isCR
            }
            lineBreaks = breaks
        }

        if lineBreaks > 0 && bracketDepth == 0 {
            let col = input.columnOf(tok.image.startIndex, tabWidth: tabWidth)
            let insertionPoint = tok.image.startIndex
            if col > indentStack.last! {
                indentStack.append(col)
                result[insertionPoint, default: []].append(indentKindID)
            } else {
                while indentStack.count > 1 && col < indentStack.last! {
                    indentStack.removeLast()
                    result[insertionPoint, default: []].append(dedentKindID)
                }
            }
        }
    }

    return result
}

func injectLayoutTokens(
    tokens: inout [Token],
    trivia: inout [[Token]],
    input: String,
    tabWidth: Int = 8,
    bracketPairs: [(open: String, close: String)] = []
) {

    let openers = Set(bracketPairs.map(\.open))
    let closers = Set(bracketPairs.map(\.close))

    var indentStack: [Int] = [0]
    var bracketDepth = 0
    var newTokens: [Token] = []
    var newTrivia: [[Token]] = [[]]

    for i in tokens.indices {
        let tok = tokens[i]

        if openers.contains(tok.kind) { bracketDepth += 1 }
        if closers.contains(tok.kind) {
            if bracketDepth > 0 {
                bracketDepth -= 1
            } else {
                Logger.scan.warning("layout injection: unbalanced closer '\(tok.kind, privacy: .public)' at token \(i)")
            }
        }

        if tok.kind == "○" {
            if bracketDepth > 0 {
                Logger.scan.warning("layout injection: \(bracketDepth) unclosed bracket(s) at end of input")
            }
            while indentStack.count > 1 {
                indentStack.removeLast()
                let marker = input[tok.image.startIndex..<tok.image.startIndex]
                newTokens.append(Token(image: marker, kind: "|<<"))
                newTrivia.append([])
            }
            newTrivia[newTokens.count].append(contentsOf: trivia[i])
            newTokens.append(tok)
            newTrivia.append([])
            continue
        }

        // Visible NEWLINE tokens sit at column 0 but carry no indentation intent.
        // Skip them to avoid false dedents on blank/comment-only lines.
        let isNewlineToken = !tok.image.isEmpty && tok.image.allSatisfy({ $0 == "\n" || $0 == "\r" })
        if isNewlineToken {
            newTrivia[newTokens.count].append(contentsOf: trivia[i])
            newTokens.append(tok)
            newTrivia.append([])
            continue
        }

        // Count line breaks from previous token's START (not END) so that
        // newlines inside visible NEWLINE tokens are detected.
        // \r\n counts as one line break (the prevWasCR guard).
        let lineBreaks: Int
        if i == 0 {
            lineBreaks = 1
        } else {
            let span = input[tokens[i - 1].image.startIndex..<tok.image.startIndex]
            var breaks = 0
            var prevWasCR = false
            for ch in span {
                let isCR = ch == "\r"
                let isLF = ch == "\n"
                if isCR || (isLF && !prevWasCR) { breaks += 1 }
                prevWasCR = isCR
            }
            lineBreaks = breaks
        }

        if lineBreaks > 0 && bracketDepth == 0 {
            let col = input.columnOf(tok.image.startIndex, tabWidth: tabWidth)
            let insertionPoint = tok.image.startIndex
            if col > indentStack.last! {
                indentStack.append(col)
                let marker = input[insertionPoint..<insertionPoint]
                newTokens.append(Token(image: marker, kind: ">>|"))
                newTrivia.append([])
            } else {
                while indentStack.count > 1 && col < indentStack.last! {
                    indentStack.removeLast()
                    let marker = input[insertionPoint..<insertionPoint]
                    newTokens.append(Token(image: marker, kind: "|<<"))
                    newTrivia.append([])
                }
            }
        }

        newTrivia[newTokens.count].append(contentsOf: trivia[i])
        newTokens.append(tok)
        newTrivia.append([])
    }

    tokens = newTokens
    trivia = newTrivia
}
