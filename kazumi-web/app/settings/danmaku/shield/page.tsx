'use client'

/**
 * 弹幕屏蔽设置页面
 * 照抄原项目 lib/pages/settings/danmaku/danmaku_shield_settings.dart
 */

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { SafeAreaWrapper, GlassPanel, Input, Button } from '@/components/ui'
import { useAppStore } from '@/lib/store'

export default function DanmakuShieldPage() {
  const router = useRouter()
  const [keyword, setKeyword] = useState('')
  
  const shieldList = useAppStore((state) => state.shieldList)
  const addShieldKeyword = useAppStore((state) => state.addShieldKeyword)
  const removeShieldKeyword = useAppStore((state) => state.removeShieldKeyword)

  const handleAdd = () => {
    const trimmed = keyword.trim()
    if (trimmed) {
      addShieldKeyword(trimmed)
      setKeyword('')
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleAdd()
    }
  }

  return (
    <SafeAreaWrapper className="min-h-screen bg-black/90">
      {/* Header */}
      <div className="sticky top-0 z-10 backdrop-blur-xl bg-black/50 border-b border-white/10">
        <div className="flex items-center h-14 px-4">
          <button
            onClick={() => router.back()}
            className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-white/10 transition-colors"
          >
            <span className="material-symbols-rounded text-white/90">arrow_back</span>
          </button>
          <h1 className="ml-2 text-lg font-medium text-white/90">弹幕屏蔽</h1>
        </div>
      </div>

      {/* Content */}
      <div className="p-4 space-y-4">
        {/* Input Section */}
        <GlassPanel className="p-4 space-y-3">
          <div className="flex gap-2">
            <Input
              value={keyword}
              onChange={(e) => setKeyword(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="输入关键词或正则表达式"
              className="flex-1"
            />
            <Button onClick={handleAdd} variant="primary" size="sm">
              <span className="material-symbols-rounded text-sm mr-1">add</span>
              添加
            </Button>
          </div>
          <p className="text-xs text-white/50">
            以"/"开头和结尾将视作正则表达式, 如"/\d+/"表示屏蔽所有数字
          </p>
          <p className="text-sm text-white/70">
            已添加 {shieldList.length} 个关键词
          </p>
        </GlassPanel>

        {/* Keywords List */}
        {shieldList.length > 0 && (
          <GlassPanel className="p-4">
            <div className="flex flex-wrap gap-2">
              {shieldList.map((item, index) => (
                <div
                  key={index}
                  className="inline-flex items-center gap-1 px-3 py-1.5 rounded-full bg-white/10 text-sm text-white/80"
                >
                  <span className="max-w-[200px] truncate">{item}</span>
                  <button
                    onClick={() => removeShieldKeyword(item)}
                    className="w-5 h-5 flex items-center justify-center rounded-full hover:bg-white/20 transition-colors"
                  >
                    <span className="material-symbols-rounded text-base">close</span>
                  </button>
                </div>
              ))}
            </div>
          </GlassPanel>
        )}

        {/* Empty State */}
        {shieldList.length === 0 && (
          <div className="flex flex-col items-center justify-center py-12 text-white/40">
            <span className="material-symbols-rounded text-5xl mb-2">filter_alt_off</span>
            <p>暂无屏蔽关键词</p>
          </div>
        )}
      </div>
    </SafeAreaWrapper>
  )
}
