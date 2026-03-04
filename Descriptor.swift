//
//  Descriptor.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

import Foundation

// Paper: descriptor = (L, k, i) — grammar slot, cluster index, input index
// Paper: R = pending descriptors, U = processed descriptors (dedup set)
struct Descriptor: Hashable {
    let slot: GrammarNode       // L: grammar slot
    let k: Int                  // cluster index
    let i: Int                  // input index
}

// Global dedup set — matches paper's U
var U: Set<Descriptor> = []

// Paper: R — pending descriptor list
var R: [Descriptor] = []

// Paper: dscAdd(L, k, i)
func dscAdd(L: GrammarNode, k: Int, i: Int) {
    let d = Descriptor(slot: L, k: k, i: i)
    if U.insert(d).inserted {
        R.append(d)
        descriptorCount += 1
    } else {
        duplicateDescriptorCount += 1
    }
}

// Paper: get next descriptor from R
func dscGet() -> Bool {
    if R.isEmpty {
        return false
    } else {
        let d = R.removeLast()
        cL = d.slot
        cU = d.k
        cI = d.i
        return true
    }
}
