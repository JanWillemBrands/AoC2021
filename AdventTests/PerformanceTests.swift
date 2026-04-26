//
//  PerformanceTests.swift
//  AdventTests
//
//  Lightweight performance harness in Swift Testing.
//  Configure once in `settings` below; no environment variables required.
//

import Testing
import Foundation

@Suite("Performance Tests", .serialized)
struct PerformanceTests {

    // MARK: - Suite Setup

    /// Centralized defaults for performance runs.
    /// Adjust these values in one place when you want broader/deeper runs.
    private struct Settings {
        let grammars: [String]
        let warmupRuns: Int
        let measuredRuns: Int
        let messageLimitPerGrammar: Int
    }

    private static let settings = Settings(
        grammars: ["Swift"],
        warmupRuns: 0,
        measuredRuns: 1,
        messageLimitPerGrammar: 1
    )

    private struct Totals {
        var descriptorCount = 0
        var duplicateDescriptorCount = 0
        var suppressedDescriptorCount = 0
        var crfCount = 0
        var yieldCount = 0

        mutating func add(from parser: MessageParser) {
            descriptorCount += parser.descriptorCount
            duplicateDescriptorCount += parser.duplicateDescriptorCount
            suppressedDescriptorCount += parser.suppressedDescriptorCount
            crfCount += parser.crf.count
            yieldCount += parser.yieldCount
        }
    }

    private static func grammarURL(named name: String) -> URL {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectDir = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
        return projectDir
            .appendingPathComponent(name)
            .appendingPathExtension("apus")
    }

    private static func loadGrammar(named name: String) throws -> Grammar {
        GrammarNode.count = 0
        trace = false
        traceIndent = 0

        let url = grammarURL(named: name)
        let parser = try ApusParser(fromFile: url)
        return try parser.parse(explicitStartSymbol: "")
    }

    private static func buildScanners(grammar: Grammar, grammarName: String, limit: Int) throws -> [Scanner] {
        let grammarDir = grammarURL(named: grammarName).deletingLastPathComponent()
        var scanners: [Scanner] = []

        for message in grammar.messages {
            if limit > 0 && scanners.count >= limit { break }
            let scanner: Scanner
            if message.hasPrefix("#") {
                let fileName = message.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                let messageFileURL = grammarDir.appendingPathComponent(fileName)
                let fileMessage = try String(contentsOf: messageFileURL, encoding: .utf8)
                scanner = try Scanner(fromString: fileMessage, patterns: grammar.terminals)
            } else {
                scanner = try Scanner(fromString: message, patterns: grammar.terminals)
            }
            scanners.append(scanner)
        }

        return scanners
    }

    @Test("Performance harness prints stable metrics")
    func benchmarkSelectedGrammars() throws {
        let warmupRuns = max(0, Self.settings.warmupRuns)
        let measuredRuns = max(1, Self.settings.measuredRuns)
        let messageLimit = max(0, Self.settings.messageLimitPerGrammar)
        let grammars = Self.settings.grammars

        print("perf-harness,warmup=\(warmupRuns),runs=\(measuredRuns),grammars=\(grammars.joined(separator: ","))")
        print("grammar,run,wallSeconds,cpuSeconds,messages,descriptorCount,duplicateDescriptorCount,suppressedDescriptorCount,crfCount,yieldCount")

        for grammarName in grammars {
            let grammar = try Self.loadGrammar(named: grammarName)
            let scanners = try Self.buildScanners(grammar: grammar, grammarName: grammarName, limit: messageLimit)

            #expect(!scanners.isEmpty, "No messages found for grammar '\(grammarName)'. Add ^^^ messages or increase messageLimitPerGrammar.")

            let parser = MessageParser(grammar: grammar)

            if warmupRuns > 0 {
                for _ in 0..<warmupRuns {
                    for scanner in scanners {
                        parser.parse(tokens: scanner.tokens)
                    }
                }
            }

            var wallSum = 0.0
            var cpuSum = 0.0

            for run in 1...measuredRuns {
                let wallStart = Date().timeIntervalSinceReferenceDate
                let cpuStart = clock()

                var totals = Totals()
                for scanner in scanners {
                    parser.parse(tokens: scanner.tokens)
                    totals.add(from: parser)
                }

                let cpuSeconds = Double(clock() - cpuStart) / Double(CLOCKS_PER_SEC)
                let wallSeconds = Date().timeIntervalSinceReferenceDate - wallStart
                wallSum += wallSeconds
                cpuSum += cpuSeconds

                print("\(grammarName),\(run),\(wallSeconds),\(cpuSeconds),\(scanners.count),\(totals.descriptorCount),\(totals.duplicateDescriptorCount),\(totals.suppressedDescriptorCount),\(totals.crfCount),\(totals.yieldCount)")

                #expect(totals.descriptorCount > 0, "Descriptor count should be > 0 for '\(grammarName)'.")
            }

            print("summary,\(grammarName),avgWall=\(wallSum / Double(measuredRuns)),avgCPU=\(cpuSum / Double(measuredRuns))")
        }
    }
}
