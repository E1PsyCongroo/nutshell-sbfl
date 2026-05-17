# P6: MRET Restore Privilege Mode Error
#
# Bug: On mret, privilegeMode is always set to ModeU instead of being
#      restored from mstatus.MPP. Even if MPP=3 (M-mode), the processor
#      drops to U-mode after mret.
#
# Test strategy:
#   1. In M-mode, set mstatus.MPP = M-mode (3) so mret should return to M-mode.
#   2. Set mepc to a target address.
#   3. Execute mret.
#   4. After mret, use ecall to check the current privilege mode.
#      - M-mode ecall -> mcause = 11 (ecallM) -> PASS
#      - U-mode ecall -> mcause = 8 (ecallU) -> FAIL (bug)

    .section .text
    .globl _start
_start:
    # Set up trap handler
    la      t0, mtrap_handler
    csrw    mtvec, t0

    # Set mstatus.MPP = M-mode (3), so mret should return to M-mode
    # MPP is bits [12:11] of mstatus
    csrr    t1, mstatus
    li      t2, 0x1800           # MPP bits at [12:11]
    or      t1, t1, t2           # set MPP = 11 (M-mode)
    csrw    mstatus, t1

    # Set mepc to the post-mret code
    la      t0, after_mret
    csrw    mepc, t0

    # Execute mret -- should return to M-mode (since MPP=3)
    mret

after_mret:
    # After mret, we should be in M-mode.
    # Use ecall to check: M-mode ecall -> mcause=11, U-mode ecall -> mcause=8
    # Save expected cause code
    li      t0, 11               # expected: ecallM = 11
    csrw    mscratch, t0         # save expected value
    ecall

    j       .

# ---- M-mode trap handler ----
mtrap_handler:
    # Read mcause and compare with expected value in mscratch
    csrr    t0, mcause
    csrr    t1, mscratch

    # t1 = 11 (ecallM, expected if still in M-mode)
    # If bug: t0 = 8 (ecallU, because dropped to U-mode)
    sub     t2, t0, t1

    # If mcause == expected (11) -> PASS, else -> FAIL
    li      x28, 0               # default FAIL
    bnez    t2, done             # mcause != expected -> bug
    li      x28, 1               # mcause == 11 -> PASS

done:
    j       .                    # halt
