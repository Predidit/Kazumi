/**
 * DanmakuCanvas Component - 照抄 Kazumi 的 canvas_danmaku 实现
 * 
 * 原项目使用 canvas_danmaku 库，这里用 Canvas API 实现相同功能
 * 
 * 弹幕类型:
 * - Type 1: 滚动弹幕 (从右向左)
 * - Type 4: 底部弹幕 (固定在底部)
 * - Type 5: 顶部弹幕 (固定在顶部)
 * 
 * 原项目参数:
 * - duration: 8秒 (默认)
 * - fontSize: 16-25px
 * - opacity: 1.0
 * - area: 1.0 (100%)
 * - lineHeight: 1.6
 * - strokeWidth: 1.5 (描边)
 */

'use client'

import { useEffect, useRef, memo } from 'react'
import type { Danmaku } from '@/types/danmaku'

export interface DanmakuCanvasProps {
  danmakuList: Danmaku[]
  currentTime: number
  enabled: boolean
  opacity: number
  speed: number // 1.0 = 8秒, 2.0 = 4秒
  fontSize: number
  containerWidth: number
  containerHeight: number
  area?: number // 弹幕区域 0-1
  hideTop?: boolean
  hideBottom?: boolean
  hideScroll?: boolean
  duration?: number // 弹幕持续时间（秒）
  lineHeight?: number // 弹幕行高
  border?: boolean // 弹幕描边
  showColor?: boolean // 显示弹幕颜色
  fontWeight?: number // 字体字重 1-9
  playbackSpeed?: number // 视频播放倍速
  followSpeed?: boolean // 弹幕跟随视频倍速
  massive?: boolean // 海量弹幕模式 - 弹幕过多时叠加绘制
  className?: string
}

// 活跃弹幕
interface ActiveDanmaku {
  id: string
  message: string
  color: string
  type: number
  x: number
  y: number
  width: number
  startTime: number
  speed: number // 每帧移动的像素
}

// 轨道
interface Track {
  y: number
  occupiedUntil: number // 该轨道被占用到的时间
}

/**
 * DanmakuCanvas - 照抄原项目的弹幕渲染逻辑
 */
export const DanmakuCanvas = memo(function DanmakuCanvas({
  danmakuList,
  currentTime,
  enabled,
  opacity,
  speed,
  fontSize,
  containerWidth,
  containerHeight,
  area = 1.0,
  hideTop = false,
  hideBottom = true, // 原项目默认隐藏底部弹幕
  hideScroll = false,
  duration = 8, // 默认8秒
  lineHeight = 1.6,
  border = true,
  showColor = true,
  fontWeight = 4,
  playbackSpeed = 1.0,
  followSpeed = true,
  massive = false, // 海量弹幕模式
  className = '',
}: DanmakuCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const activeDanmakuRef = useRef<ActiveDanmaku[]>([])
  const scrollTracksRef = useRef<Track[]>([])
  const topTracksRef = useRef<Track[]>([])
  const bottomTracksRef = useRef<Track[]>([])
  const lastTimeRef = useRef<number>(-1)
  const animationFrameRef = useRef<number | null>(null)
  const processedSecondsRef = useRef<Set<number>>(new Set())
  
  // 使用 ref 存储最新的 props，避免 render 函数依赖变化
  const propsRef = useRef({
    enabled,
    opacity,
    speed,
    fontSize,
    containerWidth,
    containerHeight,
    currentTime,
    hideTop,
    hideBottom,
    hideScroll,
    area,
    duration,
    lineHeight,
    border,
    showColor,
    fontWeight,
    playbackSpeed,
    followSpeed,
    massive,
  })
  
  // 更新 propsRef
  useEffect(() => {
    propsRef.current = {
      enabled,
      opacity,
      speed,
      fontSize,
      containerWidth,
      containerHeight,
      currentTime,
      hideTop,
      hideBottom,
      hideScroll,
      area,
      duration,
      lineHeight,
      border,
      showColor,
      fontWeight,
      playbackSpeed,
      followSpeed,
      massive,
    }
  })

  // 计算实际弹幕速度（考虑视频倍速）
  const getEffectiveSpeed = () => {
    const { speed: sp, playbackSpeed: ps, followSpeed: fs } = propsRef.current
    return fs ? sp * ps : sp
  }

  // 计算实际弹幕持续时间
  const getEffectiveDuration = () => {
    const { duration: d, playbackSpeed: ps, followSpeed: fs } = propsRef.current
    return fs ? d / ps : d
  }

  /**
   * 初始化轨道 - 照抄原项目
   */
  const initTracks = () => {
    const { fontSize: fs, containerHeight: ch, area: a, lineHeight: lh } = propsRef.current
    const trackHeight = fs * lh
    const danmakuAreaHeight = ch * a
    const trackCount = Math.floor(danmakuAreaHeight / trackHeight)
    
    // 滚动弹幕轨道 (中间区域)
    scrollTracksRef.current = []
    for (let i = 0; i < trackCount; i++) {
      scrollTracksRef.current.push({
        y: i * trackHeight + fs,
        occupiedUntil: 0,
      })
    }

    // 顶部弹幕轨道 (前20%的轨道)
    const topTrackCount = Math.max(1, Math.floor(trackCount * 0.2))
    topTracksRef.current = []
    for (let i = 0; i < topTrackCount; i++) {
      topTracksRef.current.push({
        y: i * trackHeight + fs,
        occupiedUntil: 0,
      })
    }

    // 底部弹幕轨道 (后20%的轨道)
    const bottomTrackCount = Math.max(1, Math.floor(trackCount * 0.2))
    bottomTracksRef.current = []
    for (let i = 0; i < bottomTrackCount; i++) {
      bottomTracksRef.current.push({
        y: danmakuAreaHeight - (bottomTrackCount - i) * trackHeight + fs,
        occupiedUntil: 0,
      })
    }
  }

  /**
   * 测量文本宽度
   */
  const measureText = (ctx: CanvasRenderingContext2D, text: string): number => {
    const { fontSize: fs, fontWeight: fw } = propsRef.current
    const weight = fw * 100 // 1-9 -> 100-900
    ctx.font = `${weight} ${fs}px "SF Pro Display", "PingFang SC", "Microsoft YaHei", sans-serif`
    return ctx.measureText(text).width
  }

  /**
   * 找到可用轨道 - 照抄原项目的碰撞检测
   * massive 模式下允许弹幕叠加
   */
  const findAvailableTrack = (
    tracks: Track[],
    time: number,
    isScroll: boolean
  ): Track | null => {
    const { massive: isMassive } = propsRef.current
    
    for (const track of tracks) {
      if (isScroll) {
        // 滚动弹幕: 检查是否有足够空间
        const timeSinceOccupied = time - track.occupiedUntil
        const minGap = isMassive ? 0.1 : 0.3 // 海量模式下减少间隔
        if (timeSinceOccupied >= minGap || track.occupiedUntil === 0) {
          return track
        }
      } else {
        // 固定弹幕: 检查轨道是否空闲
        if (time >= track.occupiedUntil) {
          return track
        }
      }
    }
    
    // 海量模式下，如果没有空闲轨道，随机选择一个轨道叠加
    if (isMassive && tracks.length > 0) {
      const randomIndex = Math.floor(Math.random() * tracks.length)
      return tracks[randomIndex]
    }
    
    return null
  }

  /**
   * 添加弹幕 - 照抄原项目的 addDanmaku 逻辑
   */
  const addDanmaku = (
    ctx: CanvasRenderingContext2D,
    danmaku: Danmaku,
    time: number,
    index: number
  ) => {
    const { containerWidth: cw, hideTop: ht, hideBottom: hb, hideScroll: hs } = propsRef.current
    
    // 根据类型过滤
    if (danmaku.type === 5 && ht) return
    if (danmaku.type === 4 && hb) return
    if (danmaku.type === 1 && hs) return

    const textWidth = measureText(ctx, danmaku.message)
    const effectiveDuration = getEffectiveDuration()
    const isScroll = danmaku.type === 1

    // 选择轨道
    let tracks: Track[]
    if (danmaku.type === 5) {
      tracks = topTracksRef.current
    } else if (danmaku.type === 4) {
      tracks = bottomTracksRef.current
    } else {
      tracks = scrollTracksRef.current
    }

    const track = findAvailableTrack(tracks, time, isScroll)
    if (!track) return // 没有可用轨道，丢弃弹幕

    // 计算位置
    let x: number
    let danmakuSpeed: number

    if (isScroll) {
      x = cw
      // 速度 = (屏幕宽度 + 文字宽度) / 持续时间 / 60fps
      danmakuSpeed = (cw + textWidth) / effectiveDuration / 60
      // 更新轨道占用时间 (当弹幕完全进入屏幕后释放)
      track.occupiedUntil = time + (textWidth / (cw + textWidth)) * effectiveDuration + 0.5
    } else {
      // 固定弹幕居中
      x = (cw - textWidth) / 2
      danmakuSpeed = 0
      track.occupiedUntil = time + 4 // 固定弹幕显示4秒
    }

    const id = `${danmaku.time}-${danmaku.message}-${index}`
    
    activeDanmakuRef.current.push({
      id,
      message: danmaku.message,
      color: danmaku.color,
      type: danmaku.type,
      x,
      y: track.y,
      width: textWidth,
      startTime: time,
      speed: danmakuSpeed,
    })
  }

  /**
   * 渲染循环 - 使用 requestAnimationFrame
   * 不依赖任何 props，通过 ref 获取最新值
   */
  const render = () => {
    const canvas = canvasRef.current
    if (!canvas) {
      animationFrameRef.current = requestAnimationFrame(render)
      return
    }

    const ctx = canvas.getContext('2d')
    if (!ctx) {
      animationFrameRef.current = requestAnimationFrame(render)
      return
    }

    const { 
      enabled: en, 
      opacity: op, 
      fontSize: fs, 
      containerWidth: cw, 
      containerHeight: ch, 
      currentTime: ct,
      border: bd,
      showColor: sc,
      fontWeight: fw,
    } = propsRef.current

    // 清空画布
    ctx.clearRect(0, 0, cw, ch)

    if (!en) {
      animationFrameRef.current = requestAnimationFrame(render)
      return
    }

    // 设置全局透明度
    ctx.globalAlpha = op

    // 计算字体字重
    const weight = fw * 100

    // 更新和绘制弹幕
    activeDanmakuRef.current = activeDanmakuRef.current.filter(item => {
      // 更新位置 (滚动弹幕)
      if (item.type === 1) {
        item.x -= item.speed
        // 移出屏幕则移除
        if (item.x + item.width < 0) {
          return false
        }
      } else {
        // 固定弹幕超时移除
        if (ct - item.startTime > 4) {
          return false
        }
      }

      // 绘制弹幕
      ctx.font = `${weight} ${fs}px "SF Pro Display", "PingFang SC", "Microsoft YaHei", sans-serif`
      ctx.textBaseline = 'middle'

      // 描边 (根据设置)
      if (bd) {
        ctx.strokeStyle = 'rgba(0, 0, 0, 0.8)'
        ctx.lineWidth = 3
        ctx.lineJoin = 'round'
        ctx.strokeText(item.message, item.x, item.y)
      }

      // 填充 (根据 showColor 设置决定是否显示颜色)
      ctx.fillStyle = sc ? item.color : '#FFFFFF'
      ctx.fillText(item.message, item.x, item.y)

      return true
    })

    ctx.globalAlpha = 1

    animationFrameRef.current = requestAnimationFrame(render)
  }

  /**
   * 处理当前秒的弹幕 - 照抄原项目的 playerTimer 逻辑
   * 原项目: 每秒内的弹幕均匀分布发送
   */
  useEffect(() => {
    if (!enabled) return

    const canvas = canvasRef.current
    if (!canvas) return

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const currentSecond = Math.floor(currentTime)
    
    // 检测时间跳跃 (seek)
    if (Math.abs(currentTime - lastTimeRef.current) > 1.5) {
      // 清空所有弹幕
      activeDanmakuRef.current = []
      processedSecondsRef.current.clear()
      initTracks()
    }
    lastTimeRef.current = currentTime

    // 如果这一秒已经处理过，跳过
    if (processedSecondsRef.current.has(currentSecond)) return

    // 获取当前秒的弹幕
    const danmakusInSecond = danmakuList.filter(d => Math.floor(d.time) === currentSecond)
    
    if (danmakusInSecond.length === 0) {
      processedSecondsRef.current.add(currentSecond)
      return
    }

    // 照抄原项目: 弹幕在这一秒内均匀分布
    // 原项目代码:
    // await Future.delayed(Duration(milliseconds: idx * 1000 ~/ danmakuList.length), () => ...)
    const capturedSecond = currentSecond
    danmakusInSecond.forEach((danmaku, idx) => {
      const delay = (idx * 1000) / danmakusInSecond.length
      setTimeout(() => {
        // 检查是否还在同一秒
        const nowSecond = Math.floor(propsRef.current.currentTime)
        if (nowSecond === capturedSecond || nowSecond === capturedSecond + 1) {
          addDanmaku(ctx, danmaku, propsRef.current.currentTime, idx)
        }
      }, delay)
    })

    processedSecondsRef.current.add(currentSecond)

    // 清理旧的已处理秒数 (保留最近10秒)
    if (processedSecondsRef.current.size > 20) {
      const toDelete: number[] = []
      processedSecondsRef.current.forEach(sec => {
        if (sec < currentSecond - 10) {
          toDelete.push(sec)
        }
      })
      toDelete.forEach(sec => processedSecondsRef.current.delete(sec))
    }
  }, [currentTime, danmakuList, enabled])

  /**
   * 初始化 canvas 和动画循环
   */
  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    canvas.width = containerWidth
    canvas.height = containerHeight

    initTracks()
    animationFrameRef.current = requestAnimationFrame(render)

    return () => {
      if (animationFrameRef.current !== null) {
        cancelAnimationFrame(animationFrameRef.current)
      }
    }
  }, [containerWidth, containerHeight])

  /**
   * 禁用时清空
   */
  useEffect(() => {
    if (!enabled) {
      activeDanmakuRef.current = []
      processedSecondsRef.current.clear()
      const canvas = canvasRef.current
      if (canvas) {
        const ctx = canvas.getContext('2d')
        if (ctx) {
          ctx.clearRect(0, 0, containerWidth, containerHeight)
        }
      }
    }
  }, [enabled, containerWidth, containerHeight])

  return (
    <canvas
      ref={canvasRef}
      className={`absolute inset-0 pointer-events-none ${className}`}
      style={{
        width: containerWidth,
        height: containerHeight,
      }}
      aria-hidden="true"
    />
  )
})
