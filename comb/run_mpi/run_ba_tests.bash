#!/bin/bash

divide_x=""
divide_y=""
divide_z=""
test_script=""
procs_per_node=-1

positional_arg=0

################################################################################
#
# Usage:
#     run_tests.bash [optional flags] divide_x divide_y divide_z test_script
#
# Beschreibung:
#     Dieses Skript startet einen Test mit Prozessaufteilung im 3D-Raum.
#     Jeder Wert (divide_x, divide_y, divide_z) gibt die Anzahl der Prozesse auf
#     den jeweiligen Achsen an. procs_per_node kann über -ppn oder --procs-per-node 
#     gesetzt werden.
#
# Argumente:
#     -ppn <num>           Optional: Prozesse pro Node (Default: 1)
#     divide_x             Prozesse entlang der x-Achse
#     divide_y             Prozesse entlang der y-Achse
#     divide_z             Prozesse entlang der z-Achse
#     test_script          Testskript, das ausgeführt werden soll
#
# Beispiele:
#     run_ba_tests.bash 2 2 2 basic_ba_tests.bash
#         # Startet 2x2x2=8 Prozesse, Standard 1 pro Node
#
#     run_ba_tests.bash -ppn 4 4 2 2 basic_ba_tests.bash
#         # Startet 4x2x2=16 Prozesse, jeweils 4 pro Node
#
#
################################################################################

while [ "$#" -gt 0 ]; do

   if [[ "$1" =~ ^\-.* ]]; then

        if [[ "x$1" == "x-ppn" || "x$1" == "x--procs-per-node" ]]; then
            if [ "$#" -le 1 ]; then
                echo "missing argument to $1" 1>&2
                exit 1
            fi
            natural_re='^[0-9]+$'
            if ! [[ "$2" =~ $natural_re ]]; then
                echo "invalid arguments $1 $2: argument to $1 must be a number" 1>&2
                exit 1
            fi
            procs_per_node="$2"
            shift   # entfernt -ppn oder --procs-per-node
            shift   # entfernt die folgende Zahl!
            continue
        else

         echo "unknown arg $1" 1>&2
         exit 1

      fi

   else

        if [[ "x$positional_arg" == "x0" ]]; then
            divide_x="$1"
        elif [[ "x$positional_arg" == "x1" ]]; then
            divide_y="$1"
        elif [[ "x$positional_arg" == "x2" ]]; then
            divide_z="$1"
        elif [[ "x$positional_arg" == "x3" ]]; then
            test_script="$1"
        else
            echo "Found extra positional arg $1" 1>&2
            exit 1
        fi

      let positional_arg=positional_arg+1
   fi

   shift

done


if [[ "x" == "x$divide_x" || "x" == "x$divide_y" || "x" == "x$divide_z" ]]; then
   echo "Nicht alle divide-Parameter gesetzt!" 1>&2
   exit 1
fi
if [[ "x" == "x$test_script" ]]; then
   echo "test_script nicht angegeben!" 1>&2
   exit 1
fi

let procs=divide_x*divide_y*divide_z

if [ ! -f  "$test_script" ]; then
   echo "tests script $test_script not found"
   exit 1
fi

# Choose a command to get nodes
if [[ ! "x" == "x$SYS_TYPE" ]]; then
   if [[ "x$SYS_TYPE" =~ xblueos.*_p9 ]]; then
      # Command used to get nodes on sierra systems

    if [[ "x-1" == "x$procs_per_node" ]]; then
    procs_per_node=1
    fi

    let nodes=(procs+procs_per_node-1)/procs_per_node

      # get_nodes="bsub -nnodes ${nodes} -core_isolation 2 -W 240 -G guests -Is -XF"
      get_nodes="lalloc ${nodes} -W 240 --shared-launch"

   elif [[ "x$SYS_TYPE" =~ xblueos.* ]]; then
      # Command used to get nodes on EA systems

    if [[ "x-1" == "x$procs_per_node" ]]; then
    procs_per_node=1
    fi

    let nodes=(procs+procs_per_node-1)/procs_per_node

      get_nodes="bsub -n ${procs} -R \"span[ptile=${procs_per_node}]\" -W 240 -G guests -Is -XF"

   elif [[ "x$SYS_TYPE" =~ xtoss_4_x86_64_ib_cray ]]; then
      # Command used to get nodes on ElCap EA systems

    if [[ "x-1" == "x$procs_per_node" ]]; then
    procs_per_node=1
    fi

    let nodes=(procs+procs_per_node-1)/procs_per_node

      get_nodes="salloc -N${nodes} -t 240 --exclusive"

   else
      # Command used to get nodes on slurm scheduled systems

    if [[ "x-1" == "x$procs_per_node" ]]; then
    procs_per_node=1
    fi

    let nodes=(procs+procs_per_node-1)/procs_per_node

      get_nodes=""

   fi
else
   # Command used to get nodes on other systems
    if [[ "x-1" == "x$procs_per_node" ]]; then
    procs_per_node=1
    fi

    let nodes=(procs+procs_per_node-1)/procs_per_node

   # Don't know how to get nodes, defer to mpi in next script
   get_nodes=""

fi

divide="${divide_x}_${divide_y}_${divide_z}"
run_tests="$test_script $nodes $procs $divide_x $divide_y $divide_z"

full_test="${get_nodes} ${run_tests}"

echo "${full_test}"
time ${full_test}
