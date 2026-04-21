//
//  Descriptor.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

// Paper: descriptor = (L, k, i) — grammar slot, cluster index, input index
import OSLog

/// Packed token position: upper bits = token array index, lower bits = character offset within token.
/// Character offset 0 = normal position. Character offset > 0 = Frankenstein sub-position
/// (mid-token split, e.g. ">>" being consumed as two separate ">").
struct TokenPosition: Hashable, Comparable, CustomStringConvertible {
    private static let shift = 4
    private static let mask: Int32  = 0xF

    var bits: Int32

    var tokenIndex: Int         { Int(bits) >> Self.shift }
    var charOffset: Int         { Int(bits & Self.mask) }

    init(token: Int, charOffset: Int = 0) {
        self.bits = Int32(token << Self.shift | charOffset)
    }

    private init(bits: Int32) { self.bits = bits }

    func nextToken() -> TokenPosition { TokenPosition(token: tokenIndex + 1) }
    func at(charOffset: Int) -> TokenPosition { TokenPosition(token: tokenIndex, charOffset: charOffset) }

    static let zero = TokenPosition(bits: 0)
    static let unused = TokenPosition(bits: -1)

    static func < (lhs: TokenPosition, rhs: TokenPosition) -> Bool { lhs.bits < rhs.bits }

    var description: String {
        charOffset == 0 ? "\(tokenIndex)" : "\(tokenIndex).\(charOffset)"
    }
}

struct Descriptor: Hashable {
    let L: GrammarNode          // grammar slot
    let k: TokenPosition        // cluster index
    let i: TokenPosition        // input index
    // MemoryLayout<Descriptor>.size = 16 bytes (8 + 4 + 4)
}

// MARK: - MessageParser Descriptor Operations

extension MessageParser {

    // Paper: dscAdd(L, k, i)
    func addDescriptor(L: GrammarNode, k: TokenPosition, i: TokenPosition) {
        let d = Descriptor(L: L, k: k, i: i)
        if unique.insert(d).inserted {
            remaining.append(d)
            descriptorCount += 1
        } else {
            duplicateDescriptorCount += 1
        }
    }

    // Paper: get next descriptor from R
    func getDescriptor() -> Bool {
        if remaining.isEmpty {
            return false
        } else {
            let d = remaining.removeLast()
            cL = d.L
            cU = d.k
            cI = d.i
            return true
        }
    }
}
