# U1: ADDIW/ADDW sign extension error
#
# Bug: In ALU.scala line 108, SignExt changed to ZeroExt for word ops.
# 32-bit results are zero-extended instead of sign-extended.
#
# Test: addiw x2, x1, 0 where x1 has bit 31 set.
# Correct: x2 = sign_extend(x1[31:0] + 0) = 0xFFFFFFFF80000000
# Buggy:   x2 = zero_extend(x1[31:0] + 0) = 0x0000000080000000

    .section .text
    .globl _start
_start:
    # Set x1 = 0x0000000080000000 (bit 31 of 32-bit word is set)
    li x1, 0x80000000

    # addiw x2, x1, 0 -> should sign-extend the 32-bit result
    # 32-bit result of (x1 + 0)[31:0] = 0x80000000
    # Correct: sign-extend -> 0xFFFFFFFF80000000
    # Buggy:   zero-extend -> 0x0000000080000000
    addiw x2, x1, 0

    # Load expected correct result (sign-extended)
    li x3, 0xFFFFFFFF80000000

    # Compare: if x2 == x3, test passes; if x2 == zero-extended, bug is triggered
    # x3 holds the correct value
    sub x4, x2, x3
    # x4 should be 0 if correct (sign-extended)
    li x5, 0
    bne x4, x5, .fail

.pass:
    li a0, 0
    .word 0x0000006b   # custom trap (pass)

.fail:
    li a0, 1
    .word 0x0000006b   # custom trap (fail)
