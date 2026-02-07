# Torture Syntax Test Expectations
# This file documents expected behavior for regression testing
# Format: RULE | MESSAGE | EXPECTED | CATEGORY | NOTES

## Empty Constructs (S00-S07)
S00 | (empty) | PASS | empty | empty sequence
S01 | (empty) | PASS | empty | empty selection  
S02 | (empty) | PASS | empty | empty group
S03 | (empty) | PASS | empty | empty option
S04 | (empty) | PASS | empty | empty iteration
S05 | (empty) | PASS | empty | empty iteration non-zero
S06 | a | PASS | empty | explicit end of input
S07 | - | FAIL | empty | undefined rule (should not exist)

## Basic Constructs (S10-S24)
S10 | (empty) | PASS | basic | epsilon
S11 | a | PASS | basic | literal match
S11 | b | FAIL | basic | literal mismatch
S12 | a | PASS | basic | regex
S13 | abcd | PASS | basic | sequence
S13 | abc | FAIL | basic | incomplete sequence
S14 | a | PASS | basic | selection left
S14 | b | PASS | basic | selection right
S14 | c | FAIL | basic | neither alternative
S15 | a | PASS | basic | decomposed selection
S15 | b | PASS | basic | decomposed selection

S20 | a | PASS | basic | group
S21 | (empty) | PASS | basic | option empty
S21 | a | PASS | basic | option present
S22 | (empty) | PASS | basic | iteration zero times
S22 | a | PASS | basic | iteration one time
S22 | aa | PASS | basic | iteration many times
S23 | a | PASS | basic | iteration+ one
S23 | aa | PASS | basic | iteration+ many
S24 | (empty) | PASS | basic | literal or epsilon - empty
S24 | x | PASS | basic | literal or epsilon - x

## Indirection (S30-S39)
S30 | a | PASS | indirection | simple indirection
S31 | (empty) | PASS | indirection | nullable option empty
S31 | a | PASS | indirection | nullable option present
S32 | (empty) | PASS | indirection | nullable iteration zero
S32 | aaa | PASS | indirection | nullable iteration many
S33 | a | PASS | indirection | nullable leading - just required
S33 | aa | PASS | indirection | nullable leading - both
S34 | a | PASS | indirection | nullable trailing
S35 | aa | PASS | indirection | shared non-terminal
S36 | a | PASS | indirection | shared selection
S37 | (empty) | PASS | indirection | shared nullable selection
S38 | aa | PASS | indirection | shared tail
S39 | aa | PASS | indirection | shared head

## Recursion (S40-S57)
S40 | a | PASS | recursion | left recursion one
S40 | aa | PASS | recursion | left recursion many
S41 | a | PASS | recursion | right recursion one
S41 | aa | PASS | recursion | right recursion many
S42 | - | FAIL | recursion | mutual recursion non-productive
S43 | aa | PASS | recursion | mutual left-left
S44 | aa | PASS | recursion | mutual left-right
S45 | aa | PASS | recursion | mutual right-right
S46 | aa | PASS | recursion | mutual right-left

S50 | (empty) | PASS | recursion | right recursion zero
S50 | a | PASS | recursion | right recursion zero one
S51 | a | PASS | recursion | right recursion non-zero
S51 | aa | PASS | recursion | right recursion non-zero many
S52 | a | PASS | recursion | right recursion optional
S53 | (empty) | PASS | recursion | left recursion zero
S54 | a | PASS | recursion | left recursion non-zero
S54 | aaa | PASS | recursion | left recursion non-zero many
S55 | a | PASS | recursion | left recursion optional
S56 | (empty) | PASS | recursion | even brackets zero
S56 | aa | PASS | recursion | even brackets one pair
S56 | aaaa | PASS | recursion | even brackets two pairs
S57 | a | PASS | recursion | odd brackets one
S57 | aaa | PASS | recursion | odd brackets three

## Ambiguity (S60-S83)
S60 | a | PASS | ambiguity | ambiguous selection - should have 2 parses
S61 | (empty) | PASS | ambiguity | ambiguous option empty
S61 | a | PASS | ambiguity | ambiguous option one - 2 parses
S61 | aa | PASS | ambiguity | ambiguous option both - 3 parses
S62 | (empty) | PASS | ambiguity | ambiguous iteration
S62 | aa | PASS | ambiguity | ambiguous iteration - many parses
S63 | a | PASS | ambiguity | ambiguous iteration+ - 1 parse
S63 | aa | PASS | ambiguity | ambiguous iteration+ - multiple parses
S64 | (empty) | PASS | ambiguity | ambiguous selection nullable
S64 | a | PASS | ambiguity | ambiguous selection nullable - 2 parses

S70 | a | PASS | ambiguity | one or more - one
S70 | aa | PASS | ambiguity | one or more - many
S71 | a | PASS | ambiguity | ambiguous one or more (AMBIGUOUS)
S71 | aa | PASS | ambiguity | ambiguous one or more many (AMBIGUOUS)
S72 | aa | PASS | ambiguity | two or more - two
S72 | aaa | PASS | ambiguity | two or more - many
S73 | aa | PASS | ambiguity | ambiguous two or more (AMBIGUOUS)
S74 | a | PASS | ambiguity | one or two - one
S74 | aa | PASS | ambiguity | one or two - two
S75 | a | PASS | ambiguity | ambiguous one or two (AMBIGUOUS)
S75 | aa | PASS | ambiguity | ambiguous one or two both (AMBIGUOUS)

S80 | b | PASS | sequences | iteration halt - just halt
S80 | ab | PASS | sequences | iteration halt - one
S80 | aaab | PASS | sequences | iteration halt - many
S81 | ab | PASS | sequences | iteration+ halt
S82 | a | PASS | sequences | nullable tail
S82 | aa | PASS | sequences | nullable tail both
S83 | a | PASS | sequences | ambiguous nullable head (AMBIGUOUS)
S83 | aa | PASS | sequences | ambiguous nullable head both (AMBIGUOUS)

## Nested and Complex (S90-S95)
S90 | (empty) | PASS | nested | nested option - many empty parses
S90 | a | PASS | nested | nested option - many parses
S91 | (empty) | PASS | nested | nested iteration - many empty parses
S91 | a | PASS | nested | nested iteration - exponential parses
S92 | a | PASS | nested | nested iteration+ - exponential parses
S93 | (empty) | PASS | nested | matched brackets Γ3 empty
S93 | b | PASS | nested | matched brackets Γ3 one b
S93 | ac | PASS | nested | matched brackets Γ3 ac
S93 | aac | FAIL | nested | matched brackets Γ3 unmatched
S93 | aacc | PASS | nested | matched brackets Γ3 nested
S93 | aaaccc | PASS | nested | matched brackets Γ3 deeply nested
S94 | (empty) | PASS | nested | ambiguous brackets Γ5 empty
S94 | aac | PASS | nested | ambiguous brackets Γ5 - AMBIGUOUS
S94 | aaacc | PASS | nested | ambiguous brackets Γ5 nested - HIGHLY AMBIGUOUS
S95 | a | PASS | nested | Alfroozeh ambiguous - one
S95 | aab | PASS | nested | Alfroozeh ambiguous - ab
S95 | aac | PASS | nested | Alfroozeh ambiguous - ac - AMBIGUOUS

## Messages from TortureSyntax.apus to test
# These are the actual messages in the file that should be tested against appropriate rules
# a, b, aa, ab, ba, bb, aaa, aab, aba, abb, baa, bab, bba, bbb, x, aacc, aaaccc, aac, aaacc
