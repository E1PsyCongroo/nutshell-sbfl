# X5: LR/SC reservation handling error
#
# Inspired by: DIFUZZRTL / MorFuzz / GenHuzz
#
# Bug: setLrVal is changed from lrReq to true.B, so the LR/SC reservation
# is always set to valid (true) on both LR and SC operations. After a
# successful SC, the reservation should be cleared, but with this bug it
# remains set. A second SC to the same address succeeds when it should fail.
#
# Per RISC-V spec, SC must fail if no outstanding reservation exists.
# After a successful SC, the reservation is cleared, so a subsequent SC
# to the same address without an intervening LR must fail.
#
# Test:
#   1. LR.W to an address -> sets reservation.
#   2. SC.W to the same address -> succeeds, clears reservation (correct).
#   3. SC.W to the same address again -> should FAIL (reservation cleared).
#      With bug: succeeds (reservation never cleared).

    .section .text
    .globl _start
_start:
    # Use a scratch memory area for LR/SC
    la      a0, .Lscratch

    # Clear scratch memory
    sd      x0, 0(a0)

    # Step 1: LR.W - load reserved
    lr.d    t0, (a0)

    # Step 2: SC.W - store conditional (should succeed)
    li      t1, 0xDEADBEEF
    sc.d    t2, t1, (a0)
    # t2 = 0 means SC succeeded

    # Step 3: SC.W again without LR - should fail (t2 != 0)
    li      t3, 0xCAFEBABE
    sc.d    t4, t3, (a0)
    # t4 should be nonzero (SC failed, reservation was cleared)

    # Check: second SC should have failed
    bnez    t4, .Lpass

    # Second SC succeeded -> bug triggered
    li      x28, 0                   # FAIL: reservation not cleared after SC
    j       .

.Lpass:
    li      x28, 1                   # PASS: reservation properly cleared
    j       .

.balign 8
.Lscratch:
    .dword 0
