/**
 * BottomControls - 底部控制栏组件
 * 包含进度条、播放按钮、时间、倍速、下一集等
 */

'use client'

import { useState } from 'react'
import { ProgressBar } from './ProgressBar'
import { SpeedMenu, SpeedButton } from './SpeedMenu'
import { formatDuration } from './utils'

export interface BottomControlsProps {
  // 播放状态
  isPlaying: boolean
  currentTime: number
  duration: number
  buffered: number
  playbackSpeed: number
  volume: number
  // 弹幕
  danmakuEnabled: boolean
  showDanmakuSettings: boolean
  // 集数
  totalEpisodes?: number
  episodeNumber: number
  // 回调
  onPlayPause: () => void
  onSeek: (time: number) => void
  onSpeedChange: (speed: number) => void
  onVolumeToggle: () => void
  onPlayNext?: () => void
  onDanmakuSettingsToggle: () => void
  onDragStart?: () => void
  onDragEnd?: () => void
  // 显示控制
  visible: boolean
  disableAnimations?: boolean
}

export function BottomControls({
  isPlaying,
  currentTime,
  duration,
  buffered,
  playbackSpeed,
  volume,
  danmakuEnabled,
  showDanmakuSettings,
  totalEpisodes,
  episodeNumber,
  onPlayPause,
  onSeek,
  onSpeedChange,
  onVolumeToggle,
  onPlayNext,
  onDanmakuSettingsToggle,
  onDragStart,
  onDragEnd,
  visible,
  disableAnimations = false,
}: BottomControlsProps) {
  const [showSpeedMenu, setShowSpeedMenu] = useState(false)

  const handleSpeedSelect = (speed: number) => {
    onSpeedChange(speed)
    setShowSpeedMenu(false)
  }

  return (
    <div 
      className={`absolute bottom-0 left-0 right-0 z-[50] ${
        disableAnimations ? '' : 'transition-opacity duration-300'
      } ${
        visible ? 'opacity-100' : 'opacity-0 pointer-events-none'
      }`}
      onClick={(e) => e.stopPropagation()}
    >
      {/* 渐变背景 */}
      <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/40 to-transparent pointer-events-none" />
      
      <div className="relative px-4 pb-4 pt-12 safe-area-bottom">
        {/* 进度条 */}
        <ProgressBar
          currentTime={currentTime}
          duration={duration}
          buffered={buffered}
          onSeek={onSeek}
          onDragStart={onDragStart}
          onDragEnd={onDragEnd}
        />

        {/* 控制按钮行 */}
        <div className="flex items-center justify-between flex-nowrap overflow-hidden">
          {/* 左侧: 播放/暂停 + 时间 + 倍速 */}
          <div className="flex items-center gap-1 sm:gap-2 flex-shrink-0">
            {/* 播放/暂停按钮 */}
            <button
              onClick={onPlayPause}
              className={`w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full active:scale-95 flex-shrink-0 ${
                disableAnimations ? '' : 'transition-all'
              }`}
              aria-label={isPlaying ? '暂停' : '播放'}
            >
              <span className="material-symbols-rounded text-white text-lg sm:text-xl">
                {isPlaying ? 'pause' : 'play_arrow'}
              </span>
            </button>
            
            {/* 时间显示 */}
            <span className="text-white text-xs sm:text-sm font-medium tabular-nums whitespace-nowrap">
              {formatDuration(currentTime)}/{formatDuration(duration)}
            </span>

            {/* 倍速按钮 */}
            <div className="relative flex-shrink-0">
              <SpeedButton
                currentSpeed={playbackSpeed}
                onClick={() => setShowSpeedMenu(!showSpeedMenu)}
                disableAnimations={disableAnimations}
              />

              {showSpeedMenu && (
                <SpeedMenu
                  currentSpeed={playbackSpeed}
                  onSelect={handleSpeedSelect}
                  onClose={() => setShowSpeedMenu(false)}
                  disableAnimations={disableAnimations}
                />
              )}
            </div>
          </div>

          {/* 右侧: 音量 + 下一集 + 弹幕设置 */}
          <div className="flex items-center gap-1 sm:gap-2 flex-shrink-0">
            {/* 音量控制按钮 - 移动端隐藏 */}
            <button
              onClick={onVolumeToggle}
              className={`w-10 h-10 hidden sm:flex items-center justify-center bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full active:scale-95 ${
                disableAnimations ? '' : 'transition-all'
              }`}
              aria-label="音量"
            >
              <span className="material-symbols-rounded text-white text-xl">
                {volume === 0 ? 'volume_off' : volume < 0.5 ? 'volume_down' : 'volume_up'}
              </span>
            </button>

            {/* 下一集按钮 */}
            {onPlayNext && (
              <button
                onClick={onPlayNext}
                disabled={!totalEpisodes || episodeNumber >= totalEpisodes}
                className={`w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full active:scale-95 flex-shrink-0 ${
                  disableAnimations ? '' : 'transition-all'
                } ${
                  !totalEpisodes || episodeNumber >= totalEpisodes ? 'opacity-40 cursor-not-allowed' : ''
                }`}
                aria-label="下一集"
              >
                <span className="material-symbols-rounded text-white text-lg sm:text-xl">
                  skip_next
                </span>
              </button>
            )}

            {/* 弹幕设置按钮 */}
            {showDanmakuSettings && (
              <button
                onClick={onDanmakuSettingsToggle}
                className={`w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full active:scale-95 flex-shrink-0 ${
                  disableAnimations ? '' : 'transition-all'
                }`}
                aria-label="弹幕设置"
              >
                <span className="material-symbols-rounded text-white text-base sm:text-lg">
                  {danmakuEnabled ? 'chat_bubble' : 'speaker_notes_off'}
                </span>
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
