//
//  Descriptor.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

// Paper: descriptor = (L, k, i) — grammar slot, cluster index, input index
struct Descriptor: Hashable {
    let L: GrammarNode          // grammar slot
    let k: Int                  // cluster index
    let i: Int                  // input index
}

var failedParses = 0
var successfullParses = 0
var descriptorCount = 0
var duplicateDescriptorCount = 0

// Paper: U - global dedup / unique descriptor set
var unique: Set<Descriptor> = []

// Paper: R — pending / remaining descriptor list
var remaining: [Descriptor] = []

// Paper: dscAdd(L, k, i)
func addDescriptor(L: GrammarNode, k: Int, i: Int) {
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
