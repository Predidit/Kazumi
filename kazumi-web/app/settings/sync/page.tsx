/**
 * Sync Settings Page - 照抄原项目的 webdav_setting.dart
 */

'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { SettingItem, SettingSection } from '@/components/ui'

const SYNC_SETTINGS_KEY = 'kazumi_sync_settings'

interface SyncSettings {
  enableGitProxy: boolean
  webDavEnable: boolean
  webDavEnableHistory: boolean
  webDavURL: string
  webDavUsername: string
  webDavPassword: string
}

const DEFAULT_SETTINGS: SyncSettings = {
  enableGitProxy: false,
  webDavEnable: false,
  webDavEnableHistory: false,
  webDavURL: '',
  webDavUsername: '',
  webDavPassword: '',
}

export default function SyncSettingsPage() {
  const [settings, setSettings] = useState<SyncSettings>(DEFAULT_SETTINGS)
  const [loaded, setLoaded] = useState(false)
  const [showWebDavConfig, setShowWebDavConfig] = useState(false)
  const [syncing, setSyncing] = useState(false)

  useEffect(() => {
    try {
      const saved = localStorage.getItem(SYNC_SETTINGS_KEY)
      if (saved) {
        setSettings({ ...DEFAULT_SETTINGS, ...JSON.parse(saved) })
      }
    } catch (e) {
      console.error('Failed to load sync settings:', e)
    }
    setLoaded(true)
  }, [])

  const updateSetting = <K extends keyof SyncSettings>(key: K, value: SyncSettings[K]) => {
    setSettings(prev => {
      const newSettings = { ...prev, [key]: value }
      try {
        localStorage.setItem(SYNC_SETTINGS_KEY, JSON.stringify(newSettings))
      } catch (e) {
        console.error('Failed to save sync settings:', e)
      }
      return newSettings
    })
  }

  const handleUpload = async () => {
    if (!settings.webDavEnable || !settings.webDavURL) {
      alert('请先配置并开启WebDAV同步')
      return
    }
    setSyncing(true)
    try {
      const syncData = {
        favorites: JSON.parse(localStorage.getItem('ios-liquid-glass-player-storage') || '{}').animeIds || [],
        history: JSON.parse(localStorage.getItem('ios-liquid-glass-player-storage') || '{}').items || [],
        timestamp: new Date().toISOString(),
      }
      
      const response = await fetch(settings.webDavURL + '/kazumi_sync.json', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ' + btoa(settings.webDavUsername + ':' + settings.webDavPassword),
        },
        body: JSON.stringify(syncData),
      })
      
      if (response.ok || response.status === 201 || response.status === 204) {
        alert('上传成功')
      } else {
        throw new Error(`HTTP ${response.status}`)
      }
    } catch (e) {
      alert(`上传失败: ${e instanceof Error ? e.message : '未知错误'}`)
    } finally {
      setSyncing(false)
    }
  }

  const handleDownload = async () => {
    if (!settings.webDavEnable || !settings.webDavURL) {
      alert('请先配置并开启WebDAV同步')
      return
    }
    setSyncing(true)
    try {
      const response = await fetch(settings.webDavURL + '/kazumi_sync.json', {
        method: 'GET',
        headers: {
          'Authorization': 'Basic ' + btoa(settings.webDavUsername + ':' + settings.webDavPassword),
        },
      })
      
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      
      const syncData = await response.json()
      const currentStorage = JSON.parse(localStorage.getItem('ios-liquid-glass-player-storage') || '{}')
      
      const mergedFavorites = Array.from(new Set([...(currentStorage.animeIds || []), ...(syncData.favorites || [])]))
      
      const historyMap = new Map()
      ;[...(currentStorage.items || []), ...(syncData.history || [])].forEach(item => {
        const key = `${item.animeId}-${item.episodeNumber}`
        const existing = historyMap.get(key)
        if (!existing || new Date(item.watchedAt) > new Date(existing.watchedAt)) {
          historyMap.set(key, item)
        }
      })
      
      currentStorage.animeIds = mergedFavorites
      currentStorage.items = Array.from(historyMap.values())
      localStorage.setItem('ios-liquid-glass-player-storage', JSON.stringify(currentStorage))
      
      alert('下载成功，请刷新页面查看更新')
    } catch (e) {
      alert(`下载失败: ${e instanceof Error ? e.message : '未知错误'}`)
    } finally {
      setSyncing(false)
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
          <h1 className="text-2xl font-bold text-primary-900">同步设置</h1>
        </div>

        {/* Content */}
        <div className="max-w-2xl mx-auto pb-24">
          {/* Github镜像 */}
          <SettingSection title="Github">
            <SettingItem
              type="switch"
              title="Github镜像"
              description="使用镜像访问规则托管仓库"
              checked={settings.enableGitProxy}
              onChange={(v) => updateSetting('enableGitProxy', v)}
            />
          </SettingSection>

          {/* WebDAV设置 */}
          <SettingSection title="WEBDAV">
            <SettingItem
              type="switch"
              title="WEBDAV同步"
              checked={settings.webDavEnable}
              onChange={(v) => {
                if (v && !settings.webDavURL) {
                  alert('请先配置WebDAV')
                  setShowWebDavConfig(true)
                  return
                }
                updateSetting('webDavEnable', v)
                if (!v) updateSetting('webDavEnableHistory', false)
              }}
            />
            <SettingItem
              type="switch"
              title="观看记录同步"
              description="允许自动同步观看记录"
              checked={settings.webDavEnableHistory}
              onChange={(v) => {
                if (!settings.webDavEnable) {
                  alert('请先开启WEBDAV同步')
                  return
                }
                updateSetting('webDavEnableHistory', v)
              }}
            />
            <SettingItem
              type="button"
              title="WEBDAV配置"
              description="配置WebDAV服务器地址和认证信息"
              onClick={() => setShowWebDavConfig(true)}
            />
          </SettingSection>

          {/* 手动同步 */}
          <SettingSection title="手动同步">
            <SettingItem
              type="button"
              title="手动上传"
              buttonIcon="cloud_upload"
              onClick={handleUpload}
              loading={syncing}
            />
            <SettingItem
              type="button"
              title="手动下载"
              buttonIcon="cloud_download"
              onClick={handleDownload}
              loading={syncing}
            />
          </SettingSection>

          <p className="text-sm text-primary-400 text-center mt-4">
            立即上传/下载观看记录到WEBDAV
          </p>
        </div>
      </main>

      {/* WebDAV配置弹窗 */}
      {showWebDavConfig && (
        <div 
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
          onClick={() => setShowWebDavConfig(false)}
        >
          <div 
            className="w-full max-w-md p-6 bg-white/90 backdrop-blur-glass rounded-2xl border border-glass-border animate-scale-in"
            onClick={e => e.stopPropagation()}
          >
            <h2 className="text-lg font-bold text-primary-900 mb-4">WebDAV配置</h2>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-primary-700 mb-1">服务器地址</label>
                <input
                  type="url"
                  value={settings.webDavURL}
                  onChange={(e) => updateSetting('webDavURL', e.target.value)}
                  placeholder="https://dav.example.com/kazumi"
                  className="w-full px-4 py-2 border border-primary-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-500/50"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-primary-700 mb-1">用户名</label>
                <input
                  type="text"
                  value={settings.webDavUsername}
                  onChange={(e) => updateSetting('webDavUsername', e.target.value)}
                  placeholder="username"
                  className="w-full px-4 py-2 border border-primary-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-500/50"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-primary-700 mb-1">密码</label>
                <input
                  type="password"
                  value={settings.webDavPassword}
                  onChange={(e) => updateSetting('webDavPassword', e.target.value)}
                  placeholder="password"
                  className="w-full px-4 py-2 border border-primary-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-500/50"
                />
              </div>
            </div>

            <div className="flex justify-end gap-3 mt-6">
              <button
                onClick={() => setShowWebDavConfig(false)}
                className="px-4 py-2 text-primary-500 hover:text-primary-700 transition-colors"
              >
                取消
              </button>
              <button
                onClick={() => {
                  if (settings.webDavURL) {
                    setShowWebDavConfig(false)
                    alert('配置已保存')
                  } else {
                    alert('请输入服务器地址')
                  }
                }}
                className="px-4 py-2 bg-primary-500 text-white rounded-full hover:bg-primary-600 transition-colors"
              >
                保存
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
