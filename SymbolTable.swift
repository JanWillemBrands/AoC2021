//
//  SymbolTable.swift
//  Advent
//
//  Created by Johannes Brands on 24/06/2024.
//

import Foundation
import OrderedCollections

// TODO: use an OrderedSet instead?
var symbolTable: OrderedSet<String> = []
func symbolString(at index: Int) -> String {
    symbolTable[index]
}
func symbolIndex(of string: String) -> Int {
    if let index = symbolTable.firstIndex(of: string) {
        return index
    }
    symbolTable.append(string)
    return symbolTable.count - 1
}

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
