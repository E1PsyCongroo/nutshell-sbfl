# X3: Privileged CSR access check missing
#
# Inspired by: TheHuzz / MorFuzz / GoldenFuzz
#
# Bug: isIllegalMode is set to false.B in CSR.scala, so the privilege level
# check for CSR access is completely bypassed. Any privilege mode can access
# any CSR, including M-mode CSRs from U-mode.
#
# Test:
#   1. Drop privilege to U-mode via mret (after setting mstatus.MPP=U).
#   2. Attempt to read mstatus (M-mode CSR, addr 0x300) from U-mode.
#   3. Without patch: illegal instruction exception raised -> PASS.
#   4. With patch: CSR read succeeds, no exception -> FAIL.

    .section .text
    .globl _start
_start:
    # Set up trap handler
    la      t0, trap_handler
    csrw    mtvec, t0

    # Mark no trap taken yet
    li      t1, 0
    csrw    mscratch, t1

    # Set mstatus.MPP = U-mode (0b00) so mret drops to U-mode
    li      t2, 0x0000000000000000   # MPP=00 (U-mode)
    csrw    mstatus, t2

    # Set mepc to the U-mode test instruction address
    la      t3, .Lumode_test
    csrw    mepc, t3

    # Drop to U-mode via mret
    mret

.Lumode_test:
    # Now in U-mode. Attempt to read mstatus (CSR 0x300, M-mode CSR)
    # Bits [9:8] = 11 (M-mode), so privilege check should block this
    csrr    t0, mstatus

    # If we reach here, the CSR read succeeded -> bug is triggered
    li      x28, 0                   # FAIL: U-mode accessed M-mode CSR
    j       .

trap_handler:
    # Read mcause
    csrr    t0, mcause

    # mcause == 2 means illegal instruction -> PASS
    li      t1, 2
    beq     t0, t1, .Lpass

    # Any other exception type
    li      x28, 0                   # FAIL: wrong exception type
    j       .

.Lpass:
    li      x28, 1                   # PASS: privileged CSR access blocked
    j       .
