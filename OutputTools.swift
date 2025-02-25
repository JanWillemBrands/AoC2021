//
//  OutputTools.swift
//  Advent
//
//  Created by Johannes Brands on 25/12/2024.
//

import Foundation

var trace = true
var traceIndent = 0

func trace(_ items: Any..., terminator term: String = "") {
    if trace {
        for _ in 0..<traceIndent { print(" ", terminator: "")}
        items.forEach { print("\($0)", terminator: " ") }
        print(term)
    }
}

