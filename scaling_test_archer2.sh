#!/bin/bash

#SBATCH --job-name=julia_reduction_test
#SBATCH --time=0:10:0
#SBATCH --nodes=1
#SBATCH --tasks-per-node=32
#SBATCH --cpus-per-task=1

# Replace [budget code] below with your budget code (e.g. t01)
#SBATCH --account=e723
#SBATCH --partition=standard
#SBATCH --qos=short

# Set the number of threads to 1
#   This prevents any threaded system libraries from automatically 
#   using threading.
export OMP_NUM_THREADS=1

export JULIA_DEPOT_PATH=/work/e723/e723/tkoskela/julia_depot
export julia_exe=/work/e723/e723/tkoskela/julia_install/julia-1.8.1/bin/julia
export julia_script=/work/e723/e723/tkoskela/julia_reduction_test/reduction.jl
srun --nodes=1 --ntasks=32 --distribution=block:block --hint=nomultithread $julia_exe $julia_script
