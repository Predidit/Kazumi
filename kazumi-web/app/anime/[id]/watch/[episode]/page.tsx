'use client'

import { useEffect, useState, useRef, useCallback } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { VideoPlayer } from '@/components/player/VideoPlayer'
import { SourceSelector } from '@/components/player/SourceSelector'
import { GlassPanel } from '@/components/ui/GlassPanel'
import { historyManager } from '@/lib/storage/history'
import type { SearchResult, Road, Plugin } from '@/types/plugin'

/**
 * Video Player Page - 照抄 Kazumi 的 video_page.dart 布局
 * 
 * 核心流程 (照抄原项目):
 * 1. 用户选择视频源 (SearchResult)
 * 2. 调用 queryRoads 获取播放列表 (Road[])
 * 3. 每个 Road 包含 data (URL列表) 和 identifier (集数名称列表)
 * 4. 用户选择集数后，调用 changeEpisode 切换
 * 5. changeEpisode 调用 webview.loadUrl 解析视频URL
 * 6. 解析成功后调用 playerController.init(videoUrl) 播放
 * 
 * 关键优化 (照抄原项目 video_controller.dart):
 * - currentPlugin 缓存在 controller 中，不需要每次都获取
 * - roadList 在选择视频源时获取，之后切换集数只需要使用缓存的数据
 */
export default function WatchPage() {
  const params = useParams()
  const router = useRouter()
  const animeId = parseInt(params.id as string)
  const episodeNumber = parseInt(params.episode as string)

  // 番剧信息
  const [animeTitle, setAnimeTitle] = useState('')
  const [animeCover, setAnimeCover] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // 视频源状态 - 照抄原项目 VideoPageController
  const [selectedSource, setSelectedSource] = useState<SearchResult | null>(null)
  const [roads, setRoads] = useState<Road[]>([])
  const [currentRoad, setCurrentRoad] = useState(0)
  const [currentEpisode, setCurrentEpisode] = useState(episodeNumber)
  const [videoUrl, setVideoUrl] = useState<string | null>(null)
  const [videoLoading, setVideoLoading] = useState(false)
  const [videoError, setVideoError] = useState<string | null>(null)
  
  // 照抄原项目: 缓存当前插件配置 - video_controller.dart 的 currentPlugin
  const [currentPlugin, setCurrentPlugin] = useState<Plugin | null>(null)

  // UI 状态
  const [showSourceSelector, setShowSourceSelector] = useState(false)
  const [showEpisodeList, setShowEpisodeList] = useState(false)
  const [showControls, setShowControls] = useState(true)
  const hideControlsTimerRef = useRef<NodeJS.Timeout | null>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  
  // 防止自动加载无限循环 - 追踪是否已尝试过自动加载
  const autoLoadAttemptedRef = useRef(false)

  // 自动隐藏控制栏 - 照抄原项目 startHideTimer (4秒)
  const resetHideTimer = useCallback(() => {
    if (hideControlsTimerRef.current) {
      clearTimeout(hideControlsTimerRef.current)
    }
    setShowControls(true)
    hideControlsTimerRef.current = setTimeout(() => {
      if (videoUrl && !showSourceSelector && !showEpisodeList) {
        setShowControls(false)
      }
    }, 4000)
  }, [videoUrl, showSourceSelector, showEpisodeList])

  useEffect(() => {
    resetHideTimer()
    return () => {
      if (hideControlsTimerRef.current) {
        clearTimeout(hideControlsTimerRef.current)
      }
    }
  }, [resetHideTimer])

  // 加载番剧信息
  useEffect(() => {
    if (animeId && episodeNumber) {
      fetchAnimeInfo()
    }
  }, [animeId, episodeNumber])

  // 番剧信息加载完成后自动使用 aowu 插件加载视频
  // 只在首次加载时尝试，避免无限循环
  useEffect(() => {
    if (animeTitle && !selectedSource && !autoLoadAttemptedRef.current) {
      autoLoadAttemptedRef.current = true
      autoLoadWithDefaultPlugin()
    }
  }, [animeTitle, selectedSource])

  /**
   * 自动使用默认插件（aowu）加载视频
   */
  async function autoLoadWithDefaultPlugin() {
    const DEFAULT_PLUGIN = 'aowu' // 默认使用 aowu 插件
    
    try {
      setVideoLoading(true)
      setVideoError(null)
      
      console.log(`自动使用 ${DEFAULT_PLUGIN} 插件搜索: ${animeTitle}`)
      
      // 搜索视频源
      const searchResponse = await fetch(
        `/api/plugins/search?keyword=${encodeURIComponent(animeTitle)}&plugin=${encodeURIComponent(DEFAULT_PLUGIN)}`
      )
      
      if (!searchResponse.ok) {
        throw new Error('搜索失败')
      }
      
      const searchData = await searchResponse.json()
      const results: SearchResult[] = searchData.results || []
      
      if (results.length === 0) {
        console.log('默认插件未找到结果，打开视频源选择器')
        setVideoLoading(false)
        setShowSourceSelector(true)
        return
      }
      
      // 使用第一个搜索结果
      const firstResult = results[0]
      console.log(`找到视频源: ${firstResult.name}`)
      
      // 自动选择这个视频源
      await selectSource(firstResult)
    } catch (err) {
      console.error('自动加载失败:', err)
      setVideoLoading(false)
      // 自动加载失败时打开视频源选择器
      setShowSourceSelector(true)
    }
  }

  async function fetchAnimeInfo() {
    try {
      setLoading(true)
      setError(null)

      const animeResponse = await fetch(`/api/bangumi/subject/${animeId}`)
      if (animeResponse.ok) {
        const animeData = await animeResponse.json()
        // 优先使用中文名 nameCn，如果没有则使用日文名 name
        const title = animeData.nameCn || animeData.name_cn || animeData.name || ''
        setAnimeTitle(title)
        setAnimeCover(animeData.images?.common || '')
      }
    } catch (err) {
      console.error('Failed to fetch anime info:', err)
      setError(err instanceof Error ? err.message : '加载番剧信息失败')
    } finally {
      setLoading(false)
    }
  }

  /**
   * 选择视频源 - 照抄原项目 queryRoads
   * 获取播放列表后自动播放
   * 
   * 照抄原项目 video_page.dart initState:
   * - currentEpisode 初始化为 1
   * - 如果有历史记录，恢复到历史记录的集数
   * - 集数必须在 road.data.length 范围内
   * 
   * 照抄原项目 video_controller.dart:
   * - currentPlugin 在选择视频源时缓存，之后切换集数直接使用
   */
  async function selectSource(source: SearchResult) {
    try {
      setSelectedSource(source)
      setVideoLoading(true)
      setVideoError(null)
      setVideoUrl(null)
      setShowSourceSelector(false)

      // 照抄原项目: 获取并缓存插件配置 - video_controller.dart 的 currentPlugin
      const pluginsResponse = await fetch('/plugins/index.json')
      const pluginsData = await pluginsResponse.json()
      const plugin = pluginsData.find((p: Plugin) => p.name === source.pluginName)
      
      if (!plugin) {
        throw new Error(`插件 ${source.pluginName} 不存在`)
      }
      
      // 缓存插件配置
      setCurrentPlugin(plugin)

      // 照抄原项目: Plugin.querychapterRoads
      const roadsResponse = await fetch(
        `/api/plugins/roads?url=${encodeURIComponent(source.src)}&plugin=${encodeURIComponent(source.pluginName)}`
      )
      if (!roadsResponse.ok) throw new Error('获取播放列表失败')

      const roadsData = await roadsResponse.json()
      const roadList: Road[] = roadsData.roads || []
      
      if (roadList.length === 0) {
        throw new Error('未找到播放列表')
      }

      setRoads(roadList)
      setCurrentRoad(0)

      // 照抄原项目: 确定要播放的集数
      // 1. 检查 URL 中的集数是否在视频源范围内
      // 2. 如果超出范围，默认播放第 1 集
      const maxEpisode = roadList[0].data.length
      let targetEpisode = currentEpisode
      
      if (targetEpisode > maxEpisode) {
        console.log(`集数 ${targetEpisode} 超出视频源范围 (最大 ${maxEpisode})，默认播放第 1 集`)
        targetEpisode = 1
      } else if (targetEpisode < 1) {
        targetEpisode = 1
      }

      // 自动播放目标集数 - 传入缓存的插件配置
      await changeEpisode(targetEpisode, 0, roadList, plugin)
    } catch (err) {
      console.error('Failed to select source:', err)
      setVideoLoading(false)
      setVideoError(err instanceof Error ? err.message : '选择视频源失败')
      setShowSourceSelector(true)
    }
  }

  /**
   * 切换集数 - 照抄原项目 VideoPageController.changeEpisode
   * 
   * 照抄原项目: changeEpisode 使用缓存的 currentPlugin，不需要每次都获取
   * 参数 plugin 可以是传入的新插件配置（选择视频源时），或使用缓存的 currentPlugin
   */
  async function changeEpisode(
    episode: number, 
    roadIndex: number = currentRoad, 
    roadList: Road[] = roads,
    plugin: Plugin | null = currentPlugin
  ) {
    // 照抄原项目: 使用缓存的插件配置
    if (!plugin) {
      setVideoError('请先选择视频源')
      setShowSourceSelector(true)
      return
    }

    if (roadList.length === 0) {
      setVideoError('播放列表为空')
      setShowSourceSelector(true)
      return
    }

    const road = roadList[roadIndex]
    if (!road) {
      setVideoError('播放列表不存在')
      return
    }

    // 照抄原项目: 确保集数在有效范围内
    let targetEpisode = episode
    if (targetEpisode < 1) {
      targetEpisode = 1
    } else if (targetEpisode > road.data.length) {
      // 如果集数超出范围，自动调整到最后一集
      console.log(`集数 ${episode} 超出范围，调整到第 ${road.data.length} 集`)
      targetEpisode = road.data.length
    }

    const episodeIndex = targetEpisode - 1

    try {
      setVideoLoading(true)
      setVideoError(null)
      setCurrentEpisode(targetEpisode)
      setCurrentRoad(roadIndex)

      // 照抄原项目: 构建播放URL - video_controller.dart changeEpisode
      let playUrl = road.data[episodeIndex]
      
      // 照抄原项目: 检查 urlItem 是否已经包含 baseUrl
      // if (urlItem.contains(currentPlugin.baseUrl) || urlItem.contains(currentPlugin.baseUrl.replaceAll('https', 'http'))) {
      //   urlItem = urlItem;
      // } else {
      //   urlItem = currentPlugin.baseUrl + urlItem;
      // }
      const baseUrlHttps = plugin.baseURL
      const baseUrlHttp = plugin.baseURL.replace('https', 'http')
      
      if (!playUrl.includes(baseUrlHttps) && !playUrl.includes(baseUrlHttp)) {
        // 只有当 playUrl 不包含 baseUrl 时才拼接
        if (!playUrl.startsWith('http')) {
          playUrl = plugin.baseURL + playUrl
        }
      }

      console.log(`正在加载 ${road.identifier[episodeIndex]}: ${playUrl}`)

      // 照抄原项目: WebviewItemController.loadUrl -> 解析视频URL
      const resolveResponse = await fetch(
        `/api/plugins/resolve?url=${encodeURIComponent(playUrl)}&plugin=${encodeURIComponent(plugin.name)}`
      )

      if (!resolveResponse.ok) {
        const errorData = await resolveResponse.json().catch(() => ({}))
        console.error('视频解析失败:', errorData)
        // 照抄原项目: 显示更友好的错误信息
        const errorMsg = errorData.error || '无法解析视频地址'
        // 如果有日志，在控制台输出以便调试
        if (errorData.logs && Array.isArray(errorData.logs)) {
          console.log('解析日志:', errorData.logs.join('\n'))
        }
        throw new Error(errorMsg)
      }

      const resolveData = await resolveResponse.json()
      let resolvedUrl = resolveData.videoUrl

      if (!resolvedUrl) {
        throw new Error('无法解析视频地址')
      }

      // 处理视频 URL - 某些 CDN 支持直接播放，某些需要代理
      if (resolvedUrl.startsWith('http') && !resolvedUrl.includes('localhost')) {
        const videoHostname = new URL(resolvedUrl).hostname.toLowerCase()
        
        // 某些 CDN 有严格的防盗链，代理可能无法绕过
        // 这些 CDN 通常也支持 CORS，可以尝试直接播放
        const directPlayCDNs = [
          'bytetos.com',      // 字节跳动 CDN - 有签名验证
          'bytecdn.cn',       // 字节跳动 CDN
          'douyincdn.com',    // 抖音 CDN
          'alicdn.com',       // 阿里云 CDN - 通常支持 CORS
          'aliyuncs.com',     // 阿里云 OSS
        ]
        
        const shouldDirectPlay = directPlayCDNs.some(cdn => videoHostname.includes(cdn))
        
        if (shouldDirectPlay) {
          // 尝试直接播放，不使用代理
          // 这些 CDN 的签名 URL 通常包含了所有必要的验证信息
          console.log('[Video] 尝试直接播放 (CDN 有签名验证):', videoHostname)
        } else {
          // 其他 CDN 使用代理绕过 CORS
          // 照抄原项目: 如果插件没有指定 referer，使用 baseURL 作为 referer
          const pluginReferer = plugin.referer || (plugin.baseURL ? plugin.baseURL + '/' : '')
          const proxyParams = new URLSearchParams({
            url: resolvedUrl,
          })
          if (pluginReferer) {
            proxyParams.set('referer', pluginReferer)
          }
          resolvedUrl = `/api/proxy/video?${proxyParams.toString()}`
          console.log('[Video] 使用代理播放')
        }
      }

      setVideoUrl(resolvedUrl)
      setVideoLoading(false)

      // 更新URL但不刷新页面
      window.history.replaceState(null, '', `/anime/${animeId}/watch/${targetEpisode}`)
    } catch (err) {
      console.error('Failed to change episode:', err)
      setVideoLoading(false)
      setVideoError(err instanceof Error ? err.message : '加载视频失败')
    }
  }

  const handleBack = useCallback(() => router.back(), [router])
  
  const handleRefresh = useCallback(() => {
    if (currentPlugin) {
      changeEpisode(currentEpisode, currentRoad, roads, currentPlugin)
    }
  }, [currentPlugin, currentEpisode, currentRoad, roads])

  const handlePlayNext = useCallback(() => {
    const road = roads[currentRoad]
    if (road && currentEpisode < road.data.length && currentPlugin) {
      changeEpisode(currentEpisode + 1, currentRoad, roads, currentPlugin)
    }
  }, [currentEpisode, currentRoad, roads, currentPlugin])

  const handleTimeUpdate = useCallback((time: number) => {
    if (time > 0 && animeTitle) {
      // 直接传入标题和封面，避免两次调用
      historyManager.saveProgress(animeId, currentEpisode, time, animeTitle, animeCover)
    }
  }, [animeId, currentEpisode, animeTitle, animeCover])

  const handleVideoError = useCallback((errorMsg: string) => {
    setVideoError(errorMsg)
  }, [])

  const handleContainerClick = useCallback(() => {
    resetHideTimer()
  }, [resetHideTimer])

  // 当前播放列表信息
  const currentRoadData = roads[currentRoad]
  const currentEpisodeName = currentRoadData?.identifier[currentEpisode - 1] || `第 ${currentEpisode} 集`
  const totalEpisodesInRoad = currentRoadData?.data.length || 0

  if (loading) {
    return (
      <div className="fixed inset-0 bg-black flex items-center justify-center z-50">
        <div className="flex flex-col items-center gap-4">
          <div className="w-10 h-10 border-3 border-white/20 border-t-white rounded-full animate-spin" />
          <p className="text-white text-sm">加载番剧信息...</p>
        </div>
      </div>
    )
  }

  if (error && !animeTitle) {
    return (
      <div className="fixed inset-0 bg-black flex items-center justify-center z-50">
        <GlassPanel className="p-8 max-w-md mx-4">
          <div className="flex flex-col items-center gap-4">
            <span className="material-symbols-rounded text-red-500 text-5xl">error</span>
            <p className="text-white text-center">{error}</p>
            <button onClick={handleBack} className="px-6 py-2 bg-primary-500 text-white rounded-full">
              返回
            </button>
          </div>
        </GlassPanel>
      </div>
    )
  }

  return (
    <div 
      ref={containerRef} 
      className="fixed inset-0 bg-black z-50"
      onClick={handleContainerClick}
      onMouseMove={resetHideTimer}
      onTouchStart={resetHideTimer}
    >
      {/* 顶部控制栏 - 照抄原项目 video_page.dart 的 EmbeddedNativeControlArea */}
      <div 
        className={`absolute top-0 left-0 right-0 z-[40] transition-opacity duration-300 ${
          showControls ? 'opacity-100' : 'opacity-0 pointer-events-none'
        }`}
      >
        <div className="absolute inset-0 bg-gradient-to-b from-black/70 via-black/30 to-transparent pointer-events-none" />
        
        <div className="relative flex items-center justify-between px-2 py-2 safe-area-top">
          <div className="flex items-center gap-1 flex-1 min-w-0">
            <button
              onClick={(e) => { e.stopPropagation(); handleBack(); }}
              className="flex-shrink-0 p-2 rounded-full hover:bg-white/10 active:bg-white/20 transition-colors"
              aria-label="返回"
            >
              <span className="material-symbols-rounded text-white text-2xl">arrow_back</span>
            </button>
            
            <div className="flex-1 min-w-0 px-2">
              <span className="text-white text-sm font-medium truncate block">
                {animeTitle} · {currentEpisodeName}
              </span>
            </div>
          </div>
          
          <div className="flex items-center gap-1 flex-shrink-0">
            <button
              onClick={(e) => { e.stopPropagation(); handleRefresh(); }}
              className="p-2 rounded-full hover:bg-white/10 active:bg-white/20 transition-colors disabled:opacity-50"
              aria-label="刷新"
              disabled={!selectedSource || videoLoading}
            >
              <span className={`material-symbols-rounded text-white text-2xl ${videoLoading ? 'animate-spin' : ''}`}>
                refresh
              </span>
            </button>
            
            {/* 播放列表按钮 - 照抄原项目 */}
            <button
              onClick={(e) => { e.stopPropagation(); setShowEpisodeList(true); }}
              className="p-2 rounded-full hover:bg-white/10 active:bg-white/20 transition-colors"
              aria-label="播放列表"
              disabled={roads.length === 0}
            >
              <span className="material-symbols-rounded text-white text-2xl">playlist_play</span>
            </button>

            {/* 视频源按钮 */}
            <button
              onClick={(e) => { e.stopPropagation(); setShowSourceSelector(true); }}
              className="p-2 rounded-full hover:bg-white/10 active:bg-white/20 transition-colors"
              aria-label="选择视频源"
            >
              <span className="material-symbols-rounded text-white text-2xl">video_library</span>
            </button>
          </div>
        </div>
      </div>

      {/* 视频播放器 */}
      {videoUrl ? (
        <VideoPlayer
          videoUrl={videoUrl}
          animeId={animeId}
          episodeNumber={currentEpisode}
          totalEpisodes={totalEpisodesInRoad}
          animeTitle={animeTitle}
          animeCover={animeCover}
          nextEpisodeTitle={currentRoadData?.identifier[currentEpisode] || undefined}
          onTimeUpdate={handleTimeUpdate}
          onEnded={() => {}}
          onPlayNext={handlePlayNext}
          onReady={() => {}}
          onError={handleVideoError}
          autoPlay={true}
          showNativeControls={false}
          showNextEpisodeSuggestion={true}
          enableDanmaku={true}
          showDanmakuSettings={true}
          className="w-full h-full"
        />
      ) : (
        <div className="w-full h-full flex items-center justify-center">
          {videoLoading ? (
            <div className="flex flex-col items-center gap-4">
              <div className="w-12 h-12 border-4 border-white/20 border-t-white rounded-full animate-spin" />
              <p className="text-white text-sm">视频资源解析中...</p>
            </div>
          ) : videoError ? (
            <div className="flex flex-col items-center gap-4 px-6">
              <span className="material-symbols-rounded text-red-400 text-5xl">error</span>
              <p className="text-white/80 text-sm text-center">{videoError}</p>
              <div className="flex gap-3">
                <button
                  onClick={(e) => { e.stopPropagation(); handleRefresh(); }}
                  className="px-6 py-2 bg-white/20 hover:bg-white/30 text-white rounded-full transition-colors"
                >
                  重试
                </button>
                <button
                  onClick={(e) => { e.stopPropagation(); setShowSourceSelector(true); }}
                  className="px-6 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-full transition-colors"
                >
                  换源
                </button>
              </div>
            </div>
          ) : (
            <div className="flex flex-col items-center gap-4">
              <span className="material-symbols-rounded text-white/40 text-6xl">play_circle</span>
              <p className="text-white/60 text-sm">请选择视频源</p>
              <button
                onClick={(e) => { e.stopPropagation(); setShowSourceSelector(true); }}
                className="px-6 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-full transition-colors"
              >
                选择视频源
              </button>
            </div>
          )}
        </div>
      )}

      {/* 视频源选择器 */}
      {showSourceSelector && (
        <SourceSelector
          animeTitle={animeTitle}
          selectedSource={selectedSource}
          roadsError={videoError}
          onSelect={selectSource}
          onClose={() => setShowSourceSelector(false)}
        />
      )}

      {/* 播放列表选择器 - 照抄原项目 menuBody */}
      {showEpisodeList && roads.length > 0 && (
        <div 
          className="fixed inset-0 z-40 flex items-end sm:items-center justify-center bg-black/70 backdrop-blur-sm"
          onClick={() => setShowEpisodeList(false)}
        >
          <div 
            className="w-full sm:max-w-md max-h-[80vh] flex flex-col bg-white/10 backdrop-blur-xl rounded-t-3xl sm:rounded-2xl border border-white/20 overflow-hidden"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="flex items-center justify-between p-4 border-b border-white/10">
              <div className="flex items-center gap-3">
                <h2 className="text-white font-semibold">播放列表</h2>
                {/* 线路选择 - 照抄原项目 MenuAnchor */}
                {roads.length > 1 && (
                  <select
                    value={currentRoad}
                    onChange={(e) => setCurrentRoad(parseInt(e.target.value))}
                    className="bg-white/10 text-white text-sm px-3 py-1 rounded-lg border border-white/20"
                  >
                    {roads.map((road, index) => (
                      <option key={index} value={index} className="bg-gray-800">
                        {road.name}
                      </option>
                    ))}
                  </select>
                )}
              </div>
              <button 
                onClick={() => setShowEpisodeList(false)} 
                className="p-1.5 rounded-full hover:bg-white/10"
              >
                <span className="material-symbols-rounded text-white text-xl">close</span>
              </button>
            </div>

            {/* Episode Grid - 照抄原项目 GridView */}
            <div className="flex-1 overflow-y-auto p-4">
              <div className="grid grid-cols-3 gap-2">
                {currentRoadData?.identifier.map((name, index) => {
                  const episodeNum = index + 1
                  const isPlaying = episodeNum === currentEpisode
                  return (
                    <button
                      key={index}
                      onClick={() => {
                        changeEpisode(episodeNum, currentRoad, roads, currentPlugin)
                        setShowEpisodeList(false)
                      }}
                      className={`p-3 rounded-xl text-left transition-all ${
                        isPlaying
                          ? 'bg-primary-500/30 border border-primary-500'
                          : 'bg-white/5 hover:bg-white/10 border border-transparent'
                      }`}
                    >
                      <div className="flex items-center gap-2">
                        {isPlaying && (
                          <span className="material-symbols-rounded text-primary-400 text-sm animate-pulse">
                            play_arrow
                          </span>
                        )}
                        <span className={`text-sm truncate ${isPlaying ? 'text-primary-400 font-medium' : 'text-white'}`}>
                          {name}
                        </span>
                      </div>
                    </button>
                  )
                })}
              </div>
            </div>

            {/* Footer */}
            <div className="p-3 border-t border-white/10 text-center">
              <span className="text-white/40 text-xs">
                共 {totalEpisodesInRoad} 集 · 当前播放 {currentEpisodeName}
              </span>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
