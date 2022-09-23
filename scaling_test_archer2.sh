#!/bin/bash

#SBATCH --job-name=julia_reduction_test
#SBATCH --time=00:20:00
#SBATCH --nodes=16
#SBATCH --tasks-per-node=64
#SBATCH --cpus-per-task=1

#SBATCH --account=ta084-tk-driving
#SBATCH --partition=standard
#SBATCH --qos=lowpriority

export OMP_NUM_THREADS=1

export WRKDIR=/work/ta084/ta084/tk-drivingtest

export JULIA_DEPOT_PATH=$WRKDIR/julia-depot
export julia_exe=$WRKDIR/julia-1.8.1/bin/julia
export julia_script=$WRKDIR/julia_reduction_test/reduction.jl
for tasks in 16 32 64 128 256 512 1024
do
    srun --nodes=16 --ntasks=$tasks --distribution=block:block --hint=nomultithread $julia_exe $julia_script
done
