// SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

#include "kernel_v1_impl.cuh"

#define checkCudaErrors(call)                                 \
  do {                                                        \
    cudaError_t err = call;                                   \
    if (err != cudaSuccess) {                                 \
      printf("CUDA error at %s %d: %s\n", __FILE__, __LINE__, \
             cudaGetErrorString(err));                        \
      exit(EXIT_FAILURE);                                     \
    }                                                         \
  } while (0)

extern "C"
void simulate_v1_noninteractive_simple_scan_cuda(
  usize num_blocks,
  usize num_major_stages,
  const usize *blocks_start,
  const u32 *blocks_data,
  u32 *sram_data,
  usize num_cycles,
  usize state_size,
  u32 *states_noninteractive
  )
{
  u32 enable_profile = 0;
  u32 enable_prune = 0;
  usize profile_warmup_cycles = 0;
  unsigned long long *null_ull = nullptr;
  u32 *null_u32 = nullptr;
  void *arg_ptrs[17] = {
    (void *)&num_blocks, (void *)&num_major_stages,
    (void *)&blocks_start, (void *)&blocks_data,
    (void *)&sram_data, (void *)&num_cycles, (void *)&state_size,
    (void *)&states_noninteractive,
    (void *)&enable_profile,
    (void *)&enable_prune,
    (void *)&profile_warmup_cycles,
    (void *)&null_ull,
    (void *)&null_ull,
    (void *)&null_ull,
    (void *)&null_ull,
    (void *)&null_ull,
    (void *)&null_u32
  };
  checkCudaErrors(cudaLaunchCooperativeKernel(
    (void *)simulate_v1_noninteractive_simple_scan, num_blocks, 256,
    arg_ptrs, 0, (cudaStream_t)0
    ));
}

extern "C"
void simulate_v1_noninteractive_simple_scan_cuda_profiled(
  usize num_blocks,
  usize num_major_stages,
  const usize *blocks_start,
  const u32 *blocks_data,
  u32 *sram_data,
  usize num_cycles,
  usize state_size,
  u32 *states_noninteractive,
  u32 enable_profile,
  u32 enable_prune,
  usize profile_warmup_cycles,
  unsigned long long *d_partition_cycles,
  unsigned long long *d_partition_input_changed,
  unsigned long long *d_partition_output_changed,
  unsigned long long *d_partition_toggle_popcount,
  unsigned long long *d_partition_skipped,
  u32 *d_prev_signatures
  )
{
  void *arg_ptrs[17] = {
    (void *)&num_blocks, (void *)&num_major_stages,
    (void *)&blocks_start, (void *)&blocks_data,
    (void *)&sram_data, (void *)&num_cycles, (void *)&state_size,
    (void *)&states_noninteractive,
    (void *)&enable_profile,
    (void *)&enable_prune,
    (void *)&profile_warmup_cycles,
    (void *)&d_partition_cycles,
    (void *)&d_partition_input_changed,
    (void *)&d_partition_output_changed,
    (void *)&d_partition_toggle_popcount,
    (void *)&d_partition_skipped,
    (void *)&d_prev_signatures
  };
  checkCudaErrors(cudaLaunchCooperativeKernel(
    (void *)simulate_v1_noninteractive_simple_scan, num_blocks, 256,
    arg_ptrs, 0, (cudaStream_t)0
    ));
}

extern "C"
void simulate_v1_noninteractive_simple_scan_profiled_cuda(
  usize num_blocks,
  usize num_major_stages,
  const usize *blocks_start,
  const u32 *blocks_data,
  u32 *sram_data,
  usize num_cycles,
  usize state_size,
  u32 *states_noninteractive,
  u32 enable_profile,
  u32 enable_prune,
  usize profile_warmup_cycles,
  unsigned long long *d_partition_cycles,
  unsigned long long *d_partition_input_changed,
  unsigned long long *d_partition_output_changed,
  unsigned long long *d_partition_toggle_popcount,
  unsigned long long *d_partition_skipped,
  u32 *d_prev_signatures
  )
{
  simulate_v1_noninteractive_simple_scan_cuda_profiled(
    num_blocks,
    num_major_stages,
    blocks_start,
    blocks_data,
    sram_data,
    num_cycles,
    state_size,
    states_noninteractive,
    enable_profile,
    enable_prune,
    profile_warmup_cycles,
    d_partition_cycles,
    d_partition_input_changed,
    d_partition_output_changed,
    d_partition_toggle_popcount,
    d_partition_skipped,
    d_prev_signatures
  );
}
