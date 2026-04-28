#! /usr/bin/env bash
export NOOP_HOME=$(realpath "$(dirname "$0")")
export FIRTOOL=$CIRCT_HOME/build/bin/firtool
export CORPUS=$NOOP_HOME/corpus
export XFUZZ_HOME=$NOOP_HOME/sbfl
export REF=$SPIKE_HOME/difftest/build/riscv64-spike-so
