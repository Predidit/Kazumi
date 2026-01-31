import { NextRequest, NextResponse } from 'next/server'

/**
 * GET /api/bangumi/comments
 * 获取番剧吐槽 (短评) - 照抄 BangumiHTTP.getBangumiCommentsByID
 */
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const subjectId = searchParams.get('subject_id')
  const offset = searchParams.get('offset') || '0'
  const limit = searchParams.get('limit') || '20'

  if (!subjectId) {
    return NextResponse.json(
      { error: 'subject_id is required' },
      { status: 400 }
    )
  }

  try {
    // 照抄原项目: 使用 next.bgm.tv 的 comments API
    const response = await fetch(
      `https://next.bgm.tv/p1/subjects/${subjectId}/comments?limit=${limit}&offset=${offset}`,
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
    
    // 照抄原项目的数据处理方式 - CommentResponse.fromJson
    const list = jsonData.list || jsonData.data || []
    
    const commentList = list.map((item: any) => ({
      // User - 照抄 User.fromJson
      user: {
        id: item.user?.id ?? 0,
        username: item.user?.username ?? '',
        nickname: item.user?.nickname ?? '',
        avatar: {
          small: item.user?.avatar?.small ?? '',
          medium: item.user?.avatar?.medium ?? '',
          large: item.user?.avatar?.large ?? '',
        },
        sign: item.user?.sign ?? '',
        joinedAt: item.user?.joinedAt ?? 0,
      },
      // Comment - 照抄 Comment.fromJson
      rate: item.rate ?? 0,
      comment: item.comment ?? '',
      updatedAt: item.updatedAt ?? 0,
    }))

    return NextResponse.json({
      commentList,
      total: jsonData.total ?? commentList.length,
    })
  } catch (error) {
    console.error('Failed to fetch comments:', error)
    return NextResponse.json(
      { error: 'Failed to fetch comments' },
      { status: 500 }
    )
  }
}
