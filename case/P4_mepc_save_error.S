# P4: mepc Save Error
#
# Bug: On trap to M-mode, mepc is set to PC+4 instead of PC.
#      The RISC-V spec requires mepc = PC of the trapping instruction.
#
# Test strategy:
#   1. In M-mode, set up a trap handler.
#   2. Record the current PC before ecall.
#   3. Execute ecall (which traps to M-mode).
#   4. In the trap handler, read mepc and compare with the expected PC.
#      - Expected (correct): mepc == PC of the ecall instruction.
#      - Buggy: mepc == PC of ecall + 4.
#
# We use a label at the ecall to know its exact address.
# The handler computes: mepc - ecall_addr.
# If difference is 0 -> PASS (correct), if 4 -> FAIL (bug).

    .section .text
    .globl _start
_start:
    # Set up trap handler
    la      t0, mtrap_handler
    csrw    mtvec, t0

    # Save the address of the ecall instruction for comparison
    la      t1, ecall_point
    csrw    mscratch, t1         # use mscratch to save ecall addr

    # Execute ecall to trigger M-mode exception
ecall_point:
    ecall                        # this traps to mtrap_handler

    # Should not reach here (handler jumps to done)
    j       .

# ---- M-mode trap handler ----
mtrap_handler:
    # Read mepc and compare with the saved ecall address
    csrr    t0, mepc             # t0 = mepc (should be PC of ecall)
    csrr    t1, mscratch         # t1 = address of ecall_point label

    # Compute difference: mepc - ecall_addr
    sub     t2, t0, t1

    # If difference == 0, correct (PASS). If difference == 4, buggy (FAIL).
    li      x28, 0               # default FAIL
    bnez    t2, done             # if diff != 0, bug detected, x28=0
    li      x28, 1               # diff == 0 -> PASS

done:
    j       .                    # halt
