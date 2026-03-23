//
//  main.swift
//  GeneratedParser
//

import Foundation

let inputFile = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("input.txt")

let input = try String(contentsOf: inputFile, encoding: .utf8)
let scanner = try Scanner(fromString: input, patterns: tokenPatterns)
tokens = scanner.tokens
cI = 0
parse()
print("parse succeeded")
