/**
 * Plugin Management Page - 照抄原项目的 plugin_view_page.dart + plugin_shop_page.dart
 * 
 * 功能:
 * - 查看已安装的插件列表
 * - 从规则仓库导入 (照抄原项目)
 * - 从剪贴板导入
 * - 测试/分享/删除插件
 */

'use client'

import { useState, useEffect, useCallback } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { GlassCard } from '@/components/ui'
import { SafeAreaWrapper } from '@/components/ui/SafeAreaWrapper'
import { BottomSheet } from '@/components/ui/BottomSheet'

// 规则仓库地址 - 照抄原项目 Api.pluginShop
const PLUGIN_SHOP_URL = 'https://raw.githubusercontent.com/Predidit/KazumiRules/main/'
// Github 镜像地址
const GITHUB_MIRROR = 'https://mirror.ghproxy.com/'
// 同步设置 key
const SYNC_SETTINGS_KEY = 'kazumi_sync_settings'

interface Plugin {
  api: string
  type: string
  name: string
  version: string
  muliSources: boolean
  useWebview: boolean
  useNativePlayer: boolean
  usePost?: boolean
  useLegacyParser?: boolean
  adBlocker?: boolean
  userAgent: string
  baseURL: string
  searchURL: string
  searchList: string
  searchName: string
  searchResult: string
  chapterRoads: string
  chapterResult: string
  referer?: string
}

// 规则仓库中的插件信息 - 照抄原项目 PluginHTTPItem
interface PluginHTTPItem {
  name: string
  version: string
  useNativePlayer: boolean
  author: string
  lastUpdate: number
}

export default function PluginsPage() {
  const router = useRouter()
  const [plugins, setPlugins] = useState<Plugin[]>([])
  const [loading, setLoading] = useState(true)
  const [showAddMenu, setShowAddMenu] = useState(false)
  const [showImportDialog, setShowImportDialog] = useState(false)
  const [importText, setImportText] = useState('')
  const [selectedPlugin, setSelectedPlugin] = useState<Plugin | null>(null)
  const [showPluginMenu, setShowPluginMenu] = useState(false)
  const [testResult, setTestResult] = useState<string | null>(null)
  const [testing, setTesting] = useState(false)
  
  // 规则仓库状态 - 照抄原项目 plugin_shop_page.dart
  const [showPluginShop, setShowPluginShop] = useState(false)
  const [shopPlugins, setShopPlugins] = useState<PluginHTTPItem[]>([])
  const [shopLoading, setShopLoading] = useState(false)
  const [shopError, setShopError] = useState<string | null>(null)
  const [sortByName, setSortByName] = useState(false)
  const [installingPlugin, setInstallingPlugin] = useState<string | null>(null)

  // 加载本地插件列表
  const loadPlugins = useCallback(async () => {
    try {
      setLoading(true)
      const response = await fetch('/plugins/index.json')
      const data = await response.json()
      setPlugins(Array.isArray(data) ? data : [])
    } catch (error) {
      console.error('Failed to load plugins:', error)
      setPlugins([])
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadPlugins()
  }, [loadPlugins])

  // 加载规则仓库列表 - 照抄原项目 queryPluginHTTPList
  // 支持 enableGitProxy 设置使用镜像
  const loadShopPlugins = useCallback(async () => {
    try {
      setShopLoading(true)
      setShopError(null)
      
      // 读取同步设置中的 enableGitProxy
      let enableGitProxy = false
      try {
        const syncSettings = localStorage.getItem(SYNC_SETTINGS_KEY)
        if (syncSettings) {
          const parsed = JSON.parse(syncSettings)
          enableGitProxy = parsed.enableGitProxy || false
        }
      } catch (e) {
        console.error('Failed to read sync settings:', e)
      }
      
      // 根据设置选择 URL
      const baseUrl = enableGitProxy 
        ? GITHUB_MIRROR + PLUGIN_SHOP_URL.replace('https://', '')
        : PLUGIN_SHOP_URL
      
      const response = await fetch(`${baseUrl}index.json`)
      if (!response.ok) throw new Error('无法访问规则仓库')
      const data = await response.json()
      setShopPlugins(Array.isArray(data) ? data : [])
    } catch (error) {
      console.error('Failed to load shop plugins:', error)
      setShopError(error instanceof Error ? error.message : '加载失败')
      setShopPlugins([])
    } finally {
      setShopLoading(false)
    }
  }, [])

  // 获取插件状态 - 照抄原项目 pluginStatus
  const getPluginStatus = (shopPlugin: PluginHTTPItem): 'install' | 'installed' | 'update' => {
    const localPlugin = plugins.find(p => p.name === shopPlugin.name)
    if (!localPlugin) return 'install'
    if (localPlugin.version === shopPlugin.version) return 'installed'
    return 'update'
  }

  // 从规则仓库安装/更新插件 - 照抄原项目 tryUpdatePluginByName
  // 支持 enableGitProxy 设置使用镜像
  const installFromShop = async (pluginName: string) => {
    try {
      setInstallingPlugin(pluginName)
      
      // 读取同步设置中的 enableGitProxy
      let enableGitProxy = false
      try {
        const syncSettings = localStorage.getItem(SYNC_SETTINGS_KEY)
        if (syncSettings) {
          const parsed = JSON.parse(syncSettings)
          enableGitProxy = parsed.enableGitProxy || false
        }
      } catch (e) {
        console.error('Failed to read sync settings:', e)
      }
      
      // 根据设置选择 URL
      const baseUrl = enableGitProxy 
        ? GITHUB_MIRROR + PLUGIN_SHOP_URL.replace('https://', '')
        : PLUGIN_SHOP_URL
      
      const response = await fetch(`${baseUrl}${pluginName}.json`)
      if (!response.ok) throw new Error('获取规则失败')
      const plugin: Plugin = await response.json()
      
      // 更新本地插件列表
      const exists = plugins.some(p => p.name === plugin.name)
      if (exists) {
        setPlugins(prev => prev.map(p => p.name === plugin.name ? plugin : p))
      } else {
        setPlugins(prev => [...prev, plugin])
      }
      
      alert(exists ? '更新成功' : '安装成功')
    } catch (error) {
      alert(`操作失败: ${error instanceof Error ? error.message : '未知错误'}`)
    } finally {
      setInstallingPlugin(null)
    }
  }

  // Base64 解码 (照抄原项目的 kazumiBase64ToJson)
  const decodePluginString = (str: string): Plugin | null => {
    try {
      if (str.startsWith('{')) return JSON.parse(str)
      const decoded = atob(str)
      return JSON.parse(decoded)
    } catch {
      return null
    }
  }

  // Base64 编码 (照抄原项目的 jsonToKazumiBase64)
  const encodePluginString = (plugin: Plugin): string => {
    return btoa(JSON.stringify(plugin))
  }

  // 导入插件
  const handleImport = () => {
    const plugin = decodePluginString(importText.trim())
    if (plugin && plugin.name && plugin.baseURL) {
      const exists = plugins.some(p => p.name === plugin.name)
      if (exists) {
        setPlugins(prev => prev.map(p => p.name === plugin.name ? plugin : p))
      } else {
        setPlugins(prev => [...prev, plugin])
      }
      setShowImportDialog(false)
      setImportText('')
      alert('导入成功')
    } else {
      alert('导入失败：无效的插件格式')
    }
  }

  // 删除插件
  const handleDelete = (plugin: Plugin) => {
    if (confirm(`确定要删除规则 "${plugin.name}" 吗？`)) {
      setPlugins(prev => prev.filter(p => p.name !== plugin.name))
      setShowPluginMenu(false)
      setSelectedPlugin(null)
    }
  }

  // 复制插件链接
  const handleShare = async (plugin: Plugin) => {
    const encoded = encodePluginString(plugin)
    try {
      await navigator.clipboard.writeText(encoded)
      alert('已复制到剪贴板')
    } catch {
      const textarea = document.createElement('textarea')
      textarea.value = encoded
      document.body.appendChild(textarea)
      textarea.select()
      document.execCommand('copy')
      document.body.removeChild(textarea)
      alert('已复制到剪贴板')
    }
    setShowPluginMenu(false)
  }

  // 测试插件
  const handleTest = async (plugin: Plugin) => {
    setTesting(true)
    setTestResult(null)
    try {
      const response = await fetch(`/api/plugins/search?keyword=测试&plugin=${encodeURIComponent(plugin.name)}`)
      const data = await response.json()
      if (data.results && data.results.length > 0) {
        setTestResult(`✅ 搜索成功，找到 ${data.results.length} 个结果`)
      } else {
        setTestResult('⚠️ 搜索成功但没有结果')
      }
    } catch (error) {
      setTestResult(`❌ 测试失败: ${error instanceof Error ? error.message : '未知错误'}`)
    } finally {
      setTesting(false)
    }
  }

  // 排序后的规则仓库列表 - 照抄原项目
  const sortedShopPlugins = [...shopPlugins].sort((a, b) => {
    if (sortByName) {
      return a.name.toLowerCase().localeCompare(b.name.toLowerCase())
    }
    return b.lastUpdate - a.lastUpdate
  })

  // 格式化时间
  const formatDate = (timestamp: number): string => {
    if (!timestamp) return ''
    return new Date(timestamp).toLocaleString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  return (
    <SafeAreaWrapper className="min-h-screen bg-gradient-to-br from-orange-50 via-white to-pink-50">
      {/* Header */}
      <div className="sticky top-0 z-40 bg-white/80 backdrop-blur-glass border-b border-glass-border safe-area-top">
        <div className="flex items-center justify-between px-4 py-3">
          <div className="flex items-center gap-3">
            <Link
              href="/settings"
              className="w-10 h-10 flex items-center justify-center rounded-full bg-gray-100 hover:bg-gray-200 transition-colors"
            >
              <span className="material-symbols-rounded text-gray-600">arrow_back</span>
            </Link>
            <h1 className="text-xl font-bold text-gray-800">规则管理</h1>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => loadPlugins()}
              className="w-10 h-10 flex items-center justify-center rounded-full bg-gray-100 hover:bg-gray-200 transition-colors"
              title="刷新"
            >
              <span className="material-symbols-rounded text-gray-600">refresh</span>
            </button>
            <button
              onClick={() => setShowAddMenu(true)}
              className="w-10 h-10 flex items-center justify-center rounded-full bg-[#FF6B6B] hover:bg-[#FF5252] transition-colors"
              title="添加规则"
            >
              <span className="material-symbols-rounded text-white">add</span>
            </button>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="px-4 py-4 pb-24">
        {loading ? (
          <div className="flex items-center justify-center py-20">
            <div className="w-8 h-8 border-3 border-[#FF6B6B]/30 border-t-[#FF6B6B] rounded-full animate-spin" />
          </div>
        ) : plugins.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-gray-500">
            <span className="material-symbols-rounded text-6xl mb-4">extension_off</span>
            <p>啊咧（⊙.⊙） 没有可用规则的说</p>
            <button
              onClick={() => setShowAddMenu(true)}
              className="mt-4 px-4 py-2 bg-[#FF6B6B] text-white rounded-full hover:bg-[#FF5252] transition-colors"
            >
              添加规则
            </button>
          </div>
        ) : (
          <div className="space-y-3">
            {plugins.map((plugin, index) => (
              <GlassCard key={index} className="p-4">
                <div className="flex items-start justify-between">
                  <div className="flex-1 min-w-0">
                    <h3 className="font-bold text-gray-800">{plugin.name}</h3>
                    <div className="flex items-center gap-2 mt-1 flex-wrap">
                      <span className="px-2 py-0.5 text-xs bg-gray-100 text-gray-600 rounded-full">
                        v{plugin.version}
                      </span>
                      <span className={`px-2 py-0.5 text-xs rounded-full ${
                        plugin.useNativePlayer 
                          ? 'bg-green-100 text-green-700' 
                          : 'bg-blue-100 text-blue-700'
                      }`}>
                        {plugin.useNativePlayer ? 'native' : 'webview'}
                      </span>
                      {plugin.usePost && (
                        <span className="px-2 py-0.5 text-xs bg-purple-100 text-purple-700 rounded-full">
                          POST
                        </span>
                      )}
                    </div>
                    <p className="text-sm text-gray-500 mt-1 truncate">{plugin.baseURL}</p>
                  </div>
                  <button
                    onClick={() => {
                      setSelectedPlugin(plugin)
                      setShowPluginMenu(true)
                    }}
                    className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-gray-100 transition-colors"
                  >
                    <span className="material-symbols-rounded text-gray-500">more_vert</span>
                  </button>
                </div>
              </GlassCard>
            ))}
          </div>
        )}
      </div>

      {/* Add Menu - 照抄原项目 */}
      <BottomSheet
        isOpen={showAddMenu}
        onClose={() => setShowAddMenu(false)}
        title="添加规则"
      >
        <div className="p-4 space-y-3">
          {/* 从规则仓库导入 - 照抄原项目 */}
          <button
            onClick={() => {
              setShowAddMenu(false)
              setShowPluginShop(true)
              loadShopPlugins()
            }}
            className="w-full flex items-center gap-4 p-4 rounded-xl bg-gray-50 hover:bg-gray-100 transition-colors"
          >
            <span className="material-symbols-rounded text-[#FF6B6B]">store</span>
            <div className="text-left">
              <p className="font-medium text-gray-800">从规则仓库导入</p>
              <p className="text-sm text-gray-500">浏览并安装官方规则</p>
            </div>
          </button>
          {/* 从剪贴板导入 */}
          <button
            onClick={() => {
              setShowAddMenu(false)
              setShowImportDialog(true)
            }}
            className="w-full flex items-center gap-4 p-4 rounded-xl bg-gray-50 hover:bg-gray-100 transition-colors"
          >
            <span className="material-symbols-rounded text-[#FF6B6B]">content_paste</span>
            <div className="text-left">
              <p className="font-medium text-gray-800">从剪贴板导入</p>
              <p className="text-sm text-gray-500">粘贴规则链接或 JSON</p>
            </div>
          </button>
        </div>
      </BottomSheet>

      {/* 规则仓库页面 - 照抄原项目 plugin_shop_page.dart */}
      {showPluginShop && (
        <div className="fixed inset-0 z-[60] bg-white">
          {/* Header */}
          <div className="sticky top-0 z-40 bg-white/80 backdrop-blur-glass border-b border-glass-border safe-area-top">
            <div className="flex items-center justify-between px-4 py-3">
              <div className="flex items-center gap-3">
                <button
                  onClick={() => setShowPluginShop(false)}
                  className="w-10 h-10 flex items-center justify-center rounded-full bg-gray-100 hover:bg-gray-200 transition-colors"
                >
                  <span className="material-symbols-rounded text-gray-600">arrow_back</span>
                </button>
                <h1 className="text-xl font-bold text-gray-800">规则仓库</h1>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setSortByName(!sortByName)}
                  className="w-10 h-10 flex items-center justify-center rounded-full bg-gray-100 hover:bg-gray-200 transition-colors"
                  title={sortByName ? '按名称排序' : '按更新时间排序'}
                >
                  <span className="material-symbols-rounded text-gray-600">
                    {sortByName ? 'sort_by_alpha' : 'schedule'}
                  </span>
                </button>
                <button
                  onClick={loadShopPlugins}
                  className="w-10 h-10 flex items-center justify-center rounded-full bg-gray-100 hover:bg-gray-200 transition-colors"
                  title="刷新"
                >
                  <span className="material-symbols-rounded text-gray-600">refresh</span>
                </button>
              </div>
            </div>
          </div>

          {/* Shop Content */}
          <div className="px-4 py-4 pb-24 overflow-y-auto" style={{ height: 'calc(100vh - 60px)' }}>
            {shopLoading ? (
              <div className="flex items-center justify-center py-20">
                <div className="w-8 h-8 border-3 border-[#FF6B6B]/30 border-t-[#FF6B6B] rounded-full animate-spin" />
              </div>
            ) : shopError ? (
              <div className="flex flex-col items-center justify-center py-20 text-gray-500">
                <span className="material-symbols-rounded text-6xl mb-4">cloud_off</span>
                <p className="text-center mb-2">啊咧（⊙.⊙） 无法访问远程仓库</p>
                <p className="text-sm text-gray-400 mb-4">{shopError}</p>
                <button
                  onClick={loadShopPlugins}
                  className="px-4 py-2 bg-[#FF6B6B] text-white rounded-full hover:bg-[#FF5252] transition-colors"
                >
                  重试
                </button>
              </div>
            ) : sortedShopPlugins.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-20 text-gray-500">
                <span className="material-symbols-rounded text-6xl mb-4">inventory_2</span>
                <p>规则仓库为空</p>
              </div>
            ) : (
              <div className="space-y-3">
                {sortedShopPlugins.map((shopPlugin, index) => {
                  const status = getPluginStatus(shopPlugin)
                  const isInstalling = installingPlugin === shopPlugin.name
                  
                  return (
                    <GlassCard key={index} className="p-4">
                      <div className="flex items-start justify-between">
                        <div className="flex-1 min-w-0">
                          <h3 className="font-bold text-gray-800">{shopPlugin.name}</h3>
                          <div className="flex items-center gap-2 mt-1 flex-wrap">
                            <span className="px-2 py-0.5 text-xs bg-gray-100 text-gray-600 rounded-full">
                              v{shopPlugin.version}
                            </span>
                            <span className={`px-2 py-0.5 text-xs rounded-full ${
                              shopPlugin.useNativePlayer 
                                ? 'bg-green-100 text-green-700' 
                                : 'bg-blue-100 text-blue-700'
                            }`}>
                              {shopPlugin.useNativePlayer ? 'native' : 'webview'}
                            </span>
                          </div>
                          {shopPlugin.lastUpdate > 0 && (
                            <p className="text-xs text-gray-400 mt-1">
                              更新时间: {formatDate(shopPlugin.lastUpdate)}
                            </p>
                          )}
                          {shopPlugin.author && (
                            <p className="text-xs text-gray-400">
                              作者: {shopPlugin.author}
                            </p>
                          )}
                        </div>
                        <button
                          onClick={() => installFromShop(shopPlugin.name)}
                          disabled={status === 'installed' || isInstalling}
                          className={`px-4 py-1.5 text-sm rounded-full transition-colors whitespace-nowrap ${
                            status === 'installed'
                              ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                              : status === 'update'
                              ? 'bg-orange-500 text-white hover:bg-orange-600'
                              : 'bg-[#FF6B6B] text-white hover:bg-[#FF5252]'
                          } ${isInstalling ? 'opacity-50' : ''}`}
                        >
                          {isInstalling ? '...' : status === 'installed' ? '已安装' : status === 'update' ? '更新' : '安装'}
                        </button>
                      </div>
                    </GlassCard>
                  )
                })}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Import Dialog */}
      {showImportDialog && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4" onClick={() => setShowImportDialog(false)}>
          <div 
            className="w-full max-w-md bg-white rounded-2xl p-6 animate-scale-in"
            onClick={e => e.stopPropagation()}
          >
            <h2 className="text-lg font-bold text-gray-800 mb-4">导入规则</h2>
            <textarea
              value={importText}
              onChange={e => setImportText(e.target.value)}
              placeholder="粘贴规则链接或 JSON..."
              className="w-full h-32 p-3 border border-gray-200 rounded-xl resize-none focus:outline-none focus:ring-2 focus:ring-[#FF6B6B]/50"
            />
            <div className="flex justify-end gap-3 mt-4">
              <button
                onClick={() => {
                  setShowImportDialog(false)
                  setImportText('')
                }}
                className="px-4 py-2 text-gray-500 hover:text-gray-700 transition-colors"
              >
                取消
              </button>
              <button
                onClick={handleImport}
                className="px-4 py-2 bg-[#FF6B6B] text-white rounded-full hover:bg-[#FF5252] transition-colors"
              >
                导入
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Plugin Menu */}
      <BottomSheet
        isOpen={showPluginMenu && !!selectedPlugin}
        onClose={() => {
          setShowPluginMenu(false)
          setTestResult(null)
        }}
        title={selectedPlugin?.name || ''}
      >
        <div className="p-4">
          {testResult && (
            <div className={`p-3 rounded-xl mb-4 ${
              testResult.startsWith('✅') ? 'bg-green-50 text-green-700' :
              testResult.startsWith('⚠️') ? 'bg-yellow-50 text-yellow-700' :
              'bg-red-50 text-red-700'
            }`}>
              {testResult}
            </div>
          )}
          
          <div className="space-y-2">
            {/* 快速测试 */}
            <button
              onClick={() => selectedPlugin && handleTest(selectedPlugin)}
              disabled={testing}
              className="w-full flex items-center gap-4 p-4 rounded-xl bg-gray-50 hover:bg-gray-100 transition-colors disabled:opacity-50"
            >
              <span className="material-symbols-rounded text-blue-500">
                {testing ? 'hourglass_empty' : 'bolt'}
              </span>
              <span className="font-medium text-gray-800">
                {testing ? '测试中...' : '快速测试'}
              </span>
            </button>
            {/* 详细测试 - 跳转到测试页面 */}
            <button
              onClick={() => {
                if (selectedPlugin) {
                  setShowPluginMenu(false)
                  router.push(`/settings/plugins/test/${encodeURIComponent(selectedPlugin.name)}`)
                }
              }}
              className="w-full flex items-center gap-4 p-4 rounded-xl bg-gray-50 hover:bg-gray-100 transition-colors"
            >
              <span className="material-symbols-rounded text-purple-500">bug_report</span>
              <span className="font-medium text-gray-800">详细测试</span>
            </button>
            <button
              onClick={() => selectedPlugin && handleShare(selectedPlugin)}
              className="w-full flex items-center gap-4 p-4 rounded-xl bg-gray-50 hover:bg-gray-100 transition-colors"
            >
              <span className="material-symbols-rounded text-green-500">share</span>
              <span className="font-medium text-gray-800">分享</span>
            </button>
            <button
              onClick={() => selectedPlugin && handleDelete(selectedPlugin)}
              className="w-full flex items-center gap-4 p-4 rounded-xl bg-red-50 hover:bg-red-100 transition-colors"
            >
              <span className="material-symbols-rounded text-red-500">delete</span>
              <span className="font-medium text-red-700">删除</span>
            </button>
          </div>
        </div>
      </BottomSheet>
    </SafeAreaWrapper>
  )
}
