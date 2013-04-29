/*
 * Copyright 1993-2010 NVIDIA Corporation.  All rights reserved.
 *
 * NVIDIA Corporation and its licensors retain all intellectual property and 
 * proprietary rights in and to this software and related documentation. 
 * Any use, reproduction, disclosure, or distribution of this software 
 * and related documentation without an express license agreement from
 * NVIDIA Corporation is strictly prohibited.
 *
 * Please refer to the applicable NVIDIA end user license agreement (EULA) 
 * associated with this source code for terms and conditions that govern 
 * your use of this NVIDIA software.
 * 
 */


#include <stdio.h>
#include <cuda.h>
#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include "Fitness.h"

const int threadsPerBlock = 32*32;
const int blocksPerGrid = 32*32;

__device__ __constant__ int choose_cache[44][6];
__device__ __constant__ char adj[43][43];

__global__ void eval(int *c) 
{
    __shared__ short cache[threadsPerBlock];
    int cacheIndex = threadIdx.x;
	int sum = 0; // number of cliques found by this thread
	int arr[5] = { 0, 0, 0, 0, 0 };

	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	int offset = gridDim.x * blockDim.x; // our "stride" for multiple passes

	while (tid < UPPER_BOUND) {
		int a = N;
		int b = K;
		int x = 962597 - tid; // x is the "dual" of m

		for (int i = 0; i < K; i++) {
			int v = a - 1;

			while (choose_cache[v][b] > x) {
				v--;
			}

			arr[i] = v;
			x = x - choose_cache[arr[i]][b];
			a = arr[i];
			b--;
		}

		for (int i = 0; i < K; i++) {
			arr[i] = (N - 1) - arr[i];
		}
            
		int result = adj[arr[0]][arr[1]] +
					 adj[arr[0]][arr[2]] +
					 adj[arr[0]][arr[3]] +
					 adj[arr[0]][arr[4]] +
					 adj[arr[1]][arr[2]] +
					 adj[arr[1]][arr[3]] +
					 adj[arr[1]][arr[4]] +
					 adj[arr[2]][arr[3]] +
					 adj[arr[2]][arr[4]] +
					 adj[arr[3]][arr[4]];
            
		sum += (result == 0 || result == KC2);

		tid += offset; // move on to next pass
	}

    cache[cacheIndex] = sum; // populate the cache values
    __syncthreads(); // synchronize threads in this block

    // threadsPerBlock must be a power of 2 because of the following:
    int i = blockDim.x / 2;
	while (i != 0) {
		if (cacheIndex < i) {
			cache[cacheIndex] += cache[cacheIndex + i];
		}

		__syncthreads(); // be sure every array has finished
		i /= 2;
	}

    if (cacheIndex == 0) {
        c[blockIdx.x] = cache[0]; //number of cliques found by this block
	}
}

int CudaEval(char *adjacency_matrix)
{
	int           c, *partial_c;
    int           *dev_partial_c;

	partial_c = (int*) malloc(blocksPerGrid * sizeof(int));
	cudaMalloc((void**) &dev_partial_c, blocksPerGrid * sizeof(int));

	cudaMemcpyToSymbol(adj, adjacency_matrix, 43 * 43 * sizeof(char));

	eval<<<blocksPerGrid,threadsPerBlock>>>(dev_partial_c);

	// copy the array 'c' back from the GPU to the CPU
	cudaMemcpy(partial_c, dev_partial_c, blocksPerGrid * sizeof(int), cudaMemcpyDeviceToHost);

	// sum all the blocks' sums
	c = 0;

	for (int i = 0; i < blocksPerGrid; i++) {
		c = c + partial_c[i];
	}

	cudaFree(dev_partial_c);
	free(partial_c);
	
	return c;
}

void CudaInit()
{
	int h_choose_cache[][6] = {
        {0, 0, 0, 0, 0, 0},
        {0, 1, 0, 0, 0, 0},
        {0, 2, 1, 0, 0, 0},
        {0, 3, 3, 1, 0, 0},
        {0, 4, 6, 4, 1, 0},
        {0, 5, 10, 10, 5, 1},
        {0, 6, 15, 20, 15, 6},
        {0, 7, 21, 35, 35, 21},
        {0, 8, 28, 56, 70, 56},
        {0, 9, 36, 84, 126, 126},
        {0, 10, 45, 120, 210, 252},
        {0, 11, 55, 165, 330, 462},
        {0, 12, 66, 220, 495, 792},
        {0, 13, 78, 286, 715, 1287},
        {0, 14, 91, 364, 1001, 2002},
        {0, 15, 105, 455, 1365, 3003},
        {0, 16, 120, 560, 1820, 4368},
        {0, 17, 136, 680, 2380, 6188},
        {0, 18, 153, 816, 3060, 8568},
        {0, 19, 171, 969, 3876, 11628},
        {0, 20, 190, 1140, 4845, 15504},
        {0, 21, 210, 1330, 5985, 20349},
        {0, 22, 231, 1540, 7315, 26334},
        {0, 23, 253, 1771, 8855, 33649},
        {0, 24, 276, 2024, 10626, 42504},
        {0, 25, 300, 2300, 12650, 53130},
        {0, 26, 325, 2600, 14950, 65780},
        {0, 27, 351, 2925, 17550, 80730},
        {0, 28, 378, 3276, 20475, 98280},
        {0, 29, 406, 3654, 23751, 118755},
        {0, 30, 435, 4060, 27405, 142506},
        {0, 31, 465, 4495, 31465, 169911},
        {0, 32, 496, 4960, 35960, 201376},
        {0, 33, 528, 5456, 40920, 237336},
        {0, 34, 561, 5984, 46376, 278256},
        {0, 35, 595, 6545, 52360, 324632},
        {0, 36, 630, 7140, 58905, 376992},
        {0, 37, 666, 7770, 66045, 435897},
        {0, 38, 703, 8436, 73815, 501942},
        {0, 0, 741, 9139, 82251, 575757},
        {0, 0, 0, 9880, 91390, 658008},
        {0, 0, 0, 0, 101270, 749398},
        {0, 0, 0, 0, 0, 850668},
        {0, 0, 0, 0, 0, 962598}};

	cudaMemcpyToSymbol(choose_cache, h_choose_cache, sizeof(int) * 44 * 6);
}