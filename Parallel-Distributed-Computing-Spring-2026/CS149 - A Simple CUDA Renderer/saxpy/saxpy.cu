#include <stdio.h>

#include <cuda.h>
#include <cuda_runtime.h>
#include <driver_functions.h>

#include "CycleTimer.h"


// Return GB/sec
float GBPerSec(int bytes, float sec) { return static_cast<float>(bytes) / (1024. * 1024. * 1024.) / sec; }


// This is the CUDA "kernel" function that is run on the GPU.
// You know this because it is marked as a __global__ function.
__global__ void
saxpy_kernel(int N, float alpha, float* x, float* y, float* result) {
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    if (index < N) { result[index] = alpha * x[index] + y[index]; }
}


void saxpyCuda(int N, float alpha, float* xarray, float* yarray, float* resultarray) {

    int totalBytes = sizeof(float) * 3 * N;

    const int threadsPerBlock = 512;
    const int blocks = (N + threadsPerBlock - 1) / threadsPerBlock;

    float* device_x      = nullptr;
    float* device_y      = nullptr;
    float* device_result = nullptr;

    // TODO: allocate device memory buffers on the GPU using cudaMalloc
    cudaMalloc(&device_x,      sizeof(float) * N);
    cudaMalloc(&device_y,      sizeof(float) * N);
    cudaMalloc(&device_result, sizeof(float) * N);

    // Timer A start —> from starter (full round-trip)
    double startTime = CycleTimer::currentSeconds();

    // TODO: copy input arrays to the GPU using cudaMemcpy
    cudaMemcpy(device_x, xarray, sizeof(float) * N, cudaMemcpyHostToDevice);
    cudaMemcpy(device_y, yarray, sizeof(float) * N, cudaMemcpyHostToDevice);

    // Timer B start: kernel only
    double kernelStartTime = CycleTimer::currentSeconds();

    saxpy_kernel<<<blocks, threadsPerBlock>>>(N, alpha, device_x, device_y, device_result);
    // Sync required —> kernel is async, without this Timer B measures ~0ms
    cudaDeviceSynchronize();

    // Timer B end: kernel only
    double kernelEndTime = CycleTimer::currentSeconds();

    // TODO: copy result from GPU using cudaMemcpy
    cudaMemcpy(resultarray, device_result, sizeof(float) * N, cudaMemcpyDeviceToHost);

    // Timer A end —> from starter
    double endTime = CycleTimer::currentSeconds();

    cudaError_t errCode = cudaPeekAtLastError();
    if (errCode != cudaSuccess) { fprintf(stderr, "WARNING: A CUDA error occured: code=%d, %s\n", errCode, cudaGetErrorString(errCode)); }

    // Timer A print —> from starter
    double overallDuration = endTime - startTime;
    printf("Effective BW by CUDA saxpy: %.3f ms\t\t[%.3f GB/s]\n", 1000.f * overallDuration, GBPerSec(totalBytes, overallDuration));

    // Timer B print —> ADDED
    double kernelDuration = kernelEndTime - kernelStartTime;
    printf("Kernel-only time:           %.3f ms\t\t[%.3f GB/s]\n", 1000.f * kernelDuration, GBPerSec(totalBytes, kernelDuration));

    // TODO: free device memory buffers using cudaFree
    cudaFree(device_x); cudaFree(device_y); cudaFree(device_result);
}


void printCudaInfo() {
    int deviceCount = 0;
    cudaGetDeviceCount(&deviceCount);

    printf("---------------------------------------------------------\n");
    printf("Found %d CUDA devices\n", deviceCount);

    for (int i=0; i<deviceCount; i++) {
        cudaDeviceProp deviceProps;
        cudaGetDeviceProperties(&deviceProps, i);
        printf("Device %d: %s\n", i, deviceProps.name);
        printf("   SMs:        %d\n", deviceProps.multiProcessorCount);
        printf("   Global mem: %.0f MB\n", static_cast<float>(deviceProps.totalGlobalMem) / (1024 * 1024));
        printf("   CUDA Cap:   %d.%d\n", deviceProps.major, deviceProps.minor);
    }
    printf("---------------------------------------------------------\n");
}
