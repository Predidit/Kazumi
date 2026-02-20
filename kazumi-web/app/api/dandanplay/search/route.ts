import { NextRequest, NextResponse } from 'next/server'
import { generateDanDanPlaySignature, getDanDanPlayTimestamp } from '@/lib/utils/signature'

const APP_ID = 'kvpx7qkqjh'

/**
 * GET /api/dandanplay/search
 * 搜索弹弹番剧 - 照抄 DanmakuRequest.getDanmakuSearchResponse
 */
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const keyword = searchParams.get('keyword')

  if (!keyword) {
    return NextResponse.json(
      { error: 'keyword is required' },
      { status: 400 }
    )
  }

  try {
    // 照抄原项目: 使用 dandanplay 的 search API
    const path = '/api/v2/search/anime'
    const endPoint = `https://api.dandanplay.net${path}`
    const url = new URL(endPoint)
    url.searchParams.set('keyword', keyword)
    
    // 生成签名 - 照抄原项目 (使用秒级时间戳)
    const timestamp = getDanDanPlayTimestamp()
    const signature = generateDanDanPlaySignature(timestamp, path)

    const response = await fetch(url.toString(), {
      headers: {
        'User-Agent': 'Kazumi/1.0',
        'Accept': 'application/json',
        'X-AppId': APP_ID,
        'X-Timestamp': timestamp,
        'X-Signature': signature,
      },
    })

    if (!response.ok) {
      throw new Error(`DanDanPlay API error: ${response.status}`)
    }

    const jsonData = await response.json()

    // 照抄原项目的数据处理方式 - DanmakuSearchResponse.fromJson
    return NextResponse.json({
      hasMore: jsonData.hasMore ?? false,
      animes: (jsonData.animes || []).map((anime: any) => ({
        animeId: anime.animeId ?? 0,
        animeTitle: anime.animeTitle ?? '',
        type: anime.type ?? '',
        typeDescription: anime.typeDescription ?? '',
        episodes: (anime.episodes || []).map((ep: any) => ({
          episodeId: ep.episodeId ?? 0,
          episodeTitle: ep.episodeTitle ?? '',
        })),
      })),
      errorCode: jsonData.errorCode ?? 0,
      success: jsonData.success ?? false,
      errorMessage: jsonData.errorMessage ?? '',
    })
  } catch (error) {
    console.error('Failed to search danmaku:', error)
    return NextResponse.json(
      { error: 'Failed to search danmaku' },
      { status: 500 }
    )
  }
}
