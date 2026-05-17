# Test case for C1: ALU-ALU data forwarding disabled
#
# Bug: dontForward1 is set to true.B (always prevent forwarding) in ISU.scala,
#      so data forwarding from ALU results never works. When an instruction
#      depends on the result of the immediately preceding ALU instruction, it
#      reads the stale register file value instead of the forwarded result.
#
# Test:
#   Setup: x2 = 1, x3 = 2, x5 = 0, x1 = 0
#   add x1, x2, x3   => x1 = 1 + 2 = 3
#   sub x4, x1, x5   => depends on x1
#
#   Correct (forwarding): sub reads forwarded x1 = 3, so x4 = 3 - 0 = 3
#   Buggy   (no forwarding): sub reads stale x1 = 0 from regfile, so x4 = 0 - 0 = 0

    .globl _start
_start:
    # Setup registers
    li      x2, 1           # x2 = 1
    li      x3, 2           # x3 = 2
    li      x5, 0           # x5 = 0
    li      x1, 0           # x1 = 0 (stale value in regfile)

    # Critical back-to-back ALU dependency
    add     x1, x2, x3      # x1 = 1 + 2 = 3 (ALU result, not yet written back)
    sub     x4, x1, x5      # needs forwarded x1 = 3, bug reads stale x1 = 0

    # Self-check: x4 should be 3 (correct forwarding)
    li      t1, 0x80400000
    li      t2, 3
    bne     x4, t2, fail_c1

    # Passed
    li      t0, 1
    sd      t0, 0(t1)
    j       end_c1

fail_c1:
    sd      x0, 0(t1)

end_c1:
    .word   0x0000006b
