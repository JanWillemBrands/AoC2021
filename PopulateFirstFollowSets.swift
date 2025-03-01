import Foundation

/*
 EOS    end of string ("" or "$")
 T      terminal (singleton, case sensitive)
 TI     terminal (singleton, case insensitive
 C      terminal character
 B      terminal builtin (whitespace, comment, etc)
 EPS    empty string ("#" or "")
 N      nonterminal
 ALT    start of alternate
 END    end of alternate
 DO     group ()
 OPT    optional []
 POS    one or more <>
 KLN    zero or more (Kleene) {}
 
 END.seq references start of production 'N'
 END.alt references start of the current alternate 'ALT'
 Extends naturally to EBNF brackets if END.seq references the enclosing bracket 'DO', 'OPT', 'POS', or 'KLN'
*/

/*
 Epsilon (.EPS):
 Issue: Sets first = follow instead of first = [""].
 Fix: Set first = [""] to match FIRST(ε) = {ε}.
 
 Alternates (.ALT):
 Issue: Uses only seq.first, not unioning all alternatives.
 Fix: Replace with processAlternatives() to union all alt nodes’ first sets.
 
 Additionally, folding first \ {ε} into follow for .POS and .KLN isn’t supported by Section 2 but may be a GLL-specific adaptation (e.g., for SPPF construction in Section 5). Without further context, these are flagged with TODOs in the code and require verification.
 */
//
//extension GrammarNode {
//    /// Computes the first and follow sets for this grammar node recursively.
//    /// - Note: First sets represent the possible starting symbols of a node's derivation.
//    ///         Follow sets represent the possible symbols that can appear after a node's derivation.
//    func populateFirstFollowSets() {
//        switch kind {
//        case .EPS:
//            // Epsilon produces the empty string, so its first set is tied to what follows it
//            // In this implementation, first is set to follow, reflecting that epsilon "passes through" to subsequent symbols
//            if let seq {
//                seq.populateFirstFollowSets() // Compute sets for the next node in the sequence
//                updateFollow(with: seq)       // Follow set includes first of next node, adjusted for nullability
//            }
//            first = follow                    // Non-standard but aligns with GLL's sequence handling
//
//        case .EOS, .T, .TI, .C, .B:
//            // Terminals (end of string, literal terminals, character, built-ins) have a first set of themselves
//            first = [str]
//            if let seq {
//                seq.populateFirstFollowSets()
//                updateFollow(with: seq)       // Propagate follow set based on the next node's first set
//            }
//
//        case .N:
//            if let seq {
//                // Right-hand side (RHS) nonterminal: part of a sequence
//                seq.populateFirstFollowSets()
//                updateFollow(with: seq)
//                if let production = _nonTerminals[str] {
//                    alt = production.alt          // Link to the production's alternatives
//                    first = production.first      // Inherit first set from the LHS definition
//                } else {
//                    print("error: '\(str)' has not been defined as a grammar rule")
//                    exit(4)
//                }
//            } else {
//                // Left-hand side (LHS) nonterminal: defines a production
//                processAlternatives()         // Compute first set from alternatives; follow is preset externally
//            }
//
//        case .ALT:
//            // Alternative: represents one branch in a set of alternatives
//            if let seq {
//                seq.populateFirstFollowSets()
//                first = seq.first             // First set is the first set of this alternative's sequence
//                if first.contains("") && !seq.follow.isEmpty {
//                    // If this alternative is nullable, include symbols that can follow it
//                    first.remove("")
//                    first.formUnion(seq.follow)
//                }
//            }
//
//        case .DO:
//            // Group: ( ... ), treated as a single unit with alternatives
//            handleBrackets()
//
//        case .OPT:
//            // Optional: [ ... ], nullable by definition
//            first.insert("")                  // Can produce empty string
//            handleBrackets()
//
//        case .POS:
//            // Positive closure: < ... >, one or more occurrences
//            handleBrackets()
//            // Folding first into follow may assist GLL's repetition handling, but its necessity is questionable
//            follow.formUnion(first.subtracting([""])) // TODO: Verify if needed for GLL correctness
//
//        case .KLN:
//            // Kleene closure: { ... }, zero or more occurrences
//            first.insert("")                  // Nullable due to zero occurrences
//            handleBrackets()
//            // Folding first into follow may assist GLL's repetition handling, but its necessity is questionable
//            follow.formUnion(first.subtracting([""])) // TODO: Verify if needed for GLL correctness
//
//        case .END:
//            // End of an alternative or production
//            first = [""]                      // Indicates the end can be "empty" in sequence terms
//            follow = seq?.follow ?? []        // Follow set propagates from the production's start node
//        }
//
//        GrammarNode.sizeofSets += first.count + follow.count // Track total size for optimization metrics
//    }
//
//    /// Handles bracketed constructs (DO, OPT, POS, KLN) by processing alternatives and sequences.
//    private func handleBrackets() {
//        processAlternatives()                 // Compute first set from alternatives
//        if let seq {
//            seq.populateFirstFollowSets()
//            updateFollow(with: seq)           // Propagate follow set through the sequence
//        }
//    }
//
//    /// Processes all alternatives for a node, unioning their first sets and setting their follow sets.
//    private func processAlternatives() {
//        var currentAlt = alt
//        while let altNode = currentAlt {
//            altNode.populateFirstFollowSets()
//            first.formUnion(altNode.first)    // First set is the union of all alternatives' first sets
//            altNode.follow = follow           // Follow set propagates to each alternative
//            currentAlt = altNode.alt
//        }
//    }
//
//    /// Updates the follow set based on the next node in the sequence.
//    /// - Parameter node: The next node whose first set informs this node's follow set.
//    private func updateFollow(with node: GrammarNode) {
//        follow = node.first
//        if follow.contains("") && !node.follow.isEmpty {
//            // If the next node is nullable, include its follow set (excluding epsilon)
//            follow.remove("")
//            follow.formUnion(node.follow)
//        }
//    }
//}


extension GrammarNode {
    func populateFirstFollowSets() {
        switch kind {
        case .EPS:
            seq!.populateFirstFollowSets()
            first = [""]
            updateFollow()
        case .EOS, .T, .TI, .C, .B:
            seq!.populateFirstFollowSets()
            first = [str]
            updateFollow()
        case .N:
            handleNonTerminal()
        case .ALT:
            seq!.populateFirstFollowSets()
            first = seq!.first
        case .DO:
            handleBracket()
        case .OPT:
            first.insert("")
            handleBracket()
        case .KLN:
            first.insert("")
            handleBracket()
//             TODO: not sure following is right, even though it is in ART...
//             it complicates ambiguous because it's longer overlap(first, follow)
//             file://Users/janwillem/ART/referenceImplementation/src/uk/ac/rhul/cs/csle/art/cfg/grammar/Grammar.java
//             For closure nodes, fold first into follow
//             if (root.elm.kind == GrammarKind.POS || root.elm.kind == GrammarKind.KLN) changed |= root.instanceFollow.addAll(removeEpsilon(root.instanceFirst));
//            follow.formUnion(first.subtracting([""]))
        case .POS:
            handleBracket()
        case .END:
            first = [""]
            // the follow of .END is the follow of the .seq that started it
            follow = seq!.follow
            // if the starting node was a closure node (POS, KLN) then the first folds into the follow
            if seq!.kind == .KLN || seq!.kind == .POS {
                follow.formUnion(seq!.first.subtracting([""]))
            }
       }
        GrammarNode.sizeofSets += first.count + follow.count
    }
    
    private func handleNonTerminal() {
        if let seq {
            // a rhs nonterminal instance is part of a sequence
            seq.populateFirstFollowSets()
            updateFollow()
            if let production = _nonTerminals[str] {
                // assign the alt of the rhs to the alt of the lhs
                alt = production.alt
                // rhs first of the rhs nonterminal is equal to the first of lhs production rule
                first = production.first
                // update the follow of the lhs nonterminal as the union of the follows of all rhs nonterminals
                production.follow.formUnion(follow)
            } else {
                print("error: '\(str)' has not been defined as a grammar rule")
                exit(4)
            }
        } else {
            // a lhs nonterminal defines a production rule and is NOT part of a sequence
            handleAlternatives()
            // the follow set of a lhs nonterminal production rule is [“$”] if startsymbol, and [] otherwise.
            // both have already been set before calling populateFirstFollowSets.
        }
    }
    
    private func handleBracket() {
        handleAlternatives()
        seq!.populateFirstFollowSets()
        updateFollow()
    }
    
    private func handleAlternatives() {
        // set the first set of a lhs nonterminal production rule, or a bracketed expression, to the union of first sets of all its .alt's
        var current = alt
        while let altNode = current {
            altNode.populateFirstFollowSets()
            first.formUnion(altNode.first)
            // set the follow ALT node to the follow of the bracket so that the ALT node represents the whole sequence
            altNode.follow = follow
            current = altNode.alt
        }
    }
    
    private func updateFollow() {
        follow = seq!.first
        if follow.contains("") {
            follow.remove("")
            follow.formUnion(seq!.follow)
        }
    }
}
