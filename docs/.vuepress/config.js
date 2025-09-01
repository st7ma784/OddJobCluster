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
    sidebar: [
      {
        title: 'Getting Started',
        collapsable: false,
        children: [
          '/',
          '/QUICK_INSTALL',
          '/DEPLOYMENT',
          '/RAPID_DEPLOYMENT'
        ]
      },
      {
        title: 'User Guides',
        collapsable: false,
        children: [
          '/guides/slurm-jobs',
          '/guides/jupyter',
          '/guides/monitoring',
          '/guides/user-management'
        ]
      },
      {
        title: 'Administration',
        collapsable: false,
        children: [
          '/guides/backup-restore',
          '/guides/ssl-setup',
          '/guides/troubleshooting-network'
        ]
      },
      {
        title: 'Reference',
        collapsable: false,
        children: [
          '/PROJECT_SUMMARY',
          '/api/slurm',
          '/api/kubernetes'
        ]
      }
    ],
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
