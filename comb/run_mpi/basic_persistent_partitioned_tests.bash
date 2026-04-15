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
   
   # Tatsächlicher exec-Befehlt. srun geht leider nicht
   # --bind-to core: jeden Prozess fest an Kerne binden
   # --map-by slot:PE=2: 2 Prozesse pro Rank
   run_mpi="mpiexec --bind-to core --map-by slot:PE=2 -np $procs"

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


# Some Output Varibales
DIVIDE="${divide_x}_${divide_y}_${divide_z}"
NODES="$nodes"
PROCESSES="$procs"


# Choose arguments for comb

# lokale Gittergröße
elems_per_procs_x=64
elems_per_procs_y=64
elems_per_procs_z=64

# Iterationen
CYCLES=10 # 
# OpenMP-Threads -> für 1:1 Mapping in partitioned policy anpassen!!!
THREADS=2 
# Variablen pro Gitterzelle
VARS=3

# x,y,z - sizes of the grid
let size_x=divide_x*elems_per_procs_x
let size_y=divide_y*elems_per_procs_y
let size_z=divide_z*elems_per_procs_z
GRID="${size_x}_${size_y}_${size_z}" # used for Output
comb_args=$GRID
# divide the grid into a number of procs per side
comb_args="${comb_args} -divide ${divide_x}_${divide_y}_${divide_z}"
# set the grid to be periodic in each dimension
comb_args="${comb_args} -periodic 1_1_1"
# set the halo width or number of ghost zones
comb_args="${comb_args} -ghost 1_1_1"
# set number of grid variables
comb_args="${comb_args} -vars ${VARS}"
# set number of communication cycles
comb_args="${comb_args} -cycles ${CYCLES}" 
# set cutoff between large and small message packing/unpacking kernels
comb_args="${comb_args} -comm cutoff 250"
# activate parallel openmpi
comb_args="${comb_args} -exec enable omp"
# set the number of omp threads per process
comb_args="${comb_args} -omp_threads ${THREADS}"
# enable tests passing cuda device or managed memory to mpi
# comb_args="${comb_args} -cuda_aware_mpi"

# MPI Kommuniktionsmuster. Für BA alle 3 "enablen"
comb_args="${comb_args} -comm enable mpi"
comb_args="${comb_args} -comm enable mpi_persistent"
comb_args="${comb_args} -comm enable mpi_partitioned"

# diese Optionen wie im Paper erwähnt deaktivieren
comb_args="${comb_args} -comm disallow per_message_pack_fusing"
comb_args="${comb_args} -comm disallow message_group_pack_fusing"

# Sequentiell vs Parallel (packing/unpacking) für BA omp "enablen"
comb_args="${comb_args} -exec enable omp" # für >= 2 Threads aktivieren
comb_args="${comb_args} -exec disable seq" # für == 1 Threads aktivieren 


# set up the base command to run a test
# use sep_out.bash to separate each rank's output
run_test_base="${run_mpi} ${run_comb}"

# Run a test with this comm method
echo "${run_test_base} ${comb_args}"
${run_test_base} ${comb_args}

echo "benchmarks done"

# Ergebnisverzeichnis 
RESULTDIR="results_mpi" 
DATESTR=$(date +%Y%m%d_%H%M%S) 
RUNSUBDIR="${RESULTDIR}/run_${GRID}_${DIVIDE}_${CYCLES}_$DATESTR"
mkdir -p "$RUNSUBDIR"

# Comb .csv Summarys in neuen Unterordner legen 
for FILE in Comb_*.csv; do 
    if [ -e "$FILE" ]; then 
        mv "$FILE" "$RUNSUBDIR/" 
    fi 
done

# --- Relevanten Daten für BA zusammenfassen --- 
OUTEXT="$RUNSUBDIR/extract_summary.txt"
# Parameter-Header 
echo "# ===== PARAMETERS =====" > "$OUTEXT"

echo "# --- System/Parallelisierung ---"              >> "$OUTEXT"
echo "# MPI ranks (processes):           $PROCESSES"  >> "$OUTEXT"
echo "# Nodes:                           $NODES"      >> "$OUTEXT"

RANKS_PER_NODE=$((PROCESSES / NODES))
echo "# MPI ranks per node:              $RANKS_PER_NODE" >> "$OUTEXT"

echo "# OpenMP threads per rank:         $THREADS"    >> "$OUTEXT"
THREADS_PER_NODE=$((RANKS_PER_NODE * THREADS))
echo "# OpenMP threads per node:         $THREADS_PER_NODE" >> "$OUTEXT"

TOTAL_THREADS=$((PROCESSES * THREADS))
echo "# Total threads (ranks*threads):   $TOTAL_THREADS" >> "$OUTEXT"

if [ -n "$SLURM_NTASKS" ] && [ -n "$SLURM_CPUS_PER_TASK" ]; then
  TOTAL_CPUS=$((SLURM_NTASKS * SLURM_CPUS_PER_TASK))
  echo "# Total CPU-cores (Slurm allocation): $TOTAL_CPUS" >> "$OUTEXT"
fi

echo "# --- Grid-Setup ---" >> "$OUTEXT"
echo "# Grid total:          $GRID" >> "$OUTEXT"
echo "# Grid per process:    ${elems_per_procs_x}_${elems_per_procs_y}_$\
{elems_per_procs_z}" >> "$OUTEXT"
echo "# Grid division:       $DIVIDE" >> "$OUTEXT"
echo "# Vars per field:      $VARS" >> "$OUTEXT"

echo "# --- Benchmark ---" >> "$OUTEXT"
echo "# Cycles:              $CYCLES" >> "$OUTEXT"
echo "#" >> "$OUTEXT"

# Nur die MPI-, Persistent-, Partitoned- Abschnitte extrahieren und nach
# Testvariante kategorisieren
declare -a variants=(
    "seq Host Buffers seq Host seq Host"
    "omp Host Buffers seq Host seq Host"
    "omp Host Buffers omp Host seq Host"
    "omp Host Buffers omp Host omp Host"
)
declare -a comms=(
    "mpi Mesh"
    "mpi_persistent Mesh"
    "mpi_partitioned Mesh"
)

comm_name() {
    case "$1" in
        "mpi Mesh") echo "MPI Standard";;
        "mpi_persistent Mesh") echo "MPI Persistent";;
        "mpi_partitioned Mesh") echo "MPI Partitioned";;
        *) echo "$1";;
    esac
}

for v in "${variants[@]}"; do
    echo "### Test-Variante: $v" >> "$OUTEXT"
    for c in "${comms[@]}"; do
        echo "# -- $(comm_name "$c") --" >> "$OUTEXT"
        awk -v pat="$v" -v comm="$c" '
            BEGIN {inblock=0}
            $0 ~ "^Starting test Comm " comm " " pat {inblock=1; print $0; next}
            inblock && $0 ~ /^Starting test Comm / && $0 !~ ("^Starting test Comm " comm " " pat) {inblock=0}
            inblock && NF {print}
        ' "$RUNSUBDIR"/Comb_*_summary.csv >> "$OUTEXT"
        echo "" >> "$OUTEXT"
    done
    echo "--------------------------------------------" >> "$OUTEXT"
done


echo "Relevanten Daten befinden sich in $RUNSUBDIR/" 
echo "Auszug der Summary-Daten inkl. Parametern: $OUTEXT"



