#!/bin/bash
#SBATCH --job-name=parallel-computation
#SBATCH --output=parallel-%j.out
#SBATCH --error=parallel-%j.err
#SBATCH --time=00:10:00
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=1G

echo "Starting parallel computation job"
echo "Job ID: $SLURM_JOB_ID"
echo "Running on nodes: $SLURM_JOB_NODELIST"
echo "Total tasks: $SLURM_NTASKS"

# Load any required modules (example)
# module load python/3.9

# Run parallel computation
srun --ntasks=$SLURM_NTASKS bash -c '
    echo "Task $SLURM_PROCID running on $(hostname)"
    # Simulate computation
    python3 -c "
import time
import math
import os

task_id = int(os.environ.get(\"SLURM_PROCID\", 0))
print(f\"Task {task_id}: Computing prime numbers...\")

def is_prime(n):
    if n < 2:
        return False
    for i in range(2, int(math.sqrt(n)) + 1):
        if n % i == 0:
            return False
    return True

# Find primes in different ranges for each task
start = task_id * 1000 + 1
end = (task_id + 1) * 1000
primes = [n for n in range(start, end) if is_prime(n)]
print(f\"Task {task_id}: Found {len(primes)} primes between {start} and {end}\")
time.sleep(2)  # Simulate additional work
print(f\"Task {task_id}: Completed\")
"
'

echo "Parallel computation completed at: $(date)"
