/**
 * Player utilities - 播放器工具函数
 */

/**
 * 格式化时间 - 照抄原项目的 Utils.durationToString
 */
export function formatDuration(seconds: number): string {
  if (!isFinite(seconds) || seconds < 0) return '00:00'
  
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const secs = Math.floor(seconds % 60)
  
  if (hours > 0) {
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }
  
  return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
}

/**
 * 可选播放倍速 - 照抄原项目的 defaultPlaySpeedList
 */
export const DEFAULT_PLAY_SPEED_LIST = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0]

/**
 * EWMA 平滑因子
 */
export const EWMA_ALPHA = 0.3

/**
 * 格式化网速
 */
export function formatNetworkSpeed(bytesPerSecond: number): string {
  if (bytesPerSecond >= 1024 * 1024) {
    return `${(bytesPerSecond / (1024 * 1024)).toFixed(1)} MB/s`
  } else if (bytesPerSecond >= 1024) {
    return `${Math.round(bytesPerSecond / 1024)} KB/s`
  } else if (bytesPerSecond > 0) {
    return `${Math.round(bytesPerSecond)} B/s`
  }
  return ''
}
