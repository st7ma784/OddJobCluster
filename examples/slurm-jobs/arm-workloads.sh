#!/bin/bash

# ARM-Optimized SLURM Job Examples
# Demonstrates workloads suitable for ARM-based compute nodes

echo "🚀 ARM Workload Examples for SLURM"
echo "=================================="

# Example 1: Basic ARM compute test
cat > arm-hello-world.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=arm-hello
#SBATCH --partition=arm_compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:05:00
#SBATCH --constraint=arm64

echo "Hello from ARM node: $(hostname)"
echo "Architecture: $(uname -m)"
echo "CPU info: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "Date: $(date)"

# Simple CPU test
echo "Running CPU test..."
time python3 -c "
import time
start = time.time()
result = sum(i*i for i in range(1000000))
print(f'Computed sum of squares: {result}')
print(f'Time taken: {time.time() - start:.2f} seconds')
"
EOF

# Example 2: Raspberry Pi specific workload
cat > rpi-temperature-monitor.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=rpi-temp-monitor
#SBATCH --partition=edge_compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:10:00
#SBATCH --constraint=arm64

echo "Raspberry Pi Temperature Monitoring Job"
echo "======================================="

# Check if running on Raspberry Pi
if command -v vcgencmd &> /dev/null; then
    echo "Running on Raspberry Pi"
    
    # Monitor temperature for 5 minutes
    for i in {1..30}; do
        TEMP=$(vcgencmd measure_temp | cut -d= -f2)
        CPU_FREQ=$(vcgencmd measure_clock arm | cut -d= -f2)
        GPU_MEM=$(vcgencmd get_mem gpu | cut -d= -f2)
        
        echo "$(date): Temp=$TEMP, CPU_Freq=$((CPU_FREQ/1000000))MHz, GPU_Mem=$GPU_MEM"
        
        # Throttling check
        THROTTLED=$(vcgencmd get_throttled)
        if [ "$THROTTLED" != "throttled=0x0" ]; then
            echo "WARNING: Throttling detected: $THROTTLED"
        fi
        
        sleep 10
    done
else
    echo "Not running on Raspberry Pi, using generic ARM monitoring"
    for i in {1..30}; do
        if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
            TEMP=$(($(cat /sys/class/thermal/thermal_zone0/temp)/1000))
            echo "$(date): CPU Temperature: ${TEMP}°C"
        fi
        sleep 10
    done
fi
EOF

# Example 3: Multi-architecture parallel job
cat > multi-arch-parallel.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=multi-arch-parallel
#SBATCH --nodes=2
#SBATCH --ntasks=8
#SBATCH --cpus-per-task=1
#SBATCH --time=00:15:00

echo "Multi-Architecture Parallel Computing"
echo "====================================="

# Get node information
echo "Job running on nodes:"
srun hostname | sort | uniq -c

# Parallel computation across architectures
srun python3 << 'PYTHON'
import os
import time
import platform
import multiprocessing

def compute_task(n):
    """CPU-intensive task suitable for any architecture"""
    start_time = time.time()
    
    # Prime number calculation
    def is_prime(num):
        if num < 2:
            return False
        for i in range(2, int(num ** 0.5) + 1):
            if num % i == 0:
                return False
        return True
    
    primes = [i for i in range(n*1000, (n+1)*1000) if is_prime(i)]
    
    end_time = time.time()
    
    return {
        'task_id': n,
        'hostname': platform.node(),
        'architecture': platform.machine(),
        'cpu_count': multiprocessing.cpu_count(),
        'primes_found': len(primes),
        'execution_time': end_time - start_time,
        'first_prime': primes[0] if primes else None,
        'last_prime': primes[-1] if primes else None
    }

# Run computation
task_id = int(os.environ.get('SLURM_PROCID', 0))
result = compute_task(task_id)

print(f"Task {result['task_id']} on {result['hostname']} ({result['architecture']}):")
print(f"  CPUs: {result['cpu_count']}")
print(f"  Primes found: {result['primes_found']}")
print(f"  Time: {result['execution_time']:.2f}s")
print(f"  Range: {result['first_prime']} - {result['last_prime']}")
PYTHON
EOF

# Example 4: ARM-specific container workload
cat > arm-container-job.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=arm-container
#SBATCH --partition=arm_compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:10:00
#SBATCH --constraint=arm64

echo "ARM Container Workload"
echo "====================="

# Run ARM64 container if Docker is available
if command -v docker &> /dev/null; then
    echo "Running ARM64 Python container..."
    
    # Pull and run ARM64 Python image
    docker run --rm --platform linux/arm64 python:3.9-slim python3 -c "
import platform
import sys
import time

print(f'Python version: {sys.version}')
print(f'Platform: {platform.platform()}')
print(f'Architecture: {platform.machine()}')
print(f'Processor: {platform.processor()}')

# Simple computation
start = time.time()
result = sum(x**2 for x in range(100000))
end = time.time()

print(f'Computation result: {result}')
print(f'Time taken: {end - start:.3f} seconds')
print('ARM container job completed successfully!')
"
else
    echo "Docker not available, running native Python"
    python3 -c "
import platform
import time

print(f'Native Python on {platform.machine()}')
start = time.time()
result = sum(x**2 for x in range(100000))
end = time.time()
print(f'Result: {result}, Time: {end - start:.3f}s')
"
fi
EOF

# Example 5: Mobile device workload (lightweight)
cat > mobile-device-job.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=mobile-compute
#SBATCH --partition=arm_compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --time=00:05:00
#SBATCH --mem=1G

echo "Mobile Device Compute Job"
echo "========================"

# Lightweight workload suitable for mobile devices
python3 << 'PYTHON'
import json
import time
import hashlib
import platform

def mobile_workload():
    """Lightweight computation suitable for mobile devices"""
    
    # System info
    info = {
        'hostname': platform.node(),
        'architecture': platform.machine(),
        'python_version': platform.python_version(),
        'start_time': time.time()
    }
    
    # JSON processing (common mobile task)
    data = []
    for i in range(1000):
        record = {
            'id': i,
            'timestamp': time.time(),
            'hash': hashlib.md5(f'record_{i}'.encode()).hexdigest(),
            'value': i ** 2
        }
        data.append(record)
    
    # Simple analytics
    total_value = sum(r['value'] for r in data)
    avg_value = total_value / len(data)
    
    info.update({
        'records_processed': len(data),
        'total_value': total_value,
        'average_value': avg_value,
        'end_time': time.time()
    })
    
    info['execution_time'] = info['end_time'] - info['start_time']
    
    return info

result = mobile_workload()
print(json.dumps(result, indent=2))
print(f"\nMobile workload completed in {result['execution_time']:.2f} seconds")
PYTHON
EOF

# Make all scripts executable
chmod +x *.sh

echo ""
echo "📋 ARM Workload Scripts Created:"
echo "================================"
echo "1. arm-hello-world.sh        - Basic ARM compute test"
echo "2. rpi-temperature-monitor.sh - Raspberry Pi monitoring"
echo "3. multi-arch-parallel.sh    - Cross-architecture parallel job"
echo "4. arm-container-job.sh      - ARM container workload"
echo "5. mobile-device-job.sh      - Lightweight mobile compute"
echo ""
echo "🚀 Usage Examples:"
echo "sbatch arm-hello-world.sh"
echo "sbatch rpi-temperature-monitor.sh"
echo "sbatch multi-arch-parallel.sh"
echo "sbatch arm-container-job.sh"
echo "sbatch mobile-device-job.sh"
echo ""
echo "📊 Monitor with:"
echo "squeue                    # View job queue"
echo "sinfo -p arm_compute     # View ARM partition"
echo "scontrol show job <id>   # Job details"
