//
//  Descriptor.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

// Paper: descriptor = (L, k, i) — grammar slot, cluster index, input index
import OSLog

struct Descriptor: Hashable {
    let L: GrammarNode          // grammar slot
    let k: Int32                // cluster index
    let i: Int32                // input index
    // using Int32 to reduce MemoryLayout<Descriptor>.size from 24 to 16 bytes
}

// MARK: - MessageParser Descriptor Operations

extension MessageParser {
    
    // Paper: dscAdd(L, k, i)
    func addDescriptor(L: GrammarNode, k: Int, i: Int) {
        let d = Descriptor(L: L, k: Int32(k), i: Int32(i))
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
            cU = Int(d.k)
            cI = Int(d.i)
            return true
        }
    }
}
