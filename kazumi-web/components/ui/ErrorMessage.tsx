'use client'

import React from 'react'
import { GlassPanel } from './GlassPanel'
import { Button } from './Button'
import { cn } from '@/lib/utils/cn'

export interface ErrorMessageProps {
  /** Error title */
  title?: string
  /** Error message */
  message?: string
  /** Error type for icon selection */
  type?: 'error' | 'network' | 'notfound' | 'empty'
  /** Retry callback */
  onRetry?: () => void
  /** Additional CSS classes */
  className?: string
  /** Whether to show retry button */
  showRetry?: boolean
  /** Custom action button */
  action?: {
    label: string
    icon?: string
    onClick: () => void
  }
}

const errorConfig = {
  error: {
    icon: 'error_outline',
    defaultTitle: '出错了',
    defaultMessage: '发生了一些错误，请稍后再试',
  },
  network: {
    icon: 'wifi_off',
    defaultTitle: '网络错误',
    defaultMessage: '无法连接到服务器，请检查网络连接',
  },
  notfound: {
    icon: 'search_off',
    defaultTitle: '未找到',
    defaultMessage: '您要查找的内容不存在',
  },
  empty: {
    icon: 'inbox',
    defaultTitle: '暂无内容',
    defaultMessage: '这里还没有任何内容',
  },
}

/**
 * ErrorMessage - Displays error states with liquid glass styling
 * 
 * Features:
 * - Multiple error types with appropriate icons
 * - Retry functionality
 * - Custom actions
 * - Accessible error messages
 * 
 * Requirements: 13.3, 13.6
 */
export function ErrorMessage({
  title,
  message,
  type = 'error',
  onRetry,
  className,
  showRetry = true,
  action,
}: ErrorMessageProps) {
  const config = errorConfig[type]

  return (
    <GlassPanel 
      className={cn('p-8 text-center', className)}
      role="alert"
      aria-live="polite"
    >
      <div className="flex flex-col items-center gap-4">
        <span 
          className={cn(
            'material-symbols-rounded text-6xl',
            type === 'error' ? 'text-[#FF6B6B]' : 'text-gray-400'
          )}
          aria-hidden="true"
        >
          {config.icon}
        </span>
        
        <h2 className="text-xl font-semibold text-gray-900">
          {title || config.defaultTitle}
        </h2>
        
        <p className="text-gray-600 max-w-md">
          {message || config.defaultMessage}
        </p>

        <div className="flex gap-3 mt-4">
          {showRetry && onRetry && (
            <Button
              variant="primary"
              icon="refresh"
              onClick={onRetry}
            >
              重试
            </Button>
          )}
          
          {action && (
            <Button
              variant={showRetry && onRetry ? 'ghost' : 'primary'}
              icon={action.icon}
              onClick={action.onClick}
            >
              {action.label}
            </Button>
          )}
        </div>
      </div>
    </GlassPanel>
  )
}
