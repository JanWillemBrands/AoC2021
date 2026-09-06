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

/// Times a parse of "b" * n for n in 1...maxLength against the tortureART grammar, both
/// interpreted and compiled, printing a tab-separated pair of wall-clock figures in seconds
/// with six decimals per input — plain numbers, so the output pastes straight into a
/// spreadsheet. Totals and the speedup go to stderr, along with rejects as a correctness
/// canary; that keeps stdout numeric.
///
/// The compiled column comes from generating a standalone parser for the same grammar,
/// building it with swiftc -O and running the whole sweep in one process (see
/// compiledTimings). Both sides therefore do identical work on identical inputs, which makes
/// the ratio a measurement of codegen alone. If the toolchain is unavailable the compiled
/// column is simply omitted.
///
/// The grammar and inputs are built in rather than taken from the operands: the sweep needs
/// a family of inputs, not the single one the operands provide.
///
/// Only the descriptor loop is timed on either side. Grammar reading, code generation,
/// compilation and derivation extraction are all excluded, and the numbers are only
/// meaningful from a release build — a debug build measures Swift's bounds and retain
/// checks, not the parser.
func runBenchmark(maxLength: Int) throws {
    let benchSyntax = Array(" S = b | S S | S S S .")
    let inputs = (1...maxLength).map { String(repeating: "b", count: $0) }

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

    var interpreted: [Double] = []
    for n in 1...maxLength {
        try prepare(length: n)

        let start = DispatchTime.now().uptimeNanoseconds
        try parseInput()
        let elapsed = DispatchTime.now().uptimeNanoseconds - start

        interpreted.append(Double(elapsed) / 1_000_000_000)

        if !parseAccepted {
            FileHandle.standardError.write(Data("interpreted rejected at length \(n)\n".utf8))
        }
    }

    // Leave the grammar loaded at the same length the interpreter warmed up on, so the
    // generated parser's own warm-up — which runs on its baked-in input — matches.
    try prepare(length: 5)
    let compiled = try compiledTimings(for: inputs)

    for (index, seconds) in interpreted.enumerated() {
        if let compiled, index < compiled.count {
            print(String(format: "%.6f\t%.6f", seconds, compiled[index]))
        } else {
            print(String(format: "%.6f", seconds))
        }
    }

    func note(_ text: String) {
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }

    let interpretedTotal = interpreted.reduce(0, +)
    if let compiled {
        let compiledTotal = compiled.reduce(0, +)
        note(String(format: "interpreted %.4fs   compiled %.4fs   speedup %.2fx",
                    interpretedTotal, compiledTotal, interpretedTotal / compiledTotal))
    } else {
        note(String(format: "interpreted %.4fs   compiled column skipped (swiftc unavailable or generated source did not build)",
                    interpretedTotal))
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

    // A successful parse means the grammar is worth compiling, so emit the standalone
    // parser for it. Generated only on success: the templates assume a grammar the
    // interpreter has already agreed with.
    do {
        let parserFile = try generate()
        print("generated \(parserFile.path(percentEncoded: false))")
    } catch {
        print(error)
        exit(1)
    }

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
