#!/usr/bin/env bash
set -euo pipefail

RESULTS_DIR="results"
RESULTS_FILE="${RESULTS_DIR}/gem_active_results.csv"
mkdir -p "${RESULTS_DIR}"

echo "design,num_cycles,num_blocks,baseline_gpu_time,profile_gpu_time,pruned_gpu_time,profile_overhead,prune_speedup,total_skipped,mean_activity_ratio,vcd_match" > "${RESULTS_FILE}"

# Edit the list below with real paths for your designs.
# Format: name|gatelevel.gv|result.gemparts|input.vcd|num_blocks
DESIGNS=(
  "low_activity_counter|path/to/gatelevel.gv|path/to/result.gemparts|path/to/input.vcd|216"
  "high_activity_lfsr|path/to/gatelevel.gv|path/to/result.gemparts|path/to/input.vcd|216"
)

run_sim() {
  local label="$1"
  shift
  local start_ns
  local end_ns
  start_ns=$(date +%s%N)
  "$@"
  end_ns=$(date +%s%N)
  python3 - <<PY
import sys
start = int("$start_ns")
end = int("$end_ns")
print((end - start) / 1e9)
PY
}

for entry in "${DESIGNS[@]}"; do
  IFS="|" read -r design gatelevel gemparts input_vcd num_blocks <<< "${entry}"
  baseline_vcd="${RESULTS_DIR}/${design}_baseline.vcd"
  profile_vcd="${RESULTS_DIR}/${design}_profile.vcd"
  pruned_vcd="${RESULTS_DIR}/${design}_pruned.vcd"
  profile_json="${RESULTS_DIR}/${design}_profile.json"
  pruned_json="${RESULTS_DIR}/${design}_pruned.json"

  baseline_time=$(run_sim baseline cargo run -r --features cuda --bin cuda_test -- \
    "${gatelevel}" "${gemparts}" "${input_vcd}" "${baseline_vcd}" "${num_blocks}")

  profile_time=$(run_sim profile cargo run -r --features cuda --bin cuda_test -- \
    "${gatelevel}" "${gemparts}" "${input_vcd}" "${profile_vcd}" "${num_blocks}" \
    --activity-profile-only --profile-json "${profile_json}")

  pruned_time=$(run_sim pruned cargo run -r --features cuda --bin cuda_test -- \
    "${gatelevel}" "${gemparts}" "${input_vcd}" "${pruned_vcd}" "${num_blocks}" \
    --activity-prune --profile-json "${pruned_json}")

  vcd_match=false
  if diff -u "${baseline_vcd}" "${pruned_vcd}" > /dev/null 2>&1; then
    vcd_match=true
  elif python3 scripts/compare_vcd_semantic.py "${baseline_vcd}" "${pruned_vcd}" > /dev/null 2>&1; then
    vcd_match=true
  fi

  read total_skipped mean_activity_ratio < <(python3 - <<PY
import json
with open("${pruned_json}", "r", encoding="utf-8") as handle:
    data = json.load(handle)
summary = data.get("summary", {})
print(summary.get("total_skipped", 0), summary.get("mean_activity_ratio", 0.0))
PY
  )

  profile_overhead=$(python3 - <<PY
base = float("${baseline_time}")
prof = float("${profile_time}")
print(0.0 if base == 0 else (prof / base) - 1.0)
PY
  )
  prune_speedup=$(python3 - <<PY
base = float("${baseline_time}")
pruned = float("${pruned_time}")
print(0.0 if pruned == 0 else base / pruned)
PY
  )

  echo "${design},${num_cycles:-0},${num_blocks},${baseline_time},${profile_time},${pruned_time},${profile_overhead},${prune_speedup},${total_skipped},${mean_activity_ratio},${vcd_match}" >> "${RESULTS_FILE}"
  echo "Wrote ${design} to ${RESULTS_FILE}"
  echo
  
  # Set num_cycles in the CSV by reading from profile JSON if available.
  python3 - <<PY
import csv
import json
path = "${RESULTS_FILE}"
with open(path, "r", encoding="utf-8") as handle:
    rows = list(csv.reader(handle))
header = rows[0]
for i in range(1, len(rows)):
    if rows[i][0] == "${design}":
        with open("${profile_json}", "r", encoding="utf-8") as pf:
            num_cycles = json.load(pf).get("run", {}).get("num_cycles", 0)
        rows[i][1] = str(num_cycles)
        break
with open(path, "w", encoding="utf-8", newline="") as handle:
    writer = csv.writer(handle)
    writer.writerows(rows)
PY

done
