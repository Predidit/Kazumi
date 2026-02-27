/**
 * Favorites Manager - 照抄原项目的 collect_module.dart
 * 
 * 收藏类型:
 * 0 - 未收藏
 * 1 - 在看
 * 2 - 想看
 * 3 - 搁置
 * 4 - 看过
 * 5 - 抛弃
 */

import { CollectedAnime, CollectType } from '@/types/storage'

const STORAGE_KEY = 'kazumi_favorites'

// 收藏类型标签
export const COLLECT_TYPE_LABELS: Record<CollectType, string> = {
  0: '未收藏',
  1: '在看',
  2: '想看',
  3: '搁置',
  4: '看过',
  5: '抛弃',
}

// 收藏类型图标
export const COLLECT_TYPE_ICONS: Record<CollectType, string> = {
  0: 'favorite_border',
  1: 'favorite',
  2: 'star',
  3: 'pending_actions',
  4: 'done',
  5: 'heart_broken',
}

export class FavoritesManager {
  /**
   * 添加或更新收藏 - 照抄原项目的 addCollect
   */
  addCollect(animeId: number, type: CollectType, animeData?: { name: string; nameCn: string; cover: string }): void {
    try {
      const favorites = this.getAllCollected()
      
      // 查找是否已存在
      const existingIndex = favorites.findIndex(item => item.animeId === animeId)
      
      if (type === 0) {
        // 取消收藏
        if (existingIndex !== -1) {
          favorites.splice(existingIndex, 1)
        }
      } else {
        // 添加或更新收藏
        const collectItem: CollectedAnime = {
          animeId,
          type,
          time: Date.now(),
          name: animeData?.name || '',
          nameCn: animeData?.nameCn || '',
          cover: animeData?.cover || '',
        }
        
        if (existingIndex !== -1) {
          // 更新现有收藏，保留原有数据
          collectItem.name = collectItem.name || favorites[existingIndex].name
          collectItem.nameCn = collectItem.nameCn || favorites[existingIndex].nameCn
          collectItem.cover = collectItem.cover || favorites[existingIndex].cover
          favorites[existingIndex] = collectItem
        } else {
          favorites.push(collectItem)
        }
      }
      
      this.saveToStorage(favorites)
    } catch (error) {
      console.error('Failed to add collect:', error)
    }
  }
  
  /**
   * 获取收藏类型 - 照抄原项目的 getCollectType
   */
  getCollectType(animeId: number): CollectType {
    try {
      const favorites = this.getAllCollected()
      const item = favorites.find(f => f.animeId === animeId)
      return item ? item.type : 0
    } catch (error) {
      console.error('Failed to get collect type:', error)
      return 0
    }
  }
  
  /**
   * 检查是否已收藏（任意类型）
   */
  isCollected(animeId: number): boolean {
    return this.getCollectType(animeId) !== 0
  }
  
  /**
   * 获取所有收藏
   */
  getAllCollected(): CollectedAnime[] {
    try {
      if (typeof window === 'undefined') {
        return []
      }
      
      const data = localStorage.getItem(STORAGE_KEY)
      if (!data) {
        return []
      }
      
      const parsed = JSON.parse(data) as CollectedAnime[]
      
      // 验证数据格式
      return parsed.filter(item => 
        typeof item.animeId === 'number' &&
        typeof item.type === 'number' &&
        item.type >= 0 && item.type <= 5
      )
    } catch (error) {
      console.error('Failed to get favorites:', error)
      return []
    }
  }
  
  /**
   * 按类型获取收藏 - 用于标签页显示
   */
  getCollectedByType(type: CollectType): CollectedAnime[] {
    const all = this.getAllCollected()
    return all
      .filter(item => item.type === type)
      .sort((a, b) => b.time - a.time) // 按时间倒序
  }
  
  /**
   * 获取所有收藏的 animeId（兼容旧接口）
   */
  getAllFavorites(): number[] {
    return this.getAllCollected().map(item => item.animeId)
  }
  
  /**
   * 添加收藏（兼容旧接口，默认为"在看"）
   */
  addFavorite(animeId: number): void {
    this.addCollect(animeId, 1)
  }
  
  /**
   * 移除收藏（兼容旧接口）
   */
  removeFavorite(animeId: number): void {
    this.addCollect(animeId, 0)
  }
  
  /**
   * 检查是否已收藏（兼容旧接口）
   */
  isFavorited(animeId: number): boolean {
    return this.isCollected(animeId)
  }
  
  /**
   * 更新收藏的动画信息
   */
  updateAnimeData(animeId: number, name: string, nameCn: string, cover: string): void {
    try {
      const favorites = this.getAllCollected()
      const item = favorites.find(f => f.animeId === animeId)
      
      if (item) {
        item.name = name
        item.nameCn = nameCn
        item.cover = cover
        this.saveToStorage(favorites)
      }
    } catch (error) {
      console.error('Failed to update anime data:', error)
    }
  }
  
  /**
   * 清空所有收藏
   */
  clearFavorites(): void {
    try {
      if (typeof window === 'undefined') {
        return
      }
      localStorage.removeItem(STORAGE_KEY)
    } catch (error) {
      console.error('Failed to clear favorites:', error)
    }
  }
  
  private saveToStorage(favorites: CollectedAnime[]): void {
    if (typeof window === 'undefined') {
      return
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(favorites))
  }
}

// 导出单例
export const favoritesManager = new FavoritesManager()
