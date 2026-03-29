'use client'

import { useState, useCallback, useEffect, useRef, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { Input } from '@/components/ui/Input'
import { AnimeGrid } from '@/components/anime/AnimeGrid'
import { GlassPanel, LoadingSpinner } from '@/components/ui'
import { BottomSheet } from '@/components/ui/BottomSheet'
import type { AnimeDetail } from '@/types/anime'

/**
 * Search Page - 照抄 Kazumi 的 search_page.dart 布局
 * 
 * 原项目特点:
 * - SearchAnchor.bar 搜索框
 * - 搜索历史记录 (最多10条)
 * - 浮动按钮打开排序/过滤设置
 * - 支持按热度/评分/匹配程度排序
 * - 无限滚动加载更多 (当结果 >= 20 时)
 */

const SEARCH_HISTORY_KEY = 'search_history'
const MAX_HISTORY_COUNT = 10

// 搜索历史管理 - 照抄原项目 SearchHistoryRepository
function getSearchHistory(): string[] {
  if (typeof window === 'undefined') return []
  try {
    const data = localStorage.getItem(SEARCH_HISTORY_KEY)
    return data ? JSON.parse(data) : []
  } catch {
    return []
  }
}

function saveSearchHistory(keyword: string): void {
  if (typeof window === 'undefined' || !keyword.trim()) return
  try {
    let history = getSearchHistory()
    // 删除重复的
    history = history.filter(h => h !== keyword)
    // 添加到开头
    history.unshift(keyword)
    // 限制数量
    if (history.length > MAX_HISTORY_COUNT) {
      history = history.slice(0, MAX_HISTORY_COUNT)
    }
    localStorage.setItem(SEARCH_HISTORY_KEY, JSON.stringify(history))
  } catch (e) {
    console.error('Failed to save search history:', e)
  }
}

function deleteSearchHistory(keyword: string): void {
  if (typeof window === 'undefined') return
  try {
    let history = getSearchHistory()
    history = history.filter(h => h !== keyword)
    localStorage.setItem(SEARCH_HISTORY_KEY, JSON.stringify(history))
  } catch (e) {
    console.error('Failed to delete search history:', e)
  }
}

function clearAllSearchHistory(): void {
  if (typeof window === 'undefined') return
  try {
    localStorage.removeItem(SEARCH_HISTORY_KEY)
  } catch (e) {
    console.error('Failed to clear search history:', e)
  }
}

// 内部搜索组件 - 使用 useSearchParams
function SearchContent() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const initialQuery = searchParams.get('q') || ''

  const [query, setQuery] = useState(initialQuery)
  const [searchResults, setSearchResults] = useState<AnimeDetail[]>([])
  const [loading, setLoading] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [hasSearched, setHasSearched] = useState(false)
  const [showSettings, setShowSettings] = useState(false)
  const [sortType, setSortType] = useState<'heat' | 'rank' | 'match'>('match')
  const [offset, setOffset] = useState(0)
  const [hasMore, setHasMore] = useState(true)
  
  // 搜索历史 - 照抄原项目
  const [searchHistory, setSearchHistory] = useState<string[]>([])
  const [showHistory, setShowHistory] = useState(false)
  const historyRef = useRef<HTMLDivElement>(null)
  
  // 使用 ref 来追踪最新的状态，避免闭包问题
  const stateRef = useRef({ offset, hasMore, loadingMore, query })
  const loadingMoreRef = useRef(false)
  
  useEffect(() => {
    stateRef.current = { offset, hasMore, loadingMore, query }
  }, [offset, hasMore, loadingMore, query])

  // 加载搜索历史
  useEffect(() => {
    const history = getSearchHistory()
    console.log('Loaded search history:', history)
    setSearchHistory(history)
    // 如果没有初始查询且有历史记录，显示历史
    if (!initialQuery && history.length > 0) {
      // 延迟显示，等待组件完全渲染
      setTimeout(() => {
        setShowHistory(true)
      }, 200)
    }
  }, [])

  // 点击外部关闭历史下拉
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (historyRef.current && !historyRef.current.contains(event.target as Node)) {
        setShowHistory(false)
      }
    }
    
    if (showHistory) {
      document.addEventListener('mousedown', handleClickOutside)
      return () => document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [showHistory])

  // Debounce timer
  const debounceTimerRef = useRef<NodeJS.Timeout | null>(null)

  // Search function - 照抄原项目的 searchBangumi
  const performSearch = useCallback(async (searchQuery: string, isLoadMore = false) => {
    if (!searchQuery.trim()) {
      setSearchResults([])
      setHasSearched(false)
      return
    }

    try {
      if (isLoadMore) {
        if (loadingMoreRef.current) return
        loadingMoreRef.current = true
        setLoadingMore(true)
      } else {
        setLoading(true)
        setOffset(0)
        setHasMore(true)
        setSearchResults([])
        // 保存搜索历史 - 照抄原项目
        saveSearchHistory(searchQuery)
        setSearchHistory(getSearchHistory())
      }
      setError(null)
      setHasSearched(true)
      setShowHistory(false)

      const currentOffset = isLoadMore ? stateRef.current.offset : 0
      const response = await fetch(
        `/api/bangumi/search?keyword=${encodeURIComponent(searchQuery)}&limit=20&offset=${currentOffset}`
      )
      
      if (!response.ok) {
        throw new Error('搜索失败')
      }

      const data = await response.json()
      const newResults = (data.data || []).map((item: any) => ({
        ...item,
        nameCn: item.nameCN || item.name_cn || item.nameCn || '',
      }))
      
      if (isLoadMore) {
        setSearchResults(prev => [...prev, ...newResults])
        setOffset(prev => prev + newResults.length)
      } else {
        setSearchResults(newResults)
        setOffset(newResults.length)
      }
      
      // 照抄原项目: 当结果 >= 20 时才允许加载更多
      setHasMore(newResults.length >= 20)
    } catch (err) {
      console.error('Search failed:', err)
      setError(err instanceof Error ? err.message : '搜索失败，请稍后重试')
    } finally {
      setLoading(false)
      setLoadingMore(false)
      loadingMoreRef.current = false
    }
  }, [])

  // 无限滚动监听 - 使用 window 滚动
  useEffect(() => {
    function handleScroll() {
      const { hasMore, query } = stateRef.current
      
      if (loadingMoreRef.current || !hasMore || !query.trim()) return
      
      const scrollTop = window.scrollY
      const scrollHeight = document.documentElement.scrollHeight
      const clientHeight = window.innerHeight
      
      // 照抄原项目: scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200
      if (scrollTop + clientHeight >= scrollHeight - 200) {
        console.log('SearchController: search results is loading more')
        performSearch(query, true)
      }
    }

    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => window.removeEventListener('scroll', handleScroll)
  }, [performSearch])

  // Handle input change with debouncing
  const handleQueryChange = useCallback((value: string) => {
    setQuery(value)
    setShowHistory(value === '' && searchHistory.length > 0)

    // Clear existing timer
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current)
    }

    if (!value.trim()) {
      setSearchResults([])
      setHasSearched(false)
      return
    }

    // Set new timer (500ms debounce)
    debounceTimerRef.current = setTimeout(() => {
      performSearch(value, false)
    }, 500)
  }, [searchHistory.length, performSearch])

  // 点击搜索历史
  const handleHistoryClick = useCallback((keyword: string) => {
    setQuery(keyword)
    setShowHistory(false)
    performSearch(keyword, false)
  }, [performSearch])

  // 删除单条历史
  const handleDeleteHistory = useCallback((keyword: string, e: React.MouseEvent) => {
    e.stopPropagation()
    deleteSearchHistory(keyword)
    setSearchHistory(getSearchHistory())
  }, [])

  // 清空所有历史
  const handleClearAllHistory = useCallback(() => {
    clearAllSearchHistory()
    setSearchHistory([])
  }, [])

  // Initial search if query param exists
  useEffect(() => {
    if (initialQuery) {
      performSearch(initialQuery, false)
    }
  }, []) // Only run once on mount

  // Cleanup timer on unmount
  useEffect(() => {
    return () => {
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current)
      }
    }
  }, [])

  function handleAnimeClick(anime: AnimeDetail) {
    router.push(`/anime/${anime.id}`)
  }

  function handleClear() {
    setQuery('')
    setSearchResults([])
    setHasSearched(false)
    setError(null)
    setOffset(0)
    setHasMore(true)
    setShowHistory(searchHistory.length > 0)
  }

  // 输入框获得焦点时显示历史
  function handleInputFocus() {
    console.log('Input focused, query:', query, 'history length:', searchHistory.length)
    if (!query && searchHistory.length > 0) {
      // 使用 setTimeout 确保状态更新在其他事件之后
      setTimeout(() => {
        setShowHistory(true)
      }, 100)
    }
  }

  // 输入框失去焦点时延迟隐藏历史（允许点击历史项）
  function handleInputBlur() {
    // 延迟隐藏，给用户时间点击历史项
    setTimeout(() => {
      // 只有当没有正在进行的点击时才隐藏
      setShowHistory(false)
    }, 200)
  }

  // 排序结果 - 照抄原项目
  function getSortedResults(): AnimeDetail[] {
    const sorted = [...searchResults]
    switch (sortType) {
      case 'heat':
        return sorted.sort((a, b) => (b.collection?.doing || 0) - (a.collection?.doing || 0))
      case 'rank':
        return sorted.sort((a, b) => (b.rating?.score || 0) - (a.rating?.score || 0))
      case 'match':
      default:
        return sorted // 默认按匹配程度（API返回顺序）
    }
  }

  const sortedResults = getSortedResults()

  return (
    <div className="min-h-screen safe-area-all">
      <main className="container mx-auto px-4 py-8 pb-24">
        {/* Header - 照抄原项目的 SysAppBar */}
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-primary-900">
            搜索
          </h1>
        </div>

        {/* Search Input - 照抄原项目的 SearchAnchor.bar */}
        <div className="mb-6 relative">
          <div className="flex items-center gap-3 bg-white/80 backdrop-blur-sm rounded-2xl px-4 py-3 shadow-sm border border-primary-100/50">
            <span className="material-symbols text-primary-400" style={{ fontSize: '24px' }}>
              search
            </span>
            <Input
              type="text"
              value={query}
              onChange={(e) => handleQueryChange(e.target.value)}
              onFocus={handleInputFocus}
              onBlur={handleInputBlur}
              placeholder="搜索番剧名称..."
              className="flex-1 border-none bg-transparent focus:ring-0"
              autoFocus
            />
            {query && (
              <button
                onClick={handleClear}
                className="p-1 hover:bg-primary-100 rounded-full transition-colors"
                aria-label="清除搜索"
              >
                <span className="material-symbols text-primary-400" style={{ fontSize: '20px' }}>
                  close
                </span>
              </button>
            )}
          </div>

          {/* 搜索历史下拉 - 照抄原项目的 suggestionsBuilder */}
          {showHistory && searchHistory.length > 0 && (
            <div 
              ref={historyRef}
              className="absolute top-full left-0 right-0 mt-2 z-50 bg-white rounded-xl shadow-lg border border-primary-100 overflow-hidden"
              onMouseDown={(e) => e.preventDefault()} // 防止点击时触发 blur
            >
              <div className="flex items-center justify-between px-4 py-2 border-b border-primary-100">
                <span className="text-sm text-primary-500">搜索历史</span>
                <button
                  onClick={(e) => {
                    e.preventDefault()
                    handleClearAllHistory()
                  }}
                  className="text-xs text-primary-400 hover:text-primary-600"
                >
                  清空
                </button>
              </div>
              <div className="max-h-60 overflow-y-auto">
                {searchHistory.map((keyword, index) => (
                  <div
                    key={index}
                    onClick={() => handleHistoryClick(keyword)}
                    className="flex items-center justify-between px-4 py-3 hover:bg-primary-50 cursor-pointer transition-colors"
                  >
                    <div className="flex items-center gap-3">
                      <span className="material-symbols text-primary-300" style={{ fontSize: '18px' }}>
                        history
                      </span>
                      <span className="text-primary-700">{keyword}</span>
                    </div>
                    <button
                      onClick={(e) => handleDeleteHistory(keyword, e)}
                      className="p-1 hover:bg-primary-100 rounded-full transition-colors"
                    >
                      <span className="material-symbols text-primary-300" style={{ fontSize: '18px' }}>
                        close
                      </span>
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* 加载更多进度条 - 照抄原项目的 LinearProgressIndicator */}
        {loadingMore && (
          <div className="flex items-center justify-center gap-2 mb-4 py-2">
            <LoadingSpinner size="sm" color="primary" />
            <span className="text-sm text-primary-500">加载中...</span>
          </div>
        )}

        {/* Loading State */}
        {loading && (
          <GlassPanel className="p-12">
            <div className="flex flex-col items-center justify-center gap-4">
              <LoadingSpinner size="lg" color="primary" />
              <p className="text-primary-600">搜索中...</p>
            </div>
          </GlassPanel>
        )}

        {/* Error State */}
        {error && !loading && (
          <GlassPanel className="p-8">
            <div className="flex flex-col items-center justify-center gap-4">
              <span className="material-symbols text-red-500" style={{ fontSize: '48px' }}>
                error
              </span>
              <p className="text-red-600">{error}</p>
              <button
                onClick={() => performSearch(query, false)}
                className="px-6 py-2 bg-primary-500 text-white rounded-full hover:bg-primary-600 transition-colors"
              >
                重试
              </button>
            </div>
          </GlassPanel>
        )}

        {/* Search Results */}
        {!loading && !error && hasSearched && sortedResults.length > 0 && (
          <>
            <div className="mb-4 text-primary-600 text-sm">
              找到 {sortedResults.length} 个结果 {hasMore && '(下拉加载更多)'}
            </div>
            <AnimeGrid
              animes={sortedResults}
              onAnimeClick={handleAnimeClick}
            />
          </>
        )}

        {/* Empty Results - 照抄原项目 */}
        {!loading && !error && hasSearched && sortedResults.length === 0 && (
          <GlassPanel className="p-12">
            <div className="flex flex-col items-center justify-center gap-4">
              <span className="material-symbols text-primary-300" style={{ fontSize: '64px' }}>
                search_off
              </span>
              <p className="text-primary-600">什么都没有找到 (´;ω;`)</p>
              <p className="text-primary-400 text-sm">试试其他关键词吧</p>
            </div>
          </GlassPanel>
        )}

        {/* Initial State */}
        {!loading && !error && !hasSearched && !showHistory && (
          <GlassPanel className="p-12">
            <div className="flex flex-col items-center justify-center gap-4">
              <span className="material-symbols text-primary-300" style={{ fontSize: '64px' }}>
                travel_explore
              </span>
              <p className="text-primary-600">输入关键词开始搜索</p>
            </div>
          </GlassPanel>
        )}

        {/* 浮动设置按钮 - 照抄原项目 */}
        {hasSearched && sortedResults.length > 0 && (
          <button
            onClick={() => setShowSettings(true)}
            className="fixed bottom-24 right-6 w-14 h-14 bg-primary-500 hover:bg-primary-600 text-white rounded-full shadow-lg flex items-center justify-center transition-all hover:scale-110 z-30"
            aria-label="搜索设置"
          >
            <span className="material-symbols" style={{ fontSize: '24px' }}>
              sort
            </span>
          </button>
        )}

        {/* 设置弹窗 - 使用 BottomSheet 组件 */}
        <BottomSheet
          isOpen={showSettings}
          onClose={() => setShowSettings(false)}
          title="搜索设置"
        >
          <div className="p-4">
            <h4 className="text-sm font-medium text-primary-600 mb-2">排序方式</h4>
            <div className="space-y-2">
              <button
                onClick={() => { setSortType('heat'); setShowSettings(false); }}
                className={`w-full p-4 text-left rounded-xl transition-colors ${
                  sortType === 'heat' ? 'bg-primary-100 text-primary-700' : 'hover:bg-primary-50'
                }`}
              >
                按热度排序
              </button>
              <button
                onClick={() => { setSortType('rank'); setShowSettings(false); }}
                className={`w-full p-4 text-left rounded-xl transition-colors ${
                  sortType === 'rank' ? 'bg-primary-100 text-primary-700' : 'hover:bg-primary-50'
                }`}
              >
                按评分排序
              </button>
              <button
                onClick={() => { setSortType('match'); setShowSettings(false); }}
                className={`w-full p-4 text-left rounded-xl transition-colors ${
                  sortType === 'match' ? 'bg-primary-100 text-primary-700' : 'hover:bg-primary-50'
                }`}
              >
                按匹配程度排序
              </button>
            </div>
          </div>
        </BottomSheet>
      </main>
    </div>
  )
}

// 加载状态组件
function SearchLoading() {
  return (
    <div className="min-h-screen safe-area-all">
      <main className="container mx-auto px-4 py-8 pb-24">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-primary-900">搜索</h1>
        </div>
        <div className="mb-6">
          <div className="flex items-center gap-3 bg-white/80 backdrop-blur-sm rounded-2xl px-4 py-3 shadow-sm border border-primary-100/50">
            <span className="material-symbols text-primary-400" style={{ fontSize: '24px' }}>search</span>
            <div className="flex-1 h-6 bg-primary-100 rounded animate-pulse" />
          </div>
        </div>
        <GlassPanel className="p-12">
          <div className="flex flex-col items-center justify-center gap-4">
            <LoadingSpinner size="lg" color="primary" />
            <p className="text-primary-600">加载中...</p>
          </div>
        </GlassPanel>
      </main>
    </div>
  )
}

// 导出的页面组件 - 包裹 Suspense 边界
export default function SearchPage() {
  return (
    <Suspense fallback={<SearchLoading />}>
      <SearchContent />
    </Suspense>
  )
}
