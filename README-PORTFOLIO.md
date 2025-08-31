# 🎨 Automated Portfolio System

Transform your Kubernetes cluster into an automated portfolio hosting platform that scans your GitHub repositories, converts Docker Compose files to Kubernetes deployments, and presents everything through a beautiful web interface.

## 🚀 Features

### Automated Repository Scanning
- **GitHub Integration**: Scans all your repositories every 6 hours via GitHub Actions
- **Docker Compose Detection**: Automatically finds and converts `docker-compose.yml` files
- **Kubernetes Deployment**: Converts Docker services to Kubernetes manifests
- **Port Management**: Automatically resolves port conflicts using NodePort ranges

### Project Validation & Quality Checks
- **README Analysis**: Categorizes README quality (verbose, basic, minimal, missing)
- **GitHub Pages Detection**: Identifies repositories with GitHub Pages enabled
- **Web Interface Detection**: Flags projects with web-accessible services
- **Validation Flags**: Highlights projects needing attention

### Portfolio Web Interface
- **Beautiful Dashboard**: Modern, responsive web interface at cluster root
- **Project Cards**: Each repository displayed with metadata and links
- **Filtering System**: Filter by web apps, Docker projects, or flagged items
- **Live Links**: Direct access to GitHub repos, GitHub Pages, and running applications

## 📁 System Architecture

```
📦 Portfolio System
├── 🔄 GitHub Actions (.github/workflows/portfolio-sync.yml)
├── 🐍 Python Scripts (scripts/portfolio/)
│   ├── portfolio-scanner.py     # Repository scanning & analysis
│   ├── deploy-portfolio.py      # Kubernetes deployment
│   ├── update-status.py         # Status monitoring
│   └── test-portfolio.py        # Testing suite
├── 🌐 Web Interface (Auto-generated HTML)
└── ☸️ Kubernetes Deployments (Auto-generated manifests)
```

## 🛠️ Setup Instructions

### 1. Install Portfolio System
```bash
# Run the setup script
./scripts/setup-portfolio.sh
```

### 2. Configure GitHub Secrets
Add these secrets to your GitHub repository:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `CLUSTER_HOST` | `192.168.5.57` | Your cluster IP address |
| `CLUSTER_SSH_KEY` | `(SSH key content)` | Contents of `~/.ssh/cluster_key` |
| `GITHUB_TOKEN` | `(Personal access token)` | GitHub API access token |

### 3. Enable GitHub Actions
The workflow automatically triggers:
- **Every 6 hours** (scheduled scan)
- **On push** to main branch
- **Manual trigger** via GitHub Actions tab

## 🎯 How It Works

### Repository Analysis
For each repository, the system:
1. **Scans for `docker-compose.yml`** in the root directory
2. **Analyzes README.md** for quality and completeness
3. **Checks for GitHub Pages** deployment
4. **Extracts Docker services** and port configurations
5. **Validates project completeness** against quality criteria

### Kubernetes Conversion
Docker Compose services are converted to:
- **Deployments**: Container orchestration
- **Services**: Network access with NodePort
- **ConfigMaps**: Configuration management
- **Port Resolution**: Automatic conflict avoidance (30000+ range)

### Web Interface Generation
Creates a dynamic portfolio page featuring:
- **Project Statistics**: Total projects, Docker projects, web apps
- **Interactive Filtering**: View by category or validation status
- **Direct Links**: GitHub repos, GitHub Pages, live applications
- **Status Indicators**: Health and deployment status

## 📊 Project Validation

Projects are flagged if they lack:
- ✅ **Verbose README** (installation, usage, examples)
- ✅ **GitHub Pages** (documentation site)
- ✅ **Web Interface** (accessible application)

### Validation Categories
| Flag | Meaning | Action Required |
|------|---------|----------------|
| `missing_presentation` | No README, GitHub Pages, or web interface | Add documentation or web UI |
| `no_web_interface` | Has Docker but no web ports | Expose web ports or add web service |
| `no_readme` | Missing or minimal README | Create comprehensive documentation |

## 🌐 Access Your Portfolio

After deployment:
- **Portfolio Dashboard**: `http://192.168.5.57:30080`
- **Individual Apps**: `http://192.168.5.57:30XXX` (auto-assigned ports)
- **GitHub Actions**: Monitor deployment in your repo's Actions tab

## 🔧 Manual Operations

### Test Portfolio System
```bash
# Test all components
./scripts/portfolio/test-portfolio.py

# Manual deployment
python3 scripts/portfolio/deploy-portfolio.py \
  --cluster-host 192.168.5.57 \
  --ssh-key ~/.ssh/cluster_key \
  --portfolio-dir ./portfolio-output
```

### Monitor Status
```bash
# Check deployment status
python3 scripts/portfolio/update-status.py \
  --cluster-host 192.168.5.57 \
  --ssh-key ~/.ssh/cluster_key
```

### Force Rescan
```bash
# Trigger GitHub Actions workflow manually
# Go to: GitHub → Actions → Portfolio Sync → Run workflow
```

## 📈 Portfolio Benefits

| Before | After |
|--------|-------|
| Manual project showcasing | Automated portfolio generation |
| Static documentation | Live, interactive dashboard |
| No deployment automation | One-click Docker → Kubernetes |
| Port management headaches | Automatic conflict resolution |
| Scattered project links | Centralized project hub |

## 🎨 Customization

### Modify Web Interface
Edit `deploy-portfolio.py` to customize:
- **Styling**: Update CSS in HTML template
- **Layout**: Modify project card structure  
- **Filtering**: Add new filter categories
- **Branding**: Update colors, fonts, logos

### Add New Validation Rules
Extend `portfolio-scanner.py`:
- **Custom quality metrics**
- **Technology detection**
- **License validation**
- **Security scanning**

---

**🎉 Your cluster is now a fully automated portfolio platform!**

Every repository with a Docker Compose file automatically becomes a live, hosted application accessible through your beautiful portfolio dashboard.
