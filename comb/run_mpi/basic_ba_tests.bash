#!/bin/bash

nodes="$1"
procs="$2"
divide_x="$3"
divide_y="$4"
divide_z="$5"

# Choose a command to run mpi based on the system being used
if [[ ! "x" == "x$SYS_TYPE" ]]; then
   if [[ "x$SYS_TYPE" =~ xblueos.*_p9 ]]; then
      # Command used to run mpi on sierra systems
      run_mpi="lrun -N$nodes -p$procs"
      # add arguments to turn on cuda aware mpi (optionally disable gpu direct)
      # run_mpi="${run_mpi} --smpiargs \"-gpu\""
      # run_mpi="${run_mpi} --smpiargs \"-gpu -disable_gdr\""
   elif [[ "x$SYS_TYPE" =~ xblueos.* ]]; then
      # Command used to run mpi on EA systems
      run_mpi="mpirun -np $procs /usr/tcetmp/bin/mpibind"
   else
      # Command used to run mpi on slurm scheduled systems
      run_mpi="srun -N$nodes -n$procs"
   fi
else
   # Command used to run mpi with mpirun
   # https://www.open-mpi.org/doc/v2.0/man1/mpirun.1.php
   # Note: you may need to use additional options to get reasonable mpi behavior
   # --host=hostname0,hostname1,... https://www.open-mpi.org/faq/?category=running#mpirun-hostfile
   # --hostfile my_hosts            https://www.open-mpi.org/faq/?category=running#mpirun-host
   run_mpi="mpirun -np $procs"

   # Command used to run mpi with mpiexec
   # https://www.mpich.org/static/docs/v3.1/www1/mpiexec.html
   # run_mpi="mpiexec -n $procs"
fi

# Note: you may need to bind processes to cores to get reasonable openmp behavior
# Your scheduler may help with this
# Otherwise you may need to set environment variables for each proc to bind it to cores/threads
# http://www.nersc.gov/users/software/programming-models/openmp/process-and-thread-affinity/
# Ex:
#   bash:
#     mpirun -np 1 bind_script comb
#   bind_script:
#     export OMP_PLACES={0,2} # this depends on the local rank of the process if running more than one process per node
#     exec $@

# Comb executable or symlink
run_comb="$(pwd)/comb"

# Choose arguments for comb
# elements on one side of the cube for each process
elems_per_procs_per_side=100 # 180
# x,y,z - sizes of the grid
let size_x=divide_x*elems_per_procs_per_side
let size_y=divide_y*elems_per_procs_per_side
let size_z=divide_z*elems_per_procs_per_side
comb_args="${size_x}_${size_y}_${size_z}"
# divide the grid into a number of procs per side
comb_args="${comb_args} -divide ${divide_x}_${divide_y}_${divide_z}"
# set the grid to be periodic in each dimension
comb_args="${comb_args} -periodic 1_1_1"
# set the halo width or number of ghost zones
comb_args="${comb_args} -ghost 1_1_1"
# set number of grid variables
comb_args="${comb_args} -vars 3"
# set number of communication cycles
comb_args="${comb_args} -cycles 200" # 100
# set cutoff between large and small message packing/unpacking kernels
comb_args="${comb_args} -comm cutoff 0"
# set the number of omp threads per process
comb_args="${comb_args} -omp_threads 2"
# activate parallel openmpi
comb_args="${comb_args} -exec enable omp"
# enable tests passing cuda device or managed memory to mpi
# comb_args="${comb_args} -cuda_aware_mpi"
# enable basic execution test (disables all others)
comb_args="${comb_args} -comm enable mpi"
comb_args="${comb_args} -comm enable mpi_partitioned"
comb_args="${comb_args} -comm enable mpi_persistent"
# comb_args="${comb_args} -exec enable seq"
# diese zwei Optionen deaktivieren (wie im Paper), um fairen Vergleich anzustreben
comb_args="${comb_args} -comm disallow per_message_pack_fusing"
comb_args="${comb_args} -comm disallow message_group_pack_fusing"


# set up the base command to run a test
# use sep_out.bash to separate each rank's output
run_test_base="${run_mpi} ${run_comb}"

# Run a test with this comm method
echo "${run_test_base} ${comb_args}"
${run_test_base} ${comb_args}

echo "done"

# test output!
echo "nodes: ${nodes}"
echo "procs: ${procs}"
echo "divide: ${divide_x}_${divide_y}_${divide_z}"

