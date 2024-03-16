//
//  GenerateParser.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import Foundation

let parserFileURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("output")
    .appendingPathExtension("swift")

var parserContent: String = ""

func generateParser() {
    let template = #"""
    //: start of template code
    import Foundation
    typealias TokenPattern = (image: String, regular: Bool, muted: Bool)
    //: start of generated code
    """#
    emit(template)
    
    emit(dent: .NR, "let tokenPatterns: [String:TokenPattern] = [")
    let sortedTerminals = terminals
        .sorted { $0.key.count > $1.key.count
            || $0.key.count == $1.key.count && $0.key < $1.key }
    for n in sortedTerminals {
        if n.value.regular {
            emit("\"", n.key.escapesAdded, "\":\t(#\"", n.value.pattern, "\"#,\t", n.value.regular, ",\t", n.value.muted, "),")
        } else {
            emit("\"", n.key.escapesAdded, "\":\t(\"", n.value.pattern.escapesAdded, "\",\t", n.value.regular, ",\t", n.value.muted, "),")
        }
    }
    emit(dent: .LN, "]")
    
    for (var name, node) in nonTerminals {
        if name.first!.isNumber {
            name = "_" + name
        }
        emit(dent: .NR, "func ", name, "() {")
        generate(node)
        emit(dent: .LN, "}")
    }
    
    do {
        try parserContent.write(to: parserFileURL, atomically: true, encoding: .utf8)
    } catch {
        print("error: could not write to \(parserFileURL.absoluteString)")
        exit(1)
    }
}

func generate(_ node: GrammarNode) {
    func commaList(_ set: Set<String>) -> String {
        let escapedSet = set.map { $0.escapesAdded }
        return "\"" + escapedSet.joined(separator: "\", \"") + "\""
    }
    switch node.kind {
    case .SEQ(let children):
        for child in children {
            generate(child)
        }
    case .ALT(let children):
        emit(dent: .NR, "switch token.type {")
        for child in children {
            emit(dent: .LR, "case \(commaList(child.first)):")
            generate(child)
        }
        emit(dent: .LR, "default:")
        emit("expect([\(commaList(node.first))])")
        emit(dent: .LN, "}")
    case .OPT(let child):
        emit(dent: .NR, "if [\(commaList(child.first))].contains(token.type) {")
        generate(child)
        emit(dent: .LN, "}")
    case .REP(let child):
        emit(dent: .NR, "while [\(commaList(child.first))].contains(token.type) {")
        generate(child)
        emit(dent: .LN, "}")
    case .NTR(var name, _):
        if name.first!.isNumber {
            name = "_" + name
        }
        emit(name + "()")
    case .TRM(let type):
        if type == "action" {
            if let action = actionList[node] {
                emit(action)
            }
        }
        emit("next()")
    }
}

var outputIndent = 0
enum IndentMode { case NN, LN, NR, LR, RL }

func emit(dent: IndentMode = .NN, _ items: Any..., terminator: String = "\n") {
    
    switch dent {
    case .NN: break
    case .LN: outputIndent -= 1
    case .NR: break
    case .LR: outputIndent -= 1
    case .RL: outputIndent += 1
    }
    
    for _ in 0 ..< outputIndent {
        parserContent.append("    ")
    }
    for item in items {
        parserContent.append("\(item)")
    }
    parserContent.append(terminator)
    
    switch dent {
    case .NN: break
    case .LN: break
    case .NR: outputIndent += 1
    case .LR: outputIndent += 1
    case .RL: outputIndent -= 1
    }
}
