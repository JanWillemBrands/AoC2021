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
    import RegexBuilder
    
    var input = ""
    
    typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)
    //: start of generated code
    """#
    emit(template)
    
    // TODO: check escapes etc.
    emit(dent: .NR, "let tokenPatterns: [String:TokenPattern] = [")
    for (kind, pattern) in terminals {
        if pattern.isKeyword {
            emit("\"", kind, "\":\t(\"", pattern.source.escapesAdded, ",\tRegex { \"", pattern.regex, "\" },\t", pattern.isKeyword, ",\t", pattern.isSkip, "),")
        } else {
            emit("\"", kind, "\":\t(\"", pattern.source.escapesAdded, ",\t", pattern.regex, ",\t", pattern.isKeyword, ",\t", pattern.isSkip, "),")
        }
    }
//    let sortedTerminals = term inals
//        .sorted { $0.key.count > $1.key.count
//            || $0.key.count == $1.key.count && $0.key < $1.key }
//    for n in sortedTerminals {
//        if n.value.isKeyword {
//            emit("\"", n.key.escapesAdded, "\":\t(\"", n.value.pattern.escapesAdded, "\",\t", n.value.regex, ",\t", n.value.isSkip, "),")
//        } else {
//            emit("\"", n.key.escapesAdded, "\":\t(#\"", n.value.pattern, "\"#,\t", n.value.regex, ",\t", n.value.isSkip, "),")
//        }
//    }
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

var indentation = 0
// IndentMode specifies the increase or decrease of indentation before and after emitting the items
enum IndentMode { case NN, LN, NR, LR, RL }

func emit(dent: IndentMode = .NN, _ items: Any..., terminator: String = "\n") {
    switch dent {
    case .NN: break
    case .LN: indentation -= 1
    case .NR: break
    case .LR: indentation -= 1
    case .RL: indentation += 1
    }
    
    for _ in 0 ..< indentation {
        parserContent.append("\t")
    }
    for item in items {
        parserContent.append("\(item)")
    }
    parserContent.append(terminator)
    
    switch dent {
    case .NN: break
    case .LN: break
    case .NR: indentation += 1
    case .LR: indentation += 1
    case .RL: indentation -= 1
    }
}
