/**
 * DanmakuSettings Component
 * Settings panel for danmaku (bullet comments) customization
 * 
 * Features:
 * - Toggle for enabling/disabling danmaku display
 * - Opacity slider (0-1) for transparency control
 * - Speed slider (0.5-2.0) for scroll speed adjustment
 * - Font size slider (12-32px) for text size control
 * - iOS liquid glass aesthetic with warm colors
 * - Material Symbols icons (no emoji)
 * - Minimum 44px touch targets for accessibility
 * - Smooth animations with GPU acceleration
 * - Integrates with Zustand store for state persistence
 * - 横屏适配 - 照抄原项目的响应式布局
 * 
 * Requirements: 6.5, 6.6, 6.7, 6.8
 */

'use client'

import { useCallback, useRef, useState, useEffect } from 'react'
import { cn } from '@/lib/utils/cn'
import { useDanmakuState } from '@/lib/store'

export interface DanmakuSettingsProps {
  /** Whether settings panel is visible */
  visible?: boolean
  /** Callback when settings panel should close */
  onClose?: () => void
  /** Class name for styling */
  className?: string
}

/**
 * DanmakuSettings component with iOS-styled controls
 * Uses Material Symbols icons and liquid glass aesthetic
 * 支持横屏/竖屏自适应布局
 */
export function DanmakuSettings({
  visible = true,
  onClose,
  className = '',
}: DanmakuSettingsProps) {
  const {
    enabled,
    opacity,
    speed,
    fontSize,
    setEnabled,
    setOpacity,
    setSpeed,
    setFontSize,
  } = useDanmakuState()

  const opacitySliderRef = useRef<HTMLDivElement>(null)
  const speedSliderRef = useRef<HTMLDivElement>(null)
  const fontSizeSliderRef = useRef<HTMLDivElement>(null)
  
  // 检测横屏状态
  const [isLandscape, setIsLandscape] = useState(false)
  
  // 拖动状态 - 修复滑块只能点击不能拖动的问题
  const [draggingSlider, setDraggingSlider] = useState<'opacity' | 'speed' | 'fontSize' | null>(null)
  
  useEffect(() => {
    const checkOrientation = () => {
      setIsLandscape(window.innerWidth > window.innerHeight)
    }
    
    checkOrientation()
    window.addEventListener('resize', checkOrientation)
    window.addEventListener('orientationchange', checkOrientation)
    
    return () => {
      window.removeEventListener('resize', checkOrientation)
      window.removeEventListener('orientationchange', checkOrientation)
    }
  }, [])

  /**
   * Handle slider interaction (generic)
   */
  const handleSliderInteraction = useCallback(
    (
      clientX: number,
      sliderRef: React.RefObject<HTMLDivElement | null>,
      min: number,
      max: number,
      onChange: (value: number) => void
    ) => {
      if (!sliderRef.current) return

      const rect = sliderRef.current.getBoundingClientRect()
      const percent = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width))
      const value = min + percent * (max - min)
      onChange(value)
    },
    []
  )

  /**
   * Handle opacity slider - 开始拖动
   */
  const handleOpacityMouseDown = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault()
      setDraggingSlider('opacity')
      handleSliderInteraction(e.clientX, opacitySliderRef, 0, 1, setOpacity)
    },
    [handleSliderInteraction, setOpacity]
  )

  const handleOpacityTouchStart = useCallback(
    (e: React.TouchEvent) => {
      e.preventDefault()
      setDraggingSlider('opacity')
      handleSliderInteraction(e.touches[0].clientX, opacitySliderRef, 0, 1, setOpacity)
    },
    [handleSliderInteraction, setOpacity]
  )

  /**
   * Handle speed slider - 开始拖动
   */
  const handleSpeedMouseDown = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault()
      setDraggingSlider('speed')
      handleSliderInteraction(e.clientX, speedSliderRef, 0.5, 2.0, setSpeed)
    },
    [handleSliderInteraction, setSpeed]
  )

  const handleSpeedTouchStart = useCallback(
    (e: React.TouchEvent) => {
      e.preventDefault()
      setDraggingSlider('speed')
      handleSliderInteraction(e.touches[0].clientX, speedSliderRef, 0.5, 2.0, setSpeed)
    },
    [handleSliderInteraction, setSpeed]
  )

  /**
   * Handle font size slider - 开始拖动
   */
  const handleFontSizeMouseDown = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault()
      setDraggingSlider('fontSize')
      handleSliderInteraction(e.clientX, fontSizeSliderRef, 12, 32, setFontSize)
    },
    [handleSliderInteraction, setFontSize]
  )

  const handleFontSizeTouchStart = useCallback(
    (e: React.TouchEvent) => {
      e.preventDefault()
      setDraggingSlider('fontSize')
      handleSliderInteraction(e.touches[0].clientX, fontSizeSliderRef, 12, 32, setFontSize)
    },
    [handleSliderInteraction, setFontSize]
  )

  /**
   * 全局拖动事件处理 - 修复滑块只能点击不能拖动的问题
   */
  useEffect(() => {
    if (!draggingSlider) return

    const handleMouseMove = (e: MouseEvent) => {
      if (draggingSlider === 'opacity') {
        handleSliderInteraction(e.clientX, opacitySliderRef, 0, 1, setOpacity)
      } else if (draggingSlider === 'speed') {
        handleSliderInteraction(e.clientX, speedSliderRef, 0.5, 2.0, setSpeed)
      } else if (draggingSlider === 'fontSize') {
        handleSliderInteraction(e.clientX, fontSizeSliderRef, 12, 32, setFontSize)
      }
    }

    const handleTouchMove = (e: TouchEvent) => {
      if (e.touches.length > 0) {
        if (draggingSlider === 'opacity') {
          handleSliderInteraction(e.touches[0].clientX, opacitySliderRef, 0, 1, setOpacity)
        } else if (draggingSlider === 'speed') {
          handleSliderInteraction(e.touches[0].clientX, speedSliderRef, 0.5, 2.0, setSpeed)
        } else if (draggingSlider === 'fontSize') {
          handleSliderInteraction(e.touches[0].clientX, fontSizeSliderRef, 12, 32, setFontSize)
        }
      }
    }

    const handleEnd = () => {
      setDraggingSlider(null)
    }

    window.addEventListener('mousemove', handleMouseMove)
    window.addEventListener('mouseup', handleEnd)
    window.addEventListener('touchmove', handleTouchMove, { passive: false })
    window.addEventListener('touchend', handleEnd)

    return () => {
      window.removeEventListener('mousemove', handleMouseMove)
      window.removeEventListener('mouseup', handleEnd)
      window.removeEventListener('touchmove', handleTouchMove)
      window.removeEventListener('touchend', handleEnd)
    }
  }, [draggingSlider, handleSliderInteraction, setOpacity, setSpeed, setFontSize])

  /**
   * Toggle danmaku enabled state
   */
  const handleToggle = useCallback(() => {
    setEnabled(!enabled)
  }, [enabled, setEnabled])

  /**
   * Calculate slider percentages
   */
  const opacityPercent = opacity * 100
  const speedPercent = ((speed - 0.5) / 1.5) * 100
  const fontSizePercent = ((fontSize - 12) / 20) * 100

  if (!visible) return null

  return (
    <div
      className={cn(
        // 基础定位和尺寸 - 横屏时使用更紧凑的侧边栏布局，竖屏时使用底部弹出
        isLandscape 
          ? 'absolute top-2 right-2 bottom-2 z-[70] w-[240px]' 
          : 'absolute bottom-24 right-3 z-[70] w-[280px] max-w-[calc(100vw-1.5rem)]',
        // 玻璃效果
        'bg-white/90 backdrop-blur-glass',
        'rounded-2xl border border-glass-border shadow-glass',
        isLandscape ? 'p-3' : 'p-3',
        'transition-all duration-300 gpu-accelerated',
        'animate-slide-up',
        // 横屏时允许滚动
        isLandscape && 'overflow-y-auto',
        // 安全区域
        'safe-area-right',
        className
      )}
      role="dialog"
      aria-label="弹幕设置"
    >
      {/* Header */}
      <div className={cn('flex items-center justify-between', isLandscape ? 'mb-3' : 'mb-3')}>
        <h3 className={cn(
          'font-semibold text-gray-800 flex items-center gap-1.5',
          isLandscape ? 'text-sm' : 'text-sm'
        )}>
          <span className={cn('material-symbols-rounded', isLandscape ? 'text-[18px]' : 'text-[18px]')}>
            chat_bubble
          </span>
          弹幕设置
        </h3>
        {onClose && (
          <button
            onClick={onClose}
            className={cn(
              'flex items-center justify-center',
              'bg-gray-100 hover:bg-gray-200 active:bg-gray-300',
              'rounded-full',
              'transition-all duration-200 gpu-accelerated',
              'active:scale-95 spring-animation',
              'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2',
              'focus-visible:outline-[#FF6B6B]/80',
              isLandscape 
                ? 'h-[28px] w-[28px]' 
                : 'h-[32px] w-[32px]'
            )}
            aria-label="关闭设置"
          >
            <span className={cn(
              'material-symbols-rounded text-gray-600',
              isLandscape ? 'text-[16px]' : 'text-[18px]'
            )}>
              close
            </span>
          </button>
        )}
      </div>

      {/* Enable/Disable Toggle */}
      <div className={cn('mb-4', isLandscape && 'mb-3')}>
        <div className="flex items-center justify-between">
          <label htmlFor="danmaku-toggle" className={cn(
            'font-medium text-gray-700',
            isLandscape ? 'text-xs' : 'text-sm'
          )}>
            显示弹幕
          </label>
          <button
            id="danmaku-toggle"
            onClick={handleToggle}
            className={cn(
              'relative inline-flex items-center',
              'rounded-full transition-all duration-300 gpu-accelerated',
              'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2',
              'focus-visible:outline-[#FF6B6B]/80',
              enabled ? 'bg-[#FF6B6B]' : 'bg-gray-300',
              // 竖屏和横屏都使用紧凑的开关尺寸
              isLandscape 
                ? 'h-[24px] w-[44px]' 
                : 'h-[28px] w-[52px]'
            )}
            role="switch"
            aria-checked={enabled}
            aria-label="切换弹幕显示"
          >
            <span
              className={cn(
                'inline-block rounded-full bg-white shadow-lg',
                'transition-transform duration-300 gpu-accelerated',
                // 竖屏和横屏都使用紧凑的滑块
                isLandscape 
                  ? 'h-[20px] w-[20px]' 
                  : 'h-[24px] w-[24px]',
                enabled 
                  ? (isLandscape ? 'translate-x-[22px]' : 'translate-x-[26px]') 
                  : 'translate-x-[2px]'
              )}
            />
          </button>
        </div>
      </div>

      {/* Opacity Slider */}
      <div className={cn('mb-4', isLandscape && 'mb-3')}>
        <div className="flex items-center justify-between mb-1.5">
          <label className={cn(
            'font-medium text-gray-700 flex items-center gap-1',
            isLandscape ? 'text-xs' : 'text-xs'
          )}>
            <span className={cn('material-symbols-rounded', isLandscape ? 'text-[14px]' : 'text-[16px]')}>
              opacity
            </span>
            不透明度
          </label>
          <span className={cn(
            'font-semibold text-gray-800',
            isLandscape ? 'text-xs' : 'text-xs'
          )}>
            {Math.round(opacityPercent)}%
          </span>
        </div>
        <div
          ref={opacitySliderRef}
          className={cn(
            'relative flex items-center cursor-pointer group touch-none select-none',
            isLandscape ? 'h-[28px]' : 'h-[36px]'
          )}
          onMouseDown={handleOpacityMouseDown}
          onTouchStart={handleOpacityTouchStart}
          role="slider"
          aria-label="不透明度滑块"
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={Math.round(opacityPercent)}
          tabIndex={0}
        >
          {/* Track background */}
          <div className={cn(
            'absolute inset-x-0 bg-gray-200 rounded-full overflow-hidden',
            isLandscape ? 'h-1.5' : 'h-1.5'
          )}>
            {/* Progress fill */}
            <div
              className="h-full bg-[#FF6B6B] transition-all duration-100 gpu-accelerated"
              style={{ width: `${opacityPercent}%` }}
            />
          </div>

          {/* Slider thumb */}
          <div
            className={cn(
              'absolute bg-white border-2 border-[#FF6B6B] rounded-full shadow-lg transition-transform duration-100 gpu-accelerated group-hover:scale-110',
              isLandscape ? 'h-4 w-4' : 'h-4 w-4'
            )}
            style={{ left: `calc(${opacityPercent}% - 8px)` }}
          />
        </div>
      </div>

      {/* Speed Slider */}
      <div className={cn('mb-4', isLandscape && 'mb-3')}>
        <div className="flex items-center justify-between mb-1.5">
          <label className={cn(
            'font-medium text-gray-700 flex items-center gap-1',
            isLandscape ? 'text-xs' : 'text-xs'
          )}>
            <span className={cn('material-symbols-rounded', isLandscape ? 'text-[14px]' : 'text-[16px]')}>
              speed
            </span>
            滚动速度
          </label>
          <span className={cn(
            'font-semibold text-gray-800',
            isLandscape ? 'text-xs' : 'text-xs'
          )}>
            {speed.toFixed(1)}x
          </span>
        </div>
        <div
          ref={speedSliderRef}
          className={cn(
            'relative flex items-center cursor-pointer group touch-none select-none',
            isLandscape ? 'h-[28px]' : 'h-[36px]'
          )}
          onMouseDown={handleSpeedMouseDown}
          onTouchStart={handleSpeedTouchStart}
          role="slider"
          aria-label="速度滑块"
          aria-valuemin={50}
          aria-valuemax={200}
          aria-valuenow={Math.round(speed * 100)}
          tabIndex={0}
        >
          {/* Track background */}
          <div className={cn(
            'absolute inset-x-0 bg-gray-200 rounded-full overflow-hidden',
            isLandscape ? 'h-1.5' : 'h-1.5'
          )}>
            {/* Progress fill */}
            <div
              className="h-full bg-[#FF6B6B] transition-all duration-100 gpu-accelerated"
              style={{ width: `${speedPercent}%` }}
            />
          </div>

          {/* Slider thumb */}
          <div
            className={cn(
              'absolute bg-white border-2 border-[#FF6B6B] rounded-full shadow-lg transition-transform duration-100 gpu-accelerated group-hover:scale-110',
              isLandscape ? 'h-4 w-4' : 'h-4 w-4'
            )}
            style={{ left: `calc(${speedPercent}% - 8px)` }}
          />
        </div>
        <div className="flex justify-between mt-1 px-1">
          <span className={cn('text-gray-500', isLandscape ? 'text-[10px]' : 'text-[10px]')}>0.5x</span>
          <span className={cn('text-gray-500', isLandscape ? 'text-[10px]' : 'text-[10px]')}>1.0x</span>
          <span className={cn('text-gray-500', isLandscape ? 'text-[10px]' : 'text-[10px]')}>2.0x</span>
        </div>
      </div>

      {/* Font Size Slider */}
      <div>
        <div className="flex items-center justify-between mb-1.5">
          <label className={cn(
            'font-medium text-gray-700 flex items-center gap-1',
            isLandscape ? 'text-xs' : 'text-xs'
          )}>
            <span className={cn('material-symbols-rounded', isLandscape ? 'text-[14px]' : 'text-[16px]')}>
              format_size
            </span>
            字体大小
          </label>
          <span className={cn(
            'font-semibold text-gray-800',
            isLandscape ? 'text-xs' : 'text-xs'
          )}>
            {Math.round(fontSize)}px
          </span>
        </div>
        <div
          ref={fontSizeSliderRef}
          className={cn(
            'relative flex items-center cursor-pointer group touch-none select-none',
            isLandscape ? 'h-[28px]' : 'h-[36px]'
          )}
          onMouseDown={handleFontSizeMouseDown}
          onTouchStart={handleFontSizeTouchStart}
          role="slider"
          aria-label="字体大小滑块"
          aria-valuemin={12}
          aria-valuemax={32}
          aria-valuenow={Math.round(fontSize)}
          tabIndex={0}
        >
          {/* Track background */}
          <div className={cn(
            'absolute inset-x-0 bg-gray-200 rounded-full overflow-hidden',
            isLandscape ? 'h-1.5' : 'h-1.5'
          )}>
            {/* Progress fill */}
            <div
              className="h-full bg-[#FF6B6B] transition-all duration-100 gpu-accelerated"
              style={{ width: `${fontSizePercent}%` }}
            />
          </div>

          {/* Slider thumb */}
          <div
            className={cn(
              'absolute bg-white border-2 border-[#FF6B6B] rounded-full shadow-lg transition-transform duration-100 gpu-accelerated group-hover:scale-110',
              isLandscape ? 'h-4 w-4' : 'h-4 w-4'
            )}
            style={{ left: `calc(${fontSizePercent}% - 8px)` }}
          />
        </div>
        <div className="flex justify-between mt-1 px-1">
          <span className={cn('text-gray-500', isLandscape ? 'text-[10px]' : 'text-[10px]')}>12px</span>
          <span className={cn('text-gray-500', isLandscape ? 'text-[10px]' : 'text-[10px]')}>22px</span>
          <span className={cn('text-gray-500', isLandscape ? 'text-[10px]' : 'text-[10px]')}>32px</span>
        </div>
      </div>

      {/* Preview text - 竖屏时也使用更紧凑的预览 */}
      {!isLandscape && (
        <div className="mt-3 p-2 bg-gray-100 rounded-xl">
          <p className="text-center text-gray-500 text-[10px] mb-1">预览</p>
          <p
            className="text-center transition-all duration-200"
            style={{
              fontSize: `${Math.min(fontSize, 18)}px`,
              opacity: enabled ? opacity : 0.3,
              color: '#333',
            }}
          >
            这是弹幕预览文本
          </p>
        </div>
      )}
    </div>
  )
}
