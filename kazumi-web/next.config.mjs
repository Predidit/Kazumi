import withPWA from 'next-pwa'

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  
  // ESLint - 允许构建时有警告
  eslint: {
    ignoreDuringBuilds: true,
  },
  
  // TypeScript - 允许构建时有类型错误 (Docker 构建时忽略)
  typescript: {
    ignoreBuildErrors: true,
  },
  
  // Image optimization - 使用 remotePatterns 替代 deprecated domains
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'lain.bgm.tv',
        pathname: '/**',
      },
      {
        protocol: 'https',
        hostname: 'api.bgm.tv',
        pathname: '/**',
      },
      {
        protocol: 'http',
        hostname: 'lain.bgm.tv',
        pathname: '/**',
      },
    ],
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [375, 390, 428, 744, 820, 1024, 1280],
    imageSizes: [16, 32, 48, 64, 96, 128, 256],
    // 图片懒加载优化
    minimumCacheTTL: 60 * 60 * 24 * 30, // 30 天
  },
  
  // Experimental features for performance - Next.js 15 最新优化
  experimental: {
    optimizePackageImports: ['@/components/ui', '@/components/anime', '@/components/player'],
    // 启用部分预渲染 (PPR) - Next.js 15 新特性
    // ppr: true, // 需要 Next.js 15+
  },
  
  // Compiler optimizations
  compiler: {
    removeConsole: process.env.NODE_ENV === 'production',
  },
  
  // 输出优化
  output: 'standalone',
  
  // 压缩优化
  compress: true,
  
  // 生成 ETags 用于缓存验证
  generateEtags: true,
  
  // 启用 gzip 压缩
  poweredByHeader: false,
  
  // Headers for caching - Next.js 15 缓存策略
  async headers() {
    return [
      {
        // API 路由 - stale-while-revalidate 策略
        source: '/api/:path*',
        headers: [
          { key: 'Cache-Control', value: 'public, s-maxage=60, stale-while-revalidate=300' },
          { key: 'CDN-Cache-Control', value: 'public, s-maxage=60, stale-while-revalidate=300' },
        ],
      },
      {
        // Static assets - 长期缓存 + immutable
        source: '/:all*(svg|jpg|jpeg|png|gif|ico|webp|avif|woff|woff2)',
        headers: [
          { key: 'Cache-Control', value: 'public, max-age=31536000, immutable' },
        ],
      },
      {
        // API routes for Bangumi - 5分钟缓存
        source: '/api/bangumi/:path*',
        headers: [
          { key: 'Cache-Control', value: 'public, s-maxage=300, stale-while-revalidate=600' },
        ],
      },
      {
        // API routes for DanDanPlay - 1小时缓存 (弹幕数据变化少)
        source: '/api/dandanplay/:path*',
        headers: [
          { key: 'Cache-Control', value: 'public, s-maxage=3600, stale-while-revalidate=7200' },
        ],
      },
      {
        // JS/CSS 静态资源 - 长期缓存
        source: '/_next/static/:path*',
        headers: [
          { key: 'Cache-Control', value: 'public, max-age=31536000, immutable' },
        ],
      },
      {
        // 页面预取优化
        source: '/:path*',
        headers: [
          // 安全头
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-XSS-Protection', value: '1; mode=block' },
          // iOS Safari PWA 优化
          { key: 'X-DNS-Prefetch-Control', value: 'on' },
        ],
      },
    ]
  },
  
  // Redirects for SEO
  async redirects() {
    return []
  },
}

// PWA 配置 - iOS Safari 优化
const pwaConfig = withPWA({
  dest: 'public',
  register: true,
  skipWaiting: true,
  disable: process.env.NODE_ENV === 'development',
  fallbacks: {
    document: '/offline.html',
  },
  // iOS Safari Service Worker 缓存策略
  runtimeCaching: [
    // Bangumi API - NetworkFirst (优先网络，失败时用缓存)
    {
      urlPattern: /^https:\/\/api\.bgm\.tv\/.*/i,
      handler: 'NetworkFirst',
      options: {
        cacheName: 'bangumi-api-cache',
        expiration: {
          maxEntries: 100,
          maxAgeSeconds: 60 * 60, // 1 hour
        },
        networkTimeoutSeconds: 10,
        cacheableResponse: {
          statuses: [0, 200],
        },
      },
    },
    // Bangumi 图片 - CacheFirst (优先缓存)
    {
      urlPattern: /^https:\/\/lain\.bgm\.tv\/.*/i,
      handler: 'CacheFirst',
      options: {
        cacheName: 'bangumi-image-cache',
        expiration: {
          maxEntries: 200,
          maxAgeSeconds: 7 * 24 * 60 * 60, // 7 days
        },
        cacheableResponse: {
          statuses: [0, 200],
        },
      },
    },
    // DanDanPlay API - NetworkFirst
    {
      urlPattern: /^https:\/\/api\.dandanplay\.net\/.*/i,
      handler: 'NetworkFirst',
      options: {
        cacheName: 'dandanplay-api-cache',
        expiration: {
          maxEntries: 50,
          maxAgeSeconds: 60 * 60, // 1 hour
        },
        networkTimeoutSeconds: 10,
        cacheableResponse: {
          statuses: [0, 200],
        },
      },
    },
    // 图片资源 - CacheFirst
    {
      urlPattern: /\.(?:png|jpg|jpeg|svg|gif|webp|avif)$/i,
      handler: 'CacheFirst',
      options: {
        cacheName: 'image-cache',
        expiration: {
          maxEntries: 200,
          maxAgeSeconds: 30 * 24 * 60 * 60, // 30 days
        },
        cacheableResponse: {
          statuses: [0, 200],
        },
      },
    },
    // 静态资源 - CacheFirst
    {
      urlPattern: /\.(?:js|css|woff|woff2|ttf|otf)$/i,
      handler: 'CacheFirst',
      options: {
        cacheName: 'static-resources',
        expiration: {
          maxEntries: 100,
          maxAgeSeconds: 30 * 24 * 60 * 60, // 30 days
        },
        cacheableResponse: {
          statuses: [0, 200],
        },
      },
    },
    // 页面导航 - NetworkFirst (确保内容新鲜)
    {
      urlPattern: /^https?:\/\/[^/]+\/?$/i,
      handler: 'NetworkFirst',
      options: {
        cacheName: 'pages-cache',
        expiration: {
          maxEntries: 50,
          maxAgeSeconds: 24 * 60 * 60, // 1 day
        },
        networkTimeoutSeconds: 5,
      },
    },
  ],
})

export default pwaConfig(nextConfig)
