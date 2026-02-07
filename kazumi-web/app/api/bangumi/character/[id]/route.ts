import { NextRequest, NextResponse } from 'next/server'
import { BANGUMI_NEXT_API_BASE, BANGUMI_HEADERS, Api, formatUrl } from '@/lib/api/config'

/**
 * GET /api/bangumi/character/[id]
 * 获取角色详情 - 照抄原项目的 getCharacterByCharacterID
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
    // 照抄原项目: 使用 bangumiAPINextDomain + bangumiCharacterInfoByCharacterIDNext
    const url = BANGUMI_NEXT_API_BASE + formatUrl(Api.bangumiCharacterInfoByCharacterIDNext, [characterId])
    
    const response = await fetch(url, { 
      headers: BANGUMI_HEADERS,
      next: { revalidate: 3600 } // 缓存1小时
    })

    if (!response.ok) {
      console.error(`Bangumi API error: ${response.status} for character ${characterId}`)
      return NextResponse.json(
        { error: `Bangumi API error: ${response.status}` },
        { status: response.status }
      )
    }

    const data = await response.json()

    // 转换为前端需要的格式 - 照抄原项目的 CharacterFullItem
    const character = {
      id: data.id,
      name: data.name || '',
      nameCn: data.nameCN || data.name_cn || '',
      image: data.images?.large || data.images?.medium || data.image || null,
      images: data.images || null,
      summary: data.summary || '',
      infobox: data.infobox || [],
      // Next API 特有字段
      type: data.type,
      stat: data.stat,
    }

    return NextResponse.json(character)
  } catch (error) {
    console.error('Failed to fetch character:', error)
    return NextResponse.json(
      { error: 'Failed to fetch character' },
      { status: 500 }
    )
  }
}
