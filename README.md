# GEM-Active
GEM-Active adds activity-aware profiling and conservative event-pruning to GEM's CUDA RTL simulation path. It keeps GEM's flow intact while adding per-partition counters, JSON reporting, and an optional skip path for unchanged no-SRAM partitions.

GEM is an open-source RTL logic simulator with CUDA acceleration, developed and maintained by NVIDIA Research. GEM can deliver up to 5--40X speed-up compared to CPU-based leading RTL simulators. A summary of the work with paper can be found [here](https://research.nvidia.com/publication/2025-06_gem-gpu-accelerated-emulator-inspired-rtl-simulation).

See [docs/gem_active.md](docs/gem_active.md) for GEM-Active details, limitations, and benchmark scripts.

## Compile and Run Your Design with GEM
GEM works in a way similar to an FPGA-based RTL emulator.
It first synthesizes your design with a special and-inverter graph (AIG) process, and then map the synthesized gate-level netlist to a virtual manycore Boolean processor which can be emulated with CUDA-compatible GPUs.

The synthesis and mapping is slower than the compiling/elaboration process of CPU-based simulators. But it is a one-time cost and your design can be simulated under different testbenches without re-running the synthesis or mapping.

**See [usage.md](./usage.md) for usage documentation.**

## Activity-Aware Optimization

GEM's original execution model evaluates every mapped partition every simulated cycle, regardless of whether any input to that partition changed. This is efficient for high-activity workloads but leaves optimization headroom when large portions of the design are idle for many cycles.

GEM-Active addresses this by adding two capabilities on top of the existing CUDA simulation path:

### 1. Per-Partition Activity Profiling

A lightweight profiler runs inside the CUDA kernel and tracks, for each block/partition across each simulation stage:

- how many cycles that partition executed,
- how many cycles its input signature changed compared to the previous cycle,
- how many cycles its output words changed,
- an approximate toggle popcount across output bits,
- how many cycles were skipped by pruning.

Each partition is identified by a `profile_index = stage_id * num_blocks + block_id`. Counters are accumulated using atomic operations, one per block per cycle, to keep overhead minimal. After simulation completes, these counters are copied back to the host and written to a JSON file.

### 2. Conservative Event Pruning

When `--activity-prune` is enabled, a partition may skip its computation for a cycle if all of the following hold:

- The current simulated cycle is past the warmup window.
- The partition's input signature for this cycle matches the signature from the previous cycle.
- The partition has no SRAM or RAM side effects.

The skip decision is made at the whole CUDA block level. A single signature is computed across all 256 threads in a block using shared memory reduction, then thread 0 compares it against the stored previous signature. The result is broadcast back through shared memory so every thread in the block takes the same branch. Intra-warp divergence is avoided.

When a partition is skipped, its previous output state is propagated forward without re-running the Boolean logic. The cooperative grid synchronization that GEM requires between stages is preserved regardless of whether a skip occurred.

SRAM partitions are excluded from pruning in this version because memory write-side effects may be invisible to the input signature.

### Input Signature Hash

The signature is computed per thread from the global-read input state that GEM already loads for each partition:

```cpp
u32 lane_sig = mix32(shared_state[threadIdx.x] ^ (0x9e3779b9U * threadIdx.x));
```

where `mix32` is a fast 32-bit integer finalizer using shift-multiply-XOR mixing. Per-thread signatures are XOR-reduced across the block using shared memory to produce a single 32-bit block signature.

### Warmup Cycles

Profiling and pruning are suppressed for the first `--profile-warmup-cycles N` simulated cycles. This covers reset and initialization behavior where input signatures are not yet meaningful and skipping work could be unsafe.

### Correctness Policy

Profile-only mode must produce an output VCD that is bit-identical to baseline GEM. Pruning mode must be validated against the baseline VCD before any speedup results are reported:

```bash
diff -u output_baseline.vcd output_pruned.vcd
```

For comparisons that ignore header or timestamp formatting differences:

```bash
python3 scripts/compare_vcd_semantic.py output_baseline.vcd output_pruned.vcd
```

## GEM-Active Quick Start

Profile-only mode (no pruning):

```bash
cargo run -r --features cuda --bin cuda_test -- \
	gatelevel.gv result.gemparts input.vcd output_profile.vcd 216 \
	--activity-profile-only \
	--profile-json profile.json
```

Analyze the profile:

```bash
python3 scripts/analyze_gem_active_profile.py profile.json
```

Pruning mode (experimental):

```bash
cargo run -r --features cuda --bin cuda_test -- \
	gatelevel.gv result.gemparts input.vcd output_pruned.vcd 216 \
	--activity-prune \
	--profile-json profile_pruned.json
```

Validate correctness against baseline GEM output:

```bash
diff -u output_baseline.vcd output_pruned.vcd
```


## Known Limitations

- Pruning is conservative and excludes SRAM/RAM partitions in this version.
- The profiler uses approximate block-level activity counters, not fine-grained signal-level tracking.
- Profile-only mode must be output-equivalent to baseline GEM.
- Always validate pruning with a VCD diff or semantic comparison before reporting speedup.
