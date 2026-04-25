import { NextRequest, NextResponse } from 'next/server'

/**
 * GET /api/bangumi/search
 * POST /api/bangumi/search
 * 搜索番剧 - 照抄 BangumiHTTP.bangumiSearch
 */
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const keyword = searchParams.get('keyword') || ''
  const offset = parseInt(searchParams.get('offset') || '0')
  const sort = searchParams.get('sort') || 'heat'
  const tags = searchParams.getAll('tags')

  return handleSearch(keyword, { tags, offset, sort })
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { keyword = '', tags = [], offset = 0, sort = 'heat' } = body
    return handleSearch(keyword, { tags, offset, sort })
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 })
  }
}

async function handleSearch(
  keyword: string,
  options: { tags?: string[]; offset?: number; sort?: string }
) {
  const { tags = [], offset = 0, sort = 'heat' } = options

  // 照抄原项目的搜索参数
  const params = {
    keyword,
    sort,
    filter: {
      type: [2],
      tag: tags,
      rank: sort === 'rank' ? ['>0', '<=99999'] : ['>=0', '<=99999'],
      nsfw: false,
    },
  }

  try {
    // 照抄原项目: 使用 api.bgm.tv 的搜索 API
    const url = `https://api.bgm.tv/v0/search/subjects?limit=20&offset=${offset}`
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Kazumi/1.0',
        'Accept': 'application/json',
      },
      body: JSON.stringify(params),
    })

    if (!response.ok) {
      throw new Error(`Bangumi API error: ${response.status}`)
    }

    const jsonData = await response.json()
    
    // 照抄原项目的数据处理方式
    const bangumiList = (jsonData.data || [])
      .map((jsonItem: any) => {
        // nameCn 处理逻辑 - 照抄原项目
        const nameCn = (jsonItem.name_cn || '') === ''
          ? ((jsonItem.nameCN || '') === '' ? jsonItem.name : jsonItem.nameCN)
          : jsonItem.name_cn

        return {
          id: jsonItem.id,
          type: jsonItem.type ?? 2,
          name: jsonItem.name || '',
          nameCn,
          summary: jsonItem.summary || '',
          date: jsonItem.date || '',
          images: jsonItem.images || {
            large: jsonItem.image || '',
            common: '',
            medium: '',
            small: '',
            grid: '',
          },
          rating: {
            rank: jsonItem.rating?.rank ?? 0,
            score: jsonItem.rating?.score ?? 0,
            total: jsonItem.rating?.total ?? 0,
          },
          tags: (jsonItem.tags || []).map((tag: any) => ({
            name: tag.name || '',
            count: tag.count || 0,
          })),
        }
      })
      // 照抄原项目: 过滤掉没有中文名的结果
      .filter((item: any) => item.nameCn !== '')

    return NextResponse.json({
      data: bangumiList,
      total: jsonData.total || bangumiList.length,
    })
  } catch (error) {
    console.error('Failed to search:', error)
    return NextResponse.json(
      { error: 'Failed to search anime' },
      { status: 500 }
    )
  }
}
