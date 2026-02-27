import { NextRequest, NextResponse } from 'next/server'

// 服务端缓存 - 按 offset 分页缓存
const cache = new Map<string, { data: any; timestamp: number }>()
const CACHE_TTL = 5 * 60 * 1000 // 5 minutes

/**
 * GET /api/bangumi/trending
 * 获取热门番剧列表 - 照抄 BangumiHTTP.getBangumiTrendsList
 */
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const type = parseInt(searchParams.get('type') || '2')
  const limit = parseInt(searchParams.get('limit') || '24')
  const offset = parseInt(searchParams.get('offset') || '0')
  
  const cacheKey = `trending-${type}-${limit}-${offset}`

  try {
    // 检查服务端缓存
    const now = Date.now()
    const cached = cache.get(cacheKey)
    if (cached && (now - cached.timestamp) < CACHE_TTL) {
      return NextResponse.json(cached.data, {
        headers: {
          'X-Cache': 'HIT',
          'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600',
        },
      })
    }
    
    // 照抄原项目: 使用 next.bgm.tv 的 trending API
    const params = new URLSearchParams({
      type: String(type),
      limit: String(limit),
      offset: String(offset),
    })

    const response = await fetch(
      `https://next.bgm.tv/p1/trending/subjects?${params}`,
      {
        headers: {
          'User-Agent': 'Kazumi/1.0',
          'Accept': 'application/json',
        },
        // Next.js fetch 缓存
        next: { revalidate: 300 }, // 5 minutes
      }
    )

    if (!response.ok) {
      throw new Error(`Bangumi API error: ${response.status}`)
    }

    const jsonData = await response.json()
    
    // 照抄原项目的数据处理方式
    const bangumiList = (jsonData.data || []).map((jsonItem: any) => {
      const subject = jsonItem.subject || {}
      return {
        id: subject.id,
        type: subject.type ?? 2,
        name: subject.name || '',
        // nameCn 处理逻辑 - 照抄原项目
        nameCn: (subject.name_cn || '') === ''
          ? ((subject.nameCN || '') === '' ? subject.name : subject.nameCN)
          : subject.name_cn,
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
      }
    })

    const result = {
      data: bangumiList.map((item: any) => ({ 
        subject: item,
        count: 0, // 照抄原项目的 TrendingItem 结构
      })),
      total: jsonData.total || bangumiList.length,
    }
    
    // 更新服务端缓存
    cache.set(cacheKey, { data: result, timestamp: now })
    
    // 清理过期缓存 (保留最近 20 个)
    if (cache.size > 20) {
      const entries = Array.from(cache.entries())
      entries.sort((a, b) => a[1].timestamp - b[1].timestamp)
      for (let i = 0; i < entries.length - 20; i++) {
        cache.delete(entries[i][0])
      }
    }

    return NextResponse.json(result, {
      headers: {
        'X-Cache': 'MISS',
        'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600',
      },
    })
  } catch (error) {
    console.error('Failed to fetch trending:', error)
    return NextResponse.json(
      { error: 'Failed to fetch trending anime' },
      { status: 500 }
    )
  }
}
