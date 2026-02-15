/**
 * GestureOverlay - 手势控制层组件
 * 从 VideoPlayer 拆分出来，处理触摸手势
 */

'use client'

import { useRef, useCallback } from 'react'

export interface GestureOverlayProps {
  onTap: () => void
  onDoubleTap: () => void
  onLongPressStart: (y: number) => void
  onLongPressEnd: () => void
  onHorizontalDrag: (deltaX: number, totalWidth: number) => void
  onHorizontalDragEnd: () => void
  onVerticalDrag: (deltaY: number, isLeftSide: boolean, totalHeight: number) => void
  onVerticalDragEnd: () => void
  onLongPressVerticalMove: (deltaY: number) => void
  isLongPressing: boolean
  disabled?: boolean
  className?: string
}

export function GestureOverlay({
  onTap,
  onDoubleTap,
  onLongPressStart,
  onLongPressEnd,
  onHorizontalDrag,
  onHorizontalDragEnd,
  onVerticalDrag,
  onVerticalDragEnd,
  onLongPressVerticalMove,
  isLongPressing,
  disabled = false,
  className = '',
}: GestureOverlayProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const gestureStartRef = useRef<{ x: number; y: number } | null>(null)
  const longPressTimerRef = useRef<NodeJS.Timeout | null>(null)
  const longPressStartYRef = useRef<number | null>(null)
  const isHorizontalDraggingRef = useRef(false)
  const isVerticalDraggingRef = useRef(false)

  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    if (disabled || e.touches.length !== 1) return
    
    const touch = e.touches[0]
    gestureStartRef.current = { x: touch.clientX, y: touch.clientY }
    longPressStartYRef.current = touch.clientY
    
    // 启动长按计时器
    longPressTimerRef.current = setTimeout(() => {
      onLongPressStart(touch.clientY)
    }, 500)
  }, [disabled, onLongPressStart])

  const handleTouchMove = useCallback((e: React.TouchEvent) => {
    if (disabled || e.touches.length !== 1 || !gestureStartRef.current) return
    
    const touch = e.touches[0]
    const deltaX = touch.clientX - gestureStartRef.current.x
    const deltaY = touch.clientY - gestureStartRef.current.y
    const container = containerRef.current
    if (!container) return

    const containerRect = container.getBoundingClientRect()
    const totalWidth = containerRect.width
    const totalHeight = containerRect.height

    // 长按状态下检测上下滑动
    if (isLongPressing && longPressStartYRef.current !== null) {
      const verticalDelta = touch.clientY - longPressStartYRef.current
      onLongPressVerticalMove(verticalDelta)
      if (Math.abs(verticalDelta) > 50) {
        longPressStartYRef.current = touch.clientY
      }
      return
    }

    // 判断滑动方向
    const threshold = 10
    if (!isHorizontalDraggingRef.current && !isVerticalDraggingRef.current) {
      if (Math.abs(deltaX) > threshold || Math.abs(deltaY) > threshold) {
        // 取消长按计时器
        if (longPressTimerRef.current) {
          clearTimeout(longPressTimerRef.current)
          longPressTimerRef.current = null
        }

        if (Math.abs(deltaX) > Math.abs(deltaY)) {
          isHorizontalDraggingRef.current = true
        } else {
          isVerticalDraggingRef.current = true
        }
      }
      return
    }

    // 水平滑动
    if (isHorizontalDraggingRef.current) {
      onHorizontalDrag(deltaX, totalWidth)
    }

    // 垂直滑动
    if (isVerticalDraggingRef.current) {
      const isLeftSide = gestureStartRef.current.x < totalWidth / 2
      onVerticalDrag(-deltaY, isLeftSide, totalHeight)
      gestureStartRef.current = { x: gestureStartRef.current.x, y: touch.clientY }
    }
  }, [disabled, isLongPressing, onHorizontalDrag, onVerticalDrag, onLongPressVerticalMove])

  const handleTouchEnd = useCallback(() => {
    // 清除长按计时器
    if (longPressTimerRef.current) {
      clearTimeout(longPressTimerRef.current)
      longPressTimerRef.current = null
    }

    if (isLongPressing) {
      onLongPressEnd()
    }

    if (isHorizontalDraggingRef.current) {
      onHorizontalDragEnd()
    }

    if (isVerticalDraggingRef.current) {
      onVerticalDragEnd()
    }

    // 重置状态
    isHorizontalDraggingRef.current = false
    isVerticalDraggingRef.current = false
    gestureStartRef.current = null
    longPressStartYRef.current = null
  }, [isLongPressing, onLongPressEnd, onHorizontalDragEnd, onVerticalDragEnd])

  return (
    <div
      ref={containerRef}
      className={`absolute inset-0 z-[5] ${className}`}
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      onClick={(e) => { 
        e.stopPropagation()
        onTap()
      }}
      onDoubleClick={(e) => { 
        e.stopPropagation()
        onDoubleTap()
      }}
    />
  )
}
