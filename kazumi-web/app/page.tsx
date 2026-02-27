'use client'

import { useEffect, useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { AnimeGrid } from '@/components/anime/AnimeGrid'
import { GlassPanel, LoadingSpinner } from '@/components/ui'
import { cachedFetch, CACHE_TTL } from '@/lib/utils/cache'
import type { AnimeDetail } from '@/types/anime'

/**
 * Home Page - 照抄 Kazumi 的 popular_page.dart 布局
 * 
 * 原项目特点:
 * - 标题可点击切换标签 (热门番组 / 各种标签)
 * - 下拉菜单选择标签
 * - 无限滚动加载更多
 * - 浮动按钮回到顶部
 */

// 默认动画标签 - 照抄原项目的 defaultAnimeTags
const DEFAULT_ANIME_TAGS = [
  '热门番组',
  '日常',
  '搞笑',
  '原创',
  '校园',
  '恋爱',
  '奇幻',
  '冒险',
  '战斗',
  '机战',
  '治愈',
  '百合',
  '后宫',
  '悬疑',
  '推理',
  '科幻',
  '运动',
  '音乐',
  '偶像',
  '美食',
  '职场',
  '历史',
  '战争',
  '恐怖',
  '惊悚',
]

export default function Home() {
  const router = useRouter()
  const [animeList, setAnimeList] = useState<AnimeDetail[]>([])
  const [loading, setLoading] = useState(true)
  const [loadingMore, setLoadingMore] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [currentTag, setCurrentTag] = useState('热门番组')
  const [showTagMenu, setShowTagMenu] = useState(false)
  const [offset, setOffset] = useState(0)
  const [hasMore, setHasMore] = useState(true)
  const [showScrollTop, setShowScrollTop] = useState(false)
  
  const tagButtonRef = useRef<HTMLButtonElement>(null)
  const loadingMoreRef = useRef(false)

  // 使用 ref 来追踪最新的状态，避免闭包问题
  const stateRef = useRef({ offset, hasMore, loadingMore, currentTag })
  useEffect(() => {
    stateRef.current = { offset, hasMore, loadingMore, currentTag }
  }, [offset, hasMore, loadingMore, currentTag])
  
  // 防止重复请求
  const fetchingRef = useRef(false)

  useEffect(() => {
    fetchAnime(true)
  }, [currentTag])

  // 无限滚动监听 - 使用 window 滚动
  useEffect(() => {
    function handleScroll() {
      const { offset, hasMore, loadingMore } = stateRef.current
      
      // 显示/隐藏回到顶部按钮
      setShowScrollTop(window.scrollY > 300)
      
      // 加载更多逻辑
      if (loadingMoreRef.current || !hasMore) return
      
      const scrollTop = window.scrollY
      const scrollHeight = document.documentElement.scrollHeight
      const clientHeight = window.innerHeight
      
      // 照抄原项目: scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200
      if (scrollTop + clientHeight >= scrollHeight - 200) {
        fetchAnimeMore()
      }
    }

    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  async function fetchAnime(isInit: boolean) {
    // 防止重复请求
    if (isInit && fetchingRef.current) return
    if (isInit) fetchingRef.current = true
    
    if (isInit) {
      setLoading(true)
      setOffset(0)
      setHasMore(true)
      setAnimeList([])
    }
    
    setError(null)

    try {
      const currentOffset = isInit ? 0 : offset
      let url: string
      let cacheKey: string
      
      if (currentTag === '热门番组') {
        url = `/api/bangumi/trending?limit=20&offset=${currentOffset}`
        cacheKey = `trending-${currentOffset}`
      } else {
        url = `/api/bangumi/search?keyword=${encodeURIComponent(currentTag)}&limit=20&offset=${currentOffset}&filter[type]=2`
        cacheKey = `search-${currentTag}-${currentOffset}`
      }

      // 使用缓存的 fetch
      const data = await cachedFetch<{ data: unknown[] }>(
        url,
        undefined,
        { ttl: CACHE_TTL.MEDIUM, key: cacheKey }
      )
      
      // 处理数据
      let newAnime: AnimeDetail[] = []
      
      if (currentTag === '热门番组') {
        newAnime = (data.data || [])
          .filter((item: any) => item?.subject?.id)
          .map((item: any) => ({
            ...item.subject,
            nameCn: item.subject.nameCN || item.subject.name_cn || item.subject.nameCn || '',
            eps: item.subject.eps || 0,
            date: item.subject.date || '',
          }))
      } else {
        newAnime = (data.data || [])
          .filter((item: any) => item?.id)
          .map((item: any) => ({
            ...item,
            nameCn: item.nameCN || item.name_cn || item.nameCn || '',
            eps: item.eps || 0,
            date: item.date || '',
          }))
      }
      
      if (isInit) {
        setAnimeList(newAnime)
        setOffset(newAnime.length)
      } else {
        setAnimeList(prev => [...prev, ...newAnime])
        setOffset(prev => prev + newAnime.length)
      }
      
      setHasMore(newAnime.length >= 20)
    } catch (err) {
      console.error('Failed to fetch anime:', err)
      setError(err instanceof Error ? err.message : '加载失败，请稍后重试')
    } finally {
      setLoading(false)
      setLoadingMore(false)
      loadingMoreRef.current = false
      if (isInit) fetchingRef.current = false
    }
  }

  // 加载更多 - 单独的函数避免闭包问题
  async function fetchAnimeMore() {
    if (loadingMoreRef.current) return
    loadingMoreRef.current = true
    setLoadingMore(true)
    
    const { offset, currentTag } = stateRef.current
    
    try {
      let url: string
      let cacheKey: string
      
      if (currentTag === '热门番组') {
        url = `/api/bangumi/trending?limit=20&offset=${offset}`
        cacheKey = `trending-${offset}`
      } else {
        url = `/api/bangumi/search?keyword=${encodeURIComponent(currentTag)}&limit=20&offset=${offset}&filter[type]=2`
        cacheKey = `search-${currentTag}-${offset}`
      }

      // 使用缓存的 fetch
      const data = await cachedFetch<{ data: unknown[] }>(
        url,
        undefined,
        { ttl: CACHE_TTL.MEDIUM, key: cacheKey }
      )
      
      let newAnime: AnimeDetail[] = []
      
      if (currentTag === '热门番组') {
        newAnime = (data.data || [])
          .filter((item: any) => item?.subject?.id)
          .map((item: any) => ({
            ...item.subject,
            nameCn: item.subject.nameCN || item.subject.name_cn || item.subject.nameCn || '',
            eps: item.subject.eps || 0,
            date: item.subject.date || '',
          }))
      } else {
        newAnime = (data.data || [])
          .filter((item: any) => item?.id)
          .map((item: any) => ({
            ...item,
            nameCn: item.nameCN || item.name_cn || item.nameCn || '',
            eps: item.eps || 0,
            date: item.date || '',
          }))
      }
      
      setAnimeList(prev => [...prev, ...newAnime])
      setOffset(prev => prev + newAnime.length)
      setHasMore(newAnime.length >= 20)
    } catch (err) {
      console.error('Failed to fetch more anime:', err)
    } finally {
      setLoadingMore(false)
      loadingMoreRef.current = false
    }
  }

  function handleAnimeClick(anime: AnimeDetail) {
    router.push(`/anime/${anime.id}`)
  }

  function handleTagSelect(tag: string) {
    setShowTagMenu(false)
    if (tag !== currentTag) {
      setCurrentTag(tag)
      // 切换标签时滚动到顶部
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  function scrollToTop() {
    // 多种方式尝试滚动到顶部，确保在各种环境下都能工作
    try {
      // 方法1: 使用 document.documentElement
      document.documentElement.scrollTo({ top: 0, behavior: 'smooth' })
    } catch (e) {
      console.log('scrollTo failed, trying alternative')
    }
    
    try {
      // 方法2: 使用 window.scrollTo
      window.scrollTo({ top: 0, behavior: 'smooth' })
    } catch (e) {
      console.log('window.scrollTo failed')
    }
    
    try {
      // 方法3: 使用 scrollIntoView (最可靠的方法)
      const topElement = document.querySelector('main')
      if (topElement) {
        topElement.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }
    } catch (e) {
      console.log('scrollIntoView failed')
    }
    
    // 方法4: 直接设置 scrollTop (无动画但最可靠)
    document.documentElement.scrollTop = 0
    document.body.scrollTop = 0
  }

  return (
    <div className="min-h-screen safe-area-all">
      <main className="container mx-auto px-4 py-6 pb-24">
        {/* Header - 照抄原项目的 SliverAppBar */}
        <div className="mb-4">
          {/* 标签选择器 - 照抄原项目的 InkWell + CustomDropdownMenu */}
          <button
            ref={tagButtonRef}
            onClick={() => setShowTagMenu(!showTagMenu)}
            className="flex items-center gap-1 group"
          >
            <h1 className="text-3xl font-bold text-primary-900 group-hover:text-primary-700 transition-colors">
              {currentTag}
            </h1>
            <span 
              className={`material-symbols text-primary-600 transition-transform ${showTagMenu ? 'rotate-180' : ''}`} 
              style={{ fontSize: '28px' }}
            >
              keyboard_arrow_down
            </span>
          </button>
          
          {/* 下拉菜单 */}
          {showTagMenu && (
            <>
              {/* 遮罩层 */}
              <div 
                className="fixed inset-0 z-40"
                onClick={() => setShowTagMenu(false)}
              />
              {/* 菜单 */}
              <div className="absolute z-50 mt-2 py-2 bg-white rounded-xl shadow-lg border border-primary-100 max-h-80 overflow-y-auto">
                {DEFAULT_ANIME_TAGS.map((tag) => (
                  <button
                    key={tag}
                    onClick={() => handleTagSelect(tag)}
                    className={`
                      w-full px-4 py-2 text-left text-sm transition-colors
                      ${currentTag === tag 
                        ? 'bg-primary-100 text-primary-700 font-medium' 
                        : 'text-primary-600 hover:bg-primary-50'
                      }
                    `}
                  >
                    {tag}
                  </button>
                ))}
              </div>
            </>
          )}
          
          <p className="text-primary-600 mt-2">
            {currentTag === '热门番组' ? '发现最受欢迎的动画作品' : `浏览「${currentTag}」类型的番剧`}
          </p>
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
              <p className="text-primary-600">加载中...</p>
            </div>
          </GlassPanel>
        )}

        {/* Error State */}
        {error && !loading && (
          <GlassPanel className="p-8">
            <div className="flex flex-col items-center justify-center gap-4">
              <span className="material-symbols text-primary-300" style={{ fontSize: '64px' }}>
                sentiment_dissatisfied
              </span>
              <p className="text-primary-600">什么都没有找到 (´;ω;`)</p>
              <button
                onClick={() => fetchAnime(true)}
                className="px-6 py-2 bg-primary-500 text-white rounded-full hover:bg-primary-600 transition-colors"
              >
                点击重试
              </button>
            </div>
          </GlassPanel>
        )}

        {/* Anime Grid */}
        {!loading && !error && animeList.length > 0 && (
          <AnimeGrid
            animes={animeList}
            onAnimeClick={handleAnimeClick}
          />
        )}

        {/* Empty State */}
        {!loading && !error && animeList.length === 0 && (
          <GlassPanel className="p-12">
            <div className="flex flex-col items-center justify-center gap-4">
              <span className="material-symbols text-primary-300" style={{ fontSize: '64px' }}>
                inbox
              </span>
              <p className="text-primary-600">暂无番剧</p>
            </div>
          </GlassPanel>
        )}
      </main>

      {/* 浮动按钮 - 回到顶部 - 照抄原项目的 FloatingActionButton */}
      {showScrollTop && (
        <button
          onClick={(e) => {
            e.preventDefault()
            e.stopPropagation()
            console.log('Scroll to top button clicked')
            scrollToTop()
          }}
          className="fixed bottom-24 right-6 w-14 h-14 bg-primary-500 hover:bg-primary-600 text-white rounded-full shadow-lg flex items-center justify-center transition-all hover:scale-110 z-30"
          aria-label="回到顶部"
          type="button"
        >
          <span className="material-symbols" style={{ fontSize: '24px' }}>
            arrow_upward
          </span>
        </button>
      )}
    </div>
  )
}
