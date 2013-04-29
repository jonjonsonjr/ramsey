/* 
 * Fitness function to evaluate the number of monochromatic 
 * cliques present in a given graph.
 *
 * Jon Johnson, Gabriel Triggs
 */
#include "Fitness.h"

/*
 * Populates adjacency matrix based on contents of char array.
 *
 */
void GetAdjacencyMatrixFromCharArray(char bit_arr[], char adj[N][N])
{
    int x = 0;

    for (int i = 0; i < N; i++) {
        for (int j = i + 1; j < N; j++) {
            adj[i][j] = bit_arr[x];
            adj[j][i] = bit_arr[x];
            x++;
        }
    }
}