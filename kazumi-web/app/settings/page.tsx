/**
 * Settings Page - 照抄原项目的 my_page.dart
 * 
 * 功能:
 * - 播放历史与视频源
 * - 播放器设置
 * - 弹幕设置
 * - 插件管理
 * - 同步设置
 * - 关于
 */

'use client'

import Link from 'next/link'
import { GlassCard } from '@/components/ui'

interface SettingItem {
  icon: string
  title: string
  description: string
  href: string
}

interface SettingSection {
  title: string
  items: SettingItem[]
}

export default function SettingsPage() {

  const sections: SettingSection[] = [
    {
      title: '播放历史与视频源',
      items: [
        {
          icon: 'history',
          title: '历史记录',
          description: '查看播放历史记录',
          href: '/history',
        },
        {
          icon: 'favorite',
          title: '收藏',
          description: '查看收藏的番剧',
          href: '/favorites',
        },
        {
          icon: 'extension',
          title: '规则管理',
          description: '管理番剧资源规则',
          href: '/settings/plugins',
        },
      ],
    },
    {
      title: '播放器设置',
      items: [
        {
          icon: 'play_circle',
          title: '播放设置',
          description: '自动跳转、连播、倍速等',
          href: '/settings/player',
        },
        {
          icon: 'chat_bubble',
          title: '弹幕设置',
          description: '弹幕显示、速度、字体等',
          href: '/settings/danmaku',
        },
      ],
    },
    {
      title: '应用与外观',
      items: [
        {
          icon: 'palette',
          title: '外观设置',
          description: '主题模式和主题色',
          href: '/settings/theme',
        },
        {
          icon: 'sync',
          title: '同步设置',
          description: 'WebDAV同步和Github镜像',
          href: '/settings/sync',
        },
      ],
    },
    {
      title: '其他',
      items: [
        {
          icon: 'info',
          title: '关于',
          description: '版本信息和开源协议',
          href: '/settings/about',
        },
      ],
    },
  ]

  return (
    <div className="min-h-screen safe-area-all">
      <main className="container mx-auto px-4 py-8">
        {/* Header - 照抄 favorites 页面风格，无返回按钮 */}
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-2xl font-bold text-primary-900">设置</h1>
        </div>

        {/* Content */}
        <div className="max-w-2xl mx-auto pb-24">
          {sections.map((section, sectionIndex) => (
            <div key={sectionIndex} className="mb-6">
              <h2 className="text-sm font-medium text-primary-500 mb-2 px-1">
                {section.title}
              </h2>
              <GlassCard className="overflow-hidden">
                {section.items.map((item, itemIndex) => (
                  <Link key={itemIndex} href={item.href}>
                    <div
                      className={`flex items-center gap-4 p-4 ${
                        itemIndex < section.items.length - 1 ? 'border-b border-primary-100' : ''
                      } hover:bg-primary-50 active:bg-primary-100 transition-colors`}
                    >
                      <div className="w-10 h-10 flex items-center justify-center rounded-xl bg-gradient-to-br from-primary-500/10 to-primary-300/10">
                        <span className="material-symbols-rounded text-primary-500">
                          {item.icon}
                        </span>
                      </div>
                      <div className="flex-1 min-w-0">
                        <h3 className="font-medium text-primary-900">{item.title}</h3>
                        <p className="text-sm text-primary-500 truncate">{item.description}</p>
                      </div>
                      <span className="material-symbols-rounded text-primary-400">
                        chevron_right
                      </span>
                    </div>
                  </Link>
                ))}
              </GlassCard>
            </div>
          ))}

          {/* Version Info */}
          <div className="text-center text-sm text-primary-400 mt-8">
            <p>Kazumi Web v1.0.0</p>
            <p className="mt-1">基于 Kazumi 原项目</p>
          </div>
        </div>
      </main>
    </div>
  )
}
