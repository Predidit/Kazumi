import { NextRequest, NextResponse } from 'next/server'
import { generateDanDanPlaySignature, getDanDanPlayTimestamp } from '@/lib/utils/signature'

const APP_ID = 'kvpx7qkqjh'

/**
 * GET /api/dandanplay/bangumi/bgm/[bgmId]
 * 通过BGM番剧ID获取弹弹番剧信息 - 照抄 DanmakuRequest.getDanmakuEpisodesByBangumiID
 * 
 * 支持查询参数:
 * - title: 番剧标题 (用于 BGM ID 查询失败时的备用搜索)
 */
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ bgmId: string }> }
) {
  const { bgmId } = await params
  const { searchParams } = new URL(request.url)
  const title = searchParams.get('title')

  try {
    // 照抄原项目: 使用 dandanplay 的 bgmtv API
    const path = `/api/v2/bangumi/bgmtv/${bgmId}`
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

    // 如果 BGM ID 查询成功，返回结果
    if (jsonData.bangumi?.animeId) {
      return NextResponse.json({
        bangumi: {
          animeId: jsonData.bangumi.animeId,
          animeTitle: jsonData.bangumi.animeTitle ?? '',
          type: jsonData.bangumi.type ?? '',
          typeDescription: jsonData.bangumi.typeDescription ?? '',
        },
        episodes: (jsonData.bangumi?.episodes || []).map((ep: any) => ({
          episodeId: ep.episodeId ?? 0,
          episodeTitle: ep.episodeTitle ?? '',
        })),
        errorCode: jsonData.errorCode ?? 0,
        success: true,
        errorMessage: '',
      })
    }

    // 如果 BGM ID 查询失败，尝试使用标题搜索 - 照抄原项目的 showDanmakuSwitch 备用方案
    if (title) {
      console.log(`BGM ID ${bgmId} not found in DanDanPlay, trying title search: ${title}`)
      const searchResult = await searchByTitle(title)
      if (searchResult) {
        return NextResponse.json(searchResult)
      }
    }

    // 都失败了，返回空结果
    return NextResponse.json({
      bangumi: null,
      episodes: [],
      errorCode: jsonData.errorCode ?? 0,
      success: false,
      errorMessage: jsonData.errorMessage || '未找到对应的弹幕库',
    })
  } catch (error) {
    console.error('Failed to fetch bangumi by bgm id:', error)
    
    // 如果主查询失败，尝试使用标题搜索作为备用
    if (title) {
      try {
        console.log(`BGM API failed, trying title search: ${title}`)
        const searchResult = await searchByTitle(title)
        if (searchResult) {
          return NextResponse.json(searchResult)
        }
      } catch (searchError) {
        console.error('Title search also failed:', searchError)
      }
    }
    
    return NextResponse.json(
      { 
        bangumi: null,
        episodes: [],
        error: 'Failed to fetch bangumi info',
        success: false,
      },
      { status: 500 }
    )
  }
}

/**
 * 通过标题搜索番剧 - 照抄原项目的 getDanmakuSearchResponse
 */
async function searchByTitle(title: string): Promise<any | null> {
  try {
    const path = `/api/v2/search/anime`
    const endPoint = `https://api.dandanplay.net${path}`
    
    const timestamp = getDanDanPlayTimestamp()
    const signature = generateDanDanPlaySignature(timestamp, path)

    const url = new URL(endPoint)
    url.searchParams.set('keyword', title)

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
      return null
    }

    const data = await response.json()
    
    // 返回第一个匹配结果
    if (data.animes && data.animes.length > 0) {
      const firstMatch = data.animes[0]
      return {
        bangumi: {
          animeId: firstMatch.animeId,
          animeTitle: firstMatch.animeTitle ?? '',
          type: firstMatch.type ?? '',
          typeDescription: firstMatch.typeDescription ?? '',
        },
        episodes: [], // 搜索结果不包含剧集列表
        errorCode: 0,
        success: true,
        errorMessage: '',
        searchResults: data.animes.map((anime: any) => ({
          animeId: anime.animeId,
          animeTitle: anime.animeTitle,
          type: anime.type,
          typeDescription: anime.typeDescription,
        })),
      }
    }

    return null
  } catch (error) {
    console.error('Search by title failed:', error)
    return null
  }
}
