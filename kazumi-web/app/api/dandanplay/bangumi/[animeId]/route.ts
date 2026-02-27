import { NextRequest, NextResponse } from 'next/server'
import { generateDanDanPlaySignature, getDanDanPlayTimestamp } from '@/lib/utils/signature'

const APP_ID = 'kvpx7qkqjh'

/**
 * GET /api/dandanplay/bangumi/[animeId]
 * 通过弹弹番剧ID获取番剧信息 - 照抄 DanmakuRequest.getDanDanEpisodesByDanDanBangumiID
 */
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ animeId: string }> }
) {
  const { animeId } = await params

  try {
    // 照抄原项目: 使用 dandanplay 的 bangumi API
    const path = `/api/v2/bangumi/${animeId}`
    const endPoint = `https://api.dandanplay.net${path}`
    
    // 生成签名 - 照抄原项目 (使用秒级时间戳)
    const timestamp = getDanDanPlayTimestamp()
    const signature = generateDanDanPlaySignature(timestamp, path)

    const response = await fetch(endPoint, {
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

    // 照抄原项目的数据处理方式 - DanmakuEpisodeResponse.fromJson
    return NextResponse.json({
      bangumiId: jsonData.bangumi?.animeId ?? 0,
      bangumiTitle: jsonData.bangumi?.animeTitle ?? '',
      type: jsonData.bangumi?.type ?? '',
      typeDescription: jsonData.bangumi?.typeDescription ?? '',
      episodes: (jsonData.bangumi?.episodes || []).map((ep: any) => ({
        episodeId: ep.episodeId ?? 0,
        episodeTitle: ep.episodeTitle ?? '',
      })),
      errorCode: jsonData.errorCode ?? 0,
      success: jsonData.success ?? false,
      errorMessage: jsonData.errorMessage ?? '',
    })
  } catch (error) {
    console.error('Failed to fetch bangumi:', error)
    return NextResponse.json(
      { error: 'Failed to fetch bangumi info' },
      { status: 500 }
    )
  }
}
