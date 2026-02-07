/**
 * Custom React hooks for the iOS Liquid Glass Video Player
 * Centralized exports for all hooks
 */

export { useAnime, useEpisodes, useCharacters, useComments, useStaff } from './useAnime'
export { usePlayer } from './usePlayer'
export { useDanmaku } from './useDanmaku'
export { usePlayerSettings } from './usePlayerSettings'
export {
  useSuperResolution,
  useSuperResolutionStore,
  SUPER_RESOLUTION_LABELS,
  SUPER_RESOLUTION_DESCRIPTIONS,
} from './useSuperResolution'
export type { SuperResolutionType } from './useSuperResolution'
export {
  useLocalStorage,
  useLocalStorageJSON,
  useLocalStorageString,
  useLocalStorageNumber,
  useLocalStorageBoolean,
} from './useLocalStorage'

// Re-export store selectors for convenience
export {
  useAppStore,
  useAnimeState,
  usePlayerState,
  useDanmakuState,
  useHistoryState,
  useFavoritesState,
} from '@/lib/store'
