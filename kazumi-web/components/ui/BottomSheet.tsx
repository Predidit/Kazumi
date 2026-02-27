'use client'

import { useEffect, useCallback } from 'react'

interface BottomSheetProps {
  isOpen: boolean
  onClose: () => void
  title?: string
  children: React.ReactNode
  /** 是否显示关闭按钮，默认 true */
  showCloseButton?: boolean
  /** 最大高度，默认 70vh */
  maxHeight?: string
  /** 自定义类名 */
  className?: string
}

/**
 * BottomSheet - 底部抽屉组件
 * 
 * 特点:
 * - z-index 高于导航栏 (z-[60])
 * - 底部有足够的 padding 避开导航栏
 * - 支持点击遮罩关闭
 * - 支持 ESC 键关闭
 * - 滑入动画
 */
export function BottomSheet({
  isOpen,
  onClose,
  title,
  children,
  showCloseButton = true,
  maxHeight = '70vh',
  className = '',
}: BottomSheetProps) {
  // ESC 键关闭
  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    if (e.key === 'Escape') {
      onClose()
    }
  }, [onClose])

  useEffect(() => {
    if (isOpen) {
      document.addEventListener('keydown', handleKeyDown)
      // 防止背景滚动
      document.body.style.overflow = 'hidden'
    }
    return () => {
      document.removeEventListener('keydown', handleKeyDown)
      document.body.style.overflow = ''
    }
  }, [isOpen, handleKeyDown])

  if (!isOpen) return null

  return (
    <div 
      className="fixed inset-0 z-[60] flex items-end justify-center bg-black/50 backdrop-blur-sm"
      onClick={onClose}
    >
      <div 
        className={`w-full max-w-lg bg-white rounded-t-3xl overflow-hidden animate-slide-up ${className}`}
        style={{ maxHeight }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        {(title || showCloseButton) && (
          <div className="flex items-center justify-between p-4 border-b border-primary-100">
            {title && (
              <h3 className="text-lg font-bold text-primary-900">{title}</h3>
            )}
            {!title && <div />}
            {showCloseButton && (
              <button
                onClick={onClose}
                className="p-2 rounded-full hover:bg-primary-100 transition-colors"
                aria-label="关闭"
              >
                <span className="material-symbols-rounded text-primary-600" style={{ fontSize: '24px' }}>
                  close
                </span>
              </button>
            )}
          </div>
        )}
        
        {/* Content - 底部留出导航栏空间 */}
        <div className="overflow-y-auto pb-24" style={{ maxHeight: `calc(${maxHeight} - 60px)` }}>
          {children}
        </div>
      </div>
    </div>
  )
}
