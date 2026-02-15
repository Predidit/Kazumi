'use client'

import { useState, useEffect, useCallback } from 'react'
import type { SearchResult } from '@/types/plugin'

/**
 * 插件搜索状态 - 照抄原项目 InfoController.pluginSearchStatus
 */
type PluginStatus = 'pending' | 'success' | 'error'

interface PluginSearchState {
  status: PluginStatus
  results: SearchResult[]
}

interface SourceSelectorProps {
  animeTitle: string
  aliases?: string[]  // 番剧别名列表 - 照抄原项目 bangumiItem.alias
  onSelect: (source: SearchResult) => void
  onClose: () => void
  selectedSource: SearchResult | null
  roadsError: string | null
}

/**
 * SourceSelector - 照抄原项目 source_sheet.dart
 * 
 * 功能:
 * - 按插件分 Tab 显示搜索结果
 * - 每个插件 Tab 显示状态指示灯 (绿色=成功, 橙色=成功但无结果, 灰色=加载中, 红色=失败)
 * - 支持别名搜索和手动搜索
 * - 并发搜索所有插件
 */
export function SourceSelector({
  animeTitle,
  aliases = [],
  onSelect,
  onClose,
  selectedSource,
  roadsError,
}: SourceSelectorProps) {
  const [plugins, setPlugins] = useState<string[]>([])
  const [pluginStates, setPluginStates] = useState<Record<string, PluginSearchState>>({})
  const [activePlugin, setActivePlugin] = useState<string>('')
  const [searchKeyword, setSearchKeyword] = useState(animeTitle)
  const [isSearching, setIsSearching] = useState(false)
  const [showAliasDialog, setShowAliasDialog] = useState(false)

  // 加载插件列表并开始搜索
  useEffect(() => {
    loadPluginsAndSearch()
  }, [animeTitle])

  async function loadPluginsAndSearch() {
    try {
      // 获取插件列表
      const response = await fetch('/plugins/index.json')
      const pluginList = await response.json()
      const pluginNames = pluginList.map((p: any) => p.name)
      setPlugins(pluginNames)
      
      if (pluginNames.length > 0) {
        setActivePlugin(pluginNames[0])
      }

      // 初始化所有插件状态为 pending
      const initialStates: Record<string, PluginSearchState> = {}
      for (const name of pluginNames) {
        initialStates[name] = { status: 'pending', results: [] }
      }
      setPluginStates(initialStates)

      // 并发搜索所有插件 - 照抄原项目 QueryManager.queryAllSource
      searchAllPlugins(animeTitle, pluginNames)
    } catch (err) {
      console.error('Failed to load plugins:', err)
    }
  }

  // 照抄原项目 QueryManager.queryAllSource - 并发搜索所有插件
  async function searchAllPlugins(keyword: string, pluginNames: string[]) {
    setIsSearching(true)
    
    // 重置所有状态为 pending
    const pendingStates: Record<string, PluginSearchState> = {}
    for (const name of pluginNames) {
      pendingStates[name] = { status: 'pending', results: [] }
    }
    setPluginStates(pendingStates)

    // 并发搜索每个插件
    const searchPromises = pluginNames.map(async (pluginName) => {
      try {
        const response = await fetch(
          `/api/plugins/search?keyword=${encodeURIComponent(keyword)}&plugin=${encodeURIComponent(pluginName)}`
        )
        
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`)
        }
        
        const data = await response.json()
        const results: SearchResult[] = data.results || []
        
        // 更新该插件的状态
        setPluginStates(prev => ({
          ...prev,
          [pluginName]: { status: 'success', results }
        }))
      } catch (err) {
        console.error(`Plugin ${pluginName} search failed:`, err)
        // 更新该插件的状态为 error
        setPluginStates(prev => ({
          ...prev,
          [pluginName]: { status: 'error', results: [] }
        }))
      }
    })

    await Promise.all(searchPromises)
    setIsSearching(false)
  }

  // 照抄原项目 QueryManager.querySource - 搜索单个插件
  async function searchSinglePlugin(keyword: string, pluginName: string) {
    // 设置该插件状态为 pending
    setPluginStates(prev => ({
      ...prev,
      [pluginName]: { status: 'pending', results: [] }
    }))

    try {
      const response = await fetch(
        `/api/plugins/search?keyword=${encodeURIComponent(keyword)}&plugin=${encodeURIComponent(pluginName)}`
      )
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }
      
      const data = await response.json()
      const results: SearchResult[] = data.results || []
      
      setPluginStates(prev => ({
        ...prev,
        [pluginName]: { status: 'success', results }
      }))
    } catch (err) {
      console.error(`Plugin ${pluginName} search failed:`, err)
      setPluginStates(prev => ({
        ...prev,
        [pluginName]: { status: 'error', results: [] }
      }))
    }
  }

  // 手动搜索 - 照抄原项目 showCustomSearchDialog
  const handleManualSearch = useCallback(() => {
    const keyword = prompt('输入搜索关键词', searchKeyword)
    if (keyword && keyword.trim()) {
      setSearchKeyword(keyword.trim())
      searchSinglePlugin(keyword.trim(), activePlugin)
    }
  }, [activePlugin, searchKeyword])

  // 别名搜索 - 照抄原项目 showAliasSearchDialog
  const handleAliasSearch = useCallback((alias: string) => {
    setShowAliasDialog(false)
    setSearchKeyword(alias)
    searchSinglePlugin(alias, activePlugin)
  }, [activePlugin])

  // 重试搜索
  const handleRetry = useCallback(() => {
    searchSinglePlugin(searchKeyword, activePlugin)
  }, [activePlugin, searchKeyword])

  // 获取状态指示灯颜色 - 照抄原项目的逻辑
  function getStatusColor(pluginName: string): string {
    const state = pluginStates[pluginName]
    if (!state) return 'bg-gray-400' // pending
    
    if (state.status === 'pending') return 'bg-gray-400'
    if (state.status === 'error') return 'bg-red-500'
    if (state.status === 'success') {
      // 成功但无结果显示橙色
      return state.results.length > 0 ? 'bg-green-500' : 'bg-orange-400'
    }
    return 'bg-gray-400'
  }

  const currentPluginState = pluginStates[activePlugin]
  const currentResults = currentPluginState?.results || []
  const currentStatus = currentPluginState?.status || 'pending'

  return (
    <div className="fixed inset-0 z-40 flex items-end sm:items-center justify-center bg-black/70 backdrop-blur-sm">
      <div className="w-full sm:max-w-lg max-h-[85vh] sm:max-h-[80vh] flex flex-col bg-white/10 backdrop-blur-xl rounded-t-3xl sm:rounded-2xl border border-white/20 overflow-hidden">
        {/* Header - 照抄原项目 */}
        <div className="flex items-center justify-between p-4 border-b border-white/10">
          <h2 className="text-white font-semibold">选择视频源</h2>
          <div className="flex items-center gap-2">
            {/* 在浏览器中打开 - 照抄原项目的 open_in_browser 按钮 */}
            {/* 功能: 打开当前插件的搜索页面，让用户在浏览器中查看 */}
            <button
              onClick={() => {
                // 获取当前插件的搜索 URL
                fetch('/plugins/index.json')
                  .then(res => res.json())
                  .then(plugins => {
                    const plugin = plugins.find((p: any) => p.name === activePlugin)
                    if (plugin && plugin.searchURL) {
                      // 构建搜索 URL
                      const searchUrl = plugin.searchURL.replace('@keyword', encodeURIComponent(searchKeyword))
                      window.open(searchUrl, '_blank')
                    } else if (plugin && plugin.baseURL) {
                      // 如果没有搜索 URL，打开插件首页
                      window.open(plugin.baseURL, '_blank')
                    }
                  })
                  .catch(console.error)
              }}
              className="p-1.5 rounded-full hover:bg-white/10"
              aria-label="在浏览器中打开"
              title="在浏览器中打开搜索页面"
            >
              <span className="material-symbols-rounded text-white text-xl">open_in_browser</span>
            </button>
            <button onClick={onClose} className="p-1.5 rounded-full hover:bg-white/10" aria-label="关闭">
              <span className="material-symbols-rounded text-white text-xl">close</span>
            </button>
          </div>
        </div>

        {/* TabBar - 照抄原项目的插件 Tab 列表 */}
        <div className="border-b border-white/10">
          <div className="flex overflow-x-auto scrollbar-hide">
            {plugins.map((pluginName) => (
              <button
                key={pluginName}
                onClick={() => setActivePlugin(pluginName)}
                className={`flex items-center gap-1.5 px-4 py-3 text-sm font-medium whitespace-nowrap transition-colors flex-shrink-0 ${
                  activePlugin === pluginName
                    ? 'text-white border-b-2 border-white'
                    : 'text-white/60 hover:text-white/80'
                }`}
              >
                <span>{pluginName}</span>
                {/* 状态指示灯 - 照抄原项目 */}
                <span className={`w-2 h-2 rounded-full ${getStatusColor(pluginName)}`} />
              </button>
            ))}
          </div>
        </div>

        {/* Content - 照抄原项目的 TabBarView */}
        <div className="flex-1 overflow-y-auto min-h-[300px]">
          {currentStatus === 'pending' ? (
            // 加载中 - 照抄原项目 CircularProgressIndicator
            <div className="flex items-center justify-center h-full">
              <div className="w-8 h-8 border-2 border-white/20 border-t-white rounded-full animate-spin" />
            </div>
          ) : currentStatus === 'error' ? (
            // 错误状态 - 照抄原项目 GeneralErrorWidget
            <div className="flex flex-col items-center justify-center h-full gap-4 p-6">
              <span className="material-symbols-rounded text-red-400 text-4xl">error</span>
              <p className="text-white/80 text-sm text-center">
                {activePlugin} 检索失败
              </p>
              <p className="text-white/40 text-xs text-center">
                重试或左右滑动以切换到其他视频来源
              </p>
              <button
                onClick={handleRetry}
                className="px-6 py-2 bg-primary-500 hover:bg-primary-600 text-white text-sm rounded-full transition-colors"
              >
                重试
              </button>
            </div>
          ) : currentResults.length === 0 ? (
            // 无结果 - 照抄原项目 GeneralErrorWidget
            <div className="flex flex-col items-center justify-center h-full gap-4 p-6">
              <span className="material-symbols-rounded text-orange-400 text-4xl">search_off</span>
              <p className="text-white/80 text-sm text-center">
                {activePlugin} 无结果
              </p>
              <p className="text-white/40 text-xs text-center">
                使用别名或左右滑动以切换到其他视频来源
              </p>
              <div className="flex gap-3">
                {/* 别名检索按钮 - 照抄原项目 */}
                <button
                  onClick={() => {
                    if (aliases.length === 0) {
                      alert('无可用别名，试试手动检索')
                    } else {
                      setShowAliasDialog(true)
                    }
                  }}
                  className="px-4 py-2 bg-white/10 hover:bg-white/20 text-white text-sm rounded-full transition-colors"
                >
                  别名检索
                </button>
                <button
                  onClick={handleManualSearch}
                  className="px-4 py-2 bg-white/10 hover:bg-white/20 text-white text-sm rounded-full transition-colors"
                >
                  手动检索
                </button>
              </div>
            </div>
          ) : (
            // 结果列表 - 照抄原项目的 Card 列表
            <div className="p-3 space-y-2">
              {currentResults.map((source, index) => (
                <button
                  key={`${source.pluginName}-${source.src}-${index}`}
                  onClick={() => onSelect(source)}
                  className={`w-full p-4 rounded-xl text-left transition-all ${
                    selectedSource?.src === source.src && selectedSource?.pluginName === source.pluginName
                      ? 'bg-primary-500/30 border border-primary-500'
                      : 'bg-white/5 hover:bg-white/10 border border-transparent'
                  }`}
                >
                  <p className="text-white font-medium text-sm">{source.name}</p>
                </button>
              ))}
            </div>
          )}
        </div>

        {/* 错误提示 */}
        {roadsError && (
          <div className="p-3 border-t border-white/10 bg-red-500/20">
            <p className="text-red-300 text-xs text-center">{roadsError}</p>
          </div>
        )}

        {/* Footer - 状态说明 */}
        <div className="p-3 border-t border-white/10">
          <div className="flex items-center justify-center gap-4 text-xs text-white/40">
            <span className="flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-green-500" /> 有结果
            </span>
            <span className="flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-orange-400" /> 无结果
            </span>
            <span className="flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-gray-400" /> 加载中
            </span>
            <span className="flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-red-500" /> 失败
            </span>
          </div>
        </div>
      </div>

      {/* 别名选择对话框 - 照抄原项目 showAliasSearchDialog */}
      {showAliasDialog && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 backdrop-blur-sm">
          <div className="w-full max-w-sm mx-4 bg-white rounded-2xl overflow-hidden shadow-xl">
            <div className="p-4 border-b border-gray-200">
              <h3 className="text-lg font-semibold text-gray-900">选择别名</h3>
            </div>
            <div className="max-h-60 overflow-y-auto">
              {aliases.map((alias, index) => (
                <button
                  key={index}
                  onClick={() => handleAliasSearch(alias)}
                  className="w-full px-4 py-3 text-left text-gray-700 hover:bg-gray-100 transition-colors border-b border-gray-100 last:border-b-0"
                >
                  {alias}
                </button>
              ))}
            </div>
            <div className="p-3 border-t border-gray-200">
              <button
                onClick={() => setShowAliasDialog(false)}
                className="w-full py-2 text-gray-500 hover:text-gray-700 text-sm"
              >
                取消
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
