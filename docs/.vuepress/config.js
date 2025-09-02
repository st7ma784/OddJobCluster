module.exports = {
  title: 'Kubernetes Cluster with SLURM and Jupyter',
  description: 'Production-ready HPC cluster automation',
  base: '/ansible/',
  themeConfig: {
    nav: [
      { text: 'Home', link: '/' },
      { text: 'GitHub', link: 'https://github.com/st7ma784/OddJobCluster' }
    ],
    sidebar: {
      '/guides/': [
        {
          title: 'Guides',
          collapsable: false,
          children: [
            'android-deployment',
            'android-integration-methods',
            'arm-platform-setup',
            'backup-restore',
            'jupyter',
            'monitoring',
            'new-node-setup',
            'rpi-head-node-setup',
            'slurm-jobs',
            'ssl-setup',
            'troubleshooting-network',
            'user-management'
          ]
        }
      ],
      '/api/': [
        {
          title: 'API Reference',
          collapsable: false,
          children: [
            'android-cluster',
            'kubernetes',
            'slurm'
          ]
        }
      ]
    }
  }
}
