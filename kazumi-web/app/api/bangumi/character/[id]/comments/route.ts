import { NextRequest, NextResponse } from 'next/server'
import { BANGUMI_NEXT_API_BASE, BANGUMI_HEADERS, Api, formatUrl } from '@/lib/api/config'

/**
 * GET /api/bangumi/character/[id]/comments
 * 获取角色吐槽 - 照抄原项目的 getCharacterCommentsByCharacterID
 * 使用 next.bgm.tv API
 */
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  const characterId = parseInt(id)

  if (!characterId || isNaN(characterId)) {
    return NextResponse.json({ error: 'Invalid character ID' }, { status: 400 })
  }

  try {
    // 照抄原项目: 使用 bangumiAPINextDomain + bangumiCharacterCommentsByIDNext
    const url = BANGUMI_NEXT_API_BASE + formatUrl(Api.bangumiCharacterCommentsByIDNext, [characterId])
    
    const response = await fetch(url, { 
      headers: BANGUMI_HEADERS,
      next: { revalidate: 300 } // 缓存5分钟
    })

    if (!response.ok) {
      console.error(`Bangumi API error: ${response.status} for character comments ${characterId}`)
      // 返回空数组而不是错误，保持页面可用
      return NextResponse.json([])
    }

    const data = await response.json()

    // 转换为前端需要的格式 - 照抄原项目的 CharacterCommentResponse
    // Next API 返回的是评论数组
    const comments = Array.isArray(data) ? data.map((comment: {
      id?: number
      user?: {
        id?: number
        username?: string
        nickname?: string
        avatar?: { large?: string; medium?: string; small?: string }
      }
      content?: string
      createdAt?: string
      rate?: number
    }) => ({
      id: comment.id,
      user: comment.user ? {
        id: comment.user.id,
        username: comment.user.username || '',
        nickname: comment.user.nickname || '',
        avatar: comment.user.avatar?.large || comment.user.avatar?.medium || null,
      } : null,
      content: comment.content || '',
      createdAt: comment.createdAt || '',
      rate: comment.rate,
    })) : []

    return NextResponse.json(comments)
  } catch (error) {
    console.error('Failed to fetch character comments:', error)
    // 返回空数组而不是错误
    return NextResponse.json([])
  }
}
