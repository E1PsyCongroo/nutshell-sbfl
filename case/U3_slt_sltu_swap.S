# U3: SLT/SLTU signedness confusion
#
# Bug: In ALU.scala lines 90-91, slt and sltu definitions are swapped.
# val slt = !adderRes(XLEN)        (this is actually unsigned compare)
# val sltu = xorRes(XLEN-1) ^ slt  (this is actually signed compare)
#
# Test: li x1, -1; li x2, 1; slt x3, x1, x2
# Correct: slt(-1, 1) signed -> 1 (since -1 < 1 in signed)
# Buggy:   slt uses unsigned compare, -1 = 0xFFFF...FF which is > 1 unsigned -> 0

    .section .text
    .globl _start
_start:
    # x1 = -1 = 0xFFFFFFFFFFFFFFFF
    li x1, -1
    # x2 = 1
    li x2, 1

    # slt x3, x1, x2
    # Correct (signed comparison): -1 < 1 -> x3 = 1
    # Buggy (uses unsigned comparison): 0xFFFF...FF < 1 -> x3 = 0
    slt x3, x1, x2

    # Expected correct result: 1
    li x4, 1

    # Compare
    sub x5, x3, x4
    li x6, 0
    bne x5, x6, .fail

.pass:
    li a0, 0
    .word 0x0000006b

.fail:
    li a0, 1
    .word 0x0000006b
