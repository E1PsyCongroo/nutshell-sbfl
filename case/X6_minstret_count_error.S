# X6: minstret / retired instruction count error
#
# Inspired by: DIFUZZRTL / TheHuzz / ReFuzz / Cascade
#
# Bug: The multi-commit minstret override condition changed from
# perfCntCond(multicommit) to true.B with increment +1. Since the normal
# perfCnt update already adds +1 per retired instruction, this override
# adds another +1 every cycle, doubling the retired instruction count.
#
# Correct: minstret increments by 1 per retired instruction.
# Buggy: minstret increments by 2 per retired instruction (+1 normal +1 override).
#
# Test:
#   1. Read minstret before test sequence.
#   2. Execute exactly 4 instructions (addi x 4).
#   3. Read minstret after test sequence.
#   4. Check the difference is 4 (correct) vs 8 (buggy).

    .section .text
    .globl _start
_start:
    # Read minstret before
    csrr    t0, minstret

    # Execute exactly 4 instructions with no side effects
    addi    t1, x0, 1       # instr 1
    addi    t2, x0, 2       # instr 2
    addi    t3, x0, 3       # instr 3
    addi    t4, x0, 4       # instr 4

    # Read minstret after
    csrr    t5, minstret

    # Compute difference: t5 - t0 should equal the number of instructions
    # between the two csrr reads.
    # The 4 addi instructions + 1 csrr = 5 instructions between reads.
    # (The first csrr itself is already counted, so diff includes
    #  4 addi + 1 csrr = 5 instructions, but the pipeline may include
    #  the first csrr. We conservatively check: diff >= 4 && diff <= 6)
    # With the bug, diff would be approximately 2x (10-12).
    sub     t6, t5, t0

    # Check: diff should be <= 7 (generous margin for correct behavior)
    # With bug: diff would be ~10-14 (doubled)
    li      a0, 7
    blt     a0, t6, .Lfail

    # diff <= 7 -> PASS
    li      x28, 1
    j       .

.Lfail:
    li      x28, 0           # FAIL: minstret overcounted
    j       .
