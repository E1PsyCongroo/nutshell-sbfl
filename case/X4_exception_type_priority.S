# X4: Exception type / priority error for memory access faults
#
# Inspired by: MorFuzz / SimFuzz
#
# Bug: The load and store address misaligned exception signals are swapped
# in EXU.scala. When a store address misaligned exception fires, it is reported
# as load address misaligned (mcause=4), and vice versa.
#
# This represents a class of processor bugs where the exception TYPE is
# incorrectly identified, analogous to PMP/PMA exception type confusion.
#
# Test:
#   1. Set up trap handler.
#   2. Execute a misaligned store (sw to address 3, which is not 4-aligned).
#   3. In trap handler, check mcause.
#   4. Correct: mcause = 6 (store address misaligned).
#   5. With bug: mcause = 4 (load address misaligned).

    .section .text
    .globl _start
_start:
    # Set up trap handler
    la      t0, trap_handler
    csrw    mtvec, t0

    # Prepare a value to store
    li      t1, 0x12345678

    # Execute misaligned store: sw to address 3
    # Address 3 is not 4-byte aligned -> store address misaligned
    li      t2, 3
    sw      t1, 0(t2)

    # Should not reach here (trap expected)
    li      x28, 0                   # FAIL: no exception for misaligned store
    j       .

trap_handler:
    # Read mcause
    csrr    t0, mcause

    # mcause == 6 means store address misaligned -> PASS
    li      t1, 6
    beq     t0, t1, .Lpass

    # mcause == 4 means load address misaligned -> FAIL (bug triggered)
    # Any other exception type -> FAIL
    li      x28, 0                   # FAIL: wrong exception code
    j       .

.Lpass:
    li      x28, 1                   # PASS: correct store misaligned exception
    j       .
