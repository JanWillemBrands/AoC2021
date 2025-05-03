//
//  Descriptor.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

import Foundation

//struct Descriptor: Hashable {
//    let slot: GrammarNode
//    let stack: StackNode
//    let index: Int
//}
//
//func addDescriptor(slot: GrammarNode, stack: StackNode, index: Int) {
//    let si = Position(slot: slot, index: index)
//    let d = Descriptor(slot: slot, stack: stack, index: index)
////    print("addDescriptor: \(d)")
//    if stack.unique.insert(si).inserted {
//        remainder.append(d)
//        descriptorCount += 1
//    } else {
//        duplicateDescriptorCount += 1
//    }
//}
//
//func getDescriptor() -> Bool {
//    if remainder.isEmpty { return false }
//    let d = remainder.removeLast()
//    currentSlot = d.slot
//    currentCluster = d.stack
//    currentIndex = d.index
//    return true
//}

struct Descriptor: Hashable {
    let slot: GrammarNode
    let cluster: Position
    let index: Int
}

func addDescriptor(slot: GrammarNode, cluster: Position, index: Int) {
    let pos = Position(slot: slot, index: index)
    if cluster.unique.insert(pos).inserted {
        let state = Descriptor(slot: slot, cluster: cluster, index: index)
        remainder.append(state)
        descriptorCount += 1
    } else {
        duplicateDescriptorCount += 1
    }
}

func getDescriptor() -> Bool {
    if remainder.isEmpty { return false }
    let state = remainder.removeLast()
    currentSlot = state.slot
    currentCluster = state.cluster
    currentIndex = state.index
    return true
}
