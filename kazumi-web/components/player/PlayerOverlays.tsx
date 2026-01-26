/**
 * PlayerOverlays - 播放器覆盖层组件集合
 * 包含各种提示、指示器等
 */

'use client'

import { formatDuration } from './utils'

/**
 * 长按加速提示
 */
export function SpeedIndicator({
  speed,
  isLocked,
}: {
  speed: number
  isLocked: boolean
}) {
  return (
    <div className="absolute top-24 left-1/2 -translate-x-1/2 z-30 px-4 py-2 bg-black/70 backdrop-blur-sm rounded-lg flex flex-col items-center gap-1">
      <div className="flex items-center gap-2">
        <span className="material-symbols-rounded text-white text-lg">fast_forward</span>
        <span className="text-white text-sm font-medium">
          {speed}x 倍速播放中
        </span>
        {isLocked && (
          <span className="material-symbols-rounded text-yellow-400 text-sm">lock</span>
        )}
      </div>
      <span className="text-white/60 text-xs">
        {isLocked ? '↑ 上滑解除锁定 (松手保持2x)' : '↓ 下滑锁定倍速 (松手恢复)'}
      </span>
    </div>
  )
}

/**
 * 快进/快退提示
 */
export function SeekIndicator({
  targetTime,
  currentTime,
}: {
  targetTime: number
  currentTime: number
}) {
  const delta = Math.round(targetTime - currentTime)
  const text = delta > 0 ? `快进 ${delta} 秒` : `快退 ${Math.abs(delta)} 秒`

  return (
    <div className="absolute top-1/3 left-1/2 -translate-x-1/2 z-30 px-4 py-2 bg-black/70 backdrop-blur-sm rounded-lg">
      <div className="flex flex-col items-center gap-1">
        <span className="text-white text-lg font-medium">{formatDuration(targetTime)}</span>
        <span className="text-white/80 text-sm">{text}</span>
      </div>
    </div>
  )
}

/**
 * 亮度调节提示
 */
export function BrightnessIndicator({ value }: { value: number }) {
  return (
    <div className="absolute top-24 left-1/2 -translate-x-1/2 z-30 px-4 py-2 bg-black/70 backdrop-blur-sm rounded-lg flex items-center gap-2">
      <span className="material-symbols-rounded text-white text-lg">brightness_7</span>
      <span className="text-white text-sm font-medium">{Math.round(value * 100)}%</span>
    </div>
  )
}

/**
 * 音量调节提示
 */
export function VolumeIndicator({ value }: { value: number }) {
  const icon = value === 0 ? 'volume_off' : value < 0.5 ? 'volume_down' : 'volume_up'
  
  return (
    <div className="absolute top-24 left-1/2 -translate-x-1/2 z-30 px-4 py-2 bg-black/70 backdrop-blur-sm rounded-lg flex items-center gap-2">
      <span className="material-symbols-rounded text-white text-lg">{icon}</span>
      <span className="text-white text-sm font-medium">{Math.round(value * 100)}%</span>
    </div>
  )
}

/**
 * 弹幕状态指示器
 */
export function DanmakuStatusIndicator({
  loading,
  error,
  count,
}: {
  loading: boolean
  error: boolean
  count: number
}) {
  if (loading) {
    return (
      <div className="absolute top-24 left-4 z-[60]">
        <div className="px-3 py-2 bg-black/50 backdrop-blur-sm rounded-full">
          <div className="flex items-center gap-2">
            <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            <span className="text-white text-xs">加载弹幕...</span>
          </div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="absolute top-24 left-4 z-[60]">
        <div className="px-3 py-2 bg-black/50 backdrop-blur-sm rounded-full">
          <div className="flex items-center gap-2">
            <span className="material-symbols-rounded text-yellow-400 text-sm">warning</span>
            <span className="text-white/80 text-xs">弹幕加载失败</span>
          </div>
        </div>
      </div>
    )
  }

  if (count > 0) {
    return (
      <div className="absolute top-24 left-4 z-[60]">
        <div className="px-3 py-2 bg-black/50 backdrop-blur-sm rounded-full">
          <span className="text-white/80 text-xs">{count} 条弹幕</span>
        </div>
      </div>
    )
  }

  return null
}

/**
 * 网速指示器
 */
export function NetworkSpeedIndicator({ speed }: { speed: string }) {
  if (!speed) return null

  return (
    <div className="absolute top-24 right-4 z-[60]">
      <div className="px-3 py-2 bg-black/50 backdrop-blur-sm rounded-full">
        <div className="flex items-center gap-1.5">
          <span className="material-symbols-rounded text-blue-400 text-sm">download</span>
          <span className="text-white/80 text-xs tabular-nums">{speed}</span>
        </div>
      </div>
    </div>
  )
}

/**
 * 加载指示器
 */
export function LoadingIndicator({ text }: { text: string }) {
  return (
    <div className="absolute inset-0 flex items-center justify-center bg-black/30 z-10 pointer-events-none">
      <div className="flex flex-col items-center gap-3">
        <div className="w-12 h-12 border-4 border-white/20 border-t-white rounded-full animate-spin" />
        <p className="text-white text-sm">{text}</p>
      </div>
    </div>
  )
}

/**
 * 错误显示
 */
export function ErrorDisplay({
  message,
  onRetry,
}: {
  message: string
  onRetry: () => void
}) {
  return (
    <div className="absolute inset-0 flex items-center justify-center bg-black/80 z-10">
      <div className="flex flex-col items-center gap-4 px-6 py-8 bg-white/10 backdrop-blur-md rounded-2xl border border-white/20">
        <span className="material-symbols-rounded text-red-400 text-5xl">error</span>
        <p className="text-white text-base text-center max-w-xs">{message}</p>
        <button
          onClick={onRetry}
          className="px-6 py-2 bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full text-white text-sm transition-all active:scale-95"
        >
          重试
        </button>
      </div>
    </div>
  )
}
