# X1: FENCE/FENCE.I reserved field check missing
#
# Inspired by: TheHuzz / MorFuzz / ReFuzz
#
# Bug: FENCE.I BitPat changed from strict (all fields must be zero) to permissive
# (wildcard for imm, rs1, rd). Any encoding with opcode=0001111 and funct3=001
# is decoded as FENCE.I, even when reserved fields (imm, rs1, rd) are non-zero.
#
# Per RISC-V spec, FENCE.I requires rd=x0 and rs1=x0 and imm=0.
# Non-zero values in these fields should trigger illegal instruction.
#
# Test:
#   1. Set up trap handler for illegal instruction.
#   2. Execute FENCE.I with rd=x1 (non-zero rd field).
#   3. Without patch: illegal instruction exception raised -> PASS.
#   4. With patch: instruction executes as FENCE.I, no exception -> FAIL.

    .section .text
    .globl _start
_start:
    # Set up trap handler
    la      t0, trap_handler
    csrw    mtvec, t0

    # Mark that we haven't taken any trap yet
    li      t1, 0
    csrw    mscratch, t1

    # Construct FENCE.I with rd=x1 (non-zero rd field)
    # Standard FENCE.I: 000000000000_00000_001_00000_0001111 = 0x0001000F
    # Modified (rd=x1):  000000000000_00000_001_00001_0001111 = 0x0001008F
    .word   0x0001008F

    # Should not reach here without a trap
    li      x28, 0                   # FAIL: no exception for illegal FENCE.I encoding
    j       .

trap_handler:
    # Read mcause
    csrr    t0, mcause

    # mcause == 2 means illegal instruction -> PASS
    li      t1, 2
    beq     t0, t1, .Lpass

    # Any other exception type
    li      x28, 0                   # FAIL: wrong exception type
    j       .

.Lpass:
    li      x28, 1                   # PASS: illegal FENCE.I encoding detected
    j       .
