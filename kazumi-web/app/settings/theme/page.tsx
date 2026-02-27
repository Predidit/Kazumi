/**
 * Theme Settings Page - 照抄原项目的 theme_settings_page.dart
 * 
 * 功能:
 * - 主题模式 (浅色/深色/跟随系统)
 * - 主题色选择
 */

'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { GlassCard } from '@/components/ui'

const THEME_KEY = 'kazumi_theme_settings'

type ThemeMode = 'light' | 'dark' | 'system'

interface ThemeSettings {
  mode: ThemeMode
  primaryColor: string
}

const DEFAULT_SETTINGS: ThemeSettings = {
  mode: 'system',
  primaryColor: '#FF6B6B',
}

const THEME_COLORS = [
  { name: '珊瑚红', value: '#FF6B6B' },
  { name: '天空蓝', value: '#4ECDC4' },
  { name: '紫罗兰', value: '#9B59B6' },
  { name: '翡翠绿', value: '#2ECC71' },
  { name: '阳光橙', value: '#F39C12' },
  { name: '樱花粉', value: '#FF69B4' },
  { name: '深海蓝', value: '#3498DB' },
  { name: '石墨灰', value: '#34495E' },
]

export default function ThemeSettingsPage() {
  const [settings, setSettings] = useState<ThemeSettings>(DEFAULT_SETTINGS)
  const [loaded, setLoaded] = useState(false)

  // 加载设置
  useEffect(() => {
    try {
      const saved = localStorage.getItem(THEME_KEY)
      if (saved) {
        setSettings({ ...DEFAULT_SETTINGS, ...JSON.parse(saved) })
      }
    } catch (e) {
      console.error('Failed to load theme settings:', e)
    }
    setLoaded(true)
  }, [])

  // 保存设置
  const updateSetting = <K extends keyof ThemeSettings>(key: K, value: ThemeSettings[K]) => {
    const newSettings = { ...settings, [key]: value }
    setSettings(newSettings)
    try {
      localStorage.setItem(THEME_KEY, JSON.stringify(newSettings))
      // 应用主题
      if (key === 'mode') {
        applyThemeMode(value as ThemeMode)
      }
    } catch (e) {
      console.error('Failed to save theme settings:', e)
    }
  }

  // 应用主题模式
  const applyThemeMode = (mode: ThemeMode) => {
    const root = document.documentElement
    if (mode === 'dark') {
      root.classList.add('dark')
    } else if (mode === 'light') {
      root.classList.remove('dark')
    } else {
      // 跟随系统
      if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
        root.classList.add('dark')
      } else {
        root.classList.remove('dark')
      }
    }
  }

  if (!loaded) {
    return (
      <div className="min-h-screen safe-area-all flex items-center justify-center">
        <div className="w-8 h-8 border-3 border-primary-500/30 border-t-primary-500 rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="min-h-screen safe-area-all">
      <main className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="flex items-center gap-3 mb-6">
          <Link
            href="/settings"
            className="w-10 h-10 flex items-center justify-center rounded-full bg-primary-100 hover:bg-primary-200 transition-colors"
          >
            <span className="material-symbols-rounded text-primary-600">arrow_back</span>
          </Link>
          <h1 className="text-2xl font-bold text-primary-900">外观设置</h1>
        </div>

        {/* Content */}
        <div className="max-w-2xl mx-auto pb-24">
          {/* 主题模式 */}
          <h2 className="text-sm font-medium text-primary-500 mb-2 px-1">主题模式</h2>
          <GlassCard className="overflow-hidden mb-6">
            {[
              { mode: 'light' as ThemeMode, icon: 'light_mode', label: '浅色模式', desc: '始终使用浅色主题' },
              { mode: 'dark' as ThemeMode, icon: 'dark_mode', label: '深色模式', desc: '始终使用深色主题' },
              { mode: 'system' as ThemeMode, icon: 'contrast', label: '跟随系统', desc: '自动跟随系统设置' },
            ].map((item, index) => (
              <button
                key={item.mode}
                onClick={() => updateSetting('mode', item.mode)}
                className={`w-full flex items-center gap-4 p-4 text-left transition-colors ${
                  index < 2 ? 'border-b border-primary-100' : ''
                } ${settings.mode === item.mode ? 'bg-primary-500/5' : 'hover:bg-primary-50'}`}
              >
                <div className={`w-10 h-10 flex items-center justify-center rounded-xl ${
                  settings.mode === item.mode 
                    ? 'bg-primary-500 text-white' 
                    : 'bg-primary-100 text-primary-600'
                }`}>
                  <span className="material-symbols-rounded">{item.icon}</span>
                </div>
                <div className="flex-1">
                  <p className="font-medium text-primary-900">{item.label}</p>
                  <p className="text-sm text-primary-500">{item.desc}</p>
                </div>
                {settings.mode === item.mode && (
                  <span className="material-symbols-rounded text-primary-500">check_circle</span>
                )}
              </button>
            ))}
          </GlassCard>

          {/* 主题色 */}
          <h2 className="text-sm font-medium text-primary-500 mb-2 px-1">主题色</h2>
          <GlassCard className="p-4 mb-6">
            <div className="grid grid-cols-4 gap-3">
              {THEME_COLORS.map((color) => (
                <button
                  key={color.value}
                  onClick={() => updateSetting('primaryColor', color.value)}
                  className={`flex flex-col items-center gap-2 p-3 rounded-xl transition-all ${
                    settings.primaryColor === color.value 
                      ? 'bg-primary-100 ring-2 ring-offset-2' 
                      : 'hover:bg-primary-50'
                  }`}
                  style={{ 
                    ['--tw-ring-color' as string]: settings.primaryColor === color.value ? color.value : undefined 
                  }}
                >
                  <div 
                    className="w-10 h-10 rounded-full shadow-md"
                    style={{ backgroundColor: color.value }}
                  />
                  <span className="text-xs text-primary-600">{color.name}</span>
                </button>
              ))}
            </div>
          </GlassCard>

          {/* 预览 */}
          <h2 className="text-sm font-medium text-primary-500 mb-2 px-1">预览</h2>
          <GlassCard className="p-4">
            <div className="flex items-center gap-4 mb-4">
              <div 
                className="w-12 h-12 rounded-2xl flex items-center justify-center text-white"
                style={{ backgroundColor: settings.primaryColor }}
              >
                <span className="material-symbols-rounded">play_circle</span>
              </div>
              <div>
                <p className="font-bold text-primary-900">Kazumi Web</p>
                <p className="text-sm text-primary-500">主题预览</p>
              </div>
            </div>
            <div className="flex gap-2">
              <button 
                className="flex-1 py-2 rounded-full text-white text-sm font-medium"
                style={{ backgroundColor: settings.primaryColor }}
              >
                主要按钮
              </button>
              <button 
                className="flex-1 py-2 rounded-full text-sm font-medium border-2"
                style={{ borderColor: settings.primaryColor, color: settings.primaryColor }}
              >
                次要按钮
              </button>
            </div>
          </GlassCard>

          {/* 提示 */}
          <p className="text-center text-sm text-primary-400 mt-6">
            部分设置可能需要刷新页面后生效
          </p>
        </div>
      </main>
    </div>
  )
}
