/**
 * Player components export
 */

// Main player
export { VideoPlayer } from './VideoPlayer'
export type { VideoPlayerProps } from './VideoPlayer'

// Controls
export { PlayerControls } from './PlayerControls'
export type { PlayerControlsProps } from './PlayerControls'

export { TopControls } from './TopControls'
export type { TopControlsProps } from './TopControls'

export { BottomControls } from './BottomControls'
export type { BottomControlsProps } from './BottomControls'

export { ProgressBar, MiniProgressBar } from './ProgressBar'
export type { ProgressBarProps } from './ProgressBar'

export { SpeedMenu, SpeedButton } from './SpeedMenu'
export type { SpeedMenuProps } from './SpeedMenu'

// Overlays
export {
  SpeedIndicator,
  SeekIndicator,
  BrightnessIndicator,
  VolumeIndicator,
  DanmakuStatusIndicator,
  NetworkSpeedIndicator,
  LoadingIndicator,
  ErrorDisplay,
} from './PlayerOverlays'

// Gesture
export { GestureOverlay } from './GestureOverlay'
export type { GestureOverlayProps } from './GestureOverlay'

// Episode
export { NextEpisodeSuggestion } from './NextEpisodeSuggestion'
export type { NextEpisodeSuggestionProps } from './NextEpisodeSuggestion'

// Danmaku
export { DanmakuCanvas } from './DanmakuCanvas'
export type { DanmakuCanvasProps } from './DanmakuCanvas'

export { DanmakuSettings } from './DanmakuSettings'
export type { DanmakuSettingsProps } from './DanmakuSettings'

// Source
export { SourceSelector } from './SourceSelector'

// Super Resolution
export { SuperResolutionRenderer } from './SuperResolutionRenderer'

// Utils
export { formatDuration, formatNetworkSpeed, DEFAULT_PLAY_SPEED_LIST, EWMA_ALPHA } from './utils'
