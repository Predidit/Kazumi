/**
 * SpeedMenu - 倍速选择菜单组件
 * 从 VideoPlayer 拆分出来
 */

'use client'

const DEFAULT_PLAY_SPEED_LIST = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0]

export interface SpeedMenuProps {
  currentSpeed: number
  onSelect: (speed: number) => void
  onClose: () => void
  disableAnimations?: boolean
}

export function SpeedMenu({
  currentSpeed,
  onSelect,
  onClose,
  disableAnimations = false,
}: SpeedMenuProps) {
  return (
    <>
      {/* 背景遮罩 */}
      <div 
        className="fixed inset-0 z-40"
        onClick={onClose}
      />
      
      {/* 菜单 */}
      <div className="absolute bottom-full left-0 mb-2 z-50 py-2 bg-black/80 backdrop-blur-md rounded-xl border border-white/20 max-h-60 overflow-y-auto">
        <div className="px-3 py-1 text-white/60 text-xs border-b border-white/10 mb-1">
          播放速度
        </div>
        <div className="flex flex-wrap gap-1 p-2 w-48">
          {DEFAULT_PLAY_SPEED_LIST.map((speed) => (
            <button
              key={speed}
              onClick={() => onSelect(speed)}
              className={`
                px-3 py-1.5 rounded-lg text-sm font-medium active:scale-95
                ${disableAnimations ? '' : 'transition-all'}
                ${currentSpeed === speed 
                  ? 'bg-red-500 text-white' 
                  : 'bg-white/10 text-white hover:bg-white/20'
                }
              `}
            >
              {speed}x
            </button>
          ))}
        </div>
        <div className="px-2 pt-1 border-t border-white/10 mt-1">
          <button
            onClick={() => onSelect(1.0)}
            className={`w-full px-3 py-1.5 text-sm text-white/80 hover:text-white hover:bg-white/10 rounded-lg ${
              disableAnimations ? '' : 'transition-all'
            }`}
          >
            默认速度
          </button>
        </div>
      </div>
    </>
  )
}

/**
 * SpeedButton - 倍速按钮
 */
export function SpeedButton({
  currentSpeed,
  onClick,
  disableAnimations = false,
}: {
  currentSpeed: number
  onClick: () => void
  disableAnimations?: boolean
}) {
  return (
    <button
      onClick={onClick}
      className={`h-7 sm:h-8 px-2 sm:px-3 flex items-center justify-center bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full active:scale-95 ${
        disableAnimations ? '' : 'transition-all'
      }`}
      aria-label="播放速度"
    >
      <span className="text-white text-xs sm:text-sm font-medium whitespace-nowrap">
        {currentSpeed === 1.0 ? '倍速' : `${currentSpeed}x`}
      </span>
    </button>
  )
}
