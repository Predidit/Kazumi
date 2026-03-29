'use client'

import { useEffect, useState, useRef } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { GlassPanel } from '@/components/ui/GlassPanel'
import { Button } from '@/components/ui/Button'
import { favoritesManager } from '@/lib/storage/favorites'
import { historyManager } from '@/lib/storage/history'
import type { AnimeDetail, Character, Episode } from '@/types'
import Image from 'next/image'

/**
 * Anime Detail Page - 照抄 Kazumi 的 info_page.dart 布局
 * 
 * iOS 26 / iPhone 优先布局:
 * - 所有组件使用 flex-shrink-0 防止换行
 * - 使用 min-w-0 防止文字溢出
 * - 使用 truncate/line-clamp 处理长文本
 * - Safe Area 适配刘海屏
 */

// Tab 类型定义
type TabType = '概览' | '吐槽' | '角色' | '评论' | '制作人员'
const TABS: TabType[] = ['概览', '吐槽', '角色', '评论', '制作人员']

// 评论类型 (吐槽) - 照抄原项目的 CommentItem
interface CommentItem {
  id?: number
  user?: {
    id?: number
    username?: string
    nickname?: string
    avatar?: { 
      small?: string
      medium?: string
      large?: string 
    }
    sign?: string
    joinedAt?: number
  }
  comment?: string
  rate?: number
  updatedAt?: number | string
}

// 制作人员类型
interface StaffItem {
  id?: number
  name?: string
  name_cn?: string
  images?: { large?: string; medium?: string; small?: string }
  relation?: string
}

// 安全获取字符串
const safeStr = (val: any, fallback = ''): string => {
  if (val === null || val === undefined) return fallback
  return String(val)
}

// 安全获取数字
const safeNum = (val: any, fallback = 0): number => {
  if (val === null || val === undefined) return fallback
  const num = Number(val)
  return isNaN(num) ? fallback : num
}

// 安全获取图片 URL - 使用代理解决 CORS 问题
// 照抄原项目: 角色头像用 grid, 角色详情用 large, 封面用 large
const safeImageUrl = (images: any, size: 'large' | 'medium' | 'small' | 'grid' = 'large'): string | null => {
  if (!images) return null
  // 按优先级获取图片 URL
  let url: string | null = null
  if (size === 'grid') {
    // 头像优先使用 grid (小尺寸正方形)
    url = images.grid || images.small || images.medium || images.large || null
  } else if (size === 'small') {
    url = images.small || images.grid || images.medium || images.large || null
  } else if (size === 'medium') {
    url = images.medium || images.large || images.small || images.grid || null
  } else {
    // large - 详情页大图
    url = images.large || images.medium || images.common || images.small || null
  }
  if (!url) return null
  // 如果是 lain.bgm.tv 的图片，使用代理
  if (url.includes('lain.bgm.tv') || url.includes('bgm.tv')) {
    return `/api/proxy/image?url=${encodeURIComponent(url)}`
  }
  return url
}

export default function AnimeDetailPage() {
  const params = useParams()
  const router = useRouter()
  const animeId = parseInt(params.id as string) || 0

  const [anime, setAnime] = useState<AnimeDetail | null>(null)
  const [episodes, setEpisodes] = useState<Episode[]>([])
  const [characters, setCharacters] = useState<Character[]>([])
  const [comments, setComments] = useState<CommentItem[]>([])
  const [staff, setStaff] = useState<StaffItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [isFavorited, setIsFavorited] = useState(false)
  const [lastWatched, setLastWatched] = useState<{ episode: number; progress: number } | null>(null)
  
  // Tab 状态
  const [activeTab, setActiveTab] = useState<TabType>('概览')
  const [charactersLoading, setCharactersLoading] = useState(false)
  const [commentsLoading, setCommentsLoading] = useState(false)
  const [staffLoading, setStaffLoading] = useState(false)
  
  // 概览展开状态
  const [fullIntro, setFullIntro] = useState(false)
  const [fullTag, setFullTag] = useState(false)

  useEffect(() => {
    if (animeId > 0) {
      fetchAnimeData()
      checkFavoriteStatus()
      checkWatchHistory()
    }
  }, [animeId])

  // 切换 Tab 时懒加载数据
  useEffect(() => {
    if (activeTab === '角色' && characters.length === 0 && !charactersLoading) {
      loadCharacters()
    }
    if (activeTab === '吐槽' && comments.length === 0 && !commentsLoading) {
      loadComments()
    }
    if (activeTab === '制作人员' && staff.length === 0 && !staffLoading) {
      loadStaff()
    }
  }, [activeTab])

  async function fetchAnimeData() {
    try {
      setLoading(true)
      setError(null)

      const animeResponse = await fetch(`/api/bangumi/subject/${animeId}`)
      if (!animeResponse.ok) throw new Error('获取番剧信息失败')
      const animeData = await animeResponse.json()
      
      // 安全处理 anime 数据
      if (animeData && typeof animeData === 'object') {
        setAnime(animeData)
      } else {
        throw new Error('番剧数据格式错误')
      }

      const episodesResponse = await fetch(`/api/bangumi/episodes?subject_id=${animeId}&limit=100`)
      if (episodesResponse.ok) {
        const episodesData = await episodesResponse.json()
        const episodeList = Array.isArray(episodesData?.data) ? episodesData.data : []
        setEpisodes(episodeList)
      }
    } catch (err) {
      console.error('Failed to fetch anime data:', err)
      setError(err instanceof Error ? err.message : '加载失败，请稍后重试')
    } finally {
      setLoading(false)
    }
  }

  async function loadCharacters() {
    if (charactersLoading) return
    setCharactersLoading(true)
    try {
      const response = await fetch(`/api/bangumi/characters?subject_id=${animeId}`)
      if (response.ok) {
        const data = await response.json()
        const characterList = Array.isArray(data) ? data : []
        setCharacters(characterList)
      }
    } catch (err) {
      console.error('Failed to load characters:', err)
    } finally {
      setCharactersLoading(false)
    }
  }

  async function loadComments() {
    if (commentsLoading) return
    setCommentsLoading(true)
    try {
      const response = await fetch(`/api/bangumi/comments?subject_id=${animeId}`)
      if (response.ok) {
        const data = await response.json()
        // 照抄原项目: API 返回 { commentList: [...], total: N }
        let commentList: any[] = []
        if (Array.isArray(data?.commentList)) {
          commentList = data.commentList
        } else if (Array.isArray(data)) {
          commentList = data
        }
        // 添加 id 字段
        const commentsWithId = commentList.map((item: any, index: number) => ({
          ...item,
          id: item?.id ?? index,
        }))
        setComments(commentsWithId)
      }
    } catch (err) {
      console.error('Failed to load comments:', err)
    } finally {
      setCommentsLoading(false)
    }
  }

  async function loadStaff() {
    if (staffLoading) return
    setStaffLoading(true)
    try {
      const response = await fetch(`/api/bangumi/staff?subject_id=${animeId}`)
      if (response.ok) {
        const data = await response.json()
        // 照抄原项目: API 返回 { data: [...], total: N }
        // 每个 item 是 { staff: {...}, positions: [...] }
        let staffList: any[] = []
        if (Array.isArray(data?.data)) {
          // 转换为页面需要的格式
          staffList = data.data.map((item: any) => {
            const staffInfo = item?.staff || {}
            const positions = Array.isArray(item?.positions) ? item.positions : []
            // 获取第一个职位的中文名作为 relation
            const firstPosition = positions[0]
            const relation = firstPosition?.type?.cn || firstPosition?.type?.jp || firstPosition?.type?.en || ''
            
            return {
              id: staffInfo.id,
              name: staffInfo.name || '',
              name_cn: staffInfo.nameCN || '',
              images: staffInfo.images || null,
              relation,
            }
          })
        } else if (Array.isArray(data)) {
          staffList = data
        }
        setStaff(staffList)
      }
    } catch (err) {
      console.error('Failed to load staff:', err)
    } finally {
      setStaffLoading(false)
    }
  }

  function checkFavoriteStatus() {
    try {
      setIsFavorited(favoritesManager.isFavorited(animeId))
    } catch (err) {
      console.error('Failed to check favorite status:', err)
    }
  }

  function checkWatchHistory() {
    try {
      const history = historyManager.getAllHistory()
      if (!Array.isArray(history)) return
      
      const animeHistory = history.filter(item => item?.animeId === animeId)
      if (animeHistory.length > 0) {
        const latest = animeHistory.sort((a, b) => (b?.timestamp || 0) - (a?.timestamp || 0))[0]
        if (latest) {
          setLastWatched({
            episode: latest.episodeNumber || 1,
            progress: latest.time || 0
          })
        }
      }
    } catch (err) {
      console.error('Failed to check watch history:', err)
    }
  }

  function handleToggleFavorite() {
    try {
      if (isFavorited) {
        favoritesManager.removeFavorite(animeId)
        setIsFavorited(false)
      } else {
        favoritesManager.addFavorite(animeId)
        setIsFavorited(true)
      }
    } catch (err) {
      console.error('Failed to toggle favorite:', err)
    }
  }

  function handleStartWatching() {
    const ep = lastWatched?.episode || 1
    router.push(`/anime/${animeId}/watch/${ep}`)
  }

  function handleEpisodeClick(episode: Episode) {
    const epNum = episode?.sort || episode?.ep || 1
    router.push(`/anime/${animeId}/watch/${epNum}`)
  }

  if (loading) {
    return (
      <div className="min-h-screen pt-safe pb-safe">
        <main className="container mx-auto px-4 py-8">
          <GlassPanel className="p-12">
            <div className="flex flex-col items-center justify-center gap-4">
              <div className="animate-spin">
                <span className="material-symbols text-primary-500" style={{ fontSize: '48px' }}>
                  progress_activity
                </span>
              </div>
              <p className="text-primary-600">加载中...</p>
            </div>
          </GlassPanel>
        </main>
      </div>
    )
  }

  if (error || !anime) {
    return (
      <div className="min-h-screen pt-safe pb-safe">
        <main className="container mx-auto px-4 py-8">
          <GlassPanel className="p-8">
            <div className="flex flex-col items-center justify-center gap-4">
              <span className="material-symbols text-red-500" style={{ fontSize: '48px' }}>
                error
              </span>
              <p className="text-red-600">{error || '番剧不存在'}</p>
              <Button onClick={() => router.back()}>返回</Button>
            </div>
          </GlassPanel>
        </main>
      </div>
    )
  }

  // 安全获取 anime 数据
  const animeName = safeStr(anime.nameCn || anime.name, '未知番剧')
  const animeNameOriginal = safeStr(anime.name)
  const animeImageUrl = safeImageUrl(anime.images)
  const animeRating = anime.rating
  const animeSummary = safeStr(anime.summary)
  const animeTags = Array.isArray(anime.tags) ? anime.tags : []
  const animeDate = safeStr(anime.date)
  const animeEps = safeNum(anime.eps)

  return (
    <div className="min-h-screen bg-white relative">
      {/* 固定背景模糊图 - 照抄原项目 */}
      {animeImageUrl && (
        <div className="fixed inset-0 overflow-hidden pointer-events-none z-0">
          <Image
            src={animeImageUrl}
            alt=""
            fill
            className="object-cover blur-[15px] scale-110"
            style={{ opacity: 0.4 }}
            unoptimized
          />
          {/* 渐变遮罩 */}
          <div 
            className="absolute inset-0" 
            style={{ 
              background: 'linear-gradient(to bottom, transparent 0%, transparent 60%, white 100%)' 
            }} 
          />
        </div>
      )}
      {/* 无背景图时的简单背景 */}
      {!animeImageUrl && (
        <div className="fixed inset-0 bg-gray-50 pointer-events-none z-0" />
      )}

      {/* 可滚动内容区域 */}
      <div className="relative z-10">
        {/* AppBar - iOS Safe Area */}
        <div className="flex items-center justify-between px-4 py-3 pt-safe">
          <button
            onClick={() => router.back()}
            className="flex-shrink-0 p-2 rounded-full hover:bg-white/50 active:bg-white/70 transition-colors"
            aria-label="返回"
          >
            <span className="material-symbols text-primary-900" style={{ fontSize: '24px' }}>
              arrow_back
            </span>
          </button>
          <div className="flex items-center gap-1 flex-shrink-0">
            <button
              onClick={handleToggleFavorite}
              className={`
                flex-shrink-0 p-2 rounded-full transition-all duration-200
                ${isFavorited 
                  ? 'bg-red-100 hover:bg-red-200 active:bg-red-300' 
                  : 'hover:bg-white/50 active:bg-white/70'
                }
              `}
              aria-label={isFavorited ? '取消收藏' : '收藏'}
            >
              <span 
                className={`material-symbols transition-all duration-200 ${
                  isFavorited ? 'text-red-500 scale-110' : 'text-primary-600'
                }`} 
                style={{ 
                  fontSize: '24px',
                  fontVariationSettings: isFavorited ? "'FILL' 1" : "'FILL' 0"
                }}
              >
                favorite
              </span>
            </button>
            <button
              onClick={() => window.open(`https://bangumi.tv/subject/${animeId}`, '_blank')}
              className="flex-shrink-0 p-2 rounded-full hover:bg-white/50 active:bg-white/70 transition-colors"
              aria-label="在 Bangumi 打开"
            >
              <span className="material-symbols text-primary-600" style={{ fontSize: '24px' }}>
                open_in_browser
              </span>
            </button>
          </div>
        </div>

        {/* 番剧信息卡片 */}
        <div className="px-4 pb-3">
          <BangumiInfoCard 
            name={animeName}
            nameOriginal={animeNameOriginal}
            imageUrl={animeImageUrl}
            rating={animeRating}
            date={animeDate}
            eps={animeEps}
          />
        </div>

        {/* TabBar - 粘性定位 */}
        <div className="sticky top-0 z-20 bg-white/90 backdrop-blur-sm">
          <div className="flex overflow-x-auto scrollbar-hide">
            {TABS.map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`
                  flex-shrink-0 px-5 py-3 text-sm font-medium whitespace-nowrap transition-colors
                  ${activeTab === tab 
                    ? 'text-primary-600 border-b-2 border-primary-600' 
                    : 'text-primary-400 hover:text-primary-600 active:text-primary-700'
                  }
                `}
              >
                {tab}
              </button>
            ))}
          </div>
        </div>

        {/* Tab 内容 - 底部留出导航空间 */}
        <main className="px-4 py-4 pb-32 min-h-[50vh] bg-white/80">
        {activeTab === '概览' && (
          <OverviewTab 
            summary={animeSummary}
            tags={animeTags}
            episodes={episodes}
            fullIntro={fullIntro}
            setFullIntro={setFullIntro}
            fullTag={fullTag}
            setFullTag={setFullTag}
            onEpisodeClick={handleEpisodeClick}
          />
        )}
        {activeTab === '吐槽' && (
          <CommentsTab 
            comments={comments} 
            loading={commentsLoading}
            onRetry={loadComments}
          />
        )}
        {activeTab === '角色' && (
          <CharactersTab 
            characters={characters} 
            loading={charactersLoading}
            onRetry={loadCharacters}
          />
        )}
        {activeTab === '评论' && <ReviewsTab />}
        {activeTab === '制作人员' && (
          <StaffTab 
            staff={staff} 
            loading={staffLoading}
            onRetry={loadStaff}
          />
        )}
      </main>
      </div>

      {/* 浮动按钮 - iOS Safe Area，避开底部导航 */}
      <div className="fixed bottom-24 right-4 pb-safe z-30">
        <button
          onClick={handleStartWatching}
          className="flex items-center gap-2 px-5 py-3 bg-primary-500 hover:bg-primary-600 active:bg-primary-700 text-white rounded-full shadow-lg transition-all active:scale-95"
        >
          <span className="material-symbols flex-shrink-0" style={{ fontSize: '22px' }}>
            play_arrow
          </span>
          <span className="font-medium text-sm whitespace-nowrap">
            {lastWatched ? `继续 第${lastWatched.episode}话` : '开始观看'}
          </span>
        </button>
      </div>
    </div>
  )
}


/**
 * BangumiInfoCard - 照抄原项目的 BangumiInfoCardV
 * iOS 优化: 固定宽度封面，文字区域 min-w-0 防止溢出
 */
interface BangumiInfoCardProps {
  name: string
  nameOriginal: string
  imageUrl: string | null
  rating?: { score?: number; total?: number } | null
  date: string
  eps: number
}

function BangumiInfoCard({ name, nameOriginal, imageUrl, rating, date, eps }: BangumiInfoCardProps) {
  const showOriginalName = nameOriginal && nameOriginal !== name
  const ratingScore = rating?.score
  const ratingTotal = rating?.total || 0

  return (
    <div className="flex gap-3 bg-white/80 backdrop-blur-sm rounded-2xl p-3 shadow-sm">
      {/* 封面图 - 固定尺寸 */}
      <div className="relative w-20 h-28 flex-shrink-0 rounded-xl overflow-hidden shadow-md bg-primary-100">
        {imageUrl ? (
          <Image
            src={imageUrl}
            alt={name}
            fill
            className="object-cover"
            unoptimized
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center">
            <span className="material-symbols text-primary-300" style={{ fontSize: '28px' }}>
              image
            </span>
          </div>
        )}
      </div>
      
      {/* 信息区域 - min-w-0 防止溢出 */}
      <div className="flex-1 min-w-0 flex flex-col justify-center">
        <h1 className="text-base font-bold text-primary-900 line-clamp-2 leading-tight">
          {name}
        </h1>
        {showOriginalName && (
          <p className="text-xs text-primary-500 truncate mt-0.5">
            {nameOriginal}
          </p>
        )}
        
        {/* 评分 - 单行不换行 */}
        {ratingScore != null && ratingScore > 0 && (
          <div className="flex items-center gap-1.5 mt-1.5">
            <span className="material-symbols text-yellow-500 flex-shrink-0" style={{ fontSize: '16px' }}>
              star
            </span>
            <span className="text-base font-bold text-primary-900">
              {ratingScore.toFixed(1)}
            </span>
            <span className="text-xs text-primary-400 truncate">
              ({ratingTotal}人)
            </span>
          </div>
        )}
        
        {/* 放送信息 - 横向滚动 */}
        <div className="flex items-center gap-1.5 mt-1.5 overflow-x-auto scrollbar-hide">
          {date && (
            <span className="flex-shrink-0 px-2 py-0.5 bg-primary-100 text-primary-600 text-xs rounded-full">
              {date}
            </span>
          )}
          {eps > 0 && (
            <span className="flex-shrink-0 px-2 py-0.5 bg-primary-100 text-primary-600 text-xs rounded-full">
              共{eps}话
            </span>
          )}
        </div>
      </div>
    </div>
  )
}

/**
 * OverviewTab - 概览 Tab
 */
interface OverviewTabProps {
  summary: string
  tags: Array<{ name?: string; count?: number }>
  episodes: Episode[]
  fullIntro: boolean
  setFullIntro: (v: boolean) => void
  fullTag: boolean
  setFullTag: (v: boolean) => void
  onEpisodeClick: (episode: Episode) => void
}

function OverviewTab({ summary, tags, episodes, fullIntro, setFullIntro, fullTag, setFullTag, onEpisodeClick }: OverviewTabProps) {
  const validTags = tags.filter(t => t?.name)
  const displayTags = fullTag || validTags.length < 13 ? validTags : validTags.slice(0, 12)
  
  // 使用 ref 检测文本是否被截断 - 照抄原项目的 numLines > 7 逻辑
  const summaryRef = useRef<HTMLDivElement>(null)
  const [needsExpand, setNeedsExpand] = useState(false)
  
  useEffect(() => {
    // 检测文本是否超出容器高度
    if (summaryRef.current) {
      const element = summaryRef.current
      // 如果 scrollHeight > clientHeight，说明文本被截断了
      setNeedsExpand(element.scrollHeight > element.clientHeight + 5)
    }
  }, [summary])

  return (
    <div className="space-y-6">
      {/* 简介 - 照抄原项目使用固定高度控制展开 */}
      <section>
        <h2 className="text-base font-bold text-primary-900 mb-2">简介</h2>
        <div 
          ref={summaryRef}
          className="text-primary-600 text-sm leading-relaxed whitespace-pre-line overflow-hidden transition-all duration-300"
          style={{ maxHeight: fullIntro ? 'none' : '120px' }}
        >
          {summary || '暂无简介'}
        </div>
        {(needsExpand || fullIntro) && summary && (
          <button
            onClick={() => setFullIntro(!fullIntro)}
            className="text-primary-500 text-sm mt-2 hover:text-primary-600 active:text-primary-700 font-medium whitespace-nowrap"
          >
            {fullIntro ? '收起' : '展开更多'}
          </button>
        )}
      </section>

      {/* 标签 - flex-wrap 允许换行 */}
      {validTags.length > 0 && (
        <section>
          <h2 className="text-base font-bold text-primary-900 mb-2">标签</h2>
          <div className="flex flex-wrap gap-2">
            {displayTags.map((tag, index) => (
              <span
                key={`${tag.name}-${index}`}
                className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-primary-100 text-primary-700 text-xs rounded-full"
              >
                <span>{tag.name}</span>
                {tag.count != null && (
                  <span className="px-1.5 py-0.5 bg-primary-200/80 text-primary-500 text-[10px] rounded-full font-medium">
                    {tag.count}
                  </span>
                )}
              </span>
            ))}
            {!fullTag && validTags.length >= 13 && (
              <button
                onClick={() => setFullTag(true)}
                className="px-2.5 py-1 bg-primary-500 text-white text-xs rounded-full hover:bg-primary-600 active:bg-primary-700 transition-colors"
              >
                更多 +
              </button>
            )}
          </div>
        </section>
      )}

      {/* 剧集列表 - 网格布局，iPhone 优先 */}
      {episodes.length > 0 && (
        <section>
          <h2 className="text-base font-bold text-primary-900 mb-2">剧集</h2>
          <div className="grid grid-cols-5 sm:grid-cols-6 md:grid-cols-8 lg:grid-cols-10 gap-2">
            {episodes.map((episode, index) => {
              const epNum = episode?.sort || episode?.ep || index + 1
              return (
                <button
                  key={episode?.id || index}
                  onClick={() => onEpisodeClick(episode)}
                  className="aspect-square flex items-center justify-center bg-primary-100 hover:bg-primary-200 active:bg-primary-300 text-primary-700 rounded-lg text-sm font-medium transition-colors"
                >
                  {epNum}
                </button>
              )
            })}
          </div>
        </section>
      )}
    </div>
  )
}

/**
 * CommentsTab - 吐槽 Tab
 */
interface CommentsTabProps {
  comments: CommentItem[]
  loading: boolean
  onRetry: () => void
}

function CommentsTab({ comments, loading, onRetry }: CommentsTabProps) {
  if (loading) {
    return (
      <div className="space-y-4">
        {[1, 2, 3, 4].map((i) => (
          <div key={i} className="animate-pulse">
            <div className="flex gap-3">
              <div className="w-10 h-10 bg-primary-200 rounded-full flex-shrink-0" />
              <div className="flex-1 min-w-0 space-y-2">
                <div className="h-4 bg-primary-200 rounded w-24" />
                <div className="h-3 bg-primary-200 rounded w-full" />
                <div className="h-3 bg-primary-200 rounded w-3/4" />
              </div>
            </div>
          </div>
        ))}
      </div>
    )
  }

  if (!Array.isArray(comments) || comments.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12 gap-4">
        <span className="material-symbols text-primary-300" style={{ fontSize: '48px' }}>
          chat_bubble_outline
        </span>
        <p className="text-primary-500">暂无吐槽</p>
        <Button onClick={onRetry} variant="ghost">重试</Button>
      </div>
    )
  }

  // 格式化日期
  const formatDate = (updatedAt: number | string | undefined): string => {
    if (!updatedAt) return ''
    try {
      if (typeof updatedAt === 'number') {
        return new Date(updatedAt * 1000).toLocaleDateString('zh-CN')
      }
      return new Date(updatedAt).toLocaleDateString('zh-CN')
    } catch {
      return ''
    }
  }

  return (
    <div className="space-y-4">
      {comments.map((comment, index) => {
        const user = comment?.user
        const avatarUrl = safeImageUrl(user?.avatar)
        const nickname = safeStr(user?.nickname || user?.username, '匿名用户')
        const commentText = safeStr(comment?.comment)
        const rate = safeNum(comment?.rate)
        const dateStr = formatDate(comment?.updatedAt)

        return (
          <div key={comment?.id ?? index} className="flex gap-3 pb-4 border-b border-primary-100">
            {/* 头像 - 固定尺寸 */}
            <div className="relative w-10 h-10 flex-shrink-0 rounded-full overflow-hidden bg-primary-100">
              {avatarUrl ? (
                <Image
                  src={avatarUrl}
                  alt={nickname}
                  fill
                  className="object-cover"
                  unoptimized
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center">
                  <span className="material-symbols text-primary-300" style={{ fontSize: '20px' }}>
                    person
                  </span>
                </div>
              )}
            </div>
            
            {/* 内容 - min-w-0 防止溢出 */}
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <span className="font-medium text-primary-900 text-sm truncate max-w-[120px]">
                  {nickname}
                </span>
                {rate > 0 && (
                  <span className="flex items-center text-yellow-500 text-xs flex-shrink-0">
                    <span className="material-symbols" style={{ fontSize: '14px' }}>star</span>
                    {rate}
                  </span>
                )}
              </div>
              {commentText && (
                <p className="text-primary-600 text-sm mt-1 break-words">{commentText}</p>
              )}
              {dateStr && (
                <p className="text-primary-400 text-xs mt-1">{dateStr}</p>
              )}
            </div>
          </div>
        )
      })}
    </div>
  )
}

/**
 * CharactersTab - 角色 Tab
 */
interface CharactersTabProps {
  characters: Character[]
  loading: boolean
  onRetry: () => void
}

function CharactersTab({ characters, loading, onRetry }: CharactersTabProps) {
  if (loading) {
    return (
      <div className="space-y-3">
        {[1, 2, 3, 4].map((i) => (
          <div key={i} className="animate-pulse flex gap-3 p-3 bg-white/50 rounded-xl">
            <div className="w-12 h-12 bg-primary-200 rounded-full flex-shrink-0" />
            <div className="flex-1 min-w-0 space-y-2">
              <div className="h-4 bg-primary-200 rounded w-24" />
              <div className="h-3 bg-primary-200 rounded w-16" />
            </div>
          </div>
        ))}
      </div>
    )
  }

  if (!Array.isArray(characters) || characters.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12 gap-4">
        <span className="material-symbols text-primary-300" style={{ fontSize: '48px' }}>
          group
        </span>
        <p className="text-primary-500">暂无角色信息</p>
        <Button onClick={onRetry} variant="ghost">重试</Button>
      </div>
    )
  }

  return (
    <div className="space-y-3">
      {characters.map((character, index) => {
        const charName = safeStr(character?.name, '未知角色')
        // 角色列表使用 grid 尺寸 (小头像) - 照抄原项目 character_card.dart
        const charImageUrl = safeImageUrl(character?.images, 'grid')
        const relation = safeStr(character?.relation)
        const actors = Array.isArray(character?.actors) ? character.actors : []
        const firstActor = actors[0]
        const characterId = character?.id

        return (
          <a 
            key={character?.id || index} 
            href={characterId ? `/character/${characterId}` : undefined}
            className="flex gap-3 p-3 bg-white/50 rounded-xl items-center hover:bg-white/80 active:bg-white transition-colors cursor-pointer"
          >
            {/* 角色头像 - 照抄原项目使用 CircleAvatar */}
            <div className="relative w-11 h-11 flex-shrink-0 rounded-full overflow-hidden bg-primary-100">
              {charImageUrl ? (
                <Image
                  src={charImageUrl}
                  alt={charName}
                  fill
                  className="object-cover"
                  unoptimized
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center">
                  <span className="material-symbols text-primary-300" style={{ fontSize: '22px' }}>
                    person
                  </span>
                </div>
              )}
            </div>
            
            {/* 角色信息 */}
            <div className="flex-1 min-w-0">
              <p className="font-medium text-primary-900 text-sm truncate">{charName}</p>
              {relation && <p className="text-primary-500 text-xs truncate">{relation}</p>}
            </div>
            
            {/* 声优信息 - 固定在右侧，使用 grid 尺寸头像 */}
            {firstActor && (
              <div className="flex items-center gap-2 flex-shrink-0">
                <div className="relative w-7 h-7 rounded-full overflow-hidden bg-primary-100">
                  {safeImageUrl(firstActor?.images, 'grid') ? (
                    <Image
                      src={safeImageUrl(firstActor.images, 'grid')!}
                      alt={safeStr(firstActor?.name)}
                      fill
                      className="object-cover"
                      unoptimized
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center">
                      <span className="material-symbols text-primary-300" style={{ fontSize: '14px' }}>
                        mic
                      </span>
                    </div>
                  )}
                </div>
                <span className="text-xs text-primary-500 max-w-[60px] truncate">
                  {safeStr(firstActor?.name)}
                </span>
              </div>
            )}
            
            {/* 箭头指示 */}
            <span className="material-symbols text-primary-300 flex-shrink-0" style={{ fontSize: '18px' }}>
              chevron_right
            </span>
          </a>
        )
      })}
    </div>
  )
}

/**
 * ReviewsTab - 评论 Tab (施工中)
 */
function ReviewsTab() {
  return (
    <div className="flex flex-col items-center justify-center py-12 gap-4">
      <span className="material-symbols text-primary-300" style={{ fontSize: '48px' }}>
        construction
      </span>
      <p className="text-primary-500">施工中</p>
    </div>
  )
}

/**
 * StaffTab - 制作人员 Tab
 */
interface StaffTabProps {
  staff: StaffItem[]
  loading: boolean
  onRetry: () => void
}

function StaffTab({ staff, loading, onRetry }: StaffTabProps) {
  if (loading) {
    return (
      <div className="space-y-3">
        {[1, 2, 3, 4, 5, 6].map((i) => (
          <div key={i} className="animate-pulse flex gap-3 p-3 bg-white/50 rounded-xl">
            <div className="w-10 h-10 bg-primary-200 rounded-full flex-shrink-0" />
            <div className="flex-1 min-w-0 space-y-2">
              <div className="h-4 bg-primary-200 rounded w-24" />
              <div className="h-3 bg-primary-200 rounded w-16" />
            </div>
          </div>
        ))}
      </div>
    )
  }

  if (!Array.isArray(staff) || staff.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12 gap-4">
        <span className="material-symbols text-primary-300" style={{ fontSize: '48px' }}>
          groups
        </span>
        <p className="text-primary-500">暂无制作人员信息</p>
        <Button onClick={onRetry} variant="ghost">重试</Button>
      </div>
    )
  }

  return (
    <div className="space-y-3">
      {staff.map((person, index) => {
        const personName = safeStr(person?.name_cn || person?.name, '未知')
        const personImageUrl = safeImageUrl(person?.images)
        const relation = safeStr(person?.relation)

        return (
          <div key={person?.id || index} className="flex gap-3 p-3 bg-white/50 rounded-xl items-center">
            {/* 头像 */}
            <div className="relative w-10 h-10 flex-shrink-0 rounded-full overflow-hidden bg-primary-100">
              {personImageUrl ? (
                <Image
                  src={personImageUrl}
                  alt={personName}
                  fill
                  className="object-cover"
                  unoptimized
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center">
                  <span className="material-symbols text-primary-300" style={{ fontSize: '20px' }}>
                    person
                  </span>
                </div>
              )}
            </div>
            
            {/* 信息 */}
            <div className="flex-1 min-w-0">
              <p className="font-medium text-primary-900 text-sm truncate">{personName}</p>
              {relation && <p className="text-primary-500 text-xs truncate">{relation}</p>}
            </div>
          </div>
        )
      })}
    </div>
  )
}
