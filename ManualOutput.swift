//
//  ManualOutput.swift
//  Advent
//
//  Created by Johannes Brands on 20/03/2024.
//

import Foundation

// S = "a" S "b" | "a" A "c" | "a".

var R: [Int] = [1,2,3]

func S() {
    
    enum State : CaseIterable { case A,B,C,D,E,F,G,H,I,J }
    while !R.isEmpty {
        let L = R.removeLast()
        var state = State.allCases.randomElement()!
        switch state {
        case .A:
            break
        case .B:
            state = .B
        case .C:
            state = .B
        case .D:
            state = .B
        case .E:
            state = .B
        case .F:
            state = .B
        case .G:
            state = .B
        case .H:
            state = .B
        case .I:
            state = .B
        case .J:
            state = .A
        }
    }
}


