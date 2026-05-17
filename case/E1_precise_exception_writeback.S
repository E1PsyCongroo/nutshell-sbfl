# Test case for E1: Precise exception - instruction after ecall still writes back
#
# Bug: wenFix check is removed from rfWen in EXU.scala, so when an exception
#      (ecall) fires, the write-enable fix signal does not block writeback.
#      The instruction immediately following ecall still performs its register
#      write even though it should be squashed for precise exceptions.
#
# Test:
#   x5 is initialized to 0.
#   ecall triggers an exception; the handler returns without modifying x5.
#   addi x5, x0, 1 is the next instruction in memory.
#
#   Correct: Precise exception prevents addi from writing back.
#            After returning from the handler, x5 = 0.
#   Buggy:   addi x5, x0, 1 writes back anyway.
#            After returning from the handler, x5 = 1.

    .globl _start
_start:
    # Set up mtvec to point to our exception handler
    la      t0, exc_handler
    csrw    mtvec, t0

    # Initialize x5 to 0
    li      x5, 0

    # Execute ecall; addi x5, x0, 1 immediately follows in memory.
    # With the bug, addi still writes x5 = 1 even though it should be killed.
    ecall
    addi    x5, x0, 1       # should NOT write x5 (precise exception), bug: x5 = 1

    # Self-check: x5 should be 0 (precise exception prevented writeback)
    li      t1, 0x80400000
    bnez    x5, fail_e1

    # Passed
    li      t0, 1
    sd      t0, 0(t1)
    j       end_e1

fail_e1:
    sd      x0, 0(t1)

end_e1:
    .word   0x0000006b

exc_handler:
    # Simple exception handler: just return via mret
    mret
