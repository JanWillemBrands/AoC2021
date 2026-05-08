//
//  Scanner.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

// TODO: explicit matching rules e.g. -\- any, regex101 not preceed or follow <<!  !>>, or exclude "\" not preceded "-/-" not followed "-\-"

import OSLog
import Foundation
//import AdventMacros

enum ScannerFailure: Error {
    case charactersDoNotMatchAnySymbol(position: String.Index, input: String)
    case nonAdvancingMatch(position: String.Index, tokenKind: String, tokenImage: String)
    case couldNotReadFile
}

struct GatedTransition: CustomStringConvertible {
    let gate: String
    let pops: Bool
    let push: String?

    var description: String {
        var s = "=== \"\(gate)\""
        if pops { s += " <<<" }
        if let push { s += " >>> \"\(push)\"" }
        return s
    }
}

struct TokenPattern {
    let source: String
    let regex: Regex<Substring>
    let isLiteral: Bool
    let isSkip: Bool
    var transitions: [GatedTransition]

    init(_ source: String, _ regex: Regex<Substring>, _ isLiteral: Bool, _ isSkip: Bool, transitions: [GatedTransition] = []) {
        self.source = source
        self.regex = regex
        self.isLiteral = isLiteral
        self.isSkip = isSkip
        self.transitions = transitions
    }
}

final class Token: CustomStringConvertible {
    var image: Substring
    var kind: String
    /// Integer ID from `Grammar.symbolToID`, assigned by `MessageParser.parse(tokens:trivia:input:)`
    /// before the GLL algorithm runs. Enables O(1) integer comparison in `tokenMatch()`
    /// and O(1) BitSet membership tests in `testSelect()`.
    var kindID: Int!
    var dual: Token?                            // multiple regex matches of equal length create a 'Schrödinger' token linked list
    
    init(image: Substring, kind: String) {
        self.image = image
        self.kind = kind
    }
    
    var stripped: String {
        switch kind {
        case "literal", "empty":
            return String(image.dropFirst().dropLast())
        case "regex":
            return String(image.dropFirst().dropLast())
        case "action":
            return image.dropFirst().dropLast()
                .replacingOccurrences(of: "\\'", with: "'")
        case "message":
            return String(image.dropFirst(3))
        case "pragma":
            return String(image.dropFirst())
        default:
            return String(image)
        }
    }
    
    var description: String {
        if let dual {
            return "'" + kind + "' ~ " + dual.description
        }
        return "'" + kind + "'"
    }
    var debugDescription: String {  // includes the unique token kind ID
        let idStr = kindID.map(String.init) ?? "?"
        if let dual {
            return "'" + kind + "':" + idStr + " ~ " + dual.description
        }
        return "'" + kind + "':" + idStr
    }
}

private struct Pattern {
    let kind: String
    let source: String
    let regex: Regex<Substring>
    let isLiteral: Bool
    let isSkip: Bool
    let transitions: [GatedTransition]
}

/// Scanner takes an input string and token patterns, and produces a token array.
/// One instance per scan — no shared mutable state.
/// Literal keywords are matched via hasPrefix; only true regex patterns use the regex engine.
final class Scanner {
    
    let input: String
    var tokens: [Token] = []                // normal, visible tokens that can be referenced in the grammar production rules
    var trivia: [[Token]] = [[]]            // skipped tokens are stored as lists in an array indexed by the visible token following them
    
    private var modeStack: [String] = []    // tracks state to allow e.g. nested token construction
    private var scannerMode: String {       // isolated to the scanner, not driven by the parser
        return modeStack.last ?? ""
    }
    
    private var literalPatterns: [Pattern] = []
    private var regexPatterns: [Pattern] = []
    private let telemetry: any ScannerTelemetry
    
    init(fromString inputString: String, patterns: [String: TokenPattern], telemetry: (any ScannerTelemetry)? = nil) throws {
        self.input = inputString
        self.telemetry = telemetry ?? makeDefaultScannerTelemetry()
        
        // Partition: keyword terminals use fast hasPrefix, the rest use regex engine.
        for (kind, pattern) in patterns {
            if pattern.isLiteral {
                literalPatterns.append(Pattern(kind: kind, source: pattern.source, regex: pattern.regex, isLiteral: pattern.isLiteral, isSkip: pattern.isSkip, transitions: pattern.transitions))
            } else {
                regexPatterns.append(Pattern(kind: kind, source: pattern.source, regex: pattern.regex, isLiteral: pattern.isLiteral, isSkip: pattern.isSkip, transitions: pattern.transitions))
            }
        }
        
        self.telemetry.scannerConfigured(literalPatternCount: literalPatterns.count, regexPatternCount: regexPatterns.count)
        try scanAllTokens()
    }
    
    private struct Candidate {
        let token: Token
        let pattern: Pattern
    }
    
    private func scanAllTokens() throws {
        var matchStart = input.startIndex

        var charsScanned = 0
        let inputSize = input.utf8.count
        let scanInterval = 10_000
        let scanByteLimit = 0
        telemetry.scanStarted(inputSize: inputSize, literalPatternCount: literalPatterns.count, regexPatternCount: regexPatterns.count)

        while matchStart != input.endIndex {
            var matchEnd = matchStart
            var candidates: [Candidate] = []
            let remaining = input[matchStart...]
            let mode = modeStack.last ?? ""

            // Phase 1: literal keywords via hasPrefix (gated pre-filter, then fast string comparison)
            let litT0 = CFAbsoluteTimeGetCurrent()
            for lp in literalPatterns {
                guard lp.transitions.isEmpty || lp.transitions.contains(where: { $0.gate == mode }) else { continue }
                if remaining.hasPrefix(lp.source) {
                    let literalEnd = input.index(matchStart, offsetBy: lp.source.count)
                    if literalEnd > matchEnd {
                        matchEnd = literalEnd
                        candidates.removeAll()
                    }
                    if literalEnd == matchEnd {
                        candidates.append(Candidate(
                            token: Token(image: input[matchStart..<literalEnd], kind: lp.kind),
                            pattern: lp))
                    }
                }
            }

            telemetry.recordLiteralPhase(elapsed: CFAbsoluteTimeGetCurrent() - litT0)

            // Phase 2: regex patterns via prefixMatch (gated pre-filter, then regex engine)
            let regT0 = CFAbsoluteTimeGetCurrent()
            
            for rp in regexPatterns {
                guard rp.transitions.isEmpty || rp.transitions.contains(where: { $0.gate == mode }) else { continue }
                
                let t0 = CFAbsoluteTimeGetCurrent()
                
                let match = remaining.prefixMatch(of: rp.regex)
                
                let elapsed = CFAbsoluteTimeGetCurrent() - t0
                telemetry.recordRegexCall(kind: rp.kind, elapsed: elapsed, charsScanned: charsScanned, inputSize: inputSize, mode: mode)

                if let match {
                    if match.0.endIndex > matchEnd {
                        matchEnd = match.0.endIndex
                        candidates.removeAll()
                    }
                    if match.0.endIndex == matchEnd {
                        candidates.append(Candidate(
                            token: Token(image: match.0, kind: rp.kind),
                            pattern: rp))
                    }
                }
            }
            
            telemetry.recordRegexPhase(elapsed: CFAbsoluteTimeGetCurrent() - regT0)

            // Phase 3: resolve candidates — longest match wins, ties form Schrödinger chain
            guard !candidates.isEmpty else {
                try scanError(position: matchStart)
            }

            let front = candidates.filter { $0.pattern.isLiteral && !$0.pattern.isSkip }
            let back = candidates.filter { !($0.pattern.isLiteral && !$0.pattern.isSkip) }
            let ordered = front + back

            let headMatch = ordered[0].token
            let headPattern = ordered[0].pattern

            if headMatch.image.isEmpty {
                let pos = input.linePosition(of: matchStart)
                telemetry.recordNonAdvancingMatch(
                    kind: headMatch.kind,
                    image: String(headMatch.image),
                    position: pos,
                    mode: mode,
                    candidates: ordered.map { $0.token.kind }
                )
                throw ScannerFailure.nonAdvancingMatch(position: matchStart, tokenKind: headMatch.kind, tokenImage: String(headMatch.image))
            }

            var tail = headMatch
            for candidate in ordered.dropFirst() {
                tail.dual = candidate.token
                tail = candidate.token
            }

            telemetry.recordMatchedToken(tokenDescription: headMatch.description, image: String(headMatch.image), modeBeforeTransition: mode)
            // Phase 4: execute the winning candidate's gated transition (unconditional post-action)
            if let transition = headPattern.transitions.first(where: { $0.gate == mode }) {
                telemetry.recordTransition(transition.description)
                if transition.pops { modeStack.removeLast() }
                if let push = transition.push { modeStack.append(push) }
            }

            if headPattern.isSkip {
                trivia[tokens.count].append(headMatch)
            } else {
                tokens.append(headMatch)
                trivia.append([])
            }
            matchStart = matchEnd
            charsScanned += headMatch.image.utf8.count
            if charsScanned % scanInterval < headMatch.image.utf8.count {
                telemetry.recordProgress(charsScanned: charsScanned, inputSize: inputSize, tokenCount: tokens.count)
            }
            if scanByteLimit > 0 && charsScanned >= scanByteLimit {
                telemetry.recordByteLimitStop(scanByteLimit)
                break
            }
        }
        
        let end = input.endIndex
        tokens.append(Token(image: input[end..<end], kind: "○"))  // append EndOfString token anchored in input
        telemetry.scanFinished(inputSize: inputSize, tokenCount: tokens.count)
    }

    private func scanError(position: String.Index) throws -> Never {
        var error = "scan error: input characters at position \(input.linePosition(of: position)) do not match any symbol in the grammar\n"
        let lineRange = input.lineRange(for: position ..< input.index(after: position))
        error += input[lineRange]
        let before = lineRange.lowerBound ..< position
        for _ in 0 ..< input[before].count {
            error += " "
        }
        error += "^~~~~~~~"
        Logger.scan.error("\(error, privacy: .public)")
        throw ScannerFailure.charactersDoNotMatchAnySymbol(position: position, input: input)
    }
}
