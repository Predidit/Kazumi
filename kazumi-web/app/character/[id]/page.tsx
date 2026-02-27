/**
 * Character Detail Page - 照抄原项目的 character_page.dart
 * 
 * 功能:
 * - 角色基本信息 (头像、名字、简介)
 * - 角色吐槽箱
 */

'use client'

import { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Image from 'next/image'
import { GlassCard } from '@/components/ui'

// 角色详情类型
interface CharacterDetail {
  id: number
  name: string
  nameCn?: string
  nameCN?: string // API 返回的是大写 CN
  image?: string
  images?: { large?: string; medium?: string; small?: string }
  summary?: string
  info?: string // API 返回的简化信息
  infobox?: Array<{ key: string; values?: Array<{ v: string; k?: string }>; value?: string | Array<{ v: string }> }>
}

// 角色评论类型
interface CharacterComment {
  id?: number
  user?: {
    id?: number
    username?: string
    nickname?: string
    avatar?: string | { small?: string; medium?: string; large?: string }
  }
  content?: string
  createdAt?: string
  updatedAt?: string
  rate?: number
}

// 安全获取图片 URL
// 照抄原项目: 角色详情页使用 large 尺寸
const safeImageUrl = (images: any, size: 'large' | 'medium' | 'small' | 'grid' = 'large'): string | null => {
  if (!images) return null
  // 按优先级获取图片 URL
  let url: string | null = null
  if (size === 'grid') {
    // 头像优先使用 grid (小尺寸正方形)
    url = images.grid || images.small || images.medium || images.large || null
  } else if (size === 'small') {
    url = images.small || images.grid || images.medium || images.large || null
  } else if (size === 'medium') {
    url = images.medium || images.large || images.small || images.grid || null
  } else {
    // large - 详情页大图
    url = images.large || images.medium || images.common || images.small || null
  }
  if (!url) return null
  if (url.includes('lain.bgm.tv') || url.includes('bgm.tv')) {
    return `/api/proxy/image?url=${encodeURIComponent(url)}`
  }
  return url
}

type TabType = '人物资料' | '吐槽箱'

export default function CharacterDetailPage() {
  const params = useParams()
  const router = useRouter()
  const characterId = parseInt(params.id as string) || 0

  const [character, setCharacter] = useState<CharacterDetail | null>(null)
  const [comments, setComments] = useState<CharacterComment[]>([])
  const [loadingCharacter, setLoadingCharacter] = useState(true)
  const [loadingComments, setLoadingComments] = useState(true)
  const [activeTab, setActiveTab] = useState<TabType>('人物资料')

  useEffect(() => {
    if (characterId > 0) {
      loadCharacter()
      loadComments()
    }
  }, [characterId])

  async function loadCharacter() {
    setLoadingCharacter(true)
    try {
      const response = await fetch(`/api/bangumi/character/${characterId}`)
      if (response.ok) {
        const data = await response.json()
        setCharacter(data)
      }
    } catch (err) {
      console.error('Failed to load character:', err)
    } finally {
      setLoadingCharacter(false)
    }
  }

  async function loadComments() {
    setLoadingComments(true)
    try {
      const response = await fetch(`/api/bangumi/character/${characterId}/comments`)
      if (response.ok) {
        const data = await response.json()
        setComments(Array.isArray(data) ? data : [])
      }
    } catch (err) {
      console.error('Failed to load comments:', err)
    } finally {
      setLoadingComments(false)
    }
  }

  // 解析 infobox 为可读文本
  const parseInfobox = (infobox: CharacterDetail['infobox']): string => {
    if (!infobox || !Array.isArray(infobox)) return ''
    return infobox
      .filter(item => {
        // 过滤掉空值
        if (item.values) {
          return item.values.some(v => v.v && v.v.trim() !== '')
        }
        if (Array.isArray(item.value)) {
          return item.value.some(v => v.v && v.v.trim() !== '')
        }
        return item.value && String(item.value).trim() !== ''
      })
      .map(item => {
        let value = ''
        if (item.values) {
          // Next API 格式: values 数组
          value = item.values.filter(v => v.v && v.v.trim() !== '').map(v => v.v).join(', ')
        } else if (Array.isArray(item.value)) {
          value = item.value.filter(v => v.v && v.v.trim() !== '').map(v => v.v).join(', ')
        } else {
          value = String(item.value || '')
        }
        return value ? `${item.key}: ${value}` : null
      })
      .filter(Boolean)
      .join('\n')
  }

  // 获取中文名 (兼容 nameCn 和 nameCN)
  const characterNameCn = character?.nameCn || character?.nameCN

  const imageUrl = character?.image || safeImageUrl(character?.images)

  return (
    <div className="min-h-screen bg-white safe-area-all">
      {/* Header */}
      <div className="sticky top-0 z-40 bg-white/80 backdrop-blur-sm border-b border-primary-100 safe-area-top">
        <div className="flex items-center gap-3 px-4 py-3">
          <button
            onClick={() => router.back()}
            className="w-10 h-10 flex items-center justify-center rounded-full bg-primary-100 hover:bg-primary-200 transition-colors"
          >
            <span className="material-symbols-rounded text-primary-600">arrow_back</span>
          </button>
          <h1 className="text-xl font-bold text-primary-900 truncate">
            {characterNameCn || character?.name || '角色详情'}
          </h1>
        </div>

        {/* Tab Bar */}
        <div className="flex border-b border-primary-100">
          {(['人物资料', '吐槽箱'] as TabType[]).map(tab => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`flex-1 py-3 text-sm font-medium transition-colors ${
                activeTab === tab
                  ? 'text-primary-600 border-b-2 border-primary-600'
                  : 'text-primary-400 hover:text-primary-600'
              }`}
            >
              {tab}
            </button>
          ))}
        </div>
      </div>

      {/* Content */}
      <div className="px-4 py-4 pb-24">
        {activeTab === '人物资料' ? (
          <CharacterInfoTab
            character={character}
            imageUrl={imageUrl}
            loading={loadingCharacter}
            onRetry={loadCharacter}
            parseInfobox={parseInfobox}
          />
        ) : (
          <CommentsTab
            comments={comments}
            loading={loadingComments}
            onRetry={loadComments}
          />
        )}
      </div>
    </div>
  )
}

/**
 * 人物资料 Tab
 */
interface CharacterInfoTabProps {
  character: CharacterDetail | null
  imageUrl: string | null
  loading: boolean
  onRetry: () => void
  parseInfobox: (infobox: CharacterDetail['infobox']) => string
}

function CharacterInfoTab({ character, imageUrl, loading, onRetry, parseInfobox }: CharacterInfoTabProps) {
  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="w-8 h-8 border-3 border-primary-500/30 border-t-primary-500 rounded-full animate-spin" />
      </div>
    )
  }

  if (!character || character.id === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <span className="material-symbols-rounded text-primary-300 text-5xl">person_off</span>
        <p className="text-primary-500">什么都没有找到 (´;ω;`)</p>
        <button
          onClick={onRetry}
          className="px-4 py-2 bg-primary-500 text-white rounded-full hover:bg-primary-600 transition-colors"
        >
          点击重试
        </button>
      </div>
    )
  }

  const info = parseInfobox(character.infobox)
  // 获取中文名 (兼容 nameCn 和 nameCN)
  const nameCn = character.nameCn || character.nameCN

  return (
    <div className="space-y-6">
      {/* 头像和基本信息 - 照抄原项目 character_page.dart 布局 */}
      <div className="flex gap-4">
        {/* 头像 - 照抄原项目: 宽度 30%, 高度自适应, 使用 large 图片 */}
        <div className="relative w-[30%] min-w-[100px] max-w-[160px] aspect-[2/3] flex-shrink-0 rounded-xl overflow-hidden bg-primary-100 shadow-md">
          {imageUrl ? (
            <Image
              src={imageUrl}
              alt={character.name}
              fill
              className="object-cover"
              unoptimized
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center">
              <span className="material-symbols-rounded text-primary-300 text-4xl">person</span>
            </div>
          )}
        </div>

        {/* 名字 */}
        <div className="flex-1 min-w-0">
          <h2 className="text-xl font-bold text-primary-900">{character.name}</h2>
          {nameCn && nameCn !== character.name && (
            <p className="text-primary-500 mt-1">{nameCn}</p>
          )}
          {/* 显示简化信息 */}
          {character.info && (
            <p className="text-primary-400 text-sm mt-2">{character.info}</p>
          )}
        </div>
      </div>

      {/* 基本信息 */}
      {info && (
        <GlassCard className="p-4">
          <h3 className="font-bold text-primary-900 mb-3">基本信息</h3>
          <p className="text-primary-600 text-sm whitespace-pre-line">{info}</p>
        </GlassCard>
      )}

      {/* 角色简介 */}
      {character.summary && (
        <GlassCard className="p-4">
          <h3 className="font-bold text-primary-900 mb-3">角色简介</h3>
          <p className="text-primary-600 text-sm whitespace-pre-line leading-relaxed">
            {character.summary}
          </p>
        </GlassCard>
      )}
    </div>
  )
}

/**
 * 吐槽箱 Tab
 */
interface CommentsTabProps {
  comments: CharacterComment[]
  loading: boolean
  onRetry: () => void
}

function CommentsTab({ comments, loading, onRetry }: CommentsTabProps) {
  if (loading) {
    return (
      <div className="space-y-4">
        {[1, 2, 3, 4].map(i => (
          <div key={i} className="animate-pulse flex gap-3">
            <div className="w-10 h-10 bg-primary-200 rounded-full flex-shrink-0" />
            <div className="flex-1 space-y-2">
              <div className="h-4 bg-primary-200 rounded w-24" />
              <div className="h-3 bg-primary-200 rounded w-full" />
            </div>
          </div>
        ))}
      </div>
    )
  }

  if (comments.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <span className="material-symbols-rounded text-primary-300 text-5xl">chat_bubble_outline</span>
        <p className="text-primary-500">什么都没有找到 (´;ω;`)</p>
        <button
          onClick={onRetry}
          className="px-4 py-2 bg-primary-500 text-white rounded-full hover:bg-primary-600 transition-colors"
        >
          点击重试
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {comments.map((comment, index) => {
        // 处理头像 URL - 兼容字符串和对象格式，使用 small 尺寸
        let avatarUrl: string | null = null
        if (comment.user?.avatar) {
          if (typeof comment.user.avatar === 'string') {
            avatarUrl = `/api/proxy/image?url=${encodeURIComponent(comment.user.avatar)}`
          } else {
            // 优先使用 small 尺寸 - 照抄原项目
            const avatarSrc = comment.user.avatar.small || comment.user.avatar.medium || comment.user.avatar.large
            if (avatarSrc) {
              avatarUrl = `/api/proxy/image?url=${encodeURIComponent(avatarSrc)}`
            }
          }
        }
        const nickname = comment.user?.nickname || comment.user?.username || '匿名用户'

        return (
          <div key={comment.id || index} className="flex gap-3 pb-4 border-b border-primary-100">
            {/* 头像 - 使用 small 尺寸 */}
            <div className="relative w-10 h-10 flex-shrink-0 rounded-full overflow-hidden bg-primary-100">
              {avatarUrl ? (
                <Image
                  src={avatarUrl}
                  alt={nickname}
                  fill
                  className="object-cover"
                  unoptimized
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center">
                  <span className="material-symbols-rounded text-primary-300 text-xl">person</span>
                </div>
              )}
            </div>

            {/* 内容 */}
            <div className="flex-1 min-w-0">
              <p className="font-medium text-primary-900 text-sm">{nickname}</p>
              {comment.content && (
                <p className="text-primary-600 text-sm mt-1 break-words">{comment.content}</p>
              )}
              {comment.createdAt && (
                <p className="text-primary-400 text-xs mt-1">
                  {new Date(comment.createdAt).toLocaleDateString('zh-CN')}
                </p>
              )}
            </div>
          </div>
        )
      })}
    </div>
  )
}
