#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NUTSHELL_HOME="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATASET_DIR="${NUTSHELL_HOME}/verify_dataset"

usage() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} [--all [DATASET_DIR]] [options]
  ${SCRIPT_NAME} --case <PATCH> [options]

Run every patch in verify_dataset (the default), or one selected patch, in an
isolated NutShell work directory.

Runner options:
  --all [DIR]                     Run patches listed by manifest.csv
                                  (default: ${DATASET_DIR})
  --case <PATCH>                  Run one patch
  -j, --jobs <N>                 Parallel cases (default: 1)
  -w, --workdir <DIR>            NutShell source tree (default: repository root)
  -t, --tmp <DIR>                Temporary root (default: /tmp/${SCRIPT_NAME%.sh})
  -l, --logs <DIR>               Result root (default: ./logs)
  --keep-workdir                 Keep per-case work directories
  --build-cmd <COMMAND>          Build command (default: make sbfl -B)
  --fuzzer-bin <PATH>            Fuzzer path relative to each workdir
                                  (default: build/fuzzer)

PSBFL options:
  -c, --coverage <COVERAGE>      Default: verilator.line,verilator.branch
  -s, --state <STATE>            Default: PCState,ArchIntRegState,CSRState
  --reduce-insts                 Enabled by default
  --no-reduce-insts              Disable instruction reduction
  --reduce-cover                 Enable coverage reduction
  --no-reduce-cover              Disable coverage reduction (default)
  --save-reduce                  Enabled by default
  --no-save-reduce               Do not save reduced inputs
  --save-trace                   Enabled by default
  --no-save-trace                Do not save traces
  --max-iters <N>                Default: 20
  --max-run-timeout <N>          Default: 180
  --tracker-window-size <N>      Default: 20
  --mutator-window-size <N>      Default: 5
  --mutator-weight-strategy <S>  Default: head_quad
  --cover-distance-weight <W>    Default: 0.5
  --top-pass <N>                 Default: 120
  --top-sus <N>                  Default: 50
  --selection <random|sort>      Default: sort
  --corpus-input <PATH>          Default: ready-to-run/microbench-riscv64-nutshell.elf
  --rtl-path <PATH>              RTL source directory
  --include-paths <PATHS>        Comma-separated RTL include paths
  --top-module <MODULE>          RTL top module (requires --rtl-path/--top-scope)
  --top-scope <SCOPE>            Verilator top scope (requires --rtl-path/--top-module)
  --metric <METRIC>              Default: ochiai

Simulator arguments:
  -- [ARGS...]                   Default: -C 5000000

  -h, --help                    Show this help
EOF
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

need_value() {
  (($# >= 2)) || die "$1 requires a value"
}

MODE=all
TARGET="${DATASET_DIR}"
JOBS=1
TMP_ROOT="${TMPDIR:-/tmp}/${SCRIPT_NAME%.sh}"
LOGS_ROOT="./logs"
KEEP_WORKDIR=0
BUILD_CMD="make sbfl -B"
FUZZER_BIN="build/fuzzer"

COVERAGE="verilator.line,verilator.branch"
STATE="PCState,ArchIntRegState,CSRState"
REDUCE_INSTS=1
REDUCE_COVER=0
SAVE_REDUCE=1
SAVE_TRACE=1
MAX_ITERS=20
MAX_RUN_TIMEOUT=180
TRACKER_WINDOW_SIZE=20
MUTATOR_WINDOW_SIZE=5
MUTATOR_WEIGHT_STRATEGY=head_quad
COVER_DISTANCE_WEIGHT=0.5
TOP_PASS=120
TOP_SUS=50
SELECTION="sort"
CORPUS_INPUT="ready-to-run/microbench-riscv64-nutshell.elf"
RTL_PATH=""
INCLUDE_PATHS=""
TOP_MODULE=""
TOP_SCOPE=""
METRIC="ochiai"
EXTRA_ARGS=(-C 5000000)

while (($#)); do
  case "$1" in
  --all)
    MODE=all
    if (($# >= 2)) && [[ "$2" != -* ]]; then TARGET="$2"; shift 2; else TARGET="${DATASET_DIR}"; shift; fi
    ;;
  --case) need_value "$@"; MODE=case; TARGET="$2"; shift 2 ;;
  -j | --jobs) need_value "$@"; JOBS="$2"; shift 2 ;;
  -w | --workdir) need_value "$@"; NUTSHELL_HOME="$2"; shift 2 ;;
  -t | --tmp) need_value "$@"; TMP_ROOT="$2"; shift 2 ;;
  -l | --logs) need_value "$@"; LOGS_ROOT="$2"; shift 2 ;;
  --keep-workdir) KEEP_WORKDIR=1; shift ;;
  --build-cmd) need_value "$@"; BUILD_CMD="$2"; shift 2 ;;
  --fuzzer-bin) need_value "$@"; FUZZER_BIN="$2"; shift 2 ;;
  -c | --coverage) need_value "$@"; COVERAGE="$2"; shift 2 ;;
  -s | --state) need_value "$@"; STATE="$2"; shift 2 ;;
  --reduce-insts) REDUCE_INSTS=1; shift ;;
  --no-reduce-insts) REDUCE_INSTS=0; shift ;;
  --reduce-cover) REDUCE_COVER=1; shift ;;
  --no-reduce-cover) REDUCE_COVER=0; shift ;;
  --save-reduce) SAVE_REDUCE=1; shift ;;
  --no-save-reduce) SAVE_REDUCE=0; shift ;;
  --save-trace) SAVE_TRACE=1; shift ;;
  --no-save-trace) SAVE_TRACE=0; shift ;;
  --max-iters) need_value "$@"; MAX_ITERS="$2"; shift 2 ;;
  --max-run-timeout) need_value "$@"; MAX_RUN_TIMEOUT="$2"; shift 2 ;;
  --tracker-window-size) need_value "$@"; TRACKER_WINDOW_SIZE="$2"; shift 2 ;;
  --mutator-window-size) need_value "$@"; MUTATOR_WINDOW_SIZE="$2"; shift 2 ;;
  --mutator-weight-strategy) need_value "$@"; MUTATOR_WEIGHT_STRATEGY="$2"; shift 2 ;;
  --cover-distance-weight) need_value "$@"; COVER_DISTANCE_WEIGHT="$2"; shift 2 ;;
  --top-pass) need_value "$@"; TOP_PASS="$2"; shift 2 ;;
  --top-sus) need_value "$@"; TOP_SUS="$2"; shift 2 ;;
  --selection) need_value "$@"; SELECTION="$2"; shift 2 ;;
  --corpus-input) need_value "$@"; CORPUS_INPUT="$2"; shift 2 ;;
  --rtl-path) need_value "$@"; RTL_PATH="$2"; shift 2 ;;
  --include-paths) need_value "$@"; INCLUDE_PATHS="$2"; shift 2 ;;
  --top-module) need_value "$@"; TOP_MODULE="$2"; shift 2 ;;
  --top-scope) need_value "$@"; TOP_SCOPE="$2"; shift 2 ;;
  --metric) need_value "$@"; METRIC="$2"; shift 2 ;;
  --) shift; EXTRA_ARGS=("$@"); break ;;
  -h | --help) usage; exit 0 ;;
  *) die "unknown argument: $1" ;;
  esac
done

[[ "${JOBS}" =~ ^[1-9][0-9]*$ ]] || die "jobs must be a positive integer: ${JOBS}"
for value in "${MAX_ITERS}" "${MAX_RUN_TIMEOUT}" "${TRACKER_WINDOW_SIZE}" \
  "${MUTATOR_WINDOW_SIZE}" "${TOP_PASS}" "${TOP_SUS}"; do
  [[ "${value}" =~ ^[1-9][0-9]*$ ]] || die "expected a positive integer: ${value}"
done
case "${SELECTION}" in random | sort) ;; *) die "invalid selection: ${SELECTION}" ;; esac
case "${MUTATOR_WEIGHT_STRATEGY}" in
uniform | tail_linear | tail_quad | head_linear | head_quad) ;;
*) die "invalid mutator weight strategy: ${MUTATOR_WEIGHT_STRATEGY}" ;;
esac
case "${METRIC}" in
tarantula | ochiai | jaccard | dstar | gp19 | barinel | crosstab | zoltar | ample) ;;
*) die "invalid metric: ${METRIC}" ;;
esac
if [[ -n "${RTL_PATH}${TOP_MODULE}${TOP_SCOPE}${INCLUDE_PATHS}" ]]; then
  [[ -n "${RTL_PATH}" && -n "${TOP_MODULE}" && -n "${TOP_SCOPE}" ]] ||
    die "--rtl-path, --top-module and --top-scope must be specified together"
fi
awk -v n="${COVER_DISTANCE_WEIGHT}" 'BEGIN { exit !(n ~ /^([0-9]+([.][0-9]*)?|[.][0-9]+)$/ && n >= 0 && n <= 1) }' ||
  die "cover distance weight must be in [0, 1]: ${COVER_DISTANCE_WEIGHT}"

for command in realpath patch; do command -v "${command}" >/dev/null || die "${command} not found"; done
NUTSHELL_HOME="$(realpath "${NUTSHELL_HOME}")"
[[ -f "${NUTSHELL_HOME}/Makefile" ]] || die "invalid NutShell workdir: ${NUTSHELL_HOME}"

if [[ "${CORPUS_INPUT}" = /* ]]; then
  CORPUS_SOURCE="${CORPUS_INPUT}"
else
  CORPUS_SOURCE="${NUTSHELL_HOME}/${CORPUS_INPUT}"
fi
[[ -f "${CORPUS_SOURCE}" ]] || die "corpus input not found: ${CORPUS_SOURCE}"

mkdir -p "${TMP_ROOT}" "${LOGS_ROOT}"
TMP_ROOT="$(realpath "${TMP_ROOT}")"
LOGS_ROOT="$(realpath "${LOGS_ROOT}")"
RUN_ID="$(date +'%Y-%m-%d-%H-%M-%S')_$$"
RUN_TMP="${TMP_ROOT}/${RUN_ID}"
RUN_LOGS="${LOGS_ROOT}/${RUN_ID}"
SUMMARY="${RUN_LOGS}/run_status.tsv"
LOCK_FILE="${RUN_TMP}/status.lock"
mkdir -p "${RUN_TMP}/work" "${RUN_LOGS}"
printf 'index\tpatch\tstatus\trc\telapsed_seconds\toutput\tworkdir\n' >"${SUMMARY}"

copy_workdir() {
  local destination="$1"
  mkdir -p "${destination}"
  if command -v rsync >/dev/null; then
    rsync -a --delete --exclude '/build/' --exclude '/logs/' --exclude '/target/' \
      --exclude '.git' "${NUTSHELL_HOME}/" "${destination}/"
  else
    cp -a "${NUTSHELL_HOME}/." "${destination}/"
    rm -rf -- "${destination}/build" "${destination}/logs" "${destination}/target" \
      "${destination}/.git"
  fi
}

save_patched_sources() {
  local workdir="$1" patch_file="$2" output="$3"
  local relative_path

  mkdir -p "${output}/patched_sources"
  while IFS= read -r relative_path; do
    [[ -n "${relative_path}" && "${relative_path}" != "/dev/null" ]] || continue
    relative_path="${relative_path#b/}"
    [[ -f "${workdir}/${relative_path}" ]] || continue
    (cd "${workdir}" && cp -a --parents -- "${relative_path}" "${output}/patched_sources")
  done < <(awk '$1 == "+++" { print $2 }' "${patch_file}" | sort -u)
}

save_compiled_rtl() {
  local workdir="$1" output="$2"
  local rtl_dir file_count

  [[ -d "${workdir}/build/rtl" ]] || {
    echo "[ERROR] RTL output not found: ${workdir}/build/rtl" >&2
    return 1
  }
  rtl_dir="$(realpath "${workdir}/build/rtl")"
  case "${rtl_dir}/" in
  "${workdir}/build/"*) ;;
  *)
    echo "[ERROR] RTL output resolves outside the case workdir: ${rtl_dir}" >&2
    return 1
    ;;
  esac

  file_count="$(find "${rtl_dir}" -type f | wc -l)"
  [[ "${file_count}" -gt 0 ]] || {
    echo "[ERROR] RTL output is empty: ${rtl_dir}" >&2
    return 1
  }

  echo "[RTL] build command: ${BUILD_CMD}"
  echo "[RTL] source       : ${rtl_dir}"
  echo "[RTL] destination  : ${output}/rtl"
  echo "[RTL] files        : ${file_count}"
  mkdir -p "${output}/rtl"
  cp -a "${rtl_dir}/." "${output}/rtl/"
}

append_status() {
  if command -v flock >/dev/null; then
    { flock 9; printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >>"${SUMMARY}"; } 9>"${LOCK_FILE}"
  else
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >>"${SUMMARY}"
  fi
}

run_case() (
  local index="$1" patch_file="$2" start end elapsed rc status
  local patch_name safe_name output workdir
  start="$(date +%s)"
  patch_file="$(realpath "${patch_file}")"
  patch_name="$(basename "${patch_file}")"
  safe_name="${patch_name%.patch}"
  safe_name="${safe_name//[^A-Za-z0-9._-]/_}"
  output="${RUN_LOGS}/${index}_${safe_name}"
  workdir="${RUN_TMP}/work/${index}_${safe_name}"
  mkdir -p "${output}"

  finish() {
    status="$1"; rc="$2"; end="$(date +%s)"; elapsed=$((end - start))
    append_status "${index}" "${patch_name}" "${status}" "${rc}" "${elapsed}" "${output}" "${workdir}"
    echo "[${status}][${index}] ${patch_name} (rc=${rc}, ${elapsed}s)"
    if ((KEEP_WORKDIR == 0)); then rm -rf -- "${workdir}"; fi
  }

  echo "[START][${index}] ${patch_name}"
  if copy_workdir "${workdir}" >"${output}/copy.log" 2>&1; then :; else
    rc=$?; finish COPY_FAIL "${rc}"; exit 0
  fi
  if [[ -e "${workdir}/build" ]]; then
    echo "[ERROR] source copy unexpectedly contains build/: ${workdir}/build" \
      >"${output}/build_provenance.log"
    finish COPY_CONTAINS_BUILD 1
    exit 0
  fi
  {
    echo "[BUILD] command      : ${BUILD_CMD}"
    echo "[BUILD] workdir      : ${workdir}"
    echo "[BUILD] expected RTL : ${workdir}/build/rtl"
    echo "[BUILD] expected bin : ${workdir}/${FUZZER_BIN}"
  } >"${output}/build_provenance.log"
  if (cd "${workdir}" && patch -p1 --forward --batch --input "${patch_file}") \
    >"${output}/patch.log" 2>&1; then :; else
    rc=$?; finish APPLY_FAIL "${rc}"; exit 0
  fi
  if save_patched_sources "${workdir}" "${patch_file}" "${output}" \
    >"${output}/save_patched_sources.log" 2>&1; then :; else
    rc=$?; finish SAVE_PATCHED_SOURCES_FAIL "${rc}"; exit 0
  fi
  if (
    cd "${workdir}"
    NOOP_HOME="${workdir}" \
      NUTSHELL_HOME="${workdir}" \
      SBFL_HOME="${workdir}/sbfl" \
      bash -c "${BUILD_CMD}"
  ) >"${output}/build.log" 2>&1; then :; else
    rc=$?; finish BUILD_FAIL "${rc}"; exit 0
  fi
  if save_compiled_rtl "${workdir}" "${output}" >"${output}/save_rtl.log" 2>&1; then :; else
    rc=$?; finish SAVE_RTL_FAIL "${rc}"; exit 0
  fi

  local fuzzer
  if [[ "${FUZZER_BIN}" = /* ]]; then fuzzer="${FUZZER_BIN}"; else fuzzer="${workdir}/${FUZZER_BIN}"; fi
  if [[ ! -x "${fuzzer}" ]]; then finish FUZZER_MISSING 1; exit 0; fi

  local args=(
    -c "${COVERAGE}"
    -s "${STATE}"
    sbfl
  )
  ((REDUCE_INSTS)) && args+=(--reduce-insts)
  ((REDUCE_COVER)) && args+=(--reduce-cover)
  ((SAVE_REDUCE)) && args+=(--save-reduce)
  ((SAVE_TRACE)) && args+=(--save-trace)
  args+=(
    --max-iters "${MAX_ITERS}"
    --max-run-timeout "${MAX_RUN_TIMEOUT}"
    --tracker-window-size "${TRACKER_WINDOW_SIZE}"
    --cover-distance-weight "${COVER_DISTANCE_WEIGHT}"
    --top-pass "${TOP_PASS}"
    --top-sus "${TOP_SUS}"
    --selection "${SELECTION}"
    --corpus-input "${CORPUS_SOURCE}"
    --output "${output}"
    --metric "${METRIC}"
  )
  if [[ -n "${RTL_PATH}" ]]; then
    args+=(
      --rtl-path "${RTL_PATH}"
      --top-module "${TOP_MODULE}"
      --top-scope "${TOP_SCOPE}"
    )
    [[ -n "${INCLUDE_PATHS}" ]] && args+=(--include-paths "${INCLUDE_PATHS}")
  fi
  args+=(
    psbfl
    --mutator-window-size "${MUTATOR_WINDOW_SIZE}"
    --mutator-weight-strategy "${MUTATOR_WEIGHT_STRATEGY}"
  )
  ((${#EXTRA_ARGS[@]})) && args+=(-- "${EXTRA_ARGS[@]}")
  { printf '[RUN]'; printf ' %q' "${fuzzer}" "${args[@]}"; printf '\n'; } >"${output}/command.log"

  set +e
  (cd "${workdir}" && "${fuzzer}" "${args[@]}") >"${output}/sbfl.log" 2>&1
  rc=$?
  set -e
  if ((rc == 0)); then finish OK 0; else finish SBFL_FAIL "${rc}"; fi
)

load_manifest_patches() {
  local dataset_dir="$1" manifest id
  local matches=()
  manifest="${dataset_dir}/manifest.csv"
  [[ -f "${manifest}" ]] || die "manifest not found: ${manifest}"

  while IFS= read -r id; do
    [[ -n "${id}" ]] || continue
    mapfile -d '' matches < <(
      find "${dataset_dir}" -maxdepth 1 -type f -name "${id}_*.patch" -print0 | sort -z
    )
    ((${#matches[@]} == 1)) ||
      die "manifest id ${id} must match exactly one ${id}_*.patch (found ${#matches[@]})"
    PATCHES+=("${matches[0]}")
  done < <(awk -F, 'NR > 1 { gsub(/\r$/, "", $1); print $1 }' "${manifest}")
}

main() {
  local -a PATCHES=()
  local total failed running index

  if [[ "${MODE}" == case ]]; then
    [[ -f "${TARGET}" ]] || die "patch not found: ${TARGET}"
    PATCHES=("$(realpath "${TARGET}")")
  else
    [[ -d "${TARGET}" ]] || die "dataset directory not found: ${TARGET}"
    TARGET="$(realpath "${TARGET}")"
    load_manifest_patches "${TARGET}"
  fi
  ((${#PATCHES[@]})) || die "no .patch files found"

  echo "[INFO] cases=${#PATCHES[@]} jobs=${JOBS}"
  echo "[INFO] logs=${RUN_LOGS}"
  echo "[INFO] tmp=${RUN_TMP}"

  running=0
  for index in "${!PATCHES[@]}"; do
    run_case "${index}" "${PATCHES[$index]}" &
    running=$((running + 1))
    if [[ "${running}" -ge "${JOBS}" ]]; then
      wait -n || true
      running=$((running - 1))
    fi
  done
  while [[ "${running}" -gt 0 ]]; do
    wait -n || true
    running=$((running - 1))
  done

  read -r total failed < <(
    awk -F '\t' '
      NR > 1 {
        total++
        if ($3 != "OK") {
          failed++
        }
      }
      END {
        print total + 0, failed + 0
      }
    ' "${SUMMARY}"
  )
  printf '[SUMMARY] total=%s failed=%s\n' "${total}" "${failed}"
  printf '[SUMMARY] %s\n' "${SUMMARY}"

  if [[ "${failed}" -ne 0 ]]; then
    return 1
  fi
  return 0
}

main
