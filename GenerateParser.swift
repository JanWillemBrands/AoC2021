//
//  GenerateParser.swift
//  Advent
//
//  Created by Johannes Brands on 26/12/2024.
//

import Foundation

class ParserGenerator {
    
    let parserFile: URL
    
    init(outputFile: URL) {
        self.parserFile = outputFile
    }
    
    var content = #"""
        //: start of template code
        import Foundation
        import RegexBuilder
        
        var input = ""
        
        typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)
        
        //: start of generated code
        """#
    
    func generateParser() throws {
        
        // TODO: check escapes etc.
        emit(dent: .NR, "let tokenPatterns: [String:TokenPattern] = [")
        for (kind, pattern) in terminals.sorted(by: { !$0.value.isKeyword && $1.value.isKeyword } ) {
            if pattern.isKeyword {
                emit("\"", kind, "\":\t(", pattern.source, ",\tRegex { ", pattern.source, " },\t", pattern.isKeyword, ",\t", pattern.isSkip, "),")
            } else {
                emit("\"", kind, "\":\t(\"", pattern.source.escapesAdded, "\",\t", pattern.source, ",\t", pattern.isKeyword, ",\t", pattern.isSkip, "),")
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

        try content.write(to: parserFile, atomically: true, encoding: .utf8)
    }
    
    func generate(_ node: GrammarNode) {
        
        func commaList(_ set: Set<String>) -> String {
            let escapedSet = set.map { $0.escapesAdded }
            return "\"" + escapedSet.joined(separator: "\", \"") + "\""
        }
        
        switch node.kind {
        case .EOS:
            break
        case .T:
            emit("next()")
        case .TI:
            break
        case .C:
            break
        case .B:
            break
        case .EPS:
            break
        case .N:
            if let seq = node.seq {
                // rhs nonterminal call
                emit(node.str + "()")
                generate(seq)
            } else if let alt = node.alt {
                // lhs nonterminal declaration
                generate(alt)
            }
        case .ALT:
            emit(dent: .NR, "if token.type = .\(node.kind) {")
            if let seq = node.seq { generate(seq) }
            var alt = node
            while let nextAlt = alt.alt {
                emit(dent: .LR, "} else if token.type = .\(nextAlt.kind) {")
                if let seq = node.seq { generate(seq) }
                alt = nextAlt
            }
            emit(dent: .LN, "}")
            emit("expect([\(commaList(node.first))])")
        case .END:
            emit("// END")
        case .DO:
            emit("// DO")
        case .OPT:
            emit("// OPT")
        case .POS:
            emit("// POS")
        case .KLN:
            emit("// KLN")
            emit(dent: .NR, "while [\(commaList(node.first))].contains(token.type) {")
            generate(node.alt!)
            emit(dent: .LN, "}")
        }
        emit(node.action)
    }

    // IndentMode specifies the increase or decrease of indentation before and after emitting the items
    enum IndentMode { case NN, LN, NR, LR, RL }

    var indentation = 0
    
    func emit(dent: IndentMode = .NN, _ items: Any..., terminator: String = "\n") {
        switch dent {
        case .NN: break
        case .LN: indentation -= 1
        case .NR: break
        case .LR: indentation -= 1
        case .RL: indentation += 1
        }
        
        for _ in 0 ..< indentation {
            content.append("\t")
        }
        for item in items {
            content.append("\(item)")
        }
        content.append(terminator)
        
        switch dent {
        case .NN: break
        case .LN: break
        case .NR: indentation += 1
        case .LR: indentation += 1
        case .RL: indentation -= 1
        }
    }

}
//
//let _parserFileURL = URL(fileURLWithPath: #filePath)
//    .deletingLastPathComponent()
//    .appendingPathComponent("output")
//    .appendingPathExtension("swift")
//
//var _parserContent: String = ""
//
//func _generateParser() {
//    let template = #"""
//    //: start of template code
//    import Foundation
//    import RegexBuilder
//    
//    var input = ""
//    
//    typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)
//    
//    //: start of generated code
//    """#
//    emit(template)
//    
//    // TODO: check escapes etc.
//    emit(dent: .NR, "let tokenPatterns: [String:TokenPattern] = [")
//    for (kind, pattern) in _terminals.sorted(by: { !$0.value.isKeyword && $1.value.isKeyword } ) {
//        if pattern.isKeyword {
//            emit("\"", kind, "\":\t(", pattern.source, ",\tRegex { ", pattern.source, " },\t", pattern.isKeyword, ",\t", pattern.isSkip, "),")
//        } else {
//            emit("\"", kind, "\":\t(\"", pattern.source.escapesAdded, "\",\t", pattern.source, ",\t", pattern.isKeyword, ",\t", pattern.isSkip, "),")
//        }
//    }
//    emit(dent: .LN, "]")
//    
//    for (var name, node) in _nonTerminals {
//        if name.first!.isNumber {
//            name = "_" + name
//        }
//        emit(dent: .NR, "func ", name, "() {")
//        _generate(node)
//        emit(dent: .LN, "}")
//    }
//    
//    do {
//        try _parserContent.write(to: _parserFileURL, atomically: true, encoding: .utf8)
//    } catch {
//        print("error: could not write to \(_parserFileURL.absoluteString)")
//        exit(5)
//    }
//}
//
//func _generate(_ node: _GrammarNode) {
//    func commaList(_ set: Set<String>) -> String {
//        let escapedSet = set.map { $0.escapesAdded }
//        return "\"" + escapedSet.joined(separator: "\", \"") + "\""
//    }
//    switch node.kind {
//        
//    case .EOS:
//        break
//    case .T:
//        emit("next()")
//    case .TI:
//        break
//    case .C:
//        break
//    case .B:
//        break
//    case .EPS:
//        break
//    case .N:
//        emit(node.str + "()")
//    case .ALT:
//        emit(dent: .NR, "if token.type = \(node.kind) {")
//        _generate(node.seq!)
//        emit("expect([\(commaList(node.first))])")
//        emit(dent: .LN, "}")
//        
//    case .END:
//        break
//    case .DO:
//        break
//    case .OPT:
//        break
//    case .POS:
//        break
//    case .KLN:
//        break
//    }
//    
    //    switch node.kind {
    //    case .SEQ(let children):
    //        for child in children {
    //            generate(child)
    //        }
    //    case .ALT(let children):
    //        emit(dent: .NR, "switch token.type {")
    //        for child in children {
    //            emit(dent: .LR, "case \(commaList(child.first)):")
    //            generate(child)
    //        }
    //        emit(dent: .LR, "default:")
    //        emit("expect([\(commaList(node.first))])")
    //        emit(dent: .LN, "}")
    //    case .OPT(let child):
    //        emit(dent: .NR, "if [\(commaList(child.first))].contains(token.type) {")
    //        generate(child)
    //        emit(dent: .LN, "}")
    //    case .REP(let child):
    //        emit(dent: .NR, "while [\(commaList(child.first))].contains(token.type) {")
    //        generate(child)
    //        emit(dent: .LN, "}")
    //    case .NTR(var name, _):
    //        if name.first!.isNumber {
    //            name = "_" + name
    //        }
    //        emit(name + "()")
    //    case .TRM(let type):
    //        if type == "action" {
    //            if let action = actionList[node] {
    //                emit(action)
    //            }
    //        }
    //        emit("next()")
    //    }
//}

//// IndentMode specifies the increase or decrease of indentation before and after emitting the items
//enum IndentMode { case NN, LN, NR, LR, RL }
//
//var indentation = 0
//func emit(dent: IndentMode = .NN, _ items: Any..., terminator: String = "\n") {
//    switch dent {
//    case .NN: break
//    case .LN: indentation -= 1
//    case .NR: break
//    case .LR: indentation -= 1
//    case .RL: indentation += 1
//    }
//    
//    for _ in 0 ..< indentation {
//        _parserContent.append("\t")
//    }
//    for item in items {
//        _parserContent.append("\(item)")
//    }
//    _parserContent.append(terminator)
//    
//    switch dent {
//    case .NN: break
//    case .LN: break
//    case .NR: indentation += 1
//    case .LR: indentation += 1
//    case .RL: indentation -= 1
//    }
//}
//
