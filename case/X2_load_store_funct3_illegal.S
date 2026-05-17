# X2: Illegal LOAD/STORE funct3 encoding not rejected
#
# Inspired by: ReFuzz / SimFuzz
#
# Bug: SW BitPat changed from funct3=010 to funct3=???, matching all funct3
# values for opcode 0100011 (STORE). Store instructions with undefined funct3
# (e.g., 111) are decoded as SW instead of raising illegal instruction.
#
# Per RISC-V spec, valid store funct3 values are: 000(SB), 001(SH), 010(SW), 011(SD).
# Values 100-111 are reserved and must cause illegal instruction.
#
# Test:
#   1. Set up trap handler for illegal instruction.
#   2. Execute a store with funct3=111 (undefined encoding).
#   3. Without patch: illegal instruction exception raised -> PASS.
#   4. With patch: instruction executes as SW, no exception -> FAIL.
#
# The test instruction is encoded as:
#   opcode=0100011, funct3=111, rs1=x0, rs2=x5, imm=0
#   Binary: 0000000_00101_00000_111_00000_0100011 = 0x00503023

    .section .text
    .globl _start
_start:
    # Set up trap handler
    la      t0, trap_handler
    csrw    mtvec, t0

    # Mark that we haven't taken any trap yet
    li      t1, 0
    csrw    mscratch, t1

    # Execute store with illegal funct3=111
    # Encoding: sw x5, 0(x0) but with funct3=111 instead of 010
    # 0000000 00101 00000 111 00000 0100011
    .word   0x00503023

    # Should not reach here without a trap
    li      x28, 0                   # FAIL: no exception for illegal store funct3
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
    li      x28, 1                   # PASS: illegal store funct3 detected
    j       .
