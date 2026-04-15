#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
    MPI_Init(&argc, &argv);

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    // Standardparameter aus Size-Increase Studie
    int cells_per_message = 256;
    int nvars             = 3;
    int iters             = 1000;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--iters") == 0 && i + 1 < argc) {
            iters = atoi(argv[i + 1]);
            ++i;
        } else if (strcmp(argv[i], "--cells") == 0 && i + 1 < argc) {
            cells_per_message = atoi(argv[i + 1]);
            ++i;
        }
    }

    // MPI Tags
    int left  = (rank - 1 + size) % size;
    int right = (rank + 1) % size;

    // Nachrichtengröße: cells * nvars * double
    int    doubles_per_msg = cells_per_message * nvars;
    size_t bytes_per_msg   = (size_t)doubles_per_msg * sizeof(double);

    double *send_left  = (double*)malloc(bytes_per_msg);
    double *send_right = (double*)malloc(bytes_per_msg);
    double *recv_left  = (double*)malloc(bytes_per_msg);
    double *recv_right = (double*)malloc(bytes_per_msg);

    if (!send_left || !send_right || !recv_left || !recv_right) {
        if (rank == 0) fprintf(stderr, "Memory allocation failed...\n");
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    // Puffer befüllen 
    for (int i = 0; i < doubles_per_msg; ++i) {
        send_left[i]  = 1.0 * rank;
        send_right[i] = 2.0 * rank;
        recv_left[i]  = 0.0;
        recv_right[i] = 0.0;
    }


    double nb_min_time = 0.0;
    double nb_max_time = 0.0;
    double nb_sum_time = 0.0;
    double nb_avg_time = 0.0;

    double per_min_time = 0.0;
    double per_max_time = 0.0;
    double per_sum_time = 0.0;
    double per_avg_time = 0.0;

    // 1) Non-blocking (Isend)
    {
        double t_start = 0.0, t_end = 0.0;
        double local_time = 0.0;
        MPI_Barrier(MPI_COMM_WORLD);

        t_start = MPI_Wtime();
        MPI_Request reqs[4];
        
        // Kommunikation 
        for (int it = 0; it < iters; ++it) {
            MPI_Irecv(recv_left,  doubles_per_msg, MPI_DOUBLE, left,  100, MPI_COMM_WORLD, &reqs[0]);
            MPI_Irecv(recv_right, doubles_per_msg, MPI_DOUBLE, right, 101, MPI_COMM_WORLD, &reqs[1]);

            MPI_Isend(send_right, doubles_per_msg, MPI_DOUBLE, right, 100, MPI_COMM_WORLD, &reqs[2]);
            MPI_Isend(send_left,  doubles_per_msg, MPI_DOUBLE, left,  101, MPI_COMM_WORLD, &reqs[3]);

            MPI_Waitall(4, reqs, MPI_STATUS_IGNORE);

            // Daten "lesen"
            recv_left[0]  += 1.0;
            recv_right[0] += 1.0;
        }
        t_end = MPI_Wtime();

        local_time = t_end - t_start;

        MPI_Reduce(&local_time, &nb_min_time, 1, MPI_DOUBLE, MPI_MIN, 0, MPI_COMM_WORLD);
        MPI_Reduce(&local_time, &nb_max_time, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
        MPI_Reduce(&local_time, &nb_sum_time, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);

    }
    

    // 2) Persistent (Send_init + Startall)

    {
        double t_start = 0.0, t_end = 0.0;
        double local_time = 0.0;
        
        MPI_Barrier(MPI_COMM_WORLD);

        t_start = MPI_Wtime();
        
        
        MPI_Request reqs[4];

        // Persistent Requests
        MPI_Send_init(send_right, doubles_per_msg, MPI_DOUBLE, right, 100, MPI_COMM_WORLD, &reqs[0]);
        MPI_Send_init(send_left,  doubles_per_msg, MPI_DOUBLE, left,  101, MPI_COMM_WORLD, &reqs[1]);
        MPI_Recv_init(recv_left,  doubles_per_msg, MPI_DOUBLE, left,  100, MPI_COMM_WORLD, &reqs[2]);
        MPI_Recv_init(recv_right, doubles_per_msg, MPI_DOUBLE, right, 101, MPI_COMM_WORLD, &reqs[3]);


        // Kommunikation
        for (int it = 0; it < iters; ++it) {
            MPI_Startall(4, reqs);
            MPI_Waitall(4, reqs, MPI_STATUS_IGNORE);

            // Daten "lesen"
            recv_left[0]  += 1.0;
            recv_right[0] += 1.0;
        }
        MPI_Request_free(&reqs[0]);
        MPI_Request_free(&reqs[1]);
        MPI_Request_free(&reqs[2]);
        MPI_Request_free(&reqs[3]);
        t_end = MPI_Wtime();

        // Aggregation über "Main" Rank
        local_time = t_end - t_start;
        MPI_Reduce(&local_time, &per_min_time, 1, MPI_DOUBLE, MPI_MIN, 0, MPI_COMM_WORLD);
        MPI_Reduce(&local_time, &per_max_time, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
        MPI_Reduce(&local_time, &per_sum_time, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);

    }

    

    // Timings bestimmen
    if (rank == 0) {
        nb_avg_time = nb_sum_time / size;
        per_avg_time = per_sum_time / size;


        // Ausgabe
        printf("===== Halo Benchmark (1D Ring, 2 Neighbours) =====\n");
        printf("Ranks                 : %d\n", size);
        printf("Cells per message     : %d\n", cells_per_message);
        printf("Variables per cell    : %d\n", nvars);
        printf("Doubles per message   : %d\n", doubles_per_msg);
        printf("Bytes per message     : %zu\n", bytes_per_msg);
        printf("Iterations            : %d\n\n", iters);

        // Non-blocking
        printf("Non-blocking (Isend/Irecv):\n");
        printf("  Total time [s]      : min = %.6e  avg = %.6e  max = %.6e\n",
            nb_min_time, nb_avg_time, nb_max_time);

        // Persistent
        printf("Persistent (Send_init/Startall):\n");
        printf("  Total time [s]      : min = %.6e  avg = %.6e  max = %.6e\n",
            per_min_time, per_avg_time, per_max_time);

        // Speedup basierend auf Average-Zeit
        double speedup_avg = (per_avg_time > 0.0) ? nb_avg_time / per_avg_time : 0.0;
        printf("Speedup (based on AVG time):\n");
        printf("  Speedup             : %.3f x\n", speedup_avg);
        
    }

    free(send_left);
    free(send_right);
    free(recv_left);
    free(recv_right);

    MPI_Finalize();
    return 0;
}
