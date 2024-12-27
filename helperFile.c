#include <stdio.h>
#include <stdlib.h>
#include <math.h>

int const cellDist = 1;

int is_within_range(int x1, int y1, int x2, int y2, double range);

int main() {
    int D;
    float R;
    FILE *file;

    file = fopen("topology3.txt", "w");

    if (file == NULL) {
        printf("Error opening file");
        exit(1);
    }

    printf("Enter the diameter of the grid (D): ");
    scanf("%d", &D);
    printf("Enter the range (R): ");
    scanf("%f", &R);

    int grid[D][D];

    for(int i = 0; i < D; i++)
        for(int j = 0; j < D; j++)
            grid[i][j] = i*D + j;

    for(int i = 0; i < D; i++)
        for(int j = 0; j < D; j++){
            for(int k = i; k < D; k++)
                for(int l = 0; l < D; l++) {
                    if(is_within_range(i, j, k, l, R) && grid[i][j] < grid[k][l])
                        fprintf(file, "%d %d -50.0\n%d %d -50.0\n", grid[i][j], grid[k][l], grid[k][l], grid[i][j]);
                }
            fprintf(file, "\n");
        }

    fclose(file);

    return 0;
}

int is_within_range(int x1, int y1, int x2, int y2, double range) {
    double distance = sqrt((x1 - x2) * cellDist * (x1 - x2) * cellDist + (y1 - y2) * cellDist * (y1 - y2) * cellDist);
    int cond = distance <= range;
    return cond;
}