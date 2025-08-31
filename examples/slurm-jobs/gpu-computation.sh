#!/bin/bash
#SBATCH --job-name=gpu-computation
#SBATCH --output=gpu-%j.out
#SBATCH --error=gpu-%j.err
#SBATCH --time=00:15:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --gres=gpu:1

echo "GPU computation job starting"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "Available GPUs: $CUDA_VISIBLE_DEVICES"

# Check for GPU availability
if command -v nvidia-smi &> /dev/null; then
    echo "GPU Information:"
    nvidia-smi
else
    echo "No GPU detected, running CPU-only computation"
fi

# Example GPU computation using Python
python3 -c "
import time
import numpy as np

print('Starting matrix computation...')

# Large matrix multiplication
size = 2000
print(f'Creating {size}x{size} matrices')

# Generate random matrices
A = np.random.rand(size, size).astype(np.float32)
B = np.random.rand(size, size).astype(np.float32)

start_time = time.time()

# Matrix multiplication
C = np.dot(A, B)

end_time = time.time()

print(f'Matrix multiplication completed in {end_time - start_time:.2f} seconds')
print(f'Result matrix shape: {C.shape}')
print(f'Result checksum: {np.sum(C):.2f}')
"

echo "GPU computation job completed at: $(date)"
