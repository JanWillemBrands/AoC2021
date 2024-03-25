//
//  StringExtensions.swift
//  Advent
//
//  Created by Johannes Brands on 25/01/2021.
//

import Foundation
//import SwiftUI

extension String {
    
    // https://forum.graphviz.org/t/how-do-i-properly-escape-arbitrary-text-for-use-in-labels/1762/5
    var graphviz: String {
        var modified = ""
        for char in self {
            switch char {
            case "&": modified.append("&amp;")
            case "<": modified.append("&lt;")
            case ">": modified.append("&gt;")
            default: modified.append(char)
            }
        }
        return modified.escapesRemoved
    }

    var escapesRemoved: String {
        var modified = self
        for entity in ["\0", "\t", "\n", "\r", "\"", "\'", "\\"] {
            let escapedCharacter = entity.debugDescription.dropFirst().dropLast()
            modified = modified.replacingOccurrences(of: escapedCharacter, with: entity)
        }
        return modified
    }
    
    var escapesAdded: String {
        self
            .unicodeScalars
            .reduce("") { $0 + $1.escaped(asASCII: false)}
    }
    
    var whitespaceMadeVisible: String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")  // TODO: WTF?
            .replacingOccurrences(of: " ", with: "·")
            .replacingOccurrences(of: "\t", with: "→")
            .replacingOccurrences(of: "\n", with: "↵")
    }
}

extension String.Index {
    // the position in the input as a string "0", "1", "2"...
    public var inputPosition: String {
        String(input.distance(from: input.startIndex, to: self))
    }
}

extension Range<String.Index> {
    var shortDescription: String { lowerBound.inputPosition + ":" + upperBound.inputPosition }
}
