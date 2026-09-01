//
//  main.swift
//  tinyGLL
//
//  Created by Johannes Brands on 2026.08.28.
//

import Foundation

// Driver only — the parser itself lives in Engine.swift, which has to stay free of
// top-level code so the explorer can drive it too.
//
//   tinyGLL                        parse the built-in grammar and input, printing a trace
//   tinyGLL --tree                 print the derivation trees instead of the trace
//   tinyGLL --explore              open the interactive parse-tree explorer
//   tinyGLL --bench                time the tortureART input sweep, one line per input
//   tinyGLL <flag> "S = a ." "a"   override the grammar and input

enum RunMode { case trace, tree, explore, bench }

// Manual overrides, for running from Xcode where passing a --flag means editing the scheme.
// Any one of these set to true wins over the command line; if several are true the first
// in this list wins.
let explorerAlways = true
let benchAlways = false
let treeAlways = false

// --bench sweeps input lengths 1...benchMaxLength. 100 matches the number of ^^^ lines in
// 'apus grammars/tortureART.apus', so the two runs are comparable line for line.
let benchMaxLength = 100

let arguments = CommandLine.arguments
let operands = Array(arguments.dropFirst().filter { !$0.hasPrefix("--") })

let mode: RunMode
if explorerAlways {
    mode = .explore
} else if benchAlways {
    mode = .bench
} else if treeAlways {
    mode = .tree
} else if arguments.contains("--explore") {
    mode = .explore
} else if arguments.contains("--bench") {
    mode = .bench
} else if arguments.contains("--tree") {
    mode = .tree
} else {
    mode = .trace
}

if operands.count > 0 { syntax = Array(operands[0]) }
if operands.count > 1 { input = Array(operands[1]) }

/// Times a parse of "b" * n for n in 1...maxLength against the tortureART grammar, printing
/// one wall-clock figure per input in seconds with six decimals — plain numbers, so the
/// output pastes straight into a spreadsheet. Rejects go to stderr as a correctness canary.
///
/// The grammar and inputs are built in rather than taken from the operands: the sweep needs
/// a family of inputs, not the single one the operands provide.
///
/// Only the descriptor loop is timed. Grammar reading and derivation extraction are excluded,
/// and the numbers are only meaningful from a release build — a debug build measures Swift's
/// bounds and retain checks, not the parser.
func runBenchmark(maxLength: Int) throws {
    let benchSyntax = Array(" S = b | S S | S S S .")

    func prepare(length: Int) throws {
        resetEngine()
        syntax = benchSyntax
        input = Array(repeating: "b", count: length)
        try parseGrammar()
    }

    // Discarded warm-up: the first parse in a process pays one-off allocation costs, which
    // would otherwise land entirely on the shortest — and so most sensitive — input.
    for _ in 0..<3 {
        try prepare(length: 5)
        try parseInput()
    }

    for n in 1...maxLength {
        try prepare(length: n)

        let start = DispatchTime.now().uptimeNanoseconds
        try parseInput()
        let elapsed = DispatchTime.now().uptimeNanoseconds - start

        print(String(format: "%.6f", Double(elapsed) / 1_000_000_000))

        if !parseAccepted {
            FileHandle.standardError.write(Data("rejected at length \(n)\n".utf8))
        }
    }
}

switch mode {
case .explore:
    // Top-level code runs on the main thread, which is what runExplorer() requires.
    MainActor.assumeIsolated { runExplorer() }

case .bench:
    do {
        try runBenchmark(maxLength: benchMaxLength)
    } catch {
        print(error)
        exit(1)
    }

case .trace, .tree:
    let showTrees = mode == .tree
    do {
        try parseGrammar()
        if !showTrees {
            for definition in nonTerminalDefinitions.values {
                definition.dump()
            }
        }
        try parseInput()
    } catch {
        print(error)
        exit(1)
    }

    // The parse is accepted when the start symbol yields a span covering the whole input
    guard parseAccepted, let root = nonTerminalDefinitions["S"] else {
        print("Parse fail")
        exit(0)
    }

    print("Parse pass")

    if showTrees {
        let trees = DerivationBuilder().allDerivations()
        print("\(trees.count) derivation\(trees.count == 1 ? "" : "s")")
        for (n, tree) in trees.enumerated() {
            print("derivation \(n + 1):")
            print(tree.dump(indent: 1), terminator: "")
        }
    } else {
        print(yields[root.number])
    }
}
