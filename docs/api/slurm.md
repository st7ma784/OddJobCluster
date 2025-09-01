# SLURM API Reference

## Overview
SLURM REST API and command-line interface reference for the cluster.

## REST API Endpoints
SLURM provides a REST API for job management and cluster information.

### Authentication
```bash
# Generate JWT token
scontrol token
```

### Job Management
```bash
# Submit job via API
curl -X POST -H "X-SLURM-USER-TOKEN: $TOKEN" \
  -H "Content-Type: application/json" \
  http://localhost:6820/slurm/v0.0.37/job/submit \
  -d '{"job": {"name": "test-job", "script": "#!/bin/bash\necho hello"}}'

# Get job info
curl -H "X-SLURM-USER-TOKEN: $TOKEN" \
  http://localhost:6820/slurm/v0.0.37/job/{job_id}
```

## Command Line Interface

### Job Commands
```bash
# Submit job
sbatch job_script.sh

# View queue
squeue

# Cancel job
scancel job_id

# Job information
scontrol show job job_id
```

### Node Commands
```bash
# Node information
sinfo
scontrol show nodes

# Node status
scontrol update NodeName=node01 State=DRAIN Reason="maintenance"
```

### Account Management
```bash
# Add account
sacctmgr add account myaccount

# Add user
sacctmgr add user username account=myaccount

# View associations
sacctmgr show associations
```
