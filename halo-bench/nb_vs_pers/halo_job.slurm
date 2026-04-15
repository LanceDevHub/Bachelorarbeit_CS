#!/bin/bash
#SBATCH --job-name=halo_bench
#SBATCH --nodes=32
#SBATCH --ntasks=1024
#SBATCH --ntasks-per-node=32
#SBATCH --cpus-per-task=1
#SBATCH --partition=ki-parallel
#SBATCH --time=00:20:00
#SBATCH --output=log/halo_bench.%j.out
#SBATCH --error=log/halo_bench.%j.err

module purge
module load compiler/GCC/13.3.0
module load mpi/OpenMPI/5.0.3-GCC-13.3.0

cd "$SLURM_SUBMIT_DIR"

mpirun -np 1024 ./halo_bench --cells 4096 --iters 1000
