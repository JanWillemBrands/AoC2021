//
//  SymbolTable.swift
//  Advent
//
//  Created by Johannes Brands on 24/06/2024.
//

import Foundation

var nameValues: [String] = []
var nameIndices: [String:Int] = [:]

func nameValue(at index: Int) -> String {
    nameValues[index]
}

func nameIndex(of value: String) -> Int {
    if let index = nameIndices[value] {
        return index
    }
    nameValues.append(value)
    let index = nameValues.count - 1
    nameIndices[value] = index
    return index
}

//print(index(of: "aap"))
//print(index(of: "noot"))
//print(index(of: "mies"))
//print(index(of: "mies"))
//print(value(at: 0))
//print(value(at: 1))
//print(value(at: 2))
