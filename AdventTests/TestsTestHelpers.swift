//
//  TestHelpers.swift
//  Advent Tests
//
//  Created on 02/07/2026.
//

import XCTest
import Foundation

/// Helper functions and extensions for testing

extension XCTestCase {
    /// Parse a message with a specific grammar rule
    /// Returns tuple: (success, parseCount, yields)
    func parseWithRule(
        _ rule: GrammarNode,
        message: String,
        terminals: [String: TokenPattern]
    ) throws -> (success: Bool, parseCount: Int, yields: Set<Yield>) {
        // Clear global state
        crf = []
        tokens = []
        yields = []
        remainder = []
        
        // Scan the message
        try initScanner(fromString: message, patterns: terminals)
        
        // Reset parser
        resetMessageParser()
        
        // Set up initial state
        let startCluster = Position(slot: rule, index: 0)
        currentSlot = rule
        currentCluster = startCluster
        crfRoot = startCluster
        crf.insert(startCluster)
        
        // Add initial descriptors based on rule type
        if rule.kind == .N {
            // For non-terminals, we need to start with their alternates
            if let altNode = rule.alt {
                addDescriptorsForAlternates(bracket: rule, cluster: startCluster, index: 0)
            }
        } else {
            // For other nodes, just add the single descriptor
            addDescriptor(slot: rule, cluster: startCluster, index: 0)
        }
        
        // Run the parser
        parseMessage()
        
        // Calculate results
        let inputLength = tokens.count - 1  // Excluding EOS token
        let successfulYields = yields.filter { yield in
            yield.i == 0 && yield.j == inputLength
        }
        
        let success = !successfulYields.isEmpty
        let parseCount = successfulYields.count
        
        return (success, parseCount, yields)
    }
}

/// Add descriptors for all alternates of a bracket (non-terminal)
//func addDescriptorsForAlternates(bracket: GrammarNode, cluster: Position, index: Int) {
//    guard bracket.kind == .N, let altNode = bracket.alt else {
//        // Not a non-terminal or no alternates, just add the node itself
//        addDescriptor(slot: bracket, cluster: cluster, index: index)
//        return
//    }
//    
//    // Add descriptor for each alternate
//    var alt: GrammarNode? = altNode
//    while let currentAlt = alt {
//        addDescriptor(slot: currentAlt, cluster: cluster, index: index)
//        alt = currentAlt.alt
//    }
//}
