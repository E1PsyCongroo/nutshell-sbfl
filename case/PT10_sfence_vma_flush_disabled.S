# PT10: SFENCE.VMA TLB Flush Disabled
#
# Bug: In EmbeddedTLB.scala line 104, flushTLB is disconnected from reset:
#   mdTLB.reset := reset.asBool
# The sfence.vma instruction no longer triggers a TLB flush. Stale TLB
# entries persist after page table updates, so the TLB returns the old
# (pre-update) physical address for a given virtual address.
#
# Test strategy:
#   1. Set up a page table mapping VA 0x20000000 -> PA 0x20000000.
#   2. In S-mode, load from VA 0x20000000 -> TLB fills, returns data from PA 0x20000000.
#   3. Write a different value to PA 0x20001000.
#   4. Modify the page table: VA 0x20000000 now maps to PA 0x20001000.
#   5. Execute sfence.vma to flush the TLB.
#   6. Load from VA 0x20000000 again.
#      Correct: TLB refilled with new PTE, reads from PA 0x20001000 -> new value.
#      Buggy: TLB still has old entry, reads from PA 0x20000000 -> old value.
#   7. Compare loaded value to detect the bug.
#
# Note: The PTE modification is done from M-mode (via ecall trap) because
# S-mode needs the page table region to be mapped for direct modification.

    .section .text
    .globl _start
_start:
    la      t0, mtrap_handler
    csrw    mtvec, t0

    # ---- Build page tables ----
    # Root: PTE[0] -> L1 at 0x80011000
    li      t0, 0x80010000
    li      t1, 0x0000000080011001
    sd      t1, 0(t0)

    # L1: PTE[0] -> L0 at 0x80012000
    li      t0, 0x80011000
    li      t1, 0x0000000080012001
    sd      t1, 0(t0)

    # L0: PTE[0] leaf: VA 0x20000000 -> PA 0x20000000, R=1,W=1,X=1,U=1
    li      t0, 0x80012000
    li      t1, 0x0000000020000CF7   # ppn=0x20000, flags=0xCF
    sd      t1, 0(t0)

    # ---- Write initial values ----
    li      t0, 0x20000000
    li      t1, 0xAAAAAAAA           # old value at PA 0x20000000
    sw      t1, 0(t0)

    li      t0, 0x20001000
    li      t1, 0xBBBBBBBB           # new value at PA 0x20001000
    sw      t1, 0(t0)

    # ---- Phase 1: S-mode accesses VA 0x20000000 -> PA 0x20000000 ----
    li      t0, 0x0000000800
    csrr    t1, mstatus
    li      t2, 0xFFFFFFFFFFFFF7FF
    and     t1, t1, t2
    or      t1, t1, t0
    csrw    mstatus, t1

    li      t0, 0x8000000080010
    csrw    satp, t0

    la      t0, smode_phase1
    csrw    mepc, t0
    mret

smode_phase1:
    # Load from VA 0x20000000 (maps to PA 0x20000000)
    li      t0, 0x20000000
    lw      t3, 0(t0)                # TLB filled with VA->PA 0x20000000

    # Trap back to M-mode to modify the page table
    ecall

mtrap_handler:
    csrr    t0, mcause
    li      t1, 9                    # ecall from S-mode
    beq     t0, t1, .modify_pte
    j       .

.modify_pte:
    # Disable VM to modify page table with physical addresses
    csrw    satp, zero

    # Change L0 PTE[0]: VA 0x20000000 -> PA 0x20001000
    # ppn = 0x20001, flags = 0xCF
    li      t0, 0x80012000
    li      t1, 0x0000000020001CF7   # ppn=0x20001 (PA 0x20001000)
    sd      t1, 0(t0)

    # Re-enable VM and return to S-mode for phase 2
    li      t0, 0x0000000800
    csrr    t1, mstatus
    li      t2, 0xFFFFFFFFFFFFF7FF
    and     t1, t1, t2
    or      t1, t1, t0
    csrw    mstatus, t1

    li      t0, 0x8000000080010
    csrw    satp, t0

    la      t0, smode_phase2
    csrw    mepc, t0
    mret

smode_phase2:
    # Execute sfence.vma to flush TLB
    sfence.vma zero, zero

    # Load from VA 0x20000000 again
    # Correct: TLB refilled, new PTE maps to PA 0x20001000 -> 0xBBBBBBBB
    # Buggy: TLB not flushed, old entry still maps to PA 0x20000000 -> 0xAAAAAAAA
    li      t0, 0x20000000
    lw      t3, 0(t0)

    li      t1, 0xBBBBBBBB           # expected correct value
    li      x28, 1                   # PASS by default
    bne     t3, t1, .bug_detected    # got old value -> bug
    j       .

.bug_detected:
    li      x28, 0                   # FAIL - TLB not flushed, old mapping used
    j       .
