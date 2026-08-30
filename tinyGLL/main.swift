//
//  main.swift
//  tinyGLL
//
//  Created by Johannes Brands on 2026.08.28.
//

import Foundation

let grammar = Array(" S = a. B =b|ε.C=c|B.")

let input = Array("a")

var nonTerminalDefinitions: [Character: GrammarNode] = [:]

var grammarRoot = GrammarNode(.EOS, "$") // dummy initializer, grammarRoot must not be an optional
//var grammarRoot: GrammarNode!

func parseGrammar() {
    var i = 0
    var c: Character = "$"
    
    func next(expect predicate: (Character) -> Bool = {$0==$0} ) {
        if !predicate(c) {
            print("found an unexpected '\(c)' at position \(i - 1)")
            exit(1)
        }
        while i < grammar.count && ( grammar[i] == " " || grammar[i] == "\n" ) {
            i += 1
        }
        if i < grammar.count {
            c = grammar[i]
            i += 1
        } else {
            c = "$"
        }
        print("next '\(c)' at position \(i - 1)")
    }
    
    var nonTerminal: GrammarNode!
    var nonTerminalReferences: [GrammarNode] = []
    
    func production() {
        print("\(#function)")
        let name = c
        next() { $0.isUppercase }
        nonTerminal = GrammarNode(.N, name)
        nonTerminalDefinitions[nonTerminal.name] = nonTerminal
        next() { $0 == "=" }
        nonTerminal.alt = alternates()
        next() { $0 == "." }
    }
    
    func alternates() -> GrammarNode {
        print("\(#function)")
        let startOfAlternates = sequence()
        var tmp = startOfAlternates
        while c == "|" {
            next()
            tmp.alt = sequence()
            tmp = tmp.alt!
        }
        return startOfAlternates
    }
    
    func sequence() -> GrammarNode {
        print("\(#function)")
        let startOfSequence = GrammarNode(.ALT, "[")
        var tmp = startOfSequence
        repeat {
            var factor: GrammarNode
            if c == "ε" {
                factor = GrammarNode(.EPS, c)
            } else if c.isUppercase {
                factor = GrammarNode(.N, c)
                nonTerminalReferences.append(factor)
            } else if c.isLowercase {
                factor = GrammarNode(.T, c)
            } else {
                print("found an unexpected factor '\(c)' at position \(i - 1)")
                exit(1)
            }
            tmp.seq = factor
            tmp = tmp.seq!
            next()
        } while c.isLetter
        
        tmp.seq = GrammarNode(.END, "]")
        tmp.seq?.seq = nonTerminal
        tmp.seq?.alt = startOfSequence
        return startOfSequence
    }
    
    next()
    while c != "$" {
        production()
    }
    
    for ref in nonTerminalReferences {
        ref.alt = nonTerminalDefinitions[ref.name]
    }
}

// Paper: CRF - Call Return Forest
var crf: [ParsePosition: ParseCluster] = [:]

// Paper: crfNode (L, i)
struct ParsePosition: Hashable {
    let slot: GrammarNode
    let index: Int
}

// Paper: clusterNode (X, k)
final class ParseCluster {
    let slot: GrammarNode           // the LHS nonterminal (X)
    let index: Int                  // input position (k)
    
    var returns: Set<ParsePosition> = []
    var pops: Set<Int> = []         // Paper: P — contingent returns
    
    init(slot: GrammarNode, index: Int) {
        self.slot = slot
        self.index = index
    }
}


// Paper: call(L, i, j) — enter a nonterminal
func call() {
    // cL points to the RHS nonterminal node
    // cL.alt points to the LHS nonterminal node
    
    // Create the return edge: (L=cL, i=cU)
    let returnEdge = ParsePosition(slot: cL, index: cU)
    
    // Create the index key: (X=cL.alt!, k=cI)
    let clusterKey = ParsePosition(slot: cL.alt!, index: cI)

    // Find or create the parseCluster in the crf
    if let existingCluster = crf[clusterKey] {
        if existingCluster.returns.insert(returnEdge).inserted {
            for pop in existingCluster.pops {
                addDescriptor(L: cL.seq!, k: cU, i: pop)
                addYield(L: cL, i: cU, k: cI, j: pop)
            }
        }
    } else {
        let newCluster = ParseCluster(slot: cL.alt!, index: cI)
        crf[clusterKey] = newCluster
        newCluster.returns.insert(returnEdge)
        addDecscriptorsForAlternates(X: cL.alt!, k: cI, i: cI)
    }
}

// Paper: rtn(X, k, j) — return from a nonterminal
func rtn(X: GrammarNode) {
    let clusterKey = ParsePosition(slot: X, index: cU)
    guard let cluster = crf[clusterKey] else { return }
    
    if cluster.pops.insert(cI).inserted {
        for rtn in cluster.returns {
            addDescriptor(L: rtn.slot.seq!, k: rtn.index, i: cI)
            addYield(L: rtn.slot, i: rtn.index, k: cU, j: cI)
        }
    }
}


func parseInput() {
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
            case .T:
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
            case .END:
                // the seq link of an END node always points back to the nonTerminal node
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


enum GrammarNodeKind { case EOS, T, EPS, N, ALT, END }

class GrammarNode: Hashable {
    let kind: GrammarNodeKind
    let name: Character
    
    var alt, seq: GrammarNode?
    
    let number: Int
    static var count = 0
    
    static func == (lhs: GrammarNode, rhs: GrammarNode) -> Bool {
        lhs.number == rhs.number
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
    
    init(_ kind: GrammarNodeKind, _ name: Character) {
        self.kind = kind
        self.name = name
        self.number = Self.count
        Self.count += 1
    }
}

struct Descriptor: Hashable {
    let L: GrammarNode          // grammar slot
    let k: Int                  // cluster index
    let i: Int                  // input index
}

var unique: Set<Descriptor> = []
var remaining: [Descriptor] = []

var cL = grammarRoot
var cU = 0
var cI = 0

func addDescriptor(L: GrammarNode, k: Int, i: Int) {
    let d = Descriptor(L: L, k: k, i: i)
    if unique.insert(d).inserted {
        remaining.append(d)
    }
}

// Paper: ntAdd(X, j) — add descriptors for all alternates of a nonterminal
func addDecscriptorsForAlternates(X: GrammarNode, k: Int, i: Int) {
    var current = X.alt
    while let alt = current {
        if testSelect(slot: alt, bracket: X) {
            addDescriptor(L: alt.seq!, k: k, i: i)
        }
        current = alt.alt
    }
}

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

struct BinarySpan: Hashable, Comparable, CustomStringConvertible {
    let i: Int  // left extent
    let k: Int  // pivot
    let j: Int  // right extent
    var description: String { "\(i):\(k):\(j)" }
    
    static func < (lhs: BinarySpan, rhs: BinarySpan) -> Bool {
        if lhs.i != rhs.i { return lhs.i < rhs.i }
        if lhs.k != rhs.k { return lhs.k < rhs.k }
        return lhs.j < rhs.j
    }
}

var yields: [Set<BinarySpan>] = []

func addYield(L: GrammarNode, i: Int, k: Int, j: Int) {
    let t = BinarySpan(i: i, k: k, j: j)
    yields[L.number].insert(t)
}

parseGrammar()
for r in nonTerminalDefinitions {
    r.value.dump()
}
//parseInput()
//print(yields)
