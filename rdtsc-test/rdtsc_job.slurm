#!/bin/bash

#SBATCH --job-name=rdtsc_dummy
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=ki-parallel
#SBATCH --time=00:05:00
#SBATCH --output=log/rdtsc_dummy.%j.out
#SBATCH --error=log/rdtsc_dummy.%j.err

echo "--- rdtsc Dummy Benchmark ---"
echo "Job-ID: $SLURM_JOB_ID"
echo "Datum: $(date)"
echo "Node: $SLURM_NODELIST"

module purge
module load compiler/GCC/13.3.0

cd $SLURM_SUBMIT_DIR

./rdtsc_dummy
