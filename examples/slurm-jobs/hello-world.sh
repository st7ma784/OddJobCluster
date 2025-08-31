#!/bin/bash
#SBATCH --job-name=hello-world
#SBATCH --output=hello-world-%j.out
#SBATCH --error=hello-world-%j.err
#SBATCH --time=00:05:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G

echo "Hello from SLURM job on node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
echo "Job started at: $(date)"
echo "Running on $SLURM_NNODES nodes with $SLURM_NTASKS tasks"

# Simple computation
echo "Performing simple computation..."
for i in {1..10}; do
    echo "Iteration $i"
    sleep 1
done

echo "Job completed at: $(date)"
