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
        crf = [:]
        crfReturnNodes = []
        U = []
        tokens = []
        yields = []
        remainder = []
        
        // Scan the message
        try initScanner(fromString: message, patterns: terminals)
        
        // Reset parser with the rule as root
        resetMessageParser(root: rule)
        
        // Set currentSlot to the rule (matching what main.swift does with grammarRoot)
        currentSlot = rule
        
        // Add initial descriptors based on rule type
        if rule.kind == .N {
            // TODO:  check this entire structure because I'm not sure this works universally
            // For non-terminals, add descriptors for their alternates
            if let altNode = rule.alt {
                addDescriptorsForAlternates(bracket: rule, k: 0, index: 0)
            }
        } else {
            // For other nodes, just add the single descriptor
            addDescriptor(slot: rule, k: 0, index: 0)
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
