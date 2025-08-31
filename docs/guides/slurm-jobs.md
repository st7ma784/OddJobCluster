# SLURM Job Submission Guide

Learn how to submit and manage jobs on your Kubernetes cluster with SLURM workload manager.

## Basic Job Submission

### Your First Job

Create a simple job script:

```bash
#!/bin/bash
#SBATCH --job-name=my-first-job
#SBATCH --output=output-%j.out
#SBATCH --error=error-%j.err
#SBATCH --time=00:05:00
#SBATCH --nodes=1
#SBATCH --ntasks=1

echo "Hello from SLURM on $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
date
```

Submit the job:
```bash
sbatch my-first-job.sh
```

### Job Monitoring

```bash
# View job queue
squeue

# View job details
scontrol show job <job-id>

# View job history
sacct -j <job-id>

# Cancel a job
scancel <job-id>
```

## Resource Allocation

### CPU and Memory

```bash
#!/bin/bash
#SBATCH --job-name=resource-demo
#SBATCH --cpus-per-task=4      # 4 CPU cores
#SBATCH --mem=8G               # 8GB memory
#SBATCH --time=01:00:00        # 1 hour time limit

# Your computation here
```

### Multi-node Jobs

```bash
#!/bin/bash
#SBATCH --job-name=multi-node
#SBATCH --nodes=2              # Use 2 nodes
#SBATCH --ntasks=8             # 8 total tasks
#SBATCH --ntasks-per-node=4    # 4 tasks per node

# Run MPI application
mpirun -n $SLURM_NTASKS ./my-mpi-program
```

### GPU Jobs

```bash
#!/bin/bash
#SBATCH --job-name=gpu-job
#SBATCH --gres=gpu:1           # Request 1 GPU
#SBATCH --mem=16G
#SBATCH --time=02:00:00

# Check GPU availability
nvidia-smi

# Run GPU computation
python3 gpu-script.py
```

## Job Arrays

Submit multiple similar jobs:

```bash
#!/bin/bash
#SBATCH --job-name=array-job
#SBATCH --array=1-10           # Submit 10 jobs
#SBATCH --output=array-%A_%a.out

echo "This is array task $SLURM_ARRAY_TASK_ID"
echo "Array job ID: $SLURM_ARRAY_JOB_ID"

# Process different input files
input_file="input_${SLURM_ARRAY_TASK_ID}.txt"
python3 process.py $input_file
```

## Advanced Features

### Job Dependencies

```bash
# Submit job A
job_a=$(sbatch --parsable job-a.sh)

# Submit job B that depends on job A
sbatch --dependency=afterok:$job_a job-b.sh
```

### Email Notifications

```bash
#!/bin/bash
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=your-email@domain.com

# Your job here
```

### Custom Partitions

```bash
#!/bin/bash
#SBATCH --partition=gpu        # Use GPU partition
#SBATCH --qos=high-priority    # High priority queue

# Your computation
```

## Sample Jobs

### Python Data Processing

```bash
#!/bin/bash
#SBATCH --job-name=data-processing
#SBATCH --output=processing-%j.out
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=02:00:00

# Load Python environment
source /opt/miniconda3/bin/activate
conda activate data-science

# Run processing script
python3 << 'EOF'
import pandas as pd
import numpy as np
from multiprocessing import Pool
import os

def process_chunk(chunk_id):
    # Simulate data processing
    data = np.random.rand(1000000)
    result = np.mean(data)
    print(f"Chunk {chunk_id}: mean = {result}")
    return result

if __name__ == "__main__":
    # Use all available CPUs
    num_processes = int(os.environ.get('SLURM_CPUS_PER_TASK', 1))
    
    with Pool(num_processes) as pool:
        results = pool.map(process_chunk, range(10))
    
    print(f"Overall mean: {np.mean(results)}")
EOF
```

### Machine Learning Training

```bash
#!/bin/bash
#SBATCH --job-name=ml-training
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=04:00:00

# Load ML environment
module load cuda/11.8
source venv/bin/activate

# Train model
python3 << 'EOF'
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset

# Check GPU availability
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Using device: {device}")

# Simple neural network
class SimpleNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(784, 128)
        self.fc2 = nn.Linear(128, 64)
        self.fc3 = nn.Linear(64, 10)
        
    def forward(self, x):
        x = torch.relu(self.fc1(x))
        x = torch.relu(self.fc2(x))
        return self.fc3(x)

# Create dummy data
X = torch.randn(1000, 784)
y = torch.randint(0, 10, (1000,))
dataset = TensorDataset(X, y)
dataloader = DataLoader(dataset, batch_size=32, shuffle=True)

# Train model
model = SimpleNet().to(device)
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters())

for epoch in range(10):
    for batch_x, batch_y in dataloader:
        batch_x, batch_y = batch_x.to(device), batch_y.to(device)
        
        optimizer.zero_grad()
        outputs = model(batch_x)
        loss = criterion(outputs, batch_y)
        loss.backward()
        optimizer.step()
    
    print(f"Epoch {epoch+1}, Loss: {loss.item():.4f}")

# Save model
torch.save(model.state_dict(), 'model.pth')
print("Model saved successfully")
EOF
```

### Bioinformatics Pipeline

```bash
#!/bin/bash
#SBATCH --job-name=bio-pipeline
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=08:00:00
#SBATCH --array=1-24

# Load bioinformatics tools
module load bwa/0.7.17
module load samtools/1.15
module load bcftools/1.15

# Process chromosome
CHROM=$SLURM_ARRAY_TASK_ID
REF_GENOME="/data/reference/genome.fa"
INPUT_DIR="/data/fastq"
OUTPUT_DIR="/data/results/chr${CHROM}"

mkdir -p $OUTPUT_DIR

echo "Processing chromosome $CHROM"

# Align reads
bwa mem -t $SLURM_CPUS_PER_TASK \
    $REF_GENOME \
    ${INPUT_DIR}/sample_chr${CHROM}_R1.fastq.gz \
    ${INPUT_DIR}/sample_chr${CHROM}_R2.fastq.gz \
    | samtools sort -@ $SLURM_CPUS_PER_TASK -o ${OUTPUT_DIR}/aligned.bam

# Index BAM file
samtools index ${OUTPUT_DIR}/aligned.bam

# Call variants
bcftools mpileup -f $REF_GENOME ${OUTPUT_DIR}/aligned.bam \
    | bcftools call -mv -Oz -o ${OUTPUT_DIR}/variants.vcf.gz

# Index VCF
bcftools index ${OUTPUT_DIR}/variants.vcf.gz

echo "Chromosome $CHROM processing completed"
```

## Job Optimization

### Memory Efficiency

```bash
#!/bin/bash
#SBATCH --job-name=memory-efficient
#SBATCH --mem-per-cpu=2G       # Memory per CPU core
#SBATCH --cpus-per-task=8

# Monitor memory usage
echo "Initial memory usage:"
free -h

# Your memory-intensive computation
python3 large-dataset-processing.py

echo "Final memory usage:"
free -h
```

### I/O Optimization

```bash
#!/bin/bash
#SBATCH --job-name=io-intensive
#SBATCH --cpus-per-task=4

# Use local scratch space for temporary files
SCRATCH_DIR="/tmp/job-$SLURM_JOB_ID"
mkdir -p $SCRATCH_DIR

# Copy input data to local storage
cp /shared/input/* $SCRATCH_DIR/

# Process data locally
cd $SCRATCH_DIR
./process-data.sh

# Copy results back
cp results/* /shared/output/

# Clean up
rm -rf $SCRATCH_DIR
```

## Troubleshooting

### Common Issues

**Job Pending**
```bash
# Check why job is pending
squeue -j <job-id> --start

# View cluster status
sinfo -l
```

**Out of Memory**
```bash
# Check memory usage in job output
grep -i "memory\|oom" slurm-*.out

# Request more memory
#SBATCH --mem=32G
```

**Time Limit Exceeded**
```bash
# Check job time usage
sacct -j <job-id> --format=JobID,Elapsed,Timelimit

# Request more time
#SBATCH --time=04:00:00
```

### Job Profiling

```bash
#!/bin/bash
#SBATCH --job-name=profiled-job

# Monitor resource usage
echo "Job started at: $(date)"
echo "Node: $(hostname)"
echo "CPUs allocated: $SLURM_CPUS_PER_TASK"

# Run with time profiling
/usr/bin/time -v python3 my-script.py

echo "Job completed at: $(date)"
```

## Best Practices

1. **Always specify resource requirements** accurately
2. **Use job arrays** for similar tasks
3. **Monitor resource usage** to optimize requests
4. **Use local scratch space** for temporary files
5. **Clean up** temporary files after job completion
6. **Test with small jobs** before scaling up
7. **Use appropriate partitions** for different workload types

## Integration with Jupyter

Submit jobs from Jupyter notebooks:

```python
import subprocess
import time

# Submit job
result = subprocess.run(['sbatch', 'my-job.sh'], 
                       capture_output=True, text=True)
job_id = result.stdout.strip().split()[-1]

print(f"Submitted job {job_id}")

# Monitor job status
while True:
    result = subprocess.run(['squeue', '-j', job_id], 
                           capture_output=True, text=True)
    if job_id not in result.stdout:
        break
    time.sleep(10)

print("Job completed!")
```

This guide covers the essential aspects of job submission and management in your SLURM cluster. For more advanced features, consult the SLURM documentation or use `man sbatch` for detailed options.
