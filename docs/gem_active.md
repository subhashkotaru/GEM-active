# GEM-Active

GEM-Active adds activity-aware profiling and conservative event-pruning to GEM's CUDA RTL simulation path. It keeps GEM's existing flow intact while adding optional counters, JSON reporting, and a skip path for inactive no-SRAM partitions.

## Goals and scope

- Preserve baseline GEM behavior when all GEM-Active flags are disabled.
- Provide low-overhead activity profiling for each CUDA block/partition.
- Report results as JSON for offline analysis.
- Enable conservative pruning only when it is safe to do so.
- Require output VCD equivalence checks before reporting speedup.

## CLI flags

- `--profile-json <path>`: write a JSON report after simulation.
- `--activity-profile-only`: enable profiling without pruning.
- `--activity-prune`: enable conservative pruning.
- `--profile-warmup-cycles <N>`: skip profiling and pruning for the first N cycles.

## Profile-only mode

```bash
cargo run -r --features cuda --bin cuda_test -- \
  gatelevel.gv result.gemparts input.vcd output_profile.vcd NUM_BLOCKS \
  --activity-profile-only \
  --profile-json profile.json
```

## Pruning mode

```bash
cargo run -r --features cuda --bin cuda_test -- \
  gatelevel.gv result.gemparts input.vcd output_pruned.vcd NUM_BLOCKS \
  --activity-prune \
  --profile-json profile_pruned.json
```

Validate correctness against baseline output:

```bash
diff -u output_baseline.vcd output_pruned.vcd
```

If timestamps or headers differ, use:

```bash
python3 scripts/compare_vcd_semantic.py output_baseline.vcd output_pruned.vcd
```

## JSON profile

The JSON report includes per-partition counters, activity ratios, and a summary. Use the analysis script:

```bash
python3 scripts/analyze_gem_active_profile.py profile.json --csv profile.csv
```

## Benchmarks

Two small synthetic RTL examples are provided in [benchmarks](../benchmarks):

- `low_activity_counter.v`
- `high_activity_lfsr.v`

See `scripts/run_gem_active_benchmarks.sh` for a template that runs baseline, profile-only, and prune modes.

## Correctness policy

- Pruning is only enabled when the input signature is unchanged and the partition has no SRAM.
- Output VCD equivalence must be validated before reporting speedups.

## Known limitations

GEM-Active pruning is conservative and experimental.
The first version avoids pruning SRAM/RAM partitions.
The profiler uses approximate block/partition-level activity counters.
The output VCD equivalence check is required before reporting speedup.

## Profiling counters

The CUDA kernel emits per-partition counters at block granularity:

- `partition_cycles`: number of cycles the block/partition executed.
- `partition_input_changed`: cycles where input signature changed.
- `partition_output_changed`: cycles where output words changed.
- `partition_toggle_popcount`: approximate sum of bit toggles.
- `partition_skipped`: cycles skipped by pruning.

Each counter is indexed by `profile_index = stage_id * num_blocks + block_id`.

## JSON schema overview

The JSON report includes:

- `schema_version`: current schema version (1).
- `mode`: profiling/pruning flags and warmup cycles.
- `run`: run metadata such as cycles, blocks, and state size.
- `counters`: per-partition counters and derived ratios.
- `summary`: aggregate totals and mean ratios.

Use the analysis script to print quick summaries and export CSV:

```bash
python3 scripts/analyze_gem_active_profile.py profile.json --csv profile.csv
```

## Pruning safety rules

The initial pruning policy is conservative:

- Pruning only activates after `profile_warmup_cycles`.
- The block input signature must match the previous cycle.
- SRAM/RAM partitions are excluded.
- All threads in a CUDA block take the same skip branch.

If any of these conditions are not met, the partition executes normally.

## Correctness checklist

1. Run baseline GEM simulation and collect `output_baseline.vcd`.
2. Run GEM-Active profile-only and ensure `output_profile.vcd` matches baseline.
3. Run GEM-Active pruning and verify `output_pruned.vcd` matches baseline.
4. If headers or timestamps differ, use semantic comparison:

```bash
python3 scripts/compare_vcd_semantic.py output_baseline.vcd output_pruned.vcd
```

## Benchmark automation

Use the benchmark runner template:

```bash
bash scripts/run_gem_active_benchmarks.sh
```

It outputs `results/gem_active_results.csv`. Update the script with real design paths.
