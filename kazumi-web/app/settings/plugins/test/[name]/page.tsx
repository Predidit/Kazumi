/**
 * Plugin Test Page - 照抄原项目的 plugin_test_page.dart
 * 
 * 功能:
 * - 搜索请求测试 (显示原始 HTML)
 * - 搜索解析测试 (显示解析结果)
 * - 章节列表测试 (显示播放列表)
 */

'use client'

import { useState, useEffect } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { GlassCard } from '@/components/ui'

interface Plugin {
  name: string
  version: string
  baseURL: string
  searchURL: string
  searchList: string
  searchName: string
  searchResult: string
  chapterRoads: string
  chapterResult: string
  useNativePlayer: boolean
  usePost?: boolean
}

interface SearchResult {
  name: string
  src: string
}

interface Road {
  name: string
  data: string[]
  identifier: string[]
}

type TestStatus = 'idle' | 'testing' | 'success' | 'error'

export default function PluginTestPage() {
  const params = useParams()
  const router = useRouter()
  const pluginName = decodeURIComponent(params.name as string)

  const [plugin, setPlugin] = useState<Plugin | null>(null)
  const [keyword, setKeyword] = useState('')
  const [testing, setTesting] = useState(false)
  
  // 测试结果状态
  const [searchHtml, setSearchHtml] = useState('')
  const [searchResults, setSearchResults] = useState<SearchResult[]>([])
  const [chapters, setChapters] = useState<Road[]>([])
  const [errorMsg, setErrorMsg] = useState('')
  
  // 展开状态
  const [expandSearch, setExpandSearch] = useState(false)
  const [expandParse, setExpandParse] = useState(false)
  const [expandChapter, setExpandChapter] = useState(true)

  // 加载插件信息
  useEffect(() => {
    loadPlugin()
  }, [pluginName])

  async function loadPlugin() {
    try {
      const response = await fetch('/plugins/index.json')
      const plugins = await response.json()
      const found = plugins.find((p: Plugin) => p.name === pluginName)
      if (found) {
        setPlugin(found)
      }
    } catch (err) {
      console.error('Failed to load plugin:', err)
    }
  }

  // 重置状态
  function resetState() {
    setSearchHtml('')
    setSearchResults([])
    setChapters([])
    setErrorMsg('')
  }

  // 开始测试 - 照抄原项目的 startTest
  async function startTest() {
    if (!keyword.trim() || !plugin) return
    
    resetState()
    setTesting(true)
    
    try {
      // 1. 搜索请求测试
      const searchResponse = await fetch(
        `/api/plugins/test/search?keyword=${encodeURIComponent(keyword)}&plugin=${encodeURIComponent(plugin.name)}`
      )
      const searchData = await searchResponse.json()
      
      if (searchData.html) {
        setSearchHtml(searchData.html)
      }
      
      if (searchData.results && searchData.results.length > 0) {
        setSearchResults(searchData.results)
        
        // 2. 如果有章节规则，测试章节解析
        if (plugin.chapterRoads && searchData.results[0]?.src) {
          const roadsResponse = await fetch(
            `/api/plugins/test/roads?url=${encodeURIComponent(searchData.results[0].src)}&plugin=${encodeURIComponent(plugin.name)}`
          )
          const roadsData = await roadsResponse.json()
          
          if (roadsData.roads && roadsData.roads.length > 0) {
            setChapters(roadsData.roads)
          }
        }
      }
    } catch (err) {
      console.error('Test failed:', err)
      setErrorMsg(err instanceof Error ? err.message : '测试失败')
    } finally {
      setTesting(false)
    }
  }

  // 获取状态颜色
  const getStatusColor = (hasData: boolean, isError: boolean = false): string => {
    if (isError) return 'text-red-500'
    if (hasData) return 'text-green-500'
    return 'text-gray-400'
  }

  // 获取状态文本
  const getSearchStatus = (): string => {
    if (testing) return '测试中...'
    if (!searchHtml) return '未执行测试'
    return `HTML长度：${searchHtml.length} 字符`
  }

  const getParseStatus = (): string => {
    if (testing) return '解析中...'
    if (!searchHtml) return '未执行解析'
    if (searchResults.length === 0) return '未解析到结果'
    return `解析到 ${searchResults.length} 条结果`
  }

  const getChapterStatus = (): string => {
    if (testing) return '获取中...'
    if (!plugin?.chapterRoads) return '无需解析章节'
    if (searchResults.length === 0) return '无有效搜索结果'
    if (chapters.length === 0) return '未获取章节数据'
    return `获取到 ${chapters.length} 个播放列表`
  }

  return (
    <div className="min-h-screen bg-white safe-area-all">
      {/* Header */}
      <div className="sticky top-0 z-40 bg-white/80 backdrop-blur-sm border-b border-primary-100 safe-area-top">
        <div className="flex items-center justify-between px-4 py-3">
          <div className="flex items-center gap-3">
            <button
              onClick={() => router.back()}
              className="w-10 h-10 flex items-center justify-center rounded-full bg-primary-100 hover:bg-primary-200 transition-colors"
            >
              <span className="material-symbols-rounded text-primary-600">arrow_back</span>
            </button>
            <h1 className="text-xl font-bold text-primary-900 truncate">
              {pluginName} 测试
            </h1>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={startTest}
              disabled={testing || !keyword.trim()}
              className="w-10 h-10 flex items-center justify-center rounded-full bg-primary-500 hover:bg-primary-600 disabled:bg-primary-300 transition-colors"
              title="开始测试"
            >
              <span className="material-symbols-rounded text-white">bug_report</span>
            </button>
            <button
              onClick={resetState}
              className="w-10 h-10 flex items-center justify-center rounded-full bg-primary-100 hover:bg-primary-200 transition-colors"
              title="重置"
            >
              <span className="material-symbols-rounded text-primary-600">refresh</span>
            </button>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="px-4 py-4 pb-24 max-w-3xl mx-auto">
        {/* 关键词输入 */}
        <div className="mb-6">
          <input
            type="text"
            value={keyword}
            onChange={(e) => setKeyword(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && startTest()}
            placeholder="测试关键词"
            disabled={testing}
            className="w-full px-4 py-3 border border-primary-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-500/50 disabled:bg-primary-50"
          />
        </div>

        {/* 错误提示 */}
        {errorMsg && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-xl">
            <div className="flex items-start gap-3">
              <span className="material-symbols-rounded text-red-500">error</span>
              <div className="flex-1">
                <p className="text-red-700">{errorMsg}</p>
                <button
                  onClick={startTest}
                  className="mt-2 px-3 py-1 text-sm bg-red-100 text-red-700 rounded-full hover:bg-red-200 transition-colors"
                >
                  重试测试
                </button>
              </div>
            </div>
          </div>
        )}

        {/* 1. 搜索请求测试 */}
        <TestSection
          title="1. 搜索请求测试"
          status={getSearchStatus()}
          statusColor={getStatusColor(!!searchHtml)}
          expanded={expandSearch}
          onToggle={() => setExpandSearch(!expandSearch)}
        >
          {testing && !searchHtml ? (
            <LoadingIndicator />
          ) : !searchHtml ? (
            <EmptyState text="点击顶部「开始测试」按钮执行" />
          ) : (
            <div className="bg-gray-900 rounded-xl p-4 max-h-64 overflow-auto">
              <pre className="text-xs text-gray-300 font-mono whitespace-pre-wrap break-all">
                {searchHtml.slice(0, 5000)}
                {searchHtml.length > 5000 && '\n\n... (内容过长，已截断)'}
              </pre>
            </div>
          )}
        </TestSection>

        {/* 2. 搜索解析测试 */}
        <TestSection
          title="2. 搜索解析测试"
          status={getParseStatus()}
          statusColor={getStatusColor(searchResults.length > 0, !!searchHtml && searchResults.length === 0)}
          expanded={expandParse}
          onToggle={() => setExpandParse(!expandParse)}
        >
          {testing && searchHtml && searchResults.length === 0 ? (
            <LoadingIndicator />
          ) : !searchHtml ? (
            <EmptyState text="请先完成搜索请求测试" />
          ) : searchResults.length === 0 ? (
            <EmptyState text="未解析到搜索结果" isError />
          ) : (
            <div className="space-y-3">
              {searchResults.map((result, index) => (
                <GlassCard key={index} className="p-4">
                  <p className="font-medium text-primary-900 line-clamp-2">
                    {index + 1}：{result.name}
                  </p>
                  <p className="text-xs text-primary-400 mt-2 break-all">
                    链接：{result.src}
                  </p>
                </GlassCard>
              ))}
            </div>
          )}
        </TestSection>

        {/* 3. 章节列表测试 */}
        <TestSection
          title="3. 章节列表测试"
          status={getChapterStatus()}
          statusColor={getStatusColor(chapters.length > 0, searchResults.length > 0 && chapters.length === 0)}
          expanded={expandChapter}
          onToggle={() => setExpandChapter(!expandChapter)}
        >
          {!plugin?.chapterRoads ? (
            <EmptyState text="未填写章节规则" />
          ) : testing && searchResults.length > 0 && chapters.length === 0 ? (
            <LoadingIndicator />
          ) : searchResults.length === 0 ? (
            <EmptyState text="请先解析到有效结果" />
          ) : chapters.length === 0 ? (
            <EmptyState text="未获取章节数据" isError />
          ) : (
            <div className="space-y-4">
              {chapters.map((road, index) => (
                <GlassCard key={index} className="p-4">
                  <p className="font-medium text-primary-900">
                    播放列表 {index + 1}：{road.name}
                  </p>
                  <p className="text-sm text-primary-500 mt-1">
                    章节数量：{road.data?.length || road.identifier?.length || 0}
                  </p>
                  <div className="mt-3 max-h-32 overflow-auto">
                    {(road.identifier || road.data || []).slice(0, 20).map((item, i) => (
                      <p key={i} className="text-xs text-primary-600">
                        {i + 1}. {item}
                      </p>
                    ))}
                    {(road.identifier || road.data || []).length > 20 && (
                      <p className="text-xs text-primary-400 mt-1">
                        ... 还有 {(road.identifier || road.data || []).length - 20} 个章节
                      </p>
                    )}
                  </div>
                </GlassCard>
              ))}
            </div>
          )}
        </TestSection>
      </div>
    </div>
  )
}

/**
 * 测试区块组件
 */
interface TestSectionProps {
  title: string
  status: string
  statusColor: string
  expanded: boolean
  onToggle: () => void
  children: React.ReactNode
}

function TestSection({ title, status, statusColor, expanded, onToggle, children }: TestSectionProps) {
  return (
    <div className="mb-4">
      <button
        onClick={onToggle}
        className="w-full flex items-center justify-between p-4 bg-primary-50 rounded-xl hover:bg-primary-100 transition-colors"
      >
        <div className="text-left">
          <p className="font-medium text-primary-900">{title}</p>
          <p className={`text-sm ${statusColor}`}>{status}</p>
        </div>
        <span className={`material-symbols-rounded text-primary-500 transition-transform ${expanded ? 'rotate-180' : ''}`}>
          expand_more
        </span>
      </button>
      {expanded && (
        <div className="mt-3 px-2">
          {children}
        </div>
      )}
    </div>
  )
}

/**
 * 加载指示器
 */
function LoadingIndicator() {
  return (
    <div className="flex items-center justify-center py-8">
      <div className="w-6 h-6 border-2 border-primary-500/30 border-t-primary-500 rounded-full animate-spin" />
    </div>
  )
}

/**
 * 空状态
 */
function EmptyState({ text, isError = false }: { text: string; isError?: boolean }) {
  return (
    <div className="flex items-center justify-center py-8">
      <p className={isError ? 'text-red-500' : 'text-primary-400'}>{text}</p>
    </div>
  )
}
