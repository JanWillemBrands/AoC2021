//
//  Descriptor.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

import Foundation

// Paper: descriptor = (L, k, i) — grammar slot, cluster index, input index
struct Descriptor: Hashable {
    let slot: GrammarNode       // L: grammar slot
    let k: Int                  // cluster index
    let index: Int              // input index
}

// Global dedup set — matches paper's U and gogll's U
var U: Set<Descriptor> = []

func addDescriptor(slot: GrammarNode, k: Int, index: Int) {
    let d = Descriptor(slot: slot, k: k, index: index)
    if U.insert(d).inserted {
        remainder.append(d)
        descriptorCount += 1
    } else {
        duplicateDescriptorCount += 1
    }
}

func getDescriptor() -> Bool {
    if remainder.isEmpty {
        return false
    } else {
        let d = remainder.removeLast()
        currentSlot = d.slot
        currentK = d.k
        currentIndex = d.index
        return true
    }
}
