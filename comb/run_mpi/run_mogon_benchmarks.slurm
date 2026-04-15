#!/bin/bash

#========[ + + + + Requirements + + + + ]========#
#SBATCH --comment=""
#SBATCH --job-name=comb_benchmark_lemter
#SBATCH --nodes=2
#SBATCH --ntasks=64
#SBATCH --ntasks-per-node=32
#SBATCH --cpus-per-task=2
#SBATCH --output=log/comb_benchmark_lemter.%j.out
#SBATCH --error=log/comb_benchmark_lemter.%j.err
#SBATCH -p ki-parallel
#SBATCH --time=01:00:00

# ======== [ + + + + Environment Setup + + + + ] ======== #
echo "--- Initializing Environment for Comb Benchmarks on Mogon ---"
echo "Job-ID: $SLURM_JOB_ID"
echo "Datum: $(date)"
echo "Hostnamen der zugewiesenen Knoten: $SLURM_NODELIST"

# Lade notwendige Module
module purge
module load compiler/GCC/13.3.0
module load mpi/OpenMPI/5.0.3-GCC-13.3.0

# Hardware-Check
# echo "=== CPU-Info ==="
# lscpu

# === OpenMP-Umgebung ===

# Anzahl der OpenMP-Threads pro MPI-Prozess
export OMP_NUM_THREADS=2

unset OMP_PLACES # wird in basic_persistent_partitioned_tests.bash geregelt

# Aktiviert festes Thread-Pinning auf diese Kerne
# -> 'close': Threads eines Ranks werden auf benachbarte Kerne gesetzt 
export OMP_PROC_BIND=close

# leider führt srun pro Thread/Core einen Rank aus :(
# deshalb den mpirun/mpiexec Pfad gehen    
# export SYS_TYPE=slurm

# === Log Ordner für Ausgaben erstellen ===
LOG_DIR="$HOME/comb/run_mpi/log"
mkdir -p "$LOG_DIR" || { 
    echo "FEHLER: Konnte Log-Ordner nicht erstellen: $LOG_DIR"; 
    exit 1;
}

# ==== Benchmark Skript ausführen ===
./run_ba_tests.bash -ppn 32 4 4 4 ./basic_persistent_partitioned_tests.bash

echo "--- Alle Comb MPI Benchmarks auf Mogon abgeschlossen. ---"
echo "Die Ergebnisse befinden sich in: $HOME/comb/run_mpi/results_mpi"
echo "Die Job-Ausgaben (stdout/stderr) sind in: \
$LOG_DIR/comb_benchmark_lemter.%j.out(.err)"