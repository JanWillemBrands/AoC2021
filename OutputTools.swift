//
//  OutputTools.swift
//  Advent
//
//  Created by Johannes Brands on 25/12/2024.
//

//import OSLog
import Foundation
//import AdventMacros

// Trace toggle. Marked `nonisolated(unsafe)` because:
//   - In release builds the trace function is fully gated out by `#if DEBUG`.
//   - In test/debug builds the parser path that mutates trace is serialized by
//     the test infrastructure's `withParserIsolation` lock.
// Direct global access is intentional; the trace plumbing is performance-critical
// and a TaskLocal would force every call site through a closure.
nonisolated(unsafe) var trace = false
nonisolated(unsafe) var traceIndent = 0

func trace(_ items: Any..., terminator term: String = "") {
#if DEBUG
    if trace {
        for _ in 0..<traceIndent { print(" ", terminator: "")}
        items.forEach { print("\($0)", terminator: " ") }
        for item in items { print("\(item)", terminator: " ") }
        print(term)
    }
#endif
}

/// Called by the trace macro expansion.
/// The closure defers argument evaluation until the trace flag is checked.
/// In release builds the body is empty; @inline(__always) ensures the optimizer eliminates everything.
//@inline(__always)
//func _traceImpl(_ items: () -> [Any], terminator factor: String = "") {
//#if DEBUG
//    if trace {
//        for _ in 0..<traceIndent { print(" ", terminator: "") }
//        for item in items() { print("\(item)", terminator: " ") }
//        print(factor)
//    }
//#endif
//}
