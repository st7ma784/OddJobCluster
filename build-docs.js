#!/usr/bin/env node

const fs = require('fs-extra');
const path = require('path');
const { marked } = require('marked');

const docsDir = path.join(__dirname, 'docs');
const distDir = path.join(docsDir, '.vuepress', 'dist');

// Create simple static site generator
async function buildDocs() {
    console.log('Building documentation...');
    
    // Ensure dist directory exists
    await fs.ensureDir(distDir);
    
    // Create index.html
    const indexHtml = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Kubernetes Cluster with SLURM and Jupyter</title>
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />
    <meta name="description" content="Production-ready HPC cluster automation">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0">
    <link rel="stylesheet" href="//cdn.jsdelivr.net/npm/docsify@4/lib/themes/vue.css">
    <style>
        .sidebar-nav > ul > li > p { font-weight: bold; margin: 0; }
        .sidebar-nav > ul > li > ul { margin-left: 0; }
    </style>
</head>
<body>
    <div id="app">Loading...</div>
    <script>
        window.$docsify = {
            name: 'Kubernetes Cluster with SLURM and Jupyter',
            repo: 'https://github.com/st7ma784/OddJobCluster',
            basePath: '/ansible/',
            homepage: 'README.md',
            loadSidebar: true,
            subMaxLevel: 3,
            auto2top: true,
            search: {
                maxAge: 86400000,
                paths: 'auto',
                placeholder: 'Search...',
                noData: 'No results found.'
            },
            plugins: [
                function(hook, vm) {
                    hook.beforeEach(function(html) {
                        return html;
                    });
                }
            ]
        }
    </script>
    <script src="//cdn.jsdelivr.net/npm/docsify@4"></script>
    <script src="//cdn.jsdelivr.net/npm/docsify/lib/plugins/search.min.js"></script>
    <script src="//cdn.jsdelivr.net/npm/prismjs@1/components/prism-bash.min.js"></script>
    <script src="//cdn.jsdelivr.net/npm/prismjs@1/components/prism-yaml.min.js"></script>
    <script src="//cdn.jsdelivr.net/npm/prismjs@1/components/prism-json.min.js"></script>
    <script src="//cdn.jsdelivr.net/npm/prismjs@1/components/prism-kotlin.min.js"></script>
</body>
</html>`;

    // Create sidebar
    const sidebarMd = `
- **Getting Started**
  - [Introduction](README.md)
  - [Quick Install](QUICK_INSTALL.md)
  - [Full Deployment](DEPLOYMENT.md)
  - [Node Scaling](RAPID_DEPLOYMENT.md)

- **User Guides**
  - [SLURM Jobs](guides/slurm-jobs.md)
  - [JupyterHub](guides/jupyter.md)
  - [Monitoring](guides/monitoring.md)
  - [User Management](guides/user-management.md)

- **Administration**
  - [Backup & Restore](guides/backup-restore.md)
  - [SSL Configuration](guides/ssl-setup.md)
  - [Network Troubleshooting](guides/troubleshooting-network.md)

- **Reference**
  - [Project Summary](PROJECT_SUMMARY.md)
  - [SLURM API](api/slurm.md)
  - [Kubernetes API](api/kubernetes.md)
`;

    // Write files
    await fs.writeFile(path.join(distDir, 'index.html'), indexHtml);
    await fs.writeFile(path.join(docsDir, '_sidebar.md'), sidebarMd);
    
    console.log('✅ Documentation built successfully');
    console.log('📁 Output directory:', distDir);
}

buildDocs().catch(console.error);
