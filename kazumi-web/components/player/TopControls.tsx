/**
 * TopControls - 顶部控制栏组件
 * 只包含标题，跳过按钮移到底部控制栏
 */

'use client'

export interface TopControlsProps {
  title?: string
  episodeNumber: number
  skipTime: number
  onSkip: () => void
  visible: boolean
  disableAnimations?: boolean
}

export function TopControls({
  title,
  episodeNumber,
  visible,
  disableAnimations = false,
}: TopControlsProps) {
  return (
    <div 
      className={`absolute top-0 left-0 right-0 z-[50] ${
        disableAnimations ? '' : 'transition-opacity duration-300'
      } ${
        visible ? 'opacity-100' : 'opacity-0 pointer-events-none'
      }`}
      onClick={(e) => e.stopPropagation()}
    >
      {/* 渐变背景 */}
      <div className="absolute inset-0 bg-gradient-to-b from-black/80 via-black/40 to-transparent pointer-events-none" />
      
      <div className="relative px-4 pt-4 pb-12 safe-area-top">
        {/* 标题 - 单独一行，不会被遮挡 */}
        {title && (
          <h2 className="text-white text-sm font-medium line-clamp-2">
            {title} - 第{episodeNumber}话
          </h2>
        )}
      </div>
    </div>
  )
}
