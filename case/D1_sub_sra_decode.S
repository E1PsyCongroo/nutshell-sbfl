# Test case for D1: SUB decoded as ADD, SRA decoded as SRL
#
# Bug: In RV32I_ALUInstr.table:
#        SUB -> List(InstrR, FuType.alu, ALUOpType.add)   # BUG: should be sub
#        SRA -> List(InstrR, FuType.alu, ALUOpType.srl)   # BUG: should be sra
#
# SUB test:
#   Correct: sub x3, x1, x2  =>  x3 = 5 - 3 = 2
#   Buggy:   add x3, x1, x2  =>  x3 = 5 + 3 = 8
#
# SRA test:
#   Correct: sra x3, x1, x2  =>  x3 = (-8) >> 1 = -4 (arithmetic, sign-extended)
#   Buggy:   srl x3, x1, x2  =>  x3 = (-8) >> 1 = 0x7FFFFFFFFFFFFFFC (logical, zero-extended)

    .globl _start
_start:
    # --- Test SUB ---
    li x1, 5
    li x2, 3
    sub x3, x1, x2       # should be 2, bug gives 8

    # Self-check for SUB: x3 should be 2
    li x5, 0x80400000
    li x4, 2
    bne x3, x4, fail_d1_sub

    # --- Test SRA ---
    li x1, -8            # x1 = 0xFFFFFFFFFFFFFFF8
    li x2, 1
    sra x3, x1, x2       # should be -4 (0xFFFFFFFFFFFFFFFC), bug gives logical right shift

    # Self-check for SRA: x3 should be -4
    li x4, -4
    bne x3, x4, fail_d1

    # Both passed
    li x6, 1
    sd x6, 0(x5)
    j end_d1

fail_d1_sub:
    sd x0, 0(x5)
    j end_d1

fail_d1:
    sd x0, 0(x5)

end_d1:
    .word 0x0000006b
