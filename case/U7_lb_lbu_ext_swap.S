# U7: LB/LBU sign/zero extension swap error
#
# Bug: In UnpipelinedLSU.scala (LSExecUnit), the extensions for lb and lbu are swapped.
# lb does ZeroExt instead of SignExt, and lbu does SignExt instead of ZeroExt.
#
# Test: Store byte 0x80 to memory, then load with LB.
# Correct (LB sign-extends): result = 0xFFFFFFFFFFFFFF80
# Buggy (LB zero-extends):   result = 0x0000000000000080

    .section .data
.byte_val:
    .byte 0x80, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00

    .section .text
    .globl _start
_start:
    # Get address of the test byte
    la x1, .byte_val

    # Store 0x80 to memory (ensure the byte is there)
    li x2, 0x80
    sb x2, 0(x1)

    # Load byte with LB (should sign-extend)
    # Correct: sign-extend 0x80 -> 0xFFFFFFFFFFFFFF80
    # Buggy:   zero-extend 0x80 -> 0x0000000000000080
    lb x3, 0(x1)

    # Expected correct result: 0xFFFFFFFFFFFFFF80
    li x4, -128

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
