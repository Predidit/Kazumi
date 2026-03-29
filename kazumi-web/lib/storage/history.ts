/**
 * Watch History Manager
 * Manages watch progress persistence using Local Storage with LRU eviction
 */

import { WatchHistoryItem } from '@/types/storage'

const STORAGE_KEY = 'watch_history'
const MAX_HISTORY_ITEMS = 100 // Maximum number of history items before LRU eviction

export class HistoryManager {
  /**
   * Save watch progress for an anime episode
   * Implements LRU eviction when storage quota is exceeded
   * 
   * @param animeId - Bangumi anime ID
   * @param episode - Episode number
   * @param time - Playback time in seconds
   * @param title - Optional anime title (Chinese name preferred)
   * @param cover - Optional anime cover URL
   */
  saveProgress(animeId: number, episode: number, time: number, title?: string, cover?: string): void {
    try {
      const history = this.getAllHistory()
      
      // Find existing entry for this anime/episode
      const existingIndex = history.findIndex(
        item => item.animeId === animeId && item.episodeNumber === episode
      )
      
      // Create or update the history item
      const historyItem: WatchHistoryItem = {
        animeId,
        episodeNumber: episode,
        time,
        timestamp: Date.now(),
        animeTitle: title || '', // Use provided title or empty
        animeCover: cover || ''  // Use provided cover or empty
      }
      
      // If entry exists, update it and move to front (most recent)
      if (existingIndex !== -1) {
        // Preserve title and cover from existing entry if not provided
        if (!historyItem.animeTitle) {
          historyItem.animeTitle = history[existingIndex].animeTitle
        }
        if (!historyItem.animeCover) {
          historyItem.animeCover = history[existingIndex].animeCover
        }
        history.splice(existingIndex, 1)
      }
      
      // Add to front of array (most recent)
      history.unshift(historyItem)
      
      // Implement LRU eviction if we exceed max items
      if (history.length > MAX_HISTORY_ITEMS) {
        history.splice(MAX_HISTORY_ITEMS)
      }
      
      // Try to save to localStorage
      this.saveToStorage(history)
    } catch (error) {
      // Handle quota exceeded error with LRU eviction
      if (this.isQuotaExceededError(error)) {
        this.handleQuotaExceeded()
        // Retry save after eviction
        try {
          const history = this.getAllHistory()
          const historyItem: WatchHistoryItem = {
            animeId,
            episodeNumber: episode,
            time,
            timestamp: Date.now(),
            animeTitle: title || '',
            animeCover: cover || ''
          }
          history.unshift(historyItem)
          this.saveToStorage(history)
        } catch (retryError) {
          console.error('Failed to save watch progress after quota eviction:', retryError)
        }
      } else {
        console.error('Failed to save watch progress:', error)
      }
    }
  }
  
  /**
   * Get watch progress for a specific anime episode
   * Returns the playback time in seconds, or null if not found
   */
  getProgress(animeId: number, episode: number): number | null {
    try {
      const history = this.getAllHistory()
      const item = history.find(
        h => h.animeId === animeId && h.episodeNumber === episode
      )
      return item ? item.time : null
    } catch (error) {
      console.error('Failed to get watch progress:', error)
      return null
    }
  }
  
  /**
   * Get all watch history items
   * Returns array sorted by timestamp (most recent first)
   */
  getAllHistory(): WatchHistoryItem[] {
    try {
      if (typeof window === 'undefined') {
        return [] // Server-side rendering
      }
      
      const data = localStorage.getItem(STORAGE_KEY)
      if (!data) {
        return []
      }
      
      const history = JSON.parse(data) as WatchHistoryItem[]
      
      // Validate and filter out corrupted entries
      return history.filter(item => 
        typeof item.animeId === 'number' &&
        typeof item.episodeNumber === 'number' &&
        typeof item.time === 'number' &&
        typeof item.timestamp === 'number'
      )
    } catch (error) {
      console.error('Failed to get watch history:', error)
      // Clear corrupted data and return empty array
      this.clearHistory()
      return []
    }
  }
  
  /**
   * Clear all watch history
   */
  clearHistory(): void {
    try {
      if (typeof window === 'undefined') {
        return // Server-side rendering
      }
      
      localStorage.removeItem(STORAGE_KEY)
    } catch (error) {
      console.error('Failed to clear watch history:', error)
    }
  }
  
  /**
   * Update anime metadata for a history item
   * Used to populate title and cover after initial save
   */
  updateMetadata(animeId: number, episode: number, title: string, cover: string): void {
    try {
      const history = this.getAllHistory()
      const item = history.find(
        h => h.animeId === animeId && h.episodeNumber === episode
      )
      
      if (item) {
        item.animeTitle = title
        item.animeCover = cover
        this.saveToStorage(history)
      }
    } catch (error) {
      console.error('Failed to update history metadata:', error)
    }
  }
  
  /**
   * Get the most recently watched episode for an anime
   */
  getLastWatchedEpisode(animeId: number): WatchHistoryItem | null {
    try {
      const history = this.getAllHistory()
      const animeHistory = history.filter(h => h.animeId === animeId)
      
      if (animeHistory.length === 0) {
        return null
      }
      
      // Return the most recent (already sorted by timestamp)
      return animeHistory[0]
    } catch (error) {
      console.error('Failed to get last watched episode:', error)
      return null
    }
  }
  
  /**
   * Remove a specific history item
   */
  removeHistoryItem(animeId: number, episode: number): void {
    try {
      const history = this.getAllHistory()
      const filtered = history.filter(
        h => !(h.animeId === animeId && h.episodeNumber === episode)
      )
      this.saveToStorage(filtered)
    } catch (error) {
      console.error('Failed to remove history item:', error)
    }
  }
  
  /**
   * Private helper: Save history array to localStorage
   */
  private saveToStorage(history: WatchHistoryItem[]): void {
    if (typeof window === 'undefined') {
      return // Server-side rendering
    }
    
    localStorage.setItem(STORAGE_KEY, JSON.stringify(history))
  }
  
  /**
   * Private helper: Check if error is quota exceeded
   */
  private isQuotaExceededError(error: unknown): boolean {
    if (error instanceof DOMException) {
      // Check for quota exceeded error codes
      return (
        error.code === 22 || // QUOTA_EXCEEDED_ERR
        error.code === 1014 || // NS_ERROR_DOM_QUOTA_REACHED (Firefox)
        error.name === 'QuotaExceededError' ||
        error.name === 'NS_ERROR_DOM_QUOTA_REACHED'
      )
    }
    return false
  }
  
  /**
   * Private helper: Handle quota exceeded by removing oldest items
   * Implements LRU eviction strategy
   */
  private handleQuotaExceeded(): void {
    try {
      const history = this.getAllHistory()
      
      // Remove oldest 20% of items
      const itemsToRemove = Math.max(1, Math.floor(history.length * 0.2))
      const reducedHistory = history.slice(0, history.length - itemsToRemove)
      
      this.saveToStorage(reducedHistory)
      
      console.warn(`Storage quota exceeded. Removed ${itemsToRemove} oldest history items.`)
    } catch (error) {
      console.error('Failed to handle quota exceeded:', error)
      // Last resort: clear all history
      this.clearHistory()
    }
  }
}

// Export singleton instance
export const historyManager = new HistoryManager()
