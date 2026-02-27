'use client'

import { useEffect, useState, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { GlassPanel, Button, LoadingSpinner } from '@/components/ui'
import { favoritesManager, COLLECT_TYPE_LABELS, COLLECT_TYPE_ICONS } from '@/lib/storage/favorites'
import type { CollectedAnime, CollectType } from '@/types/storage'
import Image from 'next/image'

/**
 * Favorites Page - 照抄 Kazumi 的 collect_page.dart
 * 
 * 原项目特点:
 * - TabBar 分类: 在看/想看/搁置/看过/抛弃 (5个标签)
 * - 编辑模式可删除单条记录
 * - 浮动按钮同步 WebDav (我们暂不实现)
 * - 收藏按钮显示当前状态并可切换
 */

const TABS: { type: CollectType; label: string }[] = [
  { type: 1, label: '在看' },
  { type: 2, label: '想看' },
  { type: 3, label: '搁置' },
  { type: 4, label: '看过' },
  { type: 5, label: '抛弃' },
]

export default function FavoritesPage() {
  const router = useRouter()
  const [favorites, setFavorites] = useState<CollectedAnime[]>([])
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState<CollectType>(1)
  const [editMode, setEditMode] = useState(false)

  const loadFavorites = useCallback(async () => {
    try {
      setLoading(true)
      
      // 获取当前标签的收藏
      const collected = favoritesManager.getCollectedByType(activeTab)
      
      // 如果有收藏但没有详细信息，尝试获取
      const enrichedFavorites = await Promise.all(
        collected.map(async (item) => {
          if (!item.name && !item.nameCn) {
            try {
              const response = await fetch(`/api/bangumi/subject/${item.animeId}`)
              if (response.ok) {
                const data = await response.json()
                // 更新存储中的信息
                favoritesManager.updateAnimeData(
                  item.animeId,
                  data.name || '',
                  data.nameCn || data.name_cn || '',
                  data.images?.common || data.images?.large || ''
                )
                return {
                  ...item,
                  name: data.name || '',
                  nameCn: data.nameCn || data.name_cn || '',
                  cover: data.images?.common || data.images?.large || '',
                }
              }
            } catch (err) {
              console.error(`Failed to fetch anime ${item.animeId}:`, err)
            }
          }
          return item
        })
      )
      
      setFavorites(enrichedFavorites)
    } catch (err) {
      console.error('Failed to load favorites:', err)
    } finally {
      setLoading(false)
    }
  }, [activeTab])

  useEffect(() => {
    loadFavorites()
  }, [loadFavorites])

  function handleAnimeClick(anime: CollectedAnime) {
    if (editMode) return
    router.push(`/anime/${anime.animeId}`)
  }

  function handleRemoveFavorite(animeId: number) {
    favoritesManager.addCollect(animeId, 0)
    setFavorites(prev => prev.filter(a => a.animeId !== animeId))
  }

  function handleChangeCollectType(animeId: number, newType: CollectType) {
    const item = favorites.find(f => f.animeId === animeId)
    if (item) {
      favoritesManager.addCollect(animeId, newType, {
        name: item.name,
        nameCn: item.nameCn,
        cover: item.cover,
      })
      // 如果改变了类型，从当前列表移除
      if (newType !== activeTab) {
        setFavorites(prev => prev.filter(a => a.animeId !== animeId))
      }
    }
  }

  return (
    <div className="min-h-screen safe-area-all">
      <main className="container mx-auto px-4 py-8">
        {/* Header - 照抄原项目的 SysAppBar */}
        <div className="flex items-center justify-between mb-2">
          <h1 className="text-2xl font-bold text-primary-900">追番</h1>
          <button
            onClick={() => setEditMode(!editMode)}
            className="p-2 rounded-full hover:bg-primary-100 transition-colors"
            aria-label={editMode ? '完成编辑' : '编辑'}
          >
            <span className="material-symbols-rounded text-primary-600" style={{ fontSize: '24px' }}>
              {editMode ? 'edit_off' : 'edit'}
            </span>
          </button>
        </div>

        {/* TabBar - 照抄原项目的5个标签 */}
        <div className="mb-6 overflow-x-auto">
          <div className="flex border-b border-primary-200 min-w-max">
            {TABS.map((tab) => (
              <button
                key={tab.type}
                onClick={() => setActiveTab(tab.type)}
                className={`
                  px-6 py-3 text-sm font-medium transition-all relative
                  ${activeTab === tab.type 
                    ? 'text-primary-600' 
                    : 'text-primary-400 hover:text-primary-500'
                  }
                `}
              >
                {tab.label}
                {activeTab === tab.type && (
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-primary-500" />
                )}
              </button>
            ))}
          </div>
        </div>

        {/* Loading State */}
        {loading && (
          <GlassPanel className="p-12">
            <div className="flex flex-col items-center justify-center gap-4">
              <LoadingSpinner size="lg" color="primary" />
              <p className="text-primary-600">加载中...</p>
            </div>
          </GlassPanel>
        )}

        {/* Favorites Grid */}
        {!loading && favorites.length > 0 && (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
            {favorites.map((anime) => (
              <div key={anime.animeId} className="relative group">
                <div 
                  className={`cursor-pointer ${editMode ? 'pointer-events-none' : ''}`}
                  onClick={() => handleAnimeClick(anime)}
                >
                  <div className="relative aspect-[3/4] rounded-xl overflow-hidden bg-primary-100">
                    {anime.cover ? (
                      <Image
                        src={anime.cover}
                        alt={anime.nameCn || anime.name}
                        fill
                        className="object-cover"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center">
                        <span className="material-symbols-rounded text-primary-300" style={{ fontSize: '48px' }}>
                          image
                        </span>
                      </div>
                    )}
                  </div>
                  <h3 className="mt-2 text-sm font-medium text-primary-900 line-clamp-2">
                    {anime.nameCn || anime.name || `番剧 #${anime.animeId}`}
                  </h3>
                </div>
                
                {/* 编辑模式 - 收藏按钮 */}
                {editMode && (
                  <div className="absolute top-2 right-2">
                    <CollectButton
                      animeId={anime.animeId}
                      currentType={anime.type}
                      onTypeChange={(newType) => handleChangeCollectType(anime.animeId, newType)}
                      onRemove={() => handleRemoveFavorite(anime.animeId)}
                    />
                  </div>
                )}
              </div>
            ))}
          </div>
        )}

        {/* Empty State - 照抄原项目 */}
        {!loading && favorites.length === 0 && (
          <GlassPanel className="p-12">
            <div className="flex flex-col items-center justify-center gap-4">
              <span className="material-symbols-rounded text-primary-300" style={{ fontSize: '64px' }}>
                favorite_border
              </span>
              <p className="text-primary-600">啊嘞, 没有追番的说 (´;ω;`)</p>
              <Button onClick={() => router.push('/')}>
                去首页看看
              </Button>
            </div>
          </GlassPanel>
        )}
      </main>
    </div>
  )
}

/**
 * CollectButton - 照抄原项目的 collect_button.dart
 * 显示当前收藏状态，点击弹出菜单选择类型
 */
interface CollectButtonProps {
  animeId: number
  currentType: CollectType
  onTypeChange: (type: CollectType) => void
  onRemove: () => void
}

function CollectButton({ animeId, currentType, onTypeChange, onRemove }: CollectButtonProps) {
  const [showMenu, setShowMenu] = useState(false)

  const allTypes: CollectType[] = [0, 1, 2, 3, 4, 5]

  return (
    <div className="relative">
      <button
        onClick={() => setShowMenu(!showMenu)}
        className={`
          w-10 h-10 backdrop-blur-sm rounded-full flex items-center justify-center shadow-md transition-all duration-200
          ${currentType !== 0 
            ? 'bg-primary-100 hover:bg-primary-200' 
            : 'bg-white/90 hover:bg-white'
          }
        `}
        aria-label="收藏状态"
      >
        <span 
          className={`material-symbols-rounded transition-all duration-200 ${
            currentType === 0 ? 'text-primary-400' : 'text-primary-600'
          }`}
          style={{ 
            fontSize: '20px',
            fontVariationSettings: currentType !== 0 ? "'FILL' 1" : "'FILL' 0"
          }}
        >
          {currentType === 0 ? 'favorite_border' : COLLECT_TYPE_ICONS[currentType]}
        </span>
      </button>

      {/* 收藏类型菜单 */}
      {showMenu && (
        <>
          <div 
            className="fixed inset-0 z-40"
            onClick={() => setShowMenu(false)}
          />
          <div className="absolute top-full right-0 mt-2 z-50 py-2 bg-white rounded-xl shadow-lg border border-primary-100 min-w-[120px]">
            {allTypes.map((type) => (
              <button
                key={type}
                onClick={() => {
                  if (type === 0) {
                    onRemove()
                  } else {
                    onTypeChange(type)
                  }
                  setShowMenu(false)
                }}
                className={`
                  w-full flex items-center gap-2 px-4 py-2 text-sm transition-colors
                  ${currentType === type 
                    ? 'text-primary-600 bg-primary-50' 
                    : 'text-primary-700 hover:bg-primary-50'
                  }
                `}
              >
                <span 
                  className="material-symbols-rounded" 
                  style={{ 
                    fontSize: '18px',
                    fontVariationSettings: type !== 0 && currentType === type ? "'FILL' 1" : "'FILL' 0"
                  }}
                >
                  {COLLECT_TYPE_ICONS[type]}
                </span>
                <span>{COLLECT_TYPE_LABELS[type]}</span>
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  )
}
