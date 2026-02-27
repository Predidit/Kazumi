'use client'

import { useEffect, useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { AnimeCard } from '@/components/anime/AnimeCard'
import { GlassPanel, LoadingSpinner } from '@/components/ui'
import { BottomSheet } from '@/components/ui/BottomSheet'
import { cachedFetch, CACHE_TTL } from '@/lib/utils/cache'
import type { AnimeDetail } from '@/types/anime'

interface CalendarData {
  [weekday: string]: AnimeDetail[]
}

const WEEKDAYS = ['一', '二', '三', '四', '五', '六', '日']
const SEASONS = ['冬', '春', '夏', '秋']

/**
 * Calendar Page - 照抄 Kazumi 的 timeline_page.dart 布局
 * 
 * 原项目特点:
 * - TabBar 显示周一到周日
 * - 标题显示当前季度 (如 "2025年冬")，点击可打开"时间机器"选择器
 * - 浮动按钮打开排序/过滤设置
 * - 支持按热度/评分/时间排序
 * - 支持过滤已看过/已抛弃的番剧
 */
export default function CalendarPage() {
  const router = useRouter()
  const [calendarData, setCalendarData] = useState<CalendarData>({})
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedDay, setSelectedDay] = useState<number>(new Date().getDay() || 7)
  const [showSettings, setShowSettings] = useState(false)
  const [showSeasonPicker, setShowSeasonPicker] = useState(false)
  const [sortType, setSortType] = useState<'heat' | 'rank' | 'time'>('time')
  
  // 当前选择的季度 - 照抄原项目 timelineController.selectedDate
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear())
  const [selectedSeason, setSelectedSeason] = useState(getCurrentSeason())
  
  // 防止重复请求
  const fetchingRef = useRef(false)

  useEffect(() => {
    fetchCalendar()
  }, [selectedYear, selectedSeason])

  // 获取当前季节
  function getCurrentSeason(): string {
    const month = new Date().getMonth() + 1
    if (month >= 1 && month <= 3) return '冬'
    if (month >= 4 && month <= 6) return '春'
    if (month >= 7 && month <= 9) return '夏'
    return '秋'
  }

  // 判断是否是当前季度
  function isCurrentSeason(): boolean {
    const now = new Date()
    return selectedYear === now.getFullYear() && selectedSeason === getCurrentSeason()
  }

  async function fetchCalendar() {
    // 防止重复请求
    if (fetchingRef.current) return
    fetchingRef.current = true
    
    try {
      setLoading(true)
      setError(null)

      // 如果是当前季度，使用 calendar API；否则使用 search API 按季度搜索
      if (isCurrentSeason()) {
        // 使用缓存的 fetch，TTL 5分钟
        const data = await cachedFetch<CalendarData>(
          '/api/bangumi/calendar',
          undefined,
          { ttl: CACHE_TTL.MEDIUM, key: 'calendar-current' }
        )
        setCalendarData(data)
      } else {
        // 按季度搜索 - 照抄原项目 getSchedulesBySeason
        const seasonMonth = SEASONS.indexOf(selectedSeason) * 3 + 1
        const startDate = `${selectedYear}-${String(seasonMonth).padStart(2, '0')}-01`
        const endMonth = seasonMonth + 2
        const endDate = `${selectedYear}-${String(endMonth).padStart(2, '0')}-28`
        
        const url = `/api/bangumi/search?keyword=&filter[type]=2&filter[air_date]=>=${startDate}&filter[air_date]=<=${endDate}&limit=50`
        const data = await cachedFetch<{ data: AnimeDetail[] }>(
          url,
          undefined,
          { ttl: CACHE_TTL.LONG, key: `calendar-${selectedYear}-${selectedSeason}` }
        )
        
        // 将搜索结果按星期分组
        const grouped: CalendarData = { 1: [], 2: [], 3: [], 4: [], 5: [], 6: [], 7: [] }
        for (const anime of (data.data || [])) {
          // 根据 air_date 计算星期几
          if (anime.date) {
            const date = new Date(anime.date)
            const weekday = date.getDay() || 7
            if (!grouped[weekday]) grouped[weekday] = []
            grouped[weekday].push({
              ...anime,
              nameCn: (anime as any).nameCN || (anime as any).name_cn || anime.nameCn || '',
            })
          }
        }
        setCalendarData(grouped)
      }
    } catch (err) {
      console.error('Failed to fetch calendar:', err)
      setError(err instanceof Error ? err.message : '加载失败，请稍后重试')
    } finally {
      setLoading(false)
      fetchingRef.current = false
    }
  }

  function handleAnimeClick(anime: AnimeDetail) {
    router.push(`/anime/${anime.id}`)
  }

  // 获取季度字符串 - 照抄原项目
  function getSeasonString(): string {
    return `${selectedYear}年${selectedSeason}`
  }

  // 生成可选年份列表 (最近20年)
  function getAvailableYears(): number[] {
    const currentYear = new Date().getFullYear()
    return Array.from({ length: 20 }, (_, i) => currentYear - i)
  }

  // 获取某年可用的季节 - 照抄原项目逻辑
  function getAvailableSeasons(year: number): string[] {
    const now = new Date()
    const currentYear = now.getFullYear()
    const currentMonth = now.getMonth() + 1
    
    if (year < currentYear) {
      return SEASONS
    } else if (year === currentYear) {
      // 当前年份只显示已经开始的季节
      const available: string[] = []
      if (currentMonth >= 1) available.push('冬')
      if (currentMonth >= 4) available.push('春')
      if (currentMonth >= 7) available.push('夏')
      if (currentMonth >= 10) available.push('秋')
      return available
    }
    return []
  }

  // 获取季节图标 - 照抄原项目 getSeasonIcon
  function getSeasonIcon(season: string): string {
    switch (season) {
      case '春': return 'eco'
      case '夏': return 'wb_sunny'
      case '秋': return 'park'
      case '冬': return 'ac_unit'
      default: return 'schedule'
    }
  }

  // 排序数据
  function getSortedData(data: AnimeDetail[]): AnimeDetail[] {
    const sorted = [...data]
    switch (sortType) {
      case 'heat':
        return sorted.sort((a, b) => (b.rating?.total || 0) - (a.rating?.total || 0))
      case 'rank':
        return sorted.sort((a, b) => (b.rating?.score || 0) - (a.rating?.score || 0))
      case 'time':
      default:
        return sorted
    }
  }

  // Get anime for selected day
  const selectedDayData = getSortedData(calendarData[selectedDay] || [])

  return (
    <div className="min-h-screen safe-area-all">
      <main className="container mx-auto px-4 py-8 pb-24">
        {/* Header - 照抄原项目的 SysAppBar */}
        <div className="mb-2">
          {/* 标题可点击打开时间机器 - 照抄原项目 */}
          <button 
            onClick={() => setShowSeasonPicker(true)}
            className="flex items-center gap-1 group"
          >
            <span className="text-2xl font-bold text-primary-900 group-hover:text-primary-700 transition-colors">
              {getSeasonString()}
            </span>
            <span className="material-symbols text-primary-600" style={{ fontSize: '24px' }}>
              keyboard_arrow_down
            </span>
          </button>
        </div>

        {/* TabBar - 照抄原项目，7天平均分布不滚动 */}
        <div className="mb-6">
          <div className="flex border-b border-primary-200">
            {WEEKDAYS.map((day, index) => {
              const dayNumber = index + 1
              const isSelected = selectedDay === dayNumber
              
              return (
                <button
                  key={dayNumber}
                  onClick={() => setSelectedDay(dayNumber)}
                  className={`
                    flex-1 py-3 text-sm font-medium transition-all relative text-center
                    ${isSelected 
                      ? 'text-primary-600' 
                      : 'text-primary-400 hover:text-primary-500'
                    }
                  `}
                >
                  {day}
                  {isSelected && (
                    <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-primary-500" />
                  )}
                </button>
              )
            })}
          </div>
        </div>

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
              <span className="material-symbols text-red-500" style={{ fontSize: '48px' }}>
                error
              </span>
              <p className="text-red-600">{error}</p>
              <button
                onClick={fetchCalendar}
                className="px-6 py-2 bg-primary-500 text-white rounded-full hover:bg-primary-600 transition-colors"
              >
                重试
              </button>
            </div>
          </GlassPanel>
        )}

        {/* Anime Grid */}
        {!loading && !error && selectedDayData.length > 0 && (
          <div className="grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {selectedDayData.map((anime) => (
              <AnimeCard
                key={anime.id}
                anime={anime}
                onClick={() => handleAnimeClick(anime)}
              />
            ))}
          </div>
        )}

        {/* Empty State - 照抄原项目 */}
        {!loading && !error && selectedDayData.length === 0 && (
          <GlassPanel className="p-12">
            <div className="flex flex-col items-center justify-center gap-4">
              <span className="material-symbols text-primary-300" style={{ fontSize: '64px' }}>
                event_busy
              </span>
              <p className="text-primary-600">什么都没有找到 (´;ω;`)</p>
            </div>
          </GlassPanel>
        )}

        {/* 浮动设置按钮 - 照抄原项目 */}
        <button
          onClick={() => setShowSettings(true)}
          className="fixed bottom-24 right-6 w-14 h-14 bg-primary-500 hover:bg-primary-600 text-white rounded-full shadow-lg flex items-center justify-center transition-all hover:scale-110"
          aria-label="排序设置"
        >
          <span className="material-symbols" style={{ fontSize: '24px' }}>
            tune
          </span>
        </button>

        {/* 设置弹窗 - 使用 BottomSheet 组件 */}
        <BottomSheet
          isOpen={showSettings}
          onClose={() => setShowSettings(false)}
          title="排序方式"
        >
          <div className="p-4 space-y-2">
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
              onClick={() => { setSortType('time'); setShowSettings(false); }}
              className={`w-full p-4 text-left rounded-xl transition-colors ${
                sortType === 'time' ? 'bg-primary-100 text-primary-700' : 'hover:bg-primary-50'
              }`}
            >
              按时间排序
            </button>
          </div>
        </BottomSheet>

        {/* 时间机器弹窗 - 使用 BottomSheet 组件 */}
        <BottomSheet
          isOpen={showSeasonPicker}
          onClose={() => setShowSeasonPicker(false)}
          title="时间机器"
        >
          <div className="p-4">
            {getAvailableYears().map((year) => {
              const availableSeasons = getAvailableSeasons(year)
              if (availableSeasons.length === 0) return null
              
              return (
                <div key={year} className="mb-6">
                  {/* 年份标题 */}
                  <div className="flex items-center gap-2 mb-3">
                    <div className="w-1 h-5 bg-primary-500 rounded-full" />
                    <span className="text-base font-semibold text-primary-900">{year}年</span>
                  </div>
                  
                  {/* 季节按钮 */}
                  <div className="grid grid-cols-4 gap-2">
                    {availableSeasons.map((season) => {
                      const isSelected = selectedYear === year && selectedSeason === season
                      return (
                        <button
                          key={season}
                          onClick={() => {
                            setSelectedYear(year)
                            setSelectedSeason(season)
                            setShowSeasonPicker(false)
                          }}
                          className={`flex items-center justify-center gap-1.5 py-3 px-2 rounded-xl transition-all ${
                            isSelected
                              ? 'bg-primary-500 text-white'
                              : 'bg-primary-50 text-primary-700 hover:bg-primary-100'
                          }`}
                        >
                          <span className="material-symbols" style={{ fontSize: '18px' }}>
                            {getSeasonIcon(season)}
                          </span>
                          <span className="text-sm font-medium">{season}</span>
                        </button>
                      )
                    })}
                  </div>
                </div>
              )
            })}
          </div>
        </BottomSheet>
      </main>
    </div>
  )
}
