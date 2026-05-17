# Test case for E2: Load exception - faulting load still writes destination register
#
# Bug: Load/store misalignment and TLB page fault checks are removed from rfWen
#      in EXU.scala. When a load causes an address misalignment fault, the
#      destination register should NOT be written, but the bug allows writeback.
#
# Test:
#   1. Set x5 to sentinel value 0xdeadbeef
#   2. Execute lw x5, 1(x0) -- load word from address 1 (misaligned for lw)
#   3. The load triggers loadAddrMisaligned exception.
#
#   Correct: x5 remains 0xdeadbeef (exception blocked writeback)
#   Buggy:   x5 has been overwritten with whatever was at address 1

    .globl _start
_start:
    # Set up mtvec to point to our exception handler
    la      t0, exc_handler
    csrw    mtvec, t0

    # Set x5 to sentinel value 0xdeadbeef
    li      t1, 0xdeadbeef
    mv      x5, t1

    # Misaligned load: lw from address 1 (not 4-byte aligned)
    # This triggers loadAddrMisaligned exception.
    # x5 should NOT be written, but the bug allows it.
    lw      x5, 1(x0)

    # Self-check: x5 should still be 0xdeadbeef
    li      t1, 0x80400000
    li      t2, 0xdeadbeef
    bne     x5, t2, fail_e2

    # Passed
    li      t0, 1
    sd      t0, 0(t1)
    j       end_e2

fail_e2:
    sd      x0, 0(t1)

end_e2:
    .word   0x0000006b

exc_handler:
    # Skip the faulting instruction by advancing mepc by 4
    csrr    t0, mepc
    addi    t0, t0, 4
    csrw    mepc, t0
    mret
