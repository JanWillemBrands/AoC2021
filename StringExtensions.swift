//
//  StringExtensions.swift
//  Advent
//
//  Created by Johannes Brands on 25/01/2021.
//

import Foundation

extension Range<String.Index> {
    var shortDescription: String { self.lowerBound.description + ":" + self.upperBound.description }
}

extension String {
    var escapesRemoved: String {
        var substitute = self
        for entity in ["\0", "\t", "\n", "\r", "\"", "\'", "\\"] {
            let escapedCharacter = entity.debugDescription.dropFirst().dropLast()
            substitute = substitute.replacingOccurrences(of: escapedCharacter, with: entity)
        }
        return substitute
    }
    
    var escapesAdded: String {
        return self.unicodeScalars.reduce("") { $0 + $1.escaped(asASCII: false)}
    }
    
    var whitespaceMadeVisible: String {
        return self.escapesAdded
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: " ", with: "·")
    }

    var validSwiftIdentifier: String {
        var valid = ""
        for c in self {
            if c.isLetter || c.isNumber {
                valid.append(c)
            } else {
                for s in c.unicodeScalars {
                    if let alias = nameAliases[s] {
                        valid.append(alias)
                    } else if let name = s.properties.name {
                        valid.append(name.capitalized)
                    } else {
                        valid.append("XXX")
                    }
                }
            }
        }
        valid = valid.replacingOccurrences(of: " ", with: "")
        if let first = valid.first {
            if first.isNumber {
                valid = "_" + valid
            }
        } else {
            valid = "_"
        }
        return valid
    }
}

// Describe string index as an integer label 0, 1, 2...
extension String.Index: CustomStringConvertible {
    public var description: String {
        String(input.distance(from: input.startIndex, to: self))
    }
}

// https://www.unicode.org/Public/draft/UCD/ucd/NameAliases.txt
let nameAliases: [UnicodeScalar:String] = [
    "\u{0000}" : "NUL",
    "\u{0001}" : "SOH",
    "\u{0002}" : "STX",
    "\u{0003}" : "ETX",
    "\u{0004}" : "EOT",
    "\u{0005}" : "ENQ",
    "\u{0006}" : "ACK",
    "\u{0007}" : "BEL",
    "\u{0008}" : "BS",
    "\u{0009}" : "HT",
    "\u{000A}" : "NL",
    "\u{000B}" : "VT",
    "\u{000C}" : "FF",
    "\u{000D}" : "CR",
    "\u{000E}" : "SO",
    "\u{000F}" : "SI",
    "\u{0010}" : "DLE",
    "\u{0011}" : "DC1",
    "\u{0012}" : "DC2",
    "\u{0013}" : "DC3",
    "\u{0014}" : "DC4",
    "\u{0015}" : "NAK",
    "\u{0016}" : "SYN",
    "\u{0017}" : "ETB",
    "\u{0018}" : "CAN",
    "\u{0019}" : "EOM",
    "\u{001A}" : "SUB",
    "\u{001B}" : "ESC",
    "\u{001C}" : "FS",
    "\u{001D}" : "GS",
    "\u{001E}" : "RS",
    "\u{001F}" : "US",
    "\u{0020}" : "SP",
    
    "\u{007F}" : "DEL"
]

