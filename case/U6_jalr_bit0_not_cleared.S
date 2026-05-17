# U6: JALR target address bit0 not cleared
#
# Bug: In ALU.scala line 119, JALR target uses adderRes directly instead of
# Cat(adderRes(63,1), false.B), so bit 0 is not cleared.
#
# Test: jalr x0, 0(x1) where x1 has bit 0 set.
# Correct: target = x1 & ~1 (bit 0 cleared)
# Buggy:   target = x1 (bit 0 not cleared)
#
# Strategy: Set up x1 with an odd address (bit 0 = 1) pointing to a known
# instruction. Place a nop at the aligned address and a different instruction
# at the odd address. If bug is present, execution goes to the odd address.

    .section .text
    .globl _start
_start:
    # We use a data-driven approach to check if jalr clears bit 0
    # Load address of .target_aligned + 1 into x1
    la x1, .target_aligned
    ori x1, x1, 1    # Set bit 0 to 1

    # jalr x0, 0(x1)
    # Correct: jumps to .target_aligned (bit 0 cleared)
    # Buggy: tries to jump to .target_aligned + 1 (bit 0 not cleared)
    # With the bug, this may cause an exception or misaligned fetch
    jalr x0, 0(x1)

.target_aligned:
    # If we reach here, jalr correctly cleared bit 0
    nop

    li a0, 0
    .word 0x0000006b

# Fallback - should not reach here normally
    li a0, 1
    .word 0x0000006b
