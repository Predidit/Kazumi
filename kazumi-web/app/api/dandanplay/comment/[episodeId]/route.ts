import { NextRequest, NextResponse } from 'next/server'
import { generateDanDanPlaySignature, getDanDanPlayTimestamp } from '@/lib/utils/signature'

const APP_ID = 'kvpx7qkqjh'

/**
 * GET /api/dandanplay/comment/[episodeId]
 * 获取弹幕 - 照抄 DanmakuRequest.getDanDanmakuByEpisodeID
 * 
 * 原项目弹幕格式 (Danmaku.fromJson):
 * - p: "time,mode,color,source" 格式的字符串
 * - m: 弹幕内容
 */
export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ episodeId: string }> }
) {
  const { episodeId } = await params

  try {
    // 照抄原项目: 使用 dandanplay 的 comment API
    const path = `/api/v2/comment/${episodeId}`
    const endPoint = `https://api.dandanplay.net${path}`
    const url = new URL(endPoint)
    url.searchParams.set('withRelated', 'true')
    
    // 生成签名 - 照抄原项目 (使用秒级时间戳)
    const timestamp = getDanDanPlayTimestamp()
    const signature = generateDanDanPlaySignature(timestamp, path)

    console.log(`Danmaku: final request URL ${url.toString()}`)

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
    const comments = jsonData.comments || []

    // 照抄原项目的数据格式 - 保持原始 p 和 m 格式
    // 让前端的 parseDanmakuComment 来解析
    return NextResponse.json({
      count: comments.length,
      comments: comments.map((comment: any) => ({
        p: comment.p || '',
        m: comment.m || '',
      })),
    })
  } catch (error) {
    console.error('Failed to fetch danmaku:', error)
    return NextResponse.json(
      { error: 'Failed to fetch danmaku', comments: [] },
      { status: 500 }
    )
  }
}
