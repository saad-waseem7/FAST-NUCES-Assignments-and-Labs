#include <stdio.h>
#include <cuda.h>
#include <cuda_runtime.h>
#include <driver_functions.h>
#include <thrust/scan.h>
#include <thrust/device_ptr.h>
#include <thrust/device_malloc.h>
#include <thrust/device_free.h>
#include "CycleTimer.h"

#define THREADS_PER_BLOCK 256

static inline int nextPow2(int n) {
    n--;
    n |= n >> 1;
    n |= n >> 2;
    n |= n >> 4;
    n |= n >> 8;
    n |= n >> 16;
    n++;
    return n;
}

// -----------------------------------------------------------------------
// STEP 1: warp-level inclusive scan using shfl_up
// -----------------------------------------------------------------------
__device__ int warp_inclusive_scan(int val) {
    int lane = threadIdx.x & 31;  // lane index within warp (0..31)
    for (int offset = 1; offset < 32; offset <<= 1) {
        // grab the value from 'offset' lanes to the left
        int neighbor = __shfl_up_sync(0xffffffff, val, offset);
        if (lane >= offset) val += neighbor;
    }
    return val;  // inclusive result for this lane
}

// -----------------------------------------------------------------------
// STEP 2: Each block scans its own chunk of THREADS_PER_BLOCK elements.
// -----------------------------------------------------------------------
__global__ void block_scan_kernel(int* input, int* output, int* block_sums, int N) {
    // one shared mem slot per warp (8 warps for 256 threads/block)
    __shared__ int warp_sums[THREADS_PER_BLOCK / 32];

    int tid    = threadIdx.x;
    int gid    = blockIdx.x * blockDim.x + tid;
    int lane   = tid & 31;
    int warp_id = tid >> 5;

    // load element; out-of-bounds threads contribute 0
    int val = (gid < N) ? input[gid] : 0;

    // --- warp-level inclusive scan ---
    int warp_inc = warp_inclusive_scan(val);

    // last lane of each warp writes its warp's total sum to shared mem
    if (lane == 31) { warp_sums[warp_id] = warp_inc; }
    __syncthreads();

    // --- scan the 8 warp sums sequentially (thread 0 does this) ---
    // converts warp_sums[] to exclusive prefix sums of warp totals
    if (tid == 0) {
        int running = 0;
        int num_warps = blockDim.x / 32;
        for (int i = 0; i < num_warps; i++) {
            int tmp = warp_sums[i];
            warp_sums[i] = running;  // exclusive: store prefix before this warp
            running += tmp;
        }
        // running = total sum for this entire block
        if (block_sums != nullptr) { block_sums[blockIdx.x] = running; }
    }
    __syncthreads();

    // --- convert to exclusive scan within this block ---
    // warp_sums[warp_id] = sum of all elements in warps before this one
    // (warp_inc - val) = exclusive within-warp prefix for this thread
    int exclusive_val = warp_sums[warp_id] + (warp_inc - val);

    if (gid < N) { output[gid] = exclusive_val; }
}

// -----------------------------------------------------------------------
// STEP 3 (applied top-down): propagate block offsets
// -----------------------------------------------------------------------
__global__ void add_block_offsets(int* data, int* block_sums, int N) {
    int gid = blockIdx.x * blockDim.x + threadIdx.x;
    // block_sums[blockIdx.x] = total exclusive prefix before this block
    if (gid < N) { data[gid] += block_sums[blockIdx.x]; }
} 

// -----------------------------------------------------------------------
// exclusive_scan -- CPU-side function that drives the full multi-level scan
//
// Strategy:
//   Bottom-up: scan each level, store block sums at next level up.
//   Top: single-block scan of the topmost (smallest) array.
//   Top-down: propagate offsets back down level by level.
//
// NOTE: we use result in-place (input param is intentionally unused here).
//       cudaScan already copies input into result before calling us.
// -----------------------------------------------------------------------
void exclusive_scan(int* input, int N, int* result) {
    const int MAX_LEVELS = 6;  // covers up to 256^6 ~ 280 trillion elements
    int* arrays[MAX_LEVELS];
    int  sizes[MAX_LEVELS];
    int  levels = 0;

    // level 0 is the output array itself
    arrays[0] = result;
    sizes[0]  = N;
    levels    = 1;

    // allocate intermediate arrays for each level of block sums
    int cur_size = N;
    while (cur_size > THREADS_PER_BLOCK) {
        int num_blocks = (cur_size + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
        int* next_arr;
        cudaMalloc(&next_arr, num_blocks * sizeof(int));
        cudaMemset(next_arr, 0, num_blocks * sizeof(int));
        arrays[levels] = next_arr;
        sizes[levels]  = num_blocks;
        levels++;
        cur_size = num_blocks;
    }

    // --- bottom-up pass ---
    // scan each level, writing block sums to the next level up
    for (int l = 0; l < levels - 1; l++) {
        int num_blocks = sizes[l + 1];
        block_scan_kernel<<<num_blocks, THREADS_PER_BLOCK>>>(arrays[l], arrays[l], arrays[l + 1], sizes[l]);
    }

    // scan the top level (small enough for a single block, no block sums needed)
    block_scan_kernel<<<1, THREADS_PER_BLOCK>>>(arrays[levels - 1], arrays[levels - 1], nullptr, sizes[levels - 1]);

    // --- top-down pass ---
    // add each level's prefix offsets back to the level below
    for (int l = levels - 2; l >= 0; l--) {
        int num_blocks = sizes[l + 1];
        add_block_offsets<<<num_blocks, THREADS_PER_BLOCK>>>(arrays[l], arrays[l + 1], sizes[l]);
    }

    // free the intermediate arrays (arrays[0] = result, keep that)
    for (int l = 1; l < levels; l++) { cudaFree(arrays[l]); }
}

// -----------------------------------------------------------------------
// cudaScan -- timing wrapper (unchanged from starter)
// -----------------------------------------------------------------------
double cudaScan(int* inarray, int* end, int* resultarray) {
    int* device_result; int* device_input;
    int N = end - inarray;
    int rounded_length = nextPow2(end - inarray);

    cudaMalloc((void **)&device_result, sizeof(int) * rounded_length);
    cudaMalloc((void **)&device_input,  sizeof(int) * rounded_length);

    cudaMemcpy(device_input,  inarray, (end - inarray) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(device_result, inarray, (end - inarray) * sizeof(int), cudaMemcpyHostToDevice);

    double startTime = CycleTimer::currentSeconds();
    exclusive_scan(device_input, N, device_result);
    cudaDeviceSynchronize();
    double endTime = CycleTimer::currentSeconds();

    cudaMemcpy(resultarray, device_result, (end - inarray) * sizeof(int), cudaMemcpyDeviceToHost);
    cudaFree(device_result); cudaFree(device_input);

    return endTime - startTime;
}

// -----------------------------------------------------------------------
// cudaScanThrust -- thrust wrapper (unchanged from starter)
// -----------------------------------------------------------------------
double cudaScanThrust(int* inarray, int* end, int* resultarray) {
    int length = end - inarray;
    thrust::device_ptr<int> d_input  = thrust::device_malloc<int>(length);
    thrust::device_ptr<int> d_output = thrust::device_malloc<int>(length);

    cudaMemcpy(d_input.get(), inarray, length * sizeof(int), cudaMemcpyHostToDevice);

    double startTime = CycleTimer::currentSeconds();
    thrust::exclusive_scan(d_input, d_input + length, d_output);
    cudaDeviceSynchronize();
    double endTime = CycleTimer::currentSeconds();

    cudaMemcpy(resultarray, d_output.get(), length * sizeof(int), cudaMemcpyDeviceToHost);
    thrust::device_free(d_input); thrust::device_free(d_output);
    return endTime - startTime;
}

// -----------------------------------------------------------------------
// find_repeats helpers
// -----------------------------------------------------------------------

// Mark positions where input[i] == input[i+1]
// flags[i] = 1 if repeat, 0 otherwise; last element always gets 0
__global__ void mark_repeats_kernel(int* input, int* flags, int length) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < length - 1) { flags[i] = (input[i] == input[i + 1]) ? 1 : 0; } 
    else if (i < length) { flags[i] = 0; } // no next element, can't be a repeat pair 
    
}

// Scatter: for each flagged position, write the index to output
// scan[i] tells us where in the output array to write index i
__global__ void scatter_repeats_kernel(int* flags, int* scan, int* output, int length) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < length && flags[i] == 1) { output[scan[i]] = i; }
}

// -----------------------------------------------------------------------
// find_repeats
// -----------------------------------------------------------------------
int find_repeats(int* device_input, int length, int* device_output) {
    int rounded_length = nextPow2(length);
    int num_blocks = (length + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;

    int* flags;
    int* scan_result;
    cudaMalloc(&flags,       rounded_length * sizeof(int));
    cudaMalloc(&scan_result, rounded_length * sizeof(int));
    // zero out the full buffer including padding, so scan doesn't pick up garbage
    cudaMemset(flags,       0, rounded_length * sizeof(int));
    cudaMemset(scan_result, 0, rounded_length * sizeof(int));

    // step 1: mark adjacent duplicates
    mark_repeats_kernel<<<num_blocks, THREADS_PER_BLOCK>>>(device_input, flags, length);

    // step 2: copy flags into scan_result so exclusive_scan can work in-place on it
    cudaMemcpy(scan_result, flags, rounded_length * sizeof(int), cudaMemcpyDeviceToDevice);

    // step 3: exclusive scan on the flags
    // after this: scan_result[i] = number of repeats at positions 0..i-1
    exclusive_scan(flags, rounded_length, scan_result);

    // step 4: scatter repeat indices into output
    scatter_repeats_kernel<<<num_blocks, THREADS_PER_BLOCK>>>(flags, scan_result, device_output, length);

    // step 5: total count = scan_result[last] + flags[last]
    // flags[length-1] is always 0, but using the formula is clean and general
    int last_scan = 0, last_flag = 0;
    cudaMemcpy(&last_scan, scan_result + length - 1, sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(&last_flag, flags       + length - 1, sizeof(int), cudaMemcpyDeviceToHost);

    cudaFree(flags); cudaFree(scan_result);

    return last_scan + last_flag;
}

// -----------------------------------------------------------------------
// cudaFindRepeats -- timing wrapper (unchanged from starter)
// -----------------------------------------------------------------------
double cudaFindRepeats(int *input, int length, int *output, int *output_length) {
    int *device_input; int *device_output;
    int rounded_length = nextPow2(length);

    cudaMalloc((void **)&device_input,  rounded_length * sizeof(int));
    cudaMalloc((void **)&device_output, rounded_length * sizeof(int));
    cudaMemcpy(device_input, input, length * sizeof(int), cudaMemcpyHostToDevice);

    cudaDeviceSynchronize();
    double startTime = CycleTimer::currentSeconds();
    int result = find_repeats(device_input, length, device_output);
    cudaDeviceSynchronize();
    double endTime = CycleTimer::currentSeconds();

    *output_length = result;
    cudaMemcpy(output, device_output, length * sizeof(int), cudaMemcpyDeviceToHost);

    cudaFree(device_input); cudaFree(device_output);

    return endTime - startTime;
}

void printCudaInfo() {
    int deviceCount = 0;
    cudaGetDeviceCount(&deviceCount);
    printf("---------------------------------------------------------\n");
    printf("Found %d CUDA devices\n", deviceCount);
    for (int i = 0; i < deviceCount; i++) {
        cudaDeviceProp deviceProps;
        cudaGetDeviceProperties(&deviceProps, i);
        printf("Device %d: %s\n", i, deviceProps.name);
        printf("   SMs:        %d\n", deviceProps.multiProcessorCount);
        printf("   Global mem: %.0f MB\n", static_cast<float>(deviceProps.totalGlobalMem) / (1024 * 1024));
        printf("   CUDA Cap:   %d.%d\n", deviceProps.major, deviceProps.minor);
    }
    printf("---------------------------------------------------------\n");
}