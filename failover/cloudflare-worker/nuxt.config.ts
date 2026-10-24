// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2026-10-24',
  devtools: { enabled: false },
  app: {
    head: {
      title: 'Pusat Kendali Failover (Disaster Recovery)',
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no' },
        { name: 'description', content: 'Disaster Recovery Failover Control Center - Homelab Malang ⇄ Tencent Cloud Standby' }
      ],
      link: [
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap' }
      ]
    }
  },
  nitro: {
    preset: 'cloudflare-module'
  },
  css: [
    '~/assets/scss/main.scss'
  ]
})
