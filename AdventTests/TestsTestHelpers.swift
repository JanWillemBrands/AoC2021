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
    /// Returns tuple: (success, parseCount, bsrSet)
    func parseWithRule(
        _ rule: GrammarNode,
        message: String,
        terminals: [String: TokenPattern]
    ) throws -> (success: Bool, parseCount: Int, bsrSet: Set<BSR>) {
        // Clear global state
        crf = [:]
        crfReturnNodes = []
        U = []
        tokens = []
        bsrSet = []
        R = []
        
        // Scan the message
        try initScanner(fromString: message, patterns: terminals)
        
        // Reset parser with the rule as root
        resetMessageParser(root: rule)
        
        // Set cL to the rule (matching what main.swift does with grammarRoot)
        cL = rule
        
        // Add initial descriptors based on rule type
        if rule.kind == .N {
            // TODO:  check this entire structure because I'm not sure this works universally
            // For non-terminals, add descriptors for their alternates
            if let altNode = rule.alt {
                ntAdd(X: rule, k: 0, i: 0)
            }
        } else {
            // For other nodes, just add the single descriptor
            dscAdd(L: rule, k: 0, i: 0)
        }
        
        // Run the parser
        parseMessage()
        
        // Calculate results
        let inputLength = tokens.count - 1  // Excluding EOS token
        let successfulResults = bsrSet.filter { bsr in
            bsr.i == 0 && bsr.j == inputLength
        }
        
        let success = !successfulResults.isEmpty
        let parseCount = successfulResults.count
        
        return (success, parseCount, bsrSet)
    }
}
