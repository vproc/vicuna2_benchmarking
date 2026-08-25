#!/usr/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ETISS_BASE_DIR="$(dirname "$SCRIPT_DIR")"
M2ISAR_DIR="$ETISS_BASE_DIR/M2-ISA-R"
RVV_COREDSL_DIR="$ETISS_BASE_DIR/etiss_arch_riscv"

source "$M2ISAR_DIR/venv/bin/activate"
coredsl2_parser "$RVV_COREDSL_DIR/top.core_desc"
etiss_writer "$RVV_COREDSL_DIR/gen_model/top.m2isarmodel" --fill-mode auto