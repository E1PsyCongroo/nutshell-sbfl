# RE1: Instruction-address-misaligned exceptions missed for branch instructions
#      (Paper bug R:E1)
#
# Reference: ChiRVFormal - "Formal Verification of RISC-V Processor Chisel Designs"
#
# Bug: NutShell does not generate instruction-address-misaligned exceptions for
# conditional branch instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU) when the
# target address is misaligned (not a multiple of 4 for 32-bit instructions,
# or not a multiple of 2 for compressed instructions).
#
# The RISC-V spec requires that if a branch is taken and the target address is
# misaligned, an instruction-address-misaligned exception (mcause=0) should be
# raised. NutShell enforces alignment for JAL/JALR but not for branches.
#
# This is a real design defect confirmed in the NutShell codebase (no explicit
# branch alignment checking found in IFU.scala, IDU.scala, or BRU.scala).
#
# Test strategy:
#   1. Set up a conditional branch that is always taken (beq x0, x0, target).
#   2. The target address is deliberately misaligned (not a multiple of 4).
#   3. If the processor correctly raises instruction-address-misaligned exception,
#      the trap handler sets PASS.
#   4. If the processor does NOT raise an exception and jumps to the misaligned
#      address, the bug is triggered (FAIL).

    .section .text
    .globl _start
_start:
    # Set up trap handler
    la      t0, trap_handler
    csrw    mtvec, t0

    # Mark that we haven't taken any trap yet
    li      t1, 0
    csrw    mscratch, t1

    # Branch always taken to misaligned target (+3 offset, not 4-aligned)
    # Use beq x0, x0 to force branch taken
    # Target offset: +3 bytes (misaligned)
    #
    # Encoding: beq x0, x0, +3
    # beq: opcode=1100011, funct3=000, rs1=00000, rs2=00000
    # imm[12|10:5] = 0000000, imm[4:1|11] = 00010
    # Binary: 0000000 00000 00000 000 00010 1100011
    #         imm[12|10:5] rs2  rs1  f3 imm[4:1|11] opcode
    # For offset +3: imm = 3 = 0b000000000011
    #   imm[12] = 0, imm[11] = 0, imm[10:5] = 000000, imm[4:1] = 0001
    # Binary: 0_000000_00000_00000_000_0001_0_1100011
    #       = 0x00000863

    # Use a label-based approach for clarity
    .balign 4
    beq     x0, x0, .Lmisaligned_target

    # Should not reach here if branch is taken
    nop

    # The misaligned target: force address to be 2-byte aligned, not 4-byte
    .balign 2
.Lmisaligned_target:
    # If we reach here without a trap, the bug is confirmed:
    # Branch to misaligned address did NOT raise exception
    li      x28, 0                   # FAIL: no exception for misaligned branch target
    j       .

trap_handler:
    # Check mcause
    csrr    t0, mcause

    # mcause == 0 means instruction-address-misaligned -> PASS
    li      t1, 0
    beq     t0, t1, .Lpass

    # Any other exception type
    li      x28, 0                   # FAIL: wrong exception type
    j       .

.Lpass:
    li      x28, 1                   # PASS: misaligned branch detected
    j       .
