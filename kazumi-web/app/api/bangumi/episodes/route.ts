import { NextRequest, NextResponse } from 'next/server'

/**
 * GET /api/bangumi/episodes
 * 获取番剧剧集列表 - 照抄 BangumiHTTP.getBangumiEpisodeByID
 */
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const subjectId = searchParams.get('subject_id')
  const limit = searchParams.get('limit') || '100'
  const offset = searchParams.get('offset') || '0'

  if (!subjectId) {
    return NextResponse.json(
      { error: 'subject_id is required' },
      { status: 400 }
    )
  }

  try {
    // 照抄原项目: 使用 api.bgm.tv 的 episodes API
    const params = new URLSearchParams({
      subject_id: subjectId,
      limit,
      offset,
    })

    const response = await fetch(
      `https://api.bgm.tv/v0/episodes?${params}`,
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
    
    // 照抄原项目的数据处理方式 - EpisodeInfo.fromJson
    const episodes = (jsonData.data || []).map((ep: any) => ({
      id: ep.id ?? 0,
      type: ep.type ?? 0,
      name: ep.name ?? '',
      nameCn: ep.name_cn ?? '',
      sort: ep.sort ?? 0,
      ep: ep.ep ?? 0,
      airdate: ep.airdate ?? '',
      comment: ep.comment ?? 0,
      duration: ep.duration ?? '',
      desc: ep.desc ?? '',
      disc: ep.disc ?? 0,
      durationSeconds: ep.duration_seconds ?? 0,
    }))

    return NextResponse.json({
      data: episodes,
      total: jsonData.total || episodes.length,
    })
  } catch (error) {
    console.error('Failed to fetch episodes:', error)
    return NextResponse.json(
      { error: 'Failed to fetch episodes' },
      { status: 500 }
    )
  }
}
