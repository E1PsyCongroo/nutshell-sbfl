# RE2: Store address-misaligned exception does not suppress memory write
#      (Injected from riscv-mini bug R:E2)
#
# Reference: ChiRVFormal - "Formal Verification of RISC-V Processor Chisel Designs"
# Original bug: In riscv-mini, when a store instruction triggers an address-
# misaligned exception, subsequent store instructions are not flushed correctly
# and still issue memory writes.
#
# Injection: In NutShell, UnpipelinedLSU.scala line 379 gates dmem.req.valid
# with !io.storeAddrMisaligned. The patch removes this check, so a misaligned
# store still issues a memory write request even though the exception is raised.
#
# Test strategy:
#   1. Write a known sentinel value (0xAAAABBBB) to an aligned address.
#   2. Execute SW to a misaligned address (offset by 1 byte) that overlaps.
#   3. The SW triggers a store-addr-misaligned exception (mcause=6).
#   4. In the trap handler, check if the sentinel was overwritten.
#      - If sentinel unchanged: correct behavior (store was suppressed)
#      - If sentinel changed: bug triggered (store wrote to memory anyway)

    .section .text
    .globl _start
_start:
    # Set up trap handler
    la      t0, trap_handler
    csrw    mtvec, t0

    # ---- Phase 1: Initialize memory with sentinel ----
    la      t0, .Ldata_area
    li      t1, 0xAAAABBBB
    sw      t1, 0(t0)              # aligned store: sentinel at .Ldata_area

    # ---- Phase 2: Trigger misaligned store ----
    # SW requires 4-byte alignment. Offset +1 makes it misaligned.
    la      t0, .Ldata_area
    addi    t0, t0, 1              # misaligned address (.Ldata_area + 1)
    li      t1, 0x12345678
    sw      t1, 0(t0)              # misaligned SW -> should raise exception

    # Should not reach here (trap expected)
    li      x28, 0                 # FAIL: no exception raised
    j       .

trap_handler:
    csrr    t0, mcause
    # Check mcause == 6 (store address misaligned)
    li      t1, 6
    bne     t0, t1, .Lwrong_exception

    # ---- Phase 3: Check if memory was corrupted ----
    la      t0, .Ldata_area
    lw      t1, 0(t0)
    li      t2, 0xAAAABBBB         # original sentinel

    # If sentinel unchanged -> store was properly suppressed -> PASS
    # If sentinel changed -> store wrote through -> BUG
    sub     t3, t1, t2
    bnez    t3, .Lcorrupted

    li      x28, 1                 # PASS: memory not corrupted
    j       .

.Lcorrupted:
    li      x28, 0                 # FAIL: misaligned store wrote to memory
    j       .

.Lwrong_exception:
    li      x28, 0                 # FAIL: unexpected exception type
    j       .

.balign 8
.Ldata_area:
    .dword 0                       # sentinel + padding
