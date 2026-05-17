# PT9: Superpage Alignment Check Error - Mask Always Uses Leaf Level
#
# Bug: In EmbeddedTLB.scala line 346, missMask always uses leaf-level mask:
#   missMask := "h3ffff".U(maskLen.W)
# For a 2MiB superpage (level 2), the mask should be 0x3fe00 (mask vpn0 only),
# but the bug uses 0x3ffff (masks nothing), so all VPN bits are matched
# exactly. This means a 2MiB superpage only matches its first 4KiB page.
#
# Test strategy:
#   1. Set up a 2MiB superpage at level 2 (non-leaf at level 3, leaf at level 2).
#   2. The superpage maps VA 0x20000000-0x201FFFFF -> PA 0x20000000-0x201FFFFF.
#   3. Access VA 0x20000000 (first page) -> works with both correct and buggy mask.
#   4. Access VA 0x20001000 (second page, vpn0=1) -> correct: hits superpage
#      (mask ignores vpn0). Buggy: mask requires vpn0 match, so vpn0=1 doesn't
#      match the TLB entry with vpn0=0 from the initial fill, causing a re-walk.
#   5. We access three pages: first, second, then first again to check if the
#      superpage TLB entry was evicted incorrectly.
#
# Page table layout:
#   Root at 0x80010000:
#     PTE[0] non-leaf -> L1 at 0x80011000
#   L1 at 0x80011000:
#     PTE[0] leaf (2MiB superpage): ppn=0x20000, R=1,W=1,X=1,U=1,A=1,D=1
#     This is a leaf at level 2, so vpn0 bits should be masked.

    .section .text
    .globl _start
_start:
    la      t0, mtrap_handler
    csrw    mtvec, t0

    # ---- Build page tables ----
    # Root: PTE[0] non-leaf -> L1 at 0x80011000
    li      t0, 0x80010000
    li      t1, 0x0000000080011001
    sd      t1, 0(t0)

    # L1: PTE[0] = 2MiB superpage leaf
    # ppn=0x20000, flags: V=1,R=1,W=1,X=1,U=1,A=1,D=1 = 0xCF
    li      t0, 0x80011000
    li      t1, 0x0000000020000CF7
    sd      t1, 0(t0)

    # Write known values at different PA offsets within the superpage
    li      t0, 0x20000000
    li      t1, 0x11111111
    sw      t1, 0(t0)                # PA 0x20000000

    li      t0, 0x20001000
    li      t1, 0x22222222
    sw      t1, 0(t0)                # PA 0x20001000

    # ---- Switch to S-mode ----
    li      t0, 0x0000000800
    csrr    t1, mstatus
    li      t2, 0xFFFFFFFFFFFFF7FF
    and     t1, t1, t2
    or      t1, t1, t0
    csrw    mstatus, t1

    li      t0, 0x8000000080010
    csrw    satp, t0

    la      t0, test_in_smode
    csrw    mepc, t0
    mret

test_in_smode:
    li      x28, 1                   # PASS by default

    # Access first page (VA 0x20000000, vpn0=0)
    li      t0, 0x20000000
    lw      t1, 0(t0)
    li      t2, 0x11111111
    bne     t1, t2, .fail

    # Access second page (VA 0x20001000, vpn0=1) - should hit superpage
    # Correct: mask=0x3fe00, vpn0 is ignored, TLB hit with superpage entry
    # Buggy: mask=0x3ffff, vpn0=1 doesn't match TLB entry vpn0=0, TLB miss
    #        causes re-walk which fills a new entry with wrong mask
    li      t0, 0x20001000
    lw      t1, 0(t0)
    li      t2, 0x22222222
    bne     t1, t2, .fail

    # Re-access first page to check if superpage still covers it
    # With bug: the TLB now has vpn0=1 entry with mask=0x3ffff,
    # so vpn0=0 won't match -> miss -> re-walk -> fills vpn0=0 entry
    # This ping-pong is the bug: superpage should match all vpn0 values
    li      t0, 0x20000000
    lw      t1, 0(t0)
    li      t2, 0x11111111
    bne     t1, t2, .fail

    j       .

.fail:
    li      x28, 0                   # FAIL
    j       .

mtrap_handler:
    csrr    t0, mcause
    li      t1, 13
    bne     t0, t1, .
    li      x28, 0                   # FAIL - page fault
    j       .
