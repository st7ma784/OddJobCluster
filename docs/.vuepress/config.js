module.exports = {
  title: 'Kubernetes Cluster with SLURM and Jupyter',
  description: 'Production-ready HPC cluster automation',
  base: '/windsurf-project/',
  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }]
  ],
  themeConfig: {
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Quick Start', link: '/QUICK_INSTALL.html' },
      { text: 'Deployment', link: '/DEPLOYMENT.html' },
      { text: 'GitHub', link: 'https://github.com/st7ma784/OddJobCluster' }
    ],
    sidebar: {
      '/': [
        {
          title: 'Getting Started',
          collapsable: false,
          children: [
            ['/', 'Introduction'],
            ['/QUICK_INSTALL', 'Quick Install'],
            ['/DEPLOYMENT', 'Full Deployment'],
            ['/RAPID_DEPLOYMENT', 'Node Scaling']
          ]
        },
        {
          title: 'User Guides',
          collapsable: false,
          children: [
            ['/guides/slurm-jobs', 'SLURM Jobs'],
            ['/guides/jupyter', 'JupyterHub'],
            ['/guides/monitoring', 'Monitoring'],
            ['/guides/user-management', 'User Management']
          ]
        },
        {
          title: 'Administration',
          collapsable: false,
          children: [
            ['/guides/backup-restore', 'Backup & Restore'],
            ['/guides/ssl-setup', 'SSL Configuration'],
            ['/guides/troubleshooting-network', 'Network Troubleshooting']
          ]
        },
        {
          title: 'Reference',
          collapsable: false,
          children: [
            ['/PROJECT_SUMMARY', 'Project Summary'],
            ['/api/slurm', 'SLURM API'],
            ['/api/kubernetes', 'Kubernetes API']
          ]
        }
      ]
    },
    repo: 'st7ma784/OddJobCluster',
    repoLabel: 'GitHub',
    docsDir: 'docs',
    editLinks: true,
    editLinkText: 'Edit this page on GitHub'
  },
  plugins: [
    '@vuepress/plugin-back-to-top',
    '@vuepress/plugin-medium-zoom',
    [
      '@vuepress/plugin-search',
      {
        searchMaxSuggestions: 10
      }
    ]
  ]
}
