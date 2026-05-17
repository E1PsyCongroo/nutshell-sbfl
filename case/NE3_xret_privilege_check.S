# NE3: Missing privilege checking in xRET execution (Paper bug N:E3)
#
# Reference: ChiRVFormal - "Formal Verification of RISC-V Processor Chisel Designs"
#
# Bug: According to the RISC-V ISA specification, an xRET instruction (x = M, S)
# can only be executed in a privilege mode that is the same as or higher than x.
# SRET from U-mode should raise an illegal instruction exception.
# NutShell does not check the current privilege mode before executing xRET.
#
# This is a real design defect found by formal verification in the original NutShell.
# No patch is needed — the bug already exists in the current codebase.
#
# Test strategy (from the paper):
#   1. Set mstatus.SPP = 0, so the first SRET drops privilege to U-mode.
#   2. Set sepc to a known target.
#   3. Execute first SRET — privilege drops to U-mode.
#   4. Execute second SRET — should raise illegal instruction exception
#      because U-mode cannot execute SRET. But NutShell doesn't check,
#      so the second SRET succeeds (bug).
#   5. After second SRET, check if we're still running without a trap.

    .section .text
    .globl _start
_start:
    # Set up trap handler
    la      t0, trap_handler
    csrw    mtvec, t0

    # ---- Setup mstatus for SRET ----
    # SPP = 0 (bit 8) so SRET returns to U-mode
    # SPIE = 1 (bit 5) to enable interrupts after return
    li      t0, 0x00000020           # SPP=0, SPIE=1
    csrw    mstatus, t0

    # Set sepc to the target after first SRET
    la      t0, after_first_sret
    csrw    sepc, t0

    # Execute first SRET -> drops to U-mode (SPP=0 -> U-mode)
    sret

after_first_sret:
    # We should now be in U-mode.
    # Second SRET from U-mode should raise illegal instruction.
    # Save expected behavior flag
    li      t1, 1                    # mark: we are at second SRET
    csrw    mscratch, t1             # save flag

    # This SRET should trap (illegal instruction in U-mode)
    sret

    # If we reach here, the second SRET did NOT trap -> BUG
    li      x28, 0                   # FAIL: no exception raised
    j       .

trap_handler:
    csrr    t0, mcause
    # If mcause == 2 (illegal instruction), that's the correct behavior
    li      t1, 2
    beq     t0, t1, .Lpass

    # Any other cause is unexpected
    li      x28, 0                   # FAIL: wrong exception
    j       .

.Lpass:
    li      x28, 1                   # PASS: illegal instruction caught
    j       .
