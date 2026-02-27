'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { GlassPanel, Button, LoadingSpinner } from '@/components/ui'
import { historyManager } from '@/lib/storage/history'
import { favoritesManager, COLLECT_TYPE_LABELS, COLLECT_TYPE_ICONS } from '@/lib/storage/favorites'
import type { WatchHistoryItem, CollectType } from '@/types/storage'
import Image from 'next/image'

/**
 * History Page - 照抄 Kazumi 的 history_page.dart 布局
 * 
 * 优化:
 * - 使用更宽的卡片布局
 * - 标题横向显示，不换行
 * - 更好的响应式布局
 */
export default function HistoryPage() {
  const router = useRouter()
  const [history, setHistory] = useState<WatchHistoryItem[]>([])
  const [showClearConfirm, setShowClearConfirm] = useState(false)
  const [editMode, setEditMode] = useState(false)

  useEffect(() => {
    loadHistory()
  }, [])

  function loadHistory() {
    const allHistory = historyManager.getAllHistory()
    const sorted = allHistory.sort((a, b) => b.timestamp - a.timestamp)
    setHistory(sorted)
  }

  function handleItemClick(item: WatchHistoryItem) {
    if (editMode) return
    router.push(`/anime/${item.animeId}/watch/${item.episodeNumber}`)
  }

  function handleDeleteItem(item: WatchHistoryItem, e: React.MouseEvent) {
    e.stopPropagation()
    historyManager.removeHistoryItem(item.animeId, item.episodeNumber)
    loadHistory()
  }

  function handleViewDetail(item: WatchHistoryItem, e: React.MouseEvent) {
    e.stopPropagation()
    router.push(`/anime/${item.animeId}`)
  }

  function handleClearHistory() {
    historyManager.clearHistory()
    setHistory([])
    setShowClearConfirm(false)
  }

  function formatProgress(time: number): string {
    const hours = Math.floor(time / 3600)
    const minutes = Math.floor((time % 3600) / 60)
    const seconds = Math.floor(time % 60)

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
    }
    return `${minutes}:${seconds.toString().padStart(2, '0')}`
  }

  return (
    <div className="min-h-screen safe-area-all">
      <main className="container mx-auto px-4 py-8 pb-24">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-2xl font-bold text-primary-900">历史记录</h1>
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

        {/* Clear Confirmation Dialog */}
        {showClearConfirm && (
          <div className="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
            <GlassPanel className="p-6 max-w-md w-full">
              <h3 className="text-xl font-bold text-primary-900 mb-4">记录管理</h3>
              <p className="text-primary-600 mb-6">确认要清除所有历史记录吗?</p>
              <div className="flex gap-4">
                <Button onClick={() => setShowClearConfirm(false)} variant="ghost" className="flex-1">
                  取消
                </Button>
                <Button onClick={handleClearHistory} variant="primary" className="flex-1">
                  确认
                </Button>
              </div>
            </GlassPanel>
          </div>
        )}

        {/* History List */}
        {history.length > 0 ? (
          <div className="space-y-3">
            {history.map((item, index) => (
              <HistoryCard
                key={`${item.animeId}-${item.episodeNumber}-${index}`}
                item={item}
                editMode={editMode}
                onClick={() => handleItemClick(item)}
                onDelete={(e) => handleDeleteItem(item, e)}
                onViewDetail={(e) => handleViewDetail(item, e)}
                formatProgress={formatProgress}
              />
            ))}
          </div>
        ) : (
          <GlassPanel className="p-12">
            <div className="flex flex-col items-center justify-center gap-4">
              <span className="material-symbols-rounded text-primary-300" style={{ fontSize: '64px' }}>
                history
              </span>
              <p className="text-primary-600">没有找到历史记录 (´;ω;`)</p>
              <Button onClick={() => router.push('/')}>去首页看看</Button>
            </div>
          </GlassPanel>
        )}

        {/* 浮动清空按钮 */}
        {history.length > 0 && (
          <button
            onClick={() => setShowClearConfirm(true)}
            className="fixed bottom-24 right-6 w-14 h-14 bg-primary-500 hover:bg-primary-600 text-white rounded-full shadow-lg flex items-center justify-center transition-all hover:scale-110 z-30"
            aria-label="清空历史"
          >
            <span className="material-symbols-rounded" style={{ fontSize: '24px' }}>
              clear_all
            </span>
          </button>
        )}
      </main>
    </div>
  )
}

/**
 * HistoryCard - 优化后的历史记录卡片
 */
interface HistoryCardProps {
  item: WatchHistoryItem
  editMode: boolean
  onClick: () => void
  onDelete: (e: React.MouseEvent) => void
  onViewDetail: (e: React.MouseEvent) => void
  formatProgress: (time: number) => string
}

function HistoryCard({ item, editMode, onClick, onDelete, onViewDetail, formatProgress }: HistoryCardProps) {
  const [collectType, setCollectType] = useState<CollectType>(0)
  const [showCollectMenu, setShowCollectMenu] = useState(false)

  useEffect(() => {
    setCollectType(favoritesManager.getCollectType(item.animeId))
  }, [item.animeId])

  function handleCollectChange(type: CollectType) {
    favoritesManager.addCollect(item.animeId, type, {
      name: item.animeTitle,
      nameCn: item.animeTitle,
      cover: item.animeCover,
    })
    setCollectType(type)
    setShowCollectMenu(false)
  }

  return (
    <div
      onClick={onClick}
      className={`
        flex bg-white/80 backdrop-blur-sm rounded-2xl overflow-hidden shadow-sm
        border border-primary-100/50 transition-all
        ${editMode ? 'cursor-default' : 'cursor-pointer hover:shadow-md hover:scale-[1.005]'}
      `}
    >
      {/* 左侧封面图 */}
      <div className="relative flex-shrink-0 w-20 h-28 sm:w-24 sm:h-32">
        {item.animeCover ? (
          <Image
            src={item.animeCover}
            alt={item.animeTitle || '番剧封面'}
            fill
            className="object-cover"
          />
        ) : (
          <div className="w-full h-full bg-primary-100 flex items-center justify-center">
            <span className="material-symbols-rounded text-primary-300" style={{ fontSize: '32px' }}>
              image
            </span>
          </div>
        )}
      </div>

      {/* 中间内容 */}
      <div className="flex-1 py-3 px-3 flex flex-col justify-between min-w-0">
        <div>
          <h3 className="font-bold text-primary-900 text-sm sm:text-base truncate">
            {item.animeTitle || '未知番剧'}
          </h3>
          <p className="text-primary-500 text-xs mt-1">
            看到第 {item.episodeNumber} 话
          </p>
        </div>
        
        <div className="flex items-center gap-2 mt-2">
          <span className="px-2 py-0.5 bg-primary-100 text-primary-600 text-xs rounded-full">
            {formatProgress(item.time)}
          </span>
        </div>
      </div>

      {/* 右侧按钮 */}
      <div className="flex flex-col justify-center gap-1 pr-2">
        {editMode ? (
          <button
            onClick={onDelete}
            className="p-2 rounded-full hover:bg-red-100 transition-colors"
            aria-label="删除"
          >
            <span className="material-symbols-rounded text-red-500" style={{ fontSize: '22px' }}>
              delete
            </span>
          </button>
        ) : (
          <>
            {/* 收藏按钮 */}
            <div className="relative">
              <button
                onClick={(e) => {
                  e.stopPropagation()
                  setShowCollectMenu(!showCollectMenu)
                }}
                className={`
                  p-2 rounded-full transition-all duration-200
                  ${collectType !== 0 
                    ? 'bg-primary-100 hover:bg-primary-200' 
                    : 'hover:bg-primary-100'
                  }
                `}
                aria-label="收藏"
              >
                <span 
                  className={`material-symbols-rounded transition-all duration-200 ${
                    collectType === 0 ? 'text-primary-400' : 'text-primary-600'
                  }`}
                  style={{ 
                    fontSize: '22px',
                    fontVariationSettings: collectType !== 0 ? "'FILL' 1" : "'FILL' 0"
                  }}
                >
                  {collectType === 0 ? 'favorite_border' : COLLECT_TYPE_ICONS[collectType]}
                </span>
              </button>

              {showCollectMenu && (
                <>
                  <div 
                    className="fixed inset-0 z-40"
                    onClick={(e) => {
                      e.stopPropagation()
                      setShowCollectMenu(false)
                    }}
                  />
                  <div className="absolute top-full right-0 mt-1 z-50 py-1 bg-white rounded-xl shadow-lg border border-primary-100 min-w-[100px]">
                    {([0, 1, 2, 3, 4, 5] as CollectType[]).map((type) => (
                      <button
                        key={type}
                        onClick={(e) => {
                          e.stopPropagation()
                          handleCollectChange(type)
                        }}
                        className={`
                          w-full flex items-center gap-2 px-3 py-1.5 text-xs transition-colors
                          ${collectType === type 
                            ? 'text-primary-600 bg-primary-50' 
                            : 'text-primary-700 hover:bg-primary-50'
                          }
                        `}
                      >
                        <span className="material-symbols-rounded" style={{ fontSize: '16px' }}>
                          {COLLECT_TYPE_ICONS[type]}
                        </span>
                        <span>{COLLECT_TYPE_LABELS[type]}</span>
                      </button>
                    ))}
                  </div>
                </>
              )}
            </div>

            {/* 详情按钮 */}
            <button
              onClick={onViewDetail}
              className="p-2 rounded-full hover:bg-primary-100 transition-colors"
              aria-label="番剧详情"
            >
              <span className="material-symbols-rounded text-primary-600" style={{ fontSize: '22px' }}>
                open_in_new
              </span>
            </button>
          </>
        )}
      </div>
    </div>
  )
}
