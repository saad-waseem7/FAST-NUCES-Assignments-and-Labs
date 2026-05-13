#include <string>
#include <algorithm>
#include <math.h>
#include <stdio.h>
#include <vector>

#include <cuda.h>
#include <cuda_runtime.h>
#include <driver_functions.h>

#include "cudaRenderer.h"
#include "image.h"
#include "noise.h"
#include "sceneLoader.h"
#include "util.h"

#define BLOCKX 16
#define BLOCKY 16
#define BLOCKSIZE 256
#define SCAN_BLOCK_DIM 256

#include "exclusiveScan.cu_inl"
#include "circleBoxTest.cu_inl"

// struct: GlobalConstants
// Holds all renderer parameters that are accessed by CUDA kernels.
// Stored in device constant memory for efficient access across threads.

struct GlobalConstants
{

    SceneName sceneName;

    int numCircles;
    float *position;
    float *velocity;
    float *color;
    float *radius;

    int imageWidth;
    int imageHeight;
    float *imageData;
};

__constant__ GlobalConstants cuConstRendererParams;

__constant__ int cuConstNoiseYPermutationTable[256];
__constant__ int cuConstNoiseXPermutationTable[256];
__constant__ float cuConstNoise1DValueTable[256];

#define COLOR_MAP_SIZE 5
__constant__ float cuConstColorRamp[COLOR_MAP_SIZE][3];

#include "noiseCuda.cu_inl"
#include "lookupColor.cu_inl"

// kernel: kernelClearImageSnowflake
// Clears the image buffer with a white-gray gradient effect used for snowflake rendering.
// Each thread handles one pixel, computing a shade based on vertical position.

__global__ void kernelClearImageSnowflake()
{
    int imageX = blockIdx.x * blockDim.x + threadIdx.x;
    int imageY = blockIdx.y * blockDim.y + threadIdx.y;

    int width = cuConstRendererParams.imageWidth;
    int height = cuConstRendererParams.imageHeight;

    if (imageX >= width || imageY >= height)
        return;

    int offset = 4 * (imageY * width + imageX);
    float shade = .4f + .45f * static_cast<float>(height - imageY) / height;
    float4 value = make_float4(shade, shade, shade, 1.f);

    *(float4 *)(&cuConstRendererParams.imageData[offset]) = value;
}

// kernel: kernelClearImage
// Clears the entire image buffer to a specified color (RGBA).
// Each thread sets the color for one pixel in the image.

__global__ void kernelClearImage(float r, float g, float b, float a)
{

    int imageX = blockIdx.x * blockDim.x + threadIdx.x;
    int imageY = blockIdx.y * blockDim.y + threadIdx.y;

    int width = cuConstRendererParams.imageWidth;
    int height = cuConstRendererParams.imageHeight;

    if (imageX >= width || imageY >= height)
        return;

    int offset = 4 * (imageY * width + imageX);
    float4 value = make_float4(r, g, b, a);

    *(float4 *)(&cuConstRendererParams.imageData[offset]) = value;
}

// kernel: kernelAdvanceFireWorks
// Updates positions and velocities of firework particles over one time step.
// Firework centers remain fixed; sparks are reset when they exceed max distance.

__global__ void kernelAdvanceFireWorks()
{
    const float dt = 1.f / 60.f;
    const float pi = 3.14159;
    const float maxDist = 0.25f;

    float *velocity = cuConstRendererParams.velocity;
    float *position = cuConstRendererParams.position;
    float *radius = cuConstRendererParams.radius;

    int index = blockIdx.x * blockDim.x + threadIdx.x;
    if (index >= cuConstRendererParams.numCircles)
        return;

    if (0 <= index && index < NUM_FIREWORKS)
    {
        return;
    }
    int fIdx = (index - NUM_FIREWORKS) / NUM_SPARKS;
    int sfIdx = (index - NUM_FIREWORKS) % NUM_SPARKS;

    int index3i = 3 * fIdx;
    int sIdx = NUM_FIREWORKS + fIdx * NUM_SPARKS + sfIdx;
    int index3j = 3 * sIdx;

    float cx = position[index3i];
    float cy = position[index3i + 1];

    position[index3j] += velocity[index3j] * dt;
    position[index3j + 1] += velocity[index3j + 1] * dt;

    float sx = position[index3j];
    float sy = position[index3j + 1];

    float cxsx = sx - cx;
    float cysy = sy - cy;

    float dist = sqrt(cxsx * cxsx + cysy * cysy);
    if (dist > maxDist)
    {
        float angle = (sfIdx * 2 * pi) / NUM_SPARKS;
        float sinA = sin(angle);
        float cosA = cos(angle);
        float x = cosA * radius[fIdx];
        float y = sinA * radius[fIdx];

        position[index3j] = position[index3i] + x;
        position[index3j + 1] = position[index3i + 1] + y;
        position[index3j + 2] = 0.0f;

        velocity[index3j] = cosA / 5.0;
        velocity[index3j + 1] = sinA / 5.0;
        velocity[index3j + 2] = 0.0f;
    }
}

// kernel: kernelAdvanceHypnosis
// Animates circles by gradually increasing their radius until a threshold.
// When radius exceeds cutoff, it resets to a small value for pulsing effect.

__global__ void kernelAdvanceHypnosis()
{
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    if (index >= cuConstRendererParams.numCircles)
        return;

    float *radius = cuConstRendererParams.radius;

    float cutOff = 0.5f;
    if (radius[index] > cutOff)
    {
        radius[index] = 0.02f;
    }
    else
    {
        radius[index] += 0.01f;
    }
}

// kernel: kernelAdvanceBouncingBalls
// Simulates gravity and bouncing physics for falling balls over one time step.
// Applies gravity, drag, and bounces off the bottom boundary.

__global__ void kernelAdvanceBouncingBalls()
{
    const float dt = 1.f / 60.f;
    const float kGravity = -2.8f;
    const float kDragCoeff = -0.8f;
    const float epsilon = 0.001f;

    int index = blockIdx.x * blockDim.x + threadIdx.x;

    if (index >= cuConstRendererParams.numCircles)
        return;

    float *velocity = cuConstRendererParams.velocity;
    float *position = cuConstRendererParams.position;

    int index3 = 3 * index;
    float oldVelocity = velocity[index3 + 1];
    float oldPosition = position[index3 + 1];

    if (oldVelocity == 0.f && oldPosition == 0.f)
    {
        return;
    }

    if (position[index3 + 1] < 0 && oldVelocity < 0.f)
    {
        velocity[index3 + 1] *= kDragCoeff;
    }
    velocity[index3 + 1] += kGravity * dt;

    position[index3 + 1] += velocity[index3 + 1] * dt;

    if (fabsf(velocity[index3 + 1] - oldVelocity) < epsilon && oldPosition < 0.0f && fabsf(position[index3 + 1] - oldPosition) < epsilon)
    {
        velocity[index3 + 1] = 0.f;
        position[index3 + 1] = 0.f;
    }
}

// kernel: kernelAdvanceSnowflake
// Updates snowflake positions and velocities with gravity, drag, and perlin noise.
// Resets snowflakes to the top when they leave the visible boundaries.

__global__ void kernelAdvanceSnowflake()
{

    int index = blockIdx.x * blockDim.x + threadIdx.x;

    if (index >= cuConstRendererParams.numCircles)
        return;

    const float dt = 1.f / 60.f;
    const float kGravity = -1.8f;
    const float kDragCoeff = 2.f;

    int index3 = 3 * index;

    float *positionPtr = &cuConstRendererParams.position[index3];
    float *velocityPtr = &cuConstRendererParams.velocity[index3];

    float3 position = *((float3 *)positionPtr);
    float3 velocity = *((float3 *)velocityPtr);

    float forceScaling = fmin(fmax(1.f - position.z, .1f), 1.f);

    float3 noiseInput;
    noiseInput.x = 10.f * position.x;
    noiseInput.y = 10.f * position.y;
    noiseInput.z = 255.f * position.z;
    float2 noiseForce = cudaVec2CellNoise(noiseInput, index);
    noiseForce.x *= 7.5f;
    noiseForce.y *= 5.f;

    float2 dragForce;
    dragForce.x = -1.f * kDragCoeff * velocity.x;
    dragForce.y = -1.f * kDragCoeff * velocity.y;

    position.x += velocity.x * dt;
    position.y += velocity.y * dt;

    velocity.x += forceScaling * (noiseForce.x + dragForce.y) * dt;
    velocity.y += forceScaling * (kGravity + noiseForce.y + dragForce.y) * dt;

    float radius = cuConstRendererParams.radius[index];

    if ((position.y + radius < 0.f) ||
        (position.x + radius) < -0.f ||
        (position.x - radius) > 1.f)
    {
        noiseInput.x = 255.f * position.x;
        noiseInput.y = 255.f * position.y;
        noiseInput.z = 255.f * position.z;
        noiseForce = cudaVec2CellNoise(noiseInput, index);

        position.x = .5f + .5f * noiseForce.x;
        position.y = 1.35f + radius;

        velocity.x = 2.f * noiseForce.y;
        velocity.y = 0.f;
    }

    *((float3 *)positionPtr) = position;
    *((float3 *)velocityPtr) = velocity;
}

// device: shadePixel
// Computes and blends a circle's color contribution to a pixel using alpha blending.
// Skips pixels outside the circle; applies different shading for snowflakes vs regular objects.

__device__ __inline__ void
shadePixel(int circleIndex, float2 pixelCenter, float3 p, float4 *imagePtr)
{

    float diffX = p.x - pixelCenter.x;
    float diffY = p.y - pixelCenter.y;
    float pixelDist = diffX * diffX + diffY * diffY;

    float rad = cuConstRendererParams.radius[circleIndex];
    float maxDist = rad * rad;

    if (pixelDist > maxDist)
        return;

    float3 rgb;
    float alpha;

    if (cuConstRendererParams.sceneName == SNOWFLAKES || cuConstRendererParams.sceneName == SNOWFLAKES_SINGLE_FRAME)
    {

        const float kCircleMaxAlpha = .5f;
        const float falloffScale = 4.f;

        float normPixelDist = sqrt(pixelDist) / rad;
        rgb = lookupColor(normPixelDist);

        float maxAlpha = .6f + .4f * (1.f - p.z);
        maxAlpha = kCircleMaxAlpha * fmaxf(fminf(maxAlpha, 1.f), 0.f);
        alpha = maxAlpha * exp(-1.f * falloffScale * normPixelDist * normPixelDist);
    }
    else
    {
        int index3 = 3 * circleIndex;
        rgb = *(float3 *)&(cuConstRendererParams.color[index3]);
        alpha = .5f;
    }

    float oneMinusAlpha = 1.f - alpha;

    float4 existingColor = *imagePtr;
    float4 newColor;
    newColor.x = alpha * rgb.x + oneMinusAlpha * existingColor.x;
    newColor.y = alpha * rgb.y + oneMinusAlpha * existingColor.y;
    newColor.z = alpha * rgb.z + oneMinusAlpha * existingColor.z;
    newColor.w = alpha + existingColor.w;

    *imagePtr = newColor;
}

// kernel: kernelRenderCircles
// Renders all circles to the image buffer using spatial tiling and bitmask optimization.
// Each thread processes one pixel; warp-level ballot creates efficient circle hit detection.

__global__ void kernelRenderCircles()
{
    __shared__ float4 shCirclePosRad[BLOCKSIZE];
    const int width = cuConstRendererParams.imageWidth;
    const int height = cuConstRendererParams.imageHeight;
    const float invW = 1.0f / width;
    const float invH = 1.0f / height;

    const int X0 = blockIdx.x * BLOCKX;
    const int Y0 = blockIdx.y * BLOCKY;

    const float normX0 = X0 * invW, normX1 = (X0 + BLOCKX) * invW;
    const float normY0 = Y0 * invH, normY1 = (Y0 + BLOCKY) * invH;

    const int threadid = threadIdx.y * BLOCKX + threadIdx.x;

    const int pixelx = X0 + threadIdx.x;
    const int pixely = Y0 + threadIdx.y;
    const bool validPixel = (pixelx < width && pixely < height);

    float2 pixelPos = make_float2(
        invW * (static_cast<float>(pixelx) + 0.5f),
        invH * (static_cast<float>(pixely) + 0.5f));

    float4 *imgPtr = validPixel ? (float4 *)(&cuConstRendererParams.imageData[4 * (pixely * width + pixelx)]) : nullptr;

    for (int _i = 0; _i < cuConstRendererParams.numCircles; _i += BLOCKSIZE)
    {
        int i = _i + threadid;

        if (i < cuConstRendererParams.numCircles)
        {
            float3 p = *(float3 *)(&cuConstRendererParams.position[i * 3]);
            float r = cuConstRendererParams.radius[i];
            shCirclePosRad[threadid] = make_float4(p.x, p.y, p.z, r);
        }
        __syncthreads();

        uint32_t mask = 0;
        bool isContained = false;
        if (i < cuConstRendererParams.numCircles)
        {
            float4 c = shCirclePosRad[threadid];
            isContained = circleInBox(c.x, c.y, c.w, normX0, normX1, normY1, normY0);
        }

        uint32_t warpMask = __ballot_sync(0xFFFFFFFF, isContained);

        if (validPixel)
        {
            __shared__ uint32_t blockMasks[BLOCKSIZE / 32];
            if ((threadid % 32) == 0)
            {
                blockMasks[threadid / 32] = warpMask;
            }
            __syncthreads();

            for (int w = 0; w < (BLOCKSIZE / 32); w++)
            {
                uint32_t currentWarpMask = blockMasks[w];

                while (currentWarpMask > 0)
                {
                    int bitPos = __ffs(currentWarpMask) - 1;
                    int localIdx = (w * 32) + bitPos;
                    int globalCirIdx = _i + localIdx;

                    float4 c = shCirclePosRad[localIdx];
                    shadePixel(globalCirIdx, pixelPos, make_float3(c.x, c.y, c.z), imgPtr);

                    currentWarpMask &= ~(1u << bitPos);
                }
            }
        }
        __syncthreads();
    }
}

CudaRenderer::CudaRenderer()
// Constructor: initializes all member variables to NULL or zero.
// Allocates no GPU memory; setup() must be called separately.
{
    image = NULL;

    numCircles = 0;
    position = NULL;
    velocity = NULL;
    color = NULL;
    radius = NULL;

    cudaDevicePosition = NULL;
    cudaDeviceVelocity = NULL;
    cudaDeviceColor = NULL;
    cudaDeviceRadius = NULL;
    cudaDeviceImageData = NULL;
}

CudaRenderer::~CudaRenderer()
// Destructor: frees host and GPU memory allocations for image, particles, and device buffers.
{

    if (image)
    {
        delete image;
    }

    if (position)
    {
        delete[] position;
        delete[] velocity;
        delete[] color;
        delete[] radius;
    }

    if (cudaDevicePosition)
    {
        cudaFree(cudaDevicePosition);
        cudaFree(cudaDeviceVelocity);
        cudaFree(cudaDeviceColor);
        cudaFree(cudaDeviceRadius);
        cudaFree(cudaDeviceImageData);
    }
}

const Image *
CudaRenderer::getImage()
// Returns the rendered image after copying it from GPU device memory to host.
{

    printf("Copying image data from device\n");

    cudaMemcpy(image->data,
               cudaDeviceImageData,
               sizeof(float) * 4 * image->width * image->height,
               cudaMemcpyDeviceToHost);

    return image;
}

void CudaRenderer::loadScene(SceneName scene, int seed)
// Loads a scene configuration with the specified name and random seed.
{
    sceneName = scene;
    loadCircleScene(sceneName, numCircles, position, velocity, color, radius, seed);
}

void CudaRenderer::setup()
// Initializes CUDA device, allocates GPU memory, and copies scene data and lookup tables.
// Must be called before rendering.
{

    int deviceCount = 0;
    std::string name;
    cudaError_t err = cudaGetDeviceCount(&deviceCount);

    printf("---------------------------------------------------------\n");
    printf("Initializing CUDA for CudaRenderer\n");
    printf("Found %d CUDA devices\n", deviceCount);

    for (int i = 0; i < deviceCount; i++)
    {
        cudaDeviceProp deviceProps;
        cudaGetDeviceProperties(&deviceProps, i);
        name = deviceProps.name;

        printf("Device %d: %s\n", i, deviceProps.name);
        printf("   SMs:        %d\n", deviceProps.multiProcessorCount);
        printf("   Global mem: %.0f MB\n", static_cast<float>(deviceProps.totalGlobalMem) / (1024 * 1024));
        printf("   CUDA Cap:   %d.%d\n", deviceProps.major, deviceProps.minor);
    }
    printf("---------------------------------------------------------\n");

    cudaMalloc(&cudaDevicePosition, sizeof(float) * 3 * numCircles);
    cudaMalloc(&cudaDeviceVelocity, sizeof(float) * 3 * numCircles);
    cudaMalloc(&cudaDeviceColor, sizeof(float) * 3 * numCircles);
    cudaMalloc(&cudaDeviceRadius, sizeof(float) * numCircles);
    cudaMalloc(&cudaDeviceImageData, sizeof(float) * 4 * image->width * image->height);

    cudaMemcpy(cudaDevicePosition, position, sizeof(float) * 3 * numCircles, cudaMemcpyHostToDevice);
    cudaMemcpy(cudaDeviceVelocity, velocity, sizeof(float) * 3 * numCircles, cudaMemcpyHostToDevice);
    cudaMemcpy(cudaDeviceColor, color, sizeof(float) * 3 * numCircles, cudaMemcpyHostToDevice);
    cudaMemcpy(cudaDeviceRadius, radius, sizeof(float) * numCircles, cudaMemcpyHostToDevice);

    GlobalConstants params;
    params.sceneName = sceneName;
    params.numCircles = numCircles;
    params.imageWidth = image->width;
    params.imageHeight = image->height;
    params.position = cudaDevicePosition;
    params.velocity = cudaDeviceVelocity;
    params.color = cudaDeviceColor;
    params.radius = cudaDeviceRadius;
    params.imageData = cudaDeviceImageData;

    cudaMemcpyToSymbol(cuConstRendererParams, &params, sizeof(GlobalConstants));

    int *permX;
    int *permY;
    float *value1D;
    getNoiseTables(&permX, &permY, &value1D);
    cudaMemcpyToSymbol(cuConstNoiseXPermutationTable, permX, sizeof(int) * 256);
    cudaMemcpyToSymbol(cuConstNoiseYPermutationTable, permY, sizeof(int) * 256);
    cudaMemcpyToSymbol(cuConstNoise1DValueTable, value1D, sizeof(float) * 256);

    float lookupTable[COLOR_MAP_SIZE][3] = {
        {1.f, 1.f, 1.f},
        {1.f, 1.f, 1.f},
        {.8f, .9f, 1.f},
        {.8f, .9f, 1.f},
        {.8f, 0.8f, 1.f},
    };

    cudaMemcpyToSymbol(cuConstColorRamp, lookupTable, sizeof(float) * 3 * COLOR_MAP_SIZE);
}

void CudaRenderer::allocOutputImage(int width, int height)
// Allocates a new image buffer for rendering output with specified dimensions.
{

    if (image)
        delete image;
    image = new Image(width, height);
}

void CudaRenderer::clearImage()
// Clears the image buffer to the appropriate background color for the current scene.
{

    dim3 blockDim(16, 16, 1);
    dim3 gridDim(
        (image->width + blockDim.x - 1) / blockDim.x,
        (image->height + blockDim.y - 1) / blockDim.y);

    if (sceneName == SNOWFLAKES || sceneName == SNOWFLAKES_SINGLE_FRAME)
    {
        kernelClearImageSnowflake<<<gridDim, blockDim>>>();
    }
    else
    {
        kernelClearImage<<<gridDim, blockDim>>>(1.f, 1.f, 1.f, 1.f);
    }
    cudaDeviceSynchronize();
}

void CudaRenderer::advanceAnimation()
// Advances the animation by one time step based on the current scene.
// Updates all object positions and velocities according to physics rules.
{
    dim3 blockDim(256, 1);
    dim3 gridDim((numCircles + blockDim.x - 1) / blockDim.x);

    if (sceneName == SNOWFLAKES)
    {
        kernelAdvanceSnowflake<<<gridDim, blockDim>>>();
    }
    else if (sceneName == BOUNCING_BALLS)
    {
        kernelAdvanceBouncingBalls<<<gridDim, blockDim>>>();
    }
    else if (sceneName == HYPNOSIS)
    {
        kernelAdvanceHypnosis<<<gridDim, blockDim>>>();
    }
    else if (sceneName == FIREWORKS)
    {
        kernelAdvanceFireWorks<<<gridDim, blockDim>>>();
    }
    cudaDeviceSynchronize();
}

void CudaRenderer::render()
// Renders all circles to the image buffer using CUDA kernels.
// Launches kernel with grid and block dimensions based on image size.
{
    dim3 blockDim(BLOCKX, BLOCKY);
    dim3 gridDim(
        (image->width + BLOCKX - 1) / BLOCKX,
        (image->height + BLOCKY - 1) / BLOCKY);
    kernelRenderCircles<<<gridDim, blockDim>>>();
    cudaDeviceSynchronize();
}
