/**
 * PullToRefresh - iOS 风格的下拉刷新组件
 * 支持下拉刷新和上拉加载更多
 */

'use client'

import {
  useRef,
  useState,
  useCallback,
  useEffect,
  type ReactNode,
  type TouchEvent,
} from 'react'
import { LoadingSpinner } from './LoadingSpinner'

export interface PullToRefreshProps {
  children: ReactNode
  onRefresh?: () => Promise<void>
  onLoadMore?: () => Promise<void>
  hasMore?: boolean
  refreshThreshold?: number
  loadMoreThreshold?: number
  disabled?: boolean
  className?: string
}

type RefreshState = 'idle' | 'pulling' | 'ready' | 'refreshing'
type LoadMoreState = 'idle' | 'loading' | 'noMore'

export function PullToRefresh({
  children,
  onRefresh,
  onLoadMore,
  hasMore = true,
  refreshThreshold = 80,
  loadMoreThreshold = 100,
  disabled = false,
  className = '',
}: PullToRefreshProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const contentRef = useRef<HTMLDivElement>(null)
  const startYRef = useRef(0)
  const currentYRef = useRef(0)
  const isAtTopRef = useRef(true)

  const [refreshState, setRefreshState] = useState<RefreshState>('idle')
  const [loadMoreState, setLoadMoreState] = useState<LoadMoreState>('idle')
  const [pullDistance, setPullDistance] = useState(0)

  // 检查是否在顶部
  const checkIsAtTop = useCallback(() => {
    if (!containerRef.current) return true
    return containerRef.current.scrollTop <= 0
  }, [])

  // 检查是否接近底部
  const checkNearBottom = useCallback(() => {
    if (!containerRef.current) return false
    const { scrollTop, scrollHeight, clientHeight } = containerRef.current
    return scrollHeight - scrollTop - clientHeight < loadMoreThreshold
  }, [loadMoreThreshold])

  // 处理触摸开始
  const handleTouchStart = useCallback((e: TouchEvent) => {
    if (disabled || refreshState === 'refreshing') return
    
    isAtTopRef.current = checkIsAtTop()
    if (!isAtTopRef.current) return

    startYRef.current = e.touches[0].clientY
    currentYRef.current = e.touches[0].clientY
  }, [disabled, refreshState, checkIsAtTop])

  // 处理触摸移动
  const handleTouchMove = useCallback((e: TouchEvent) => {
    if (disabled || refreshState === 'refreshing' || !isAtTopRef.current) return

    currentYRef.current = e.touches[0].clientY
    const distance = currentYRef.current - startYRef.current

    // 只处理下拉
    if (distance <= 0) {
      setPullDistance(0)
      setRefreshState('idle')
      return
    }

    // 阻尼效果 - 拉得越远阻力越大
    const dampedDistance = Math.min(distance * 0.5, refreshThreshold * 1.5)
    setPullDistance(dampedDistance)

    if (dampedDistance >= refreshThreshold) {
      setRefreshState('ready')
    } else {
      setRefreshState('pulling')
    }
  }, [disabled, refreshState, refreshThreshold])

  // 处理触摸结束
  const handleTouchEnd = useCallback(async () => {
    if (disabled || refreshState === 'refreshing') return

    if (refreshState === 'ready' && onRefresh) {
      setRefreshState('refreshing')
      setPullDistance(refreshThreshold * 0.6)
      
      try {
        await onRefresh()
      } finally {
        setRefreshState('idle')
        setPullDistance(0)
      }
    } else {
      setRefreshState('idle')
      setPullDistance(0)
    }
  }, [disabled, refreshState, onRefresh, refreshThreshold])

  // 处理滚动 - 上拉加载更多
  const handleScroll = useCallback(async () => {
    if (
      disabled ||
      loadMoreState === 'loading' ||
      !hasMore ||
      !onLoadMore
    ) return

    if (checkNearBottom()) {
      setLoadMoreState('loading')
      try {
        await onLoadMore()
      } finally {
        setLoadMoreState(hasMore ? 'idle' : 'noMore')
      }
    }
  }, [disabled, loadMoreState, hasMore, onLoadMore, checkNearBottom])

  // 更新 hasMore 状态
  useEffect(() => {
    if (!hasMore) {
      setLoadMoreState('noMore')
    } else if (loadMoreState === 'noMore') {
      setLoadMoreState('idle')
    }
  }, [hasMore, loadMoreState])

  // 刷新指示器图标
  const getRefreshIcon = () => {
    switch (refreshState) {
      case 'pulling':
        return (
          <span 
            className="material-symbols-rounded text-primary-500 transition-transform duration-200"
            style={{ 
              transform: `rotate(${Math.min(pullDistance / refreshThreshold * 180, 180)}deg)` 
            }}
          >
            arrow_downward
          </span>
        )
      case 'ready':
        return (
          <span className="material-symbols-rounded text-primary-500 animate-bounce">
            arrow_downward
          </span>
        )
      case 'refreshing':
        return <LoadingSpinner size="sm" color="primary" />
      default:
        return null
    }
  }

  // 刷新提示文字
  const getRefreshText = () => {
    switch (refreshState) {
      case 'pulling':
        return '下拉刷新'
      case 'ready':
        return '释放刷新'
      case 'refreshing':
        return '刷新中...'
      default:
        return ''
    }
  }

  return (
    <div
      ref={containerRef}
      className={`relative overflow-auto overscroll-none ${className}`}
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      onScroll={handleScroll}
    >
      {/* 下拉刷新指示器 */}
      <div
        className="absolute left-0 right-0 flex flex-col items-center justify-end overflow-hidden transition-all duration-200 ease-out"
        style={{
          height: pullDistance,
          top: 0,
          zIndex: 10,
        }}
      >
        <div className="flex items-center gap-2 pb-3">
          {getRefreshIcon()}
          <span className="text-sm text-primary-500">{getRefreshText()}</span>
        </div>
      </div>

      {/* 内容区域 */}
      <div
        ref={contentRef}
        className="transition-transform duration-200 ease-out"
        style={{
          transform: `translateY(${pullDistance}px)`,
        }}
      >
        {children}

        {/* 上拉加载更多指示器 */}
        {onLoadMore && (
          <div className="flex items-center justify-center py-4">
            {loadMoreState === 'loading' && (
              <div className="flex items-center gap-2">
                <LoadingSpinner size="sm" color="primary" />
                <span className="text-sm text-primary-500">加载中...</span>
              </div>
            )}
            {loadMoreState === 'noMore' && (
              <span className="text-sm text-primary-400">没有更多了</span>
            )}
            {loadMoreState === 'idle' && hasMore && (
              <span className="text-sm text-primary-400">上拉加载更多</span>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
