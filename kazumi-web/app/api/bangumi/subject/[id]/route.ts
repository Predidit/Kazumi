import { NextRequest, NextResponse } from 'next/server'

// 解析别名 - 照抄 parseBangumiAliases
const parseBangumiAliases = (jsonData: any): string[] => {
  if (jsonData.infobox && Array.isArray(jsonData.infobox)) {
    for (const item of jsonData.infobox) {
      if (item && item.key === '别名') {
        const value = item.value
        if (Array.isArray(value)) {
          return value
            .map((element: any) => {
              if (element && element.v) {
                return String(element.v)
              }
              return ''
            })
            .filter((alias: string) => alias.length > 0)
        }
      }
    }
  }
  return []
}

// 解析投票数 - 照抄 parseBangumiVoteCount
const parseBangumiVoteCount = (jsonData: any): number[] => {
  if (!jsonData.rating) {
    return []
  }
  const count = jsonData.rating.count
  // For api.bgm.tv
  if (count && typeof count === 'object' && !Array.isArray(count)) {
    return Array.from({ length: 10 }, (_, i) => count[String(i + 1)] || 0)
  }
  // For next.bgm.tv
  if (Array.isArray(count)) {
    return count.map((e: any) => Number(e) || 0)
  }
  return []
}

// 计算星期几 - 照抄 Utils.dateStringToWeekday
const dateStringToWeekday = (dateStr: string): number => {
  try {
    const date = new Date(dateStr)
    const day = date.getDay()
    return day === 0 ? 7 : day
  } catch {
    return 1
  }
}

/**
 * GET /api/bangumi/subject/[id]
 * 获取番剧详情 - 照抄 BangumiHTTP.getBangumiInfoByID
 */
export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params

  try {
    // 照抄原项目: 使用 api.bgm.tv 的 subject API
    const response = await fetch(`https://api.bgm.tv/v0/subjects/${id}`, {
      headers: {
        'User-Agent': 'Kazumi/1.0',
        'Accept': 'application/json',
      },
    })

    if (!response.ok) {
      throw new Error(`Bangumi API error: ${response.status}`)
    }

    const json = await response.json()
    
    // 照抄原项目的数据处理方式 - BangumiItem.fromJson
    const tagList = (json.tags || []).map((i: any) => ({
      name: i.name || '',
      count: i.count || 0,
    }))
    const bangumiAlias = parseBangumiAliases(json)
    const voteList = parseBangumiVoteCount(json)

    // nameCn 处理逻辑 - 照抄原项目
    let nameCn = json.name_cn || ''
    if (nameCn === '') {
      nameCn = json.nameCN || ''
      if (nameCn === '') {
        nameCn = json.name || ''
      }
    }

    const bangumiItem = {
      id: json.id,
      type: json.type ?? 2,
      name: json.name || '',
      nameCn,
      summary: json.summary || '',
      airDate: json.date || '',
      date: json.date || '',
      airWeekday: dateStringToWeekday(json.date || '2000-11-11'),
      rank: json.rating?.rank ?? 0,
      images: json.images || {
        large: json.image || '',
        common: '',
        medium: '',
        small: '',
        grid: '',
      },
      tags: tagList,
      alias: bangumiAlias,
      ratingScore: Number((json.rating?.score ?? 0).toFixed(1)),
      votes: json.rating?.total ?? 0,
      votesCount: voteList,
      info: json.info || '',
      // 额外字段
      rating: {
        rank: json.rating?.rank ?? 0,
        score: json.rating?.score ?? 0,
        total: json.rating?.total ?? 0,
        count: json.rating?.count || {},
      },
      eps: json.eps ?? 0,
      totalEpisodes: json.total_episodes ?? json.eps ?? 0,
      infobox: json.infobox || [],
    }

    return NextResponse.json(bangumiItem)
  } catch (error) {
    console.error('Failed to fetch subject:', error)
    return NextResponse.json(
      { error: 'Failed to fetch anime details' },
      { status: 500 }
    )
  }
}
