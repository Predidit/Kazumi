/**
 * About Page - 照抄原项目的 about_page.dart
 */

'use client'

import Link from 'next/link'
import Image from 'next/image'
import { GlassCard } from '@/components/ui'

export default function AboutPage() {
  return (
    <div className="min-h-screen safe-area-all">
      <main className="container mx-auto px-4 py-8">
        {/* Header - 照抄其他子页面风格 */}
        <div className="flex items-center gap-3 mb-6">
          <Link
            href="/settings"
            className="w-10 h-10 flex items-center justify-center rounded-full bg-primary-100 hover:bg-primary-200 transition-colors"
          >
            <span className="material-symbols-rounded text-primary-600">arrow_back</span>
          </Link>
          <h1 className="text-2xl font-bold text-primary-900">关于</h1>
        </div>

        {/* Content */}
        <div className="max-w-2xl mx-auto pb-24">
          {/* Logo and Version - 使用本地 SVG 图标 */}
          <div className="flex flex-col items-center mb-8">
            <div className="w-24 h-24 rounded-3xl overflow-hidden shadow-lg mb-4">
              <Image
                src="/icons/icon.svg"
                alt="Kazumi Logo"
                width={96}
                height={96}
                className="w-full h-full"
              />
            </div>
            <h2 className="text-2xl font-bold text-primary-900">Kazumi Web</h2>
            <p className="text-primary-500 mt-1">v1.0.0</p>
          </div>

          {/* Description */}
          <GlassCard className="p-4 mb-6">
            <p className="text-primary-600 leading-relaxed">
              Kazumi Web 是基于 Kazumi 原项目的 Web 版本实现，采用 iOS Liquid Glass 设计风格，
              提供流畅的番剧观看体验。
            </p>
          </GlassCard>

          {/* Links */}
          <GlassCard className="overflow-hidden mb-6">
            <a
              href="https://github.com/Predidit/Kazumi"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-4 p-4 border-b border-primary-100 hover:bg-primary-50 transition-colors"
            >
              <span className="material-symbols-rounded text-primary-600">code</span>
              <div className="flex-1">
                <p className="font-medium text-primary-900">原项目 GitHub</p>
                <p className="text-sm text-primary-500">Predidit/Kazumi</p>
              </div>
              <span className="material-symbols-rounded text-primary-400">open_in_new</span>
            </a>
            <a
              href="https://github.com/Predidit/Kazumi/issues"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-4 p-4 hover:bg-primary-50 transition-colors"
            >
              <span className="material-symbols-rounded text-primary-600">bug_report</span>
              <div className="flex-1">
                <p className="font-medium text-primary-900">反馈问题</p>
                <p className="text-sm text-primary-500">在 GitHub 上提交 Issue</p>
              </div>
              <span className="material-symbols-rounded text-primary-400">open_in_new</span>
            </a>
          </GlassCard>

          {/* Tech Stack */}
          <h3 className="text-sm font-medium text-primary-500 mb-2 px-1">技术栈</h3>
          <GlassCard className="p-4 mb-6">
            <div className="flex flex-wrap gap-2">
              {['Next.js 14', 'React 18', 'TypeScript', 'Tailwind CSS', 'HLS.js', 'Zustand'].map(tech => (
                <span key={tech} className="px-3 py-1 bg-primary-100 text-primary-600 rounded-full text-sm">
                  {tech}
                </span>
              ))}
            </div>
          </GlassCard>

          {/* Credits */}
          <h3 className="text-sm font-medium text-primary-500 mb-2 px-1">致谢</h3>
          <GlassCard className="p-4 mb-6">
            <ul className="space-y-2 text-primary-600">
              <li className="flex items-center gap-2">
                <span className="material-symbols-rounded text-primary-500 text-sm">favorite</span>
                <span>Kazumi 原项目作者 Predidit</span>
              </li>
              <li className="flex items-center gap-2">
                <span className="material-symbols-rounded text-primary-500 text-sm">favorite</span>
                <span>Bangumi 番组计划 API</span>
              </li>
              <li className="flex items-center gap-2">
                <span className="material-symbols-rounded text-primary-500 text-sm">favorite</span>
                <span>弹弹play 弹幕 API</span>
              </li>
            </ul>
          </GlassCard>

          {/* License */}
          <h3 className="text-sm font-medium text-primary-500 mb-2 px-1">开源协议</h3>
          <GlassCard className="p-4">
            <p className="text-primary-600 text-sm">
              本项目基于 GPL-3.0 协议开源。
            </p>
          </GlassCard>

          {/* Footer */}
          <div className="text-center text-sm text-primary-400 mt-8">
            <p>Made with ❤️</p>
          </div>
        </div>
      </main>
    </div>
  )
}
