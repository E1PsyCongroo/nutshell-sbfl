# PT4: PTE R=0 W=1 Legality Check Removed
#
# Bug: In EmbeddedTLB.scala, the PTW does not detect R=0, W=1 as an illegal
#      PTE encoding. Per RISC-V spec, a leaf PTE with R=0, W=1 is reserved/
#      illegal and must cause a page fault. The legal combinations are:
#      R+W, R-only, W+R, X-only, R+X, W+X, R+W+X, and none (non-leaf).
#      R=0,W=1 is always illegal.
#
# Test strategy:
#   1. Set up a page table with a leaf PTE that has R=0, W=1 (bits: V=1, W=1, R=0).
#   2. Attempt to store a value to the mapped VA.
#   3. Check whether a page fault occurs.
#
# Expected (correct): The store triggers a page fault (access fault / illegal PTE).
#   The trap handler sets a0=0 (PASS).
# Buggy behavior: The store succeeds because the illegal PTE was not caught.
#   No trap, a0 stays 1 (FAIL).
#
# Trigger pattern: Leaf PTE with R=0, W=1; attempt a store to the mapped page.

    .section .text
    .globl _start

.equ PTE_V,          0x001
.equ PTE_W,          0x004
.equ PTE_X,          0x008
.equ PTE_A,          0x040
.equ PTE_D,          0x080

_start:
    # ---- Phase 1: Setup trap handler ----
    la      t0, mtrap_handler
    csrw    mtvec, t0

    # ---- Phase 2: Build page table with illegal PTE ----
    # L2 mega-page PTE: R=0, W=1 (illegal!), V=1, A=1, D=1
    # Maps VPN[2]=0 region to PA of data_page
    la      t0, data_page
    srli    t0, t0, 12
    slli    t0, t0, 10
    li      t1, PTE_V | PTE_W | PTE_A | PTE_D   # R=0, W=1 -> illegal
    or      t0, t0, t1
    la      t1, l2_pte_illegal
    sd      t0, 0(t1)

    # ---- Phase 3: Enable paging ----
    la      t0, pt_root
    srli    t0, t0, 12
    li      t1, 8
    slli    t1, t1, 60
    or      t0, t0, t1
    csrw    satp, t0

    sfence.vma

    # ---- Phase 4: Attempt store to mapped VA ----
    # We expect a page fault (PASS). If no fault, the bug let it through (FAIL).
    li      a0, 1                # FAIL by default (no trap taken)
    li      t0, 0x1234
    li      t1, 0x1000           # VA in the mapped mega-page region
    sd      t0, 0(t1)            # store to illegal-PTE page

    # If we reach here, no fault was raised -> bug confirmed
    # a0 is already 1 (FAIL)
    j       .end

    # ---- M-mode trap handler ----
mtrap_handler:
    # We got a trap -> the illegal PTE was correctly detected
    csrr    t0, mcause
    # mcause should be 13 (store page fault) or 15 (store/AMO access fault)
    li      t1, 13
    beq     t0, t1, .trap_pass
    li      t1, 15
    beq     t0, t1, .trap_pass   # access fault also acceptable
    li      t1, 12
    beq     t0, t1, .trap_pass   # instruction page fault also acceptable
    j       .                    # unexpected cause, halt

.trap_pass:
    li      a0, 0                # PASS: illegal PTE was caught

.end:
    .word 0x0000006b

    .section .data
.balign 4096
data_page:
    .dword 0

.balign 4096
pt_root:
l2_pte_illegal:
    .dword 0                     # PTE[0] with illegal R=0,W=1
    .rept 511
    .dword 0
    .endr
