/**
 * ProgressBar - 进度条组件
 * 从 VideoPlayer 拆分出来
 */

'use client'

import { useRef, useCallback, useEffect, useState } from 'react'

export interface ProgressBarProps {
  currentTime: number
  duration: number
  buffered: number
  onSeek: (time: number) => void
  onDragStart?: () => void
  onDragEnd?: () => void
  disabled?: boolean
  className?: string
}

export function ProgressBar({
  currentTime,
  duration,
  buffered,
  onSeek,
  onDragStart,
  onDragEnd,
  disabled = false,
  className = '',
}: ProgressBarProps) {
  const progressBarRef = useRef<HTMLDivElement>(null)
  const [isDragging, setIsDragging] = useState(false)
  const [dragTime, setDragTime] = useState<number | null>(null)

  const getTimeFromPosition = useCallback((clientX: number): number => {
    if (!progressBarRef.current || duration <= 0) return 0
    const rect = progressBarRef.current.getBoundingClientRect()
    const percent = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width))
    return percent * duration
  }, [duration])

  const handleDragStart = useCallback((clientX: number) => {
    if (disabled) return
    setIsDragging(true)
    onDragStart?.()
    const time = getTimeFromPosition(clientX)
    setDragTime(time)
  }, [disabled, getTimeFromPosition, onDragStart])

  const handleDragMove = useCallback((clientX: number) => {
    if (!isDragging) return
    const time = getTimeFromPosition(clientX)
    setDragTime(time)
  }, [isDragging, getTimeFromPosition])

  const handleDragEnd = useCallback(() => {
    if (!isDragging) return
    if (dragTime !== null) {
      onSeek(dragTime)
    }
    setIsDragging(false)
    setDragTime(null)
    onDragEnd?.()
  }, [isDragging, dragTime, onSeek, onDragEnd])

  const handleClick = useCallback((e: React.MouseEvent) => {
    if (isDragging || disabled) return
    const time = getTimeFromPosition(e.clientX)
    onSeek(time)
  }, [isDragging, disabled, getTimeFromPosition, onSeek])

  // 全局事件监听
  useEffect(() => {
    if (!isDragging) return

    const handleMouseMove = (e: MouseEvent) => handleDragMove(e.clientX)
    const handleMouseUp = () => handleDragEnd()
    const handleTouchMove = (e: TouchEvent) => {
      if (e.touches.length > 0) handleDragMove(e.touches[0].clientX)
    }
    const handleTouchEnd = () => handleDragEnd()

    window.addEventListener('mousemove', handleMouseMove)
    window.addEventListener('mouseup', handleMouseUp)
    window.addEventListener('touchmove', handleTouchMove, { passive: false })
    window.addEventListener('touchend', handleTouchEnd)

    return () => {
      window.removeEventListener('mousemove', handleMouseMove)
      window.removeEventListener('mouseup', handleMouseUp)
      window.removeEventListener('touchmove', handleTouchMove)
      window.removeEventListener('touchend', handleTouchEnd)
    }
  }, [isDragging, handleDragMove, handleDragEnd])

  const displayTime = isDragging && dragTime !== null ? dragTime : currentTime
  const progressPercent = duration > 0 ? (displayTime / duration) * 100 : 0
  const bufferedPercent = duration > 0 ? (buffered / duration) * 100 : 0

  return (
    <div 
      ref={progressBarRef}
      className={`relative h-12 flex items-center cursor-pointer group touch-none select-none ${className}`}
      onClick={handleClick}
      onMouseDown={(e) => { e.preventDefault(); handleDragStart(e.clientX) }}
      onTouchStart={(e) => { e.preventDefault(); if (e.touches.length > 0) handleDragStart(e.touches[0].clientX) }}
    >
      {/* 进度条背景 */}
      <div 
        className="absolute inset-x-0 h-[4px] bg-white/30 rounded-full group-hover:h-[6px] transition-all" 
        style={{ top: '50%', transform: 'translateY(-50%)' }}
      >
        {/* 缓冲进度 */}
        <div 
          className="absolute h-full bg-white/40 rounded-full"
          style={{ width: `${bufferedPercent}%` }}
        />
        {/* 播放进度 */}
        <div 
          className="absolute h-full bg-red-500 rounded-full"
          style={{ width: `${progressPercent}%` }}
        />
      </div>
      
      {/* 滑块 */}
      <div 
        className={`absolute w-4 h-4 bg-white rounded-full shadow-lg transition-transform ${
          isDragging ? 'scale-150' : 'group-hover:scale-125'
        }`}
        style={{ 
          left: `calc(${progressPercent}% - 8px)`,
          top: '50%',
          transform: `translateY(-50%) ${isDragging ? 'scale(1.5)' : ''}`
        }}
      />
    </div>
  )
}

/**
 * MiniProgressBar - 迷你进度条（控制栏隐藏时显示）
 */
export function MiniProgressBar({
  currentTime,
  duration,
  buffered,
  onClick,
}: {
  currentTime: number
  duration: number
  buffered: number
  onClick: () => void
}) {
  const progressPercent = duration > 0 ? (currentTime / duration) * 100 : 0
  const bufferedPercent = duration > 0 ? (buffered / duration) * 100 : 0

  return (
    <div 
      className="absolute left-0 right-0 bottom-0 z-[100] h-[3px] cursor-pointer"
      onClick={(e) => { e.stopPropagation(); onClick() }}
      onTouchStart={(e) => { e.stopPropagation(); onClick() }}
    >
      <div className="absolute inset-0 bg-black/60" />
      <div 
        className="absolute top-0 bottom-0 left-0 bg-white/40"
        style={{ width: `${bufferedPercent}%` }}
      />
      <div 
        className="absolute top-0 bottom-0 left-0 bg-red-500"
        style={{ width: `${progressPercent}%` }}
      />
    </div>
  )
}
