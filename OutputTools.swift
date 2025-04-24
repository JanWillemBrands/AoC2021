//
//  OutputTools.swift
//  Advent
//
//  Created by Johannes Brands on 25/12/2024.
//

import Foundation

public var trace = true
public var traceIndent = 0

@inlinable
func trace(_ items: Any..., terminator term: String = "") {
#if DEBUG
    if trace {
        for _ in 0..<traceIndent { print(" ", terminator: "")}
        items.forEach { print("\($0)", terminator: " ") }
        print(term)
    }
#endif
}
