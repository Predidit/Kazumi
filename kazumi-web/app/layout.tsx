import type { Metadata, Viewport } from 'next'
import { Inter } from 'next/font/google'
import { Navigation } from '@/components/layout/Navigation'
import { InstallPrompt } from '@/components/pwa/InstallPrompt'
import { IconFontLoader } from '@/components/ui/IconFontLoader'
import { ThemeProvider } from '@/components/ui/ThemeProvider'
import './globals.css'

const inter = Inter({ 
  subsets: ['latin'],
  weight: ['300', '400', '500', '600', '700'],
  display: 'swap',
  variable: '--font-inter',
})

export const metadata: Metadata = {
  title: '番剧播放器',
  description: '具有iOS 26液态玻璃美学的渐进式Web应用番剧播放器，支持弹幕、收藏和观看历史',
  manifest: '/manifest.json',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'default',
    title: '番剧',
  },
  formatDetection: {
    telephone: false,
  },
  icons: {
    icon: '/icons/icon.svg',
    apple: '/icons/icon.svg',
  },
  openGraph: {
    title: '番剧播放器',
    description: '具有iOS 26液态玻璃美学的渐进式Web应用番剧播放器',
    type: 'website',
    locale: 'zh_CN',
  },
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
  userScalable: true,
  viewportFit: 'cover',
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#FF6B6B' },
    { media: '(prefers-color-scheme: dark)', color: '#1a1a1a' },
  ],
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="zh-CN" className={inter.variable} suppressHydrationWarning>
      <head>
        {/* iOS Safari PWA 必需的 meta 标签 - 2025 最佳实践 */}
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="default" />
        <meta name="apple-mobile-web-app-title" content="番剧" />
        <meta name="mobile-web-app-capable" content="yes" />
        {/* iOS Safari 手势和触摸优化 */}
        <meta name="format-detection" content="telephone=no" />
        <meta name="format-detection" content="date=no" />
        <meta name="format-detection" content="address=no" />
        <meta name="format-detection" content="email=no" />
        {/* iOS Safari 图标 */}
        <link rel="apple-touch-icon" href="/icons/icon.svg" />
        <link rel="apple-touch-icon" sizes="180x180" href="/icons/icon-192x192.png" />
        <link rel="icon" type="image/svg+xml" href="/icons/icon.svg" />
        {/* iOS Safari 启动画面 - 可选 */}
        <link rel="apple-touch-startup-image" href="/icons/icon-512x512.png" />
        {/* DNS 预解析 - 性能优化 */}
        <link rel="dns-prefetch" href="https://api.bgm.tv" />
        <link rel="dns-prefetch" href="https://lain.bgm.tv" />
        <link rel="dns-prefetch" href="https://api.dandanplay.net" />
        <link rel="preconnect" href="https://api.bgm.tv" crossOrigin="anonymous" />
        <link rel="preconnect" href="https://lain.bgm.tv" crossOrigin="anonymous" />
      </head>
      <body className="antialiased pb-24">
        {/* Skip to main content link for accessibility */}
        <a 
          href="#main-content" 
          className="skip-link"
          tabIndex={0}
        >
          跳转到主要内容
        </a>
        <ThemeProvider>
          <IconFontLoader>
            <main id="main-content" className="min-h-screen">
              {children}
            </main>
            <Navigation />
            <InstallPrompt />
          </IconFontLoader>
        </ThemeProvider>
      </body>
    </html>
  )
}
