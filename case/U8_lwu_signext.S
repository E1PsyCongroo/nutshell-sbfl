# U8: LWU zero extension error
#
# Bug: In UnpipelinedLSU.scala (LSExecUnit), LWU uses SignExt instead of ZeroExt.
# LWU should zero-extend a 32-bit load, but the bug sign-extends it.
#
# Test: Store 0xFFFFFFFF to memory, load with LWU.
# Correct (LWU zero-extends): result = 0x00000000FFFFFFFF
# Buggy (LWU sign-extends):   result = 0xFFFFFFFFFFFFFFFF

    .section .data
.word_val:
    .word 0xFFFFFFFF
    .word 0x00000000

    .section .text
    .globl _start
_start:
    # Get address of the test word
    la x1, .word_val

    # Store 0xFFFFFFFF to memory
    li x2, 0xFFFFFFFF
    sw x2, 0(x1)

    # Load word unsigned with LWU (should zero-extend)
    # Correct: zero-extend 0xFFFFFFFF -> 0x00000000FFFFFFFF
    # Buggy:   sign-extend 0xFFFFFFFF -> 0xFFFFFFFFFFFFFFFF
    lwu x3, 0(x1)

    # Expected correct result: 0x00000000FFFFFFFF
    li x4, 0xFFFFFFFF

    # Compare
    # In RV64, li x4, 0xFFFFFFFF gives 0x00000000FFFFFFFF (positive 32-bit value)
    sub x5, x3, x4
    li x6, 0
    bne x5, x6, .fail

.pass:
    li a0, 0
    .word 0x0000006b

.fail:
    li a0, 1
    .word 0x0000006b
