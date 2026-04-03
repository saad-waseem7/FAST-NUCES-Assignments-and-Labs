#include <algorithm>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <thread>

#include "CycleTimer.h"

using namespace std;

typedef struct
{
  // Control work assignments
  int start, end;

  // Shared by all functions
  double *data;
  double *clusterCentroids;
  int *clusterAssignments;
  double *currCost;
  int M, N, K;
} WorkerArgs;

/**
 * Checks if the algorithm has converged.
 *
 * @param prevCost Pointer to the K dimensional array containing cluster costs
 *    from the previous iteration.
 * @param currCost Pointer to the K dimensional array containing cluster costs
 *    from the current iteration.
 * @param epsilon Predefined hyperparameter which is used to determine when
 *    the algorithm has converged.
 * @param K The number of clusters.
 *
 * NOTE: DO NOT MODIFY THIS FUNCTION!!!
 */
static bool stoppingConditionMet(double *prevCost, double *currCost,
                                 double epsilon, int K)
{
  for (int k = 0; k < K; k++)
  {
    if (abs(prevCost[k] - currCost[k]) > epsilon)
      return false;
  }
  return true;
}

/**
 * Computes L2 distance between two points of dimension nDim.
 *
 * @param x Pointer to the beginning of the array representing the first
 *     data point.
 * @param y Poitner to the beginning of the array representing the second
 *     data point.
 * @param nDim The dimensionality (number of elements) in each data point
 *     (must be the same for x and y).
 */

inline double distSq(double *x, double *y, int nDim)
{
  double accum = 0.0;
  for (int i = 0; i < nDim; i++) {
    double diff = x[i] - y[i];
    accum += diff * diff;
  }
  return accum;
}

void assignmentWorker(WorkerArgs *const args, int startM, int endM, double *localCost)
{
  int K = args->K;
  int N = args->N;
  for (int k = 0; k < K; k++) { localCost[k] = 0.0; }

  for (int m = startM; m < endM; m++)
  {
    double minD2 = 1e30;
    int bestK = 0;
    for (int k = 0; k < K; k++) {
      double d2 = distSq(&args->data[m * N], &args->clusterCentroids[k * N], N);
      if (d2 < minD2) {
        minD2 = d2;
        bestK = k;
      }
    }
    args->clusterAssignments[m] = bestK;
    localCost[bestK] += minD2;
  }
}

void centroidWorker(WorkerArgs *const args, int startM, int endM, double *localCentroids, int *localCounts)
{
  int N = args->N;
  int K = args->K;
  for (int i = 0; i < K * N; i++) { localCentroids[i] = 0.0; }
  for (int i = 0; i < K; i++) { localCounts[i] = 0; }

  for (int m = startM; m < endM; m++) {
    int k = args->clusterAssignments[m];
    localCounts[k]++;
    for (int n = 0; n < N; n++) { localCentroids[k * N + n] += args->data[m * N + n]; }
  }
}

void computeAssignments(WorkerArgs *const args)
{
  int nWorkers = 6;
  thread threads[nWorkers];
  int K = args->K;

  double *thrdCosts = new double[nWorkers * K];

  int place = args->M / nWorkers;
  for (int t = 0; t < nWorkers; t++) {
    int s = t * place;
    int e = (t == nWorkers - 1) ? args->M : s + place;
    threads[t] = thread(assignmentWorker, args, s, e, &thrdCosts[t * K]);
  }
  for (int t = 0; t < nWorkers; t++) { threads[t].join(); }

  for (int k = 0; k < K; k++) {
    args->currCost[k] = 0.0;
    for (int t = 0; t < nWorkers; t++) { args->currCost[k] += thrdCosts[t * K + k]; }
  }
  delete[] thrdCosts;
}

void computeCentroids(WorkerArgs *const args)
{
  int nWorkers = 6;
  int K = args->K;
  int N = args->N;
  double *allLocalCentroids = new double[nWorkers * K * N];
  int *allLocalCounts = new int[nWorkers * K];
  thread threads[nWorkers];

  int place = args->M / nWorkers;
  for (int t = 0; t < nWorkers; t++) {
    int s = t * place;
    int e = (t == nWorkers - 1) ? args->M : s + place;
    threads[t] = thread(centroidWorker, args, s, e, &allLocalCentroids[t * K * N], &allLocalCounts[t * K]);
  }
  for (int t = 0; t < nWorkers; t++) { threads[t].join(); }

  for (int k = 0; k < K; k++) {
    int totalKCount = 0;
    for (int t = 0; t < nWorkers; t++) { totalKCount += allLocalCounts[t * K + k]; }
    int divisor = (totalKCount > 0) ? totalKCount : 1;
    for (int n = 0; n < N; n++) {
      double sum = 0;
      for (int t = 0; t < nWorkers; t++) { sum += allLocalCentroids[t * K * N + k * N + n]; }
      args->clusterCentroids[k * N + n] = sum / divisor;
    }
  }
  delete[] allLocalCentroids;
  delete[] allLocalCounts;
}

/**
 * Computes the K-Means algorithm, using thread to parallelize the work.
 *
 * @param data Pointer to an array of length M*N representing the M different N
 *     dimensional data points clustered. The data is layed out in a "data point
 *     major" format, so that data[i*N] is the start of the i'th data point in
 *     the array. The N values of the i'th datapoint are the N values in the
 *     range data[i*N] to data[(i+1) * N].
 * @param clusterCentroids Pointer to an array of length K*N representing the K
 *     different N dimensional cluster centroids. The data is laid out in
 *     the same way as explained above for data.
 * @param clusterAssignments Pointer to an array of length M representing the
 *     cluster assignments of each data point, where clusterAssignments[i] = j
 *     indicates that data point i is closest to cluster centroid j.
 * @param M The number of data points to cluster.
 * @param N The dimensionality of the data points.
 * @param K The number of cluster centroids.
 * @param epsilon The algorithm is said to have converged when
 *     |currCost[i] - prevCost[i]| < epsilon for all i where i = 0, 1, ..., K-1
 */
void kMeansThread(double *data, double *clusterCentroids, int *clusterAssignments,
                  int M, int N, int K, double epsilon)
{

  // Used to track convergence
  double *prevCost = new double[K];
  double *currCost = new double[K];

  // The WorkerArgs array is used to pass inputs to and return output from
  // functions.
  WorkerArgs args;
  args.data = data;
  args.clusterCentroids = clusterCentroids;
  args.clusterAssignments = clusterAssignments;
  args.currCost = currCost;
  args.M = M;
  args.N = N;
  args.K = K;

  // Initialize arrays to track cost
  for (int k = 0; k < K; k++) {
    prevCost[k] = 1e30;
    currCost[k] = 0.0;
  }

  double totalAssign = 0, totalCentroids = 0;
  // double totalCost = 0;
  /* Main K-Means Algorithm Loop */
  int iter = 0;
  while (!stoppingConditionMet(prevCost, currCost, epsilon, K)) {
    // Update cost arrays (for checking convergence criteria)
    for (int k = 0; k < K; k++) { prevCost[k] = currCost[k]; }

    // Setup args struct
    args.start = 0;
    args.end = K;

    double t1 = CycleTimer::currentSeconds();
    computeAssignments(&args);
    double t2 = CycleTimer::currentSeconds();
    totalAssign += t2 - t1;

    double t3 = CycleTimer::currentSeconds();
    computeCentroids(&args);
    double t4 = CycleTimer::currentSeconds();
    totalCentroids += t4 - t3;

    iter++;
  }
  // prints once at the end
  printf("\n--- Timing Breakdown (%d iterations) ---\n", iter);
  printf("computeAssignments total: %.4f sec\n", totalAssign);
  printf("computeCentroids   total: %.4f sec\n", totalCentroids);
  // printf("computeCost        total: %.4f sec\n", totalCost);

  delete[] currCost;
  delete[] prevCost;
}
