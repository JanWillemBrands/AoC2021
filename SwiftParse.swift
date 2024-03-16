//
//  SwiftParse.swift
//  Advent
//
//  Created by Johannes Brands on 14/02/2021.
//

import Foundation
import SwiftUI
import SwiftParse

struct Day19Grammar: Grammar {
    let day19Syntax = #"""
    skip            : '[ ]+'
    day19           = rule { rule }
                      "\n"
                      message { message }
    rule            = name ":" selection "\n"
    message         = ab_sequence "\n"
    selection       = sequence [ "|" sequence ]
    sequence        = ( terminal ) 1...2
    terminal        = literal | number | action
    literal         = '"[ab]"'
    name            = '[a-zA-Z0-9_]+'
    action          = '@(\\@|[^@]+?)*@'     @t.image.escape("\@")@
                                            @var n = Node(.ACT(action: t.image))@
    ab_sequence     = '[ab\\]+'
    """#
    
    func expect(_ expected: Set<String>) {
        if !expected.contains(token.kind) {
            print("Found a '\(token.kind)' but expected one of \(expected)")
        }
    }
    
    struct Production: Production {
        let name = "skip"
        var body: some Production {
            Selection()
        }
        
        var body: some Grammar {
            
            "day19" = (
                rule
                +
                REP( rule )
                +
                "\n"
                message()
                REP( message() )
            )
            .startSymbol
            
            "rule" =
                name() + ":" + selection() + "\n"
            
            "message" =
                ab_sequence()
                +
                Literal("\n")
            
            "selection") {
                sequence()
                +
                OPT( "|" + sequence() )
            
            "sequence" =
                Group(repeats: 1...2) {
                    terminal()
                }
            
            "terminal" =
                ( literal()
                | number()
                | action()
                )
            
            "literal" = '\"[ab]\"'
            
            "name" =
                Regex("[a-zA-Z0-9_]+")
            
            "action" = '@(\\@|[^@]+?)*@' {
                t.image.escape("\@")
                var n = Node(.ACT(action: t.image))
            }
            
            Production("ab_sequence") {
                Regex("[ab\\]+")
            }
        }
    }
    
    
    struct IconView_Previews: PreviewProvider {
        let input = #"""
    a
    a\
    b
    bb
    ab
    ba
    aaaa
    abab
    bbbbba
    """#
        static var previews: some Grammar {
            Day19Grammar()
        }
    }
}
