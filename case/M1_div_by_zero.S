# Test case for M1: DIV divide-by-zero semantic error
#
# Bug: Remove the `&& !divBy0` from qSignReg calculation and remove the
#      divBy0 guard in cnt.value assignment. This causes DIV by zero to
#      produce 0 (through normal signed division path) instead of -1 (all 1s).
#
# RISC-V spec (RV64): DIV rs1, rs2 where rs2=0 => quotient = -1 (all bits set)
#
# Expected (correct):  DIV x3, x1, x0  =>  x3 = 0xFFFFFFFFFFFFFFFF (-1)
# Buggy behavior:       DIV x3, x1, x0  =>  x3 = 0x0000000000000000 (0)

    .globl _start
_start:
    li x1, 42            # dividend = 42
    div x3, x1, x0       # divide by zero

    # x3 should be -1 (0xFFFFFFFFFFFFFFFF) per RISC-V spec
    # With bug, x3 = 0 (wrong)

    # Self-check: if x3 == -1, write pass (1) to address 0x80400000
    #             otherwise write fail (0) to address 0x80400000
    li x5, 0x80400000
    li x4, -1
    bne x3, x4, fail_m1
    li x6, 1
    sd x6, 0(x5)
    j end_m1
fail_m1:
    sd x0, 0(x5)
end_m1:
    # Use NutShell trap to end simulation
    .word 0x0000006b
