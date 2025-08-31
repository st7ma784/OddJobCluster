# JupyterHub User Guide

Learn how to use JupyterHub for interactive computing on your Kubernetes cluster.

## Getting Started

### Accessing JupyterHub

1. Open your browser and navigate to: `https://<master-ip>/jupyter`
2. Login with your credentials (default: admin/admin)
3. Select your server options and start your notebook server

### First Login

After your first login:
1. Change your password in the Control Panel
2. Explore the available notebook environments
3. Create your first notebook

## Notebook Environments

### Available Kernels

- **Python 3**: Data science stack with pandas, numpy, matplotlib
- **R**: Statistical computing environment
- **Julia**: High-performance scientific computing
- **Scala**: Big data processing with Spark

### Pre-installed Packages

Python environment includes:
```python
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import scikit-learn
import tensorflow as tf
import torch
```

## Working with Data

### Uploading Files

1. Use the file browser in JupyterLab
2. Click "Upload" to add files from your computer
3. Drag and drop files directly into the interface

### Accessing Shared Storage

```python
# Access shared datasets
import os
shared_data = "/shared/datasets"
if os.path.exists(shared_data):
    print(f"Available datasets: {os.listdir(shared_data)}")
```

### Connecting to Databases

```python
import sqlalchemy as db

# Connect to cluster database
engine = db.create_engine('postgresql://user:pass@db-server:5432/mydb')
df = pd.read_sql('SELECT * FROM mytable', engine)
```

## SLURM Integration

### Submitting Jobs from Notebooks

```python
import subprocess
import time

# Create job script
job_script = """#!/bin/bash
#SBATCH --job-name=notebook-job
#SBATCH --output=job-%j.out
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=01:00:00

python3 -c "
import numpy as np
import time

# Heavy computation
data = np.random.rand(10000, 10000)
result = np.linalg.eigvals(data)
print(f'Computed {len(result)} eigenvalues')
time.sleep(30)  # Simulate long computation
"
"""

# Write job script
with open('notebook_job.sh', 'w') as f:
    f.write(job_script)

# Submit job
result = subprocess.run(['sbatch', 'notebook_job.sh'], 
                       capture_output=True, text=True)
job_id = result.stdout.strip().split()[-1]
print(f"Submitted job {job_id}")
```

### Monitoring Jobs

```python
def check_job_status(job_id):
    result = subprocess.run(['squeue', '-j', job_id], 
                           capture_output=True, text=True)
    if job_id in result.stdout:
        return "RUNNING"
    else:
        return "COMPLETED"

# Check status
status = check_job_status(job_id)
print(f"Job {job_id} status: {status}")
```

### Retrieving Results

```python
import glob

# Wait for job completion and get results
def wait_for_job(job_id, timeout=3600):
    start_time = time.time()
    while time.time() - start_time < timeout:
        if check_job_status(job_id) == "COMPLETED":
            return True
        time.sleep(10)
    return False

if wait_for_job(job_id):
    # Read job output
    output_files = glob.glob(f"job-{job_id}.out")
    if output_files:
        with open(output_files[0], 'r') as f:
            print("Job output:")
            print(f.read())
```

## Data Science Workflows

### Machine Learning Pipeline

```python
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report
import matplotlib.pyplot as plt

# Load data
df = pd.read_csv('/shared/datasets/sample_data.csv')

# Explore data
print(f"Dataset shape: {df.shape}")
print(f"Columns: {df.columns.tolist()}")
df.head()
```

```python
# Data preprocessing
X = df.drop('target', axis=1)
y = df['target']

# Split data
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# Train model
model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# Evaluate
predictions = model.predict(X_test)
print(classification_report(y_test, predictions))
```

### Visualization

```python
# Create visualizations
fig, axes = plt.subplots(2, 2, figsize=(12, 10))

# Feature importance
feature_importance = pd.DataFrame({
    'feature': X.columns,
    'importance': model.feature_importances_
}).sort_values('importance', ascending=False)

axes[0,0].barh(feature_importance['feature'][:10], 
               feature_importance['importance'][:10])
axes[0,0].set_title('Top 10 Feature Importance')

# Distribution plots
axes[0,1].hist(y, bins=20, alpha=0.7)
axes[0,1].set_title('Target Distribution')

# Correlation heatmap
corr_matrix = df.corr()
im = axes[1,0].imshow(corr_matrix, cmap='coolwarm', aspect='auto')
axes[1,0].set_title('Correlation Matrix')

# Scatter plot
axes[1,1].scatter(X_train.iloc[:,0], X_train.iloc[:,1], 
                  c=y_train, alpha=0.6)
axes[1,1].set_title('Feature Scatter Plot')

plt.tight_layout()
plt.show()
```

## Advanced Features

### Custom Environments

Create custom conda environments:

```bash
# In terminal
conda create -n myenv python=3.9
conda activate myenv
conda install jupyter ipykernel
python -m ipykernel install --user --name myenv --display-name "My Environment"
```

### Extensions and Widgets

```python
# Install JupyterLab extensions
!pip install ipywidgets
!jupyter labextension install @jupyter-widgets/jupyterlab-manager

# Interactive widgets
import ipywidgets as widgets
from IPython.display import display

slider = widgets.IntSlider(value=50, min=0, max=100, description='Value:')
display(slider)
```

### Collaborative Features

```python
# Share notebooks via Git
!git init
!git add notebook.ipynb
!git commit -m "Initial notebook"
!git remote add origin https://github.com/user/repo.git
!git push -u origin main
```

## GPU Computing

### TensorFlow/Keras

```python
import tensorflow as tf

# Check GPU availability
print("GPU Available: ", tf.config.list_physical_devices('GPU'))

# Simple neural network
model = tf.keras.Sequential([
    tf.keras.layers.Dense(128, activation='relu', input_shape=(784,)),
    tf.keras.layers.Dropout(0.2),
    tf.keras.layers.Dense(10, activation='softmax')
])

model.compile(optimizer='adam',
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])

# Train on GPU
with tf.device('/GPU:0'):
    history = model.fit(X_train, y_train, epochs=10, batch_size=32)
```

### PyTorch

```python
import torch
import torch.nn as nn

# Check GPU
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Using device: {device}")

# Simple model
class SimpleNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(784, 128)
        self.fc2 = nn.Linear(128, 10)
        
    def forward(self, x):
        x = torch.relu(self.fc1(x))
        return self.fc2(x)

model = SimpleNet().to(device)
```

## Distributed Computing

### Dask Integration

```python
import dask.dataframe as dd
from dask.distributed import Client

# Connect to Dask cluster
client = Client('scheduler-address:8786')

# Process large datasets
df = dd.read_csv('/shared/big-data/*.csv')
result = df.groupby('category').value.mean().compute()
```

### Spark Integration

```python
from pyspark.sql import SparkSession

# Create Spark session
spark = SparkSession.builder \
    .appName("JupyterSparkApp") \
    .config("spark.executor.memory", "4g") \
    .getOrCreate()

# Process data
df = spark.read.csv('/shared/data.csv', header=True, inferSchema=True)
df.groupBy('category').count().show()
```

## Best Practices

### Resource Management

```python
# Monitor memory usage
import psutil
import os

def print_memory_usage():
    process = psutil.Process(os.getpid())
    memory_mb = process.memory_info().rss / 1024 / 1024
    print(f"Memory usage: {memory_mb:.1f} MB")

print_memory_usage()
```

### Code Organization

```python
# Use functions for reusable code
def load_and_preprocess_data(filepath):
    """Load and preprocess dataset"""
    df = pd.read_csv(filepath)
    # Preprocessing steps
    return df

def train_model(X_train, y_train):
    """Train machine learning model"""
    model = RandomForestClassifier()
    model.fit(X_train, y_train)
    return model

# Main analysis
data = load_and_preprocess_data('/shared/data.csv')
model = train_model(X_train, y_train)
```

### Version Control

```python
# Save notebook checkpoints
%notebook -s checkpoint_name

# Export to Python script
!jupyter nbconvert --to script notebook.ipynb

# Track experiments
experiment_log = {
    'timestamp': pd.Timestamp.now(),
    'model': 'RandomForest',
    'accuracy': 0.95,
    'parameters': {'n_estimators': 100}
}
```

## Troubleshooting

### Common Issues

**Kernel Not Starting**
- Check server logs in JupyterHub admin panel
- Restart your server from Control Panel
- Contact administrator if issues persist

**Out of Memory**
- Reduce dataset size or use chunking
- Clear variables with `del variable_name`
- Restart kernel to free memory

**Slow Performance**
- Check CPU/memory usage with `htop`
- Use profiling tools: `%timeit`, `%prun`
- Consider moving computation to SLURM jobs

### Performance Optimization

```python
# Profile code performance
%timeit expensive_function()

# Memory profiling
%load_ext memory_profiler
%memit expensive_function()

# Line profiling
%load_ext line_profiler
%lprun -f expensive_function expensive_function()
```

## Integration Examples

### Complete Data Science Project

```python
# 1. Data Loading and Exploration
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix

# Load data
df = pd.read_csv('/shared/datasets/customer_data.csv')
print(f"Dataset shape: {df.shape}")

# 2. Exploratory Data Analysis
fig, axes = plt.subplots(2, 2, figsize=(15, 10))
df['age'].hist(bins=30, ax=axes[0,0])
df['income'].hist(bins=30, ax=axes[0,1])
sns.countplot(data=df, x='category', ax=axes[1,0])
sns.boxplot(data=df, x='category', y='spending', ax=axes[1,1])
plt.tight_layout()
plt.show()

# 3. Feature Engineering
df['age_group'] = pd.cut(df['age'], bins=[0, 25, 40, 60, 100], 
                        labels=['Young', 'Adult', 'Middle', 'Senior'])
df_encoded = pd.get_dummies(df, columns=['category', 'age_group'])

# 4. Model Training
X = df_encoded.drop(['target', 'customer_id'], axis=1)
y = df_encoded['target']

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# 5. Evaluation
predictions = model.predict(X_test)
print("Classification Report:")
print(classification_report(y_test, predictions))

# 6. Visualization of Results
plt.figure(figsize=(8, 6))
cm = confusion_matrix(y_test, predictions)
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues')
plt.title('Confusion Matrix')
plt.show()

# 7. Save Results
results = {
    'model_type': 'RandomForest',
    'accuracy': model.score(X_test, y_test),
    'feature_importance': dict(zip(X.columns, model.feature_importances_))
}

import json
with open('/shared/results/model_results.json', 'w') as f:
    json.dump(results, f, indent=2)

print("Analysis complete! Results saved to /shared/results/")
```

This comprehensive guide covers all aspects of using JupyterHub in your cluster environment. For additional help, consult the JupyterHub documentation or contact your cluster administrator.
