import { NextRequest, NextResponse } from 'next/server'

/**
 * GET /api/bangumi/characters
 * 获取番剧角色列表 - 照抄 BangumiHTTP.getCharatersByBangumiID
 */
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const subjectId = searchParams.get('subject_id')

  if (!subjectId) {
    return NextResponse.json(
      { error: 'subject_id is required' },
      { status: 400 }
    )
  }

  try {
    // 照抄原项目: 使用 api.bgm.tv 的 characters API
    const response = await fetch(
      `https://api.bgm.tv/v0/subjects/${subjectId}/characters`,
      {
        headers: {
          'User-Agent': 'Kazumi/1.0',
          'Accept': 'application/json',
        },
      }
    )

    if (!response.ok) {
      throw new Error(`Bangumi API error: ${response.status}`)
    }

    const jsonData = await response.json()
    
    // 照抄原项目的数据处理方式 - CharacterItem.fromJson
    const characters = (jsonData || []).map((item: any) => {
      // 解析声优列表 - 照抄 ActorItem.fromJson
      const actors = (item.actors || []).map((actor: any) => ({
        id: actor.id ?? 0,
        name: actor.name ?? '',
        type: actor.type ?? 0,
        images: {
          small: actor.images?.small ?? '',
          medium: actor.images?.medium ?? '',
          grid: actor.images?.grid ?? '',
          large: actor.images?.large ?? '',
        },
      }))

      return {
        id: item.id ?? 0,
        type: item.type ?? 0,
        name: item.name ?? '',
        relation: item.relation ?? '未知',
        images: {
          small: item.images?.small ?? '',
          medium: item.images?.medium ?? '',
          grid: item.images?.grid ?? '',
          large: item.images?.large ?? '',
        },
        actors,
      }
    })

    return NextResponse.json(characters)
  } catch (error) {
    console.error('Failed to fetch characters:', error)
    return NextResponse.json(
      { error: 'Failed to fetch characters' },
      { status: 500 }
    )
  }
}
