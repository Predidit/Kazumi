/**
 * LoadingSpinner - iOS 风格的加载动画组件
 * 支持多种尺寸和样式
 */

'use client'

import { memo } from 'react'

export interface LoadingSpinnerProps {
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl'
  color?: 'primary' | 'white' | 'gray'
  className?: string
}

const sizeMap = {
  xs: 'w-3 h-3 border-[1.5px]',
  sm: 'w-4 h-4 border-2',
  md: 'w-6 h-6 border-2',
  lg: 'w-8 h-8 border-[2.5px]',
  xl: 'w-12 h-12 border-3',
}

const colorMap = {
  primary: 'border-primary-200 border-t-primary-500',
  white: 'border-white/20 border-t-white',
  gray: 'border-gray-200 border-t-gray-500',
}

export const LoadingSpinner = memo(function LoadingSpinner({
  size = 'md',
  color = 'primary',
  className = '',
}: LoadingSpinnerProps) {
  return (
    <div
      className={`
        ${sizeMap[size]}
        ${colorMap[color]}
        rounded-full
        animate-spin
        ${className}
      `}
      style={{
        animationDuration: '0.6s',
        animationTimingFunction: 'linear',
      }}
    />
  )
})

/**
 * LoadingDots - 三点加载动画
 */
export const LoadingDots = memo(function LoadingDots({
  size = 'md',
  color = 'primary',
  className = '',
}: LoadingSpinnerProps) {
  const dotSize = {
    xs: 'w-1 h-1',
    sm: 'w-1.5 h-1.5',
    md: 'w-2 h-2',
    lg: 'w-2.5 h-2.5',
    xl: 'w-3 h-3',
  }

  const dotColor = {
    primary: 'bg-primary-500',
    white: 'bg-white',
    gray: 'bg-gray-500',
  }

  return (
    <div className={`flex items-center gap-1 ${className}`}>
      {[0, 1, 2].map((i) => (
        <div
          key={i}
          className={`${dotSize[size]} ${dotColor[color]} rounded-full animate-bounce`}
          style={{
            animationDelay: `${i * 0.15}s`,
            animationDuration: '0.6s',
          }}
        />
      ))}
    </div>
  )
})

/**
 * LoadingOverlay - 全屏加载遮罩
 */
export const LoadingOverlay = memo(function LoadingOverlay({
  visible = true,
  text,
}: {
  visible?: boolean
  text?: string
}) {
  if (!visible) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className="flex flex-col items-center gap-3 p-6 rounded-2xl bg-white/10 backdrop-blur-xl">
        <LoadingSpinner size="lg" color="white" />
        {text && <p className="text-white text-sm">{text}</p>}
      </div>
    </div>
  )
})
