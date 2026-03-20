import { NextRequest, NextResponse } from 'next/server'

// 服务端缓存 - 5分钟
let cachedData: { data: Record<string, any[]>; timestamp: number } | null = null
const CACHE_TTL = 5 * 60 * 1000 // 5 minutes

/**
 * GET /api/bangumi/calendar
 * 获取每日放送 - 照抄 BangumiHTTP.getCalendar
 */
export async function GET(request: NextRequest) {
  try {
    // 检查服务端缓存
    const now = Date.now()
    if (cachedData && (now - cachedData.timestamp) < CACHE_TTL) {
      return NextResponse.json(cachedData.data, {
        headers: {
          'X-Cache': 'HIT',
          'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600',
        },
      })
    }
    
    // 照抄原项目: 使用 next.bgm.tv 的 calendar API
    const response = await fetch('https://next.bgm.tv/p1/calendar', {
      headers: {
        'User-Agent': 'Kazumi/1.0',
        'Accept': 'application/json',
      },
      // Next.js fetch 缓存
      next: { revalidate: 300 }, // 5 minutes
    })

    if (!response.ok) {
      throw new Error(`Bangumi API error: ${response.status}`)
    }

    const jsonData = await response.json()
    
    // 照抄原项目的数据处理方式
    // 返回格式: { "1": [...], "2": [...], ..., "7": [...] }
    const bangumiCalendar: Record<string, any[]> = {}
    
    for (let i = 1; i <= 7; i++) {
      const bangumiList: any[] = []
      const jsonList = jsonData[String(i)] || []
      
      for (const jsonItem of jsonList) {
        try {
          const subject = jsonItem.subject || {}
          
          // nameCn 处理逻辑 - 照抄原项目
          const nameCn = (subject.name_cn || '') === ''
            ? ((subject.nameCN || '') === '' ? subject.name : subject.nameCN)
            : subject.name_cn

          bangumiList.push({
            id: subject.id,
            type: subject.type ?? 2,
            name: subject.name || '',
            nameCn,
            summary: subject.summary || '',
            date: subject.date || '',
            images: subject.images || {
              large: subject.image || '',
              common: '',
              medium: '',
              small: '',
              grid: '',
            },
            rating: {
              rank: subject.rating?.rank ?? 0,
              score: subject.rating?.score ?? 0,
              total: subject.rating?.total ?? 0,
            },
            tags: (subject.tags || []).map((tag: any) => ({
              name: tag.name || '',
              count: tag.count || 0,
            })),
          })
        } catch {}
      }
      
      bangumiCalendar[String(i)] = bangumiList
    }

    // 更新服务端缓存
    cachedData = { data: bangumiCalendar, timestamp: now }

    return NextResponse.json(bangumiCalendar, {
      headers: {
        'X-Cache': 'MISS',
        'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600',
      },
    })
  } catch (error) {
    console.error('Failed to fetch calendar:', error)
    return NextResponse.json(
      { error: 'Failed to fetch calendar' },
      { status: 500 }
    )
  }
}
