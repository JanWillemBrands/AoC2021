//
//  OutputTools.swift
//  Advent
//
//  Created by Johannes Brands on 25/12/2024.
//

import OSLog
import Foundation
import AdventMacros

var trace = false
var traceIndent = 0

/// Called by the #Trace macro expansion.
/// The closure defers argument evaluation until the trace flag is checked.
/// In release builds the body is empty; @inline(__always) ensures the optimizer eliminates everything.
@inline(__always)
func _traceImpl(_ items: () -> [Any], terminator factor: String = "") {
#if DEBUG
    if trace {
        for _ in 0..<traceIndent { print(" ", terminator: "") }
        for item in items() { print("\(item)", terminator: " ") }
        print(factor)
    }
#endif
}
