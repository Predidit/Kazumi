import { NextRequest, NextResponse } from 'next/server'

/**
 * GET /api/bangumi/staff
 * 获取番剧制作人员 - 照抄 BangumiHTTP.getBangumiStaffByID
 */
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const subjectId = searchParams.get('subject_id')

  if (!subjectId) {
    return NextResponse.json(
      { error: 'subject_id is required' },
      { status: 400 }
    )
  }

  try {
    // 照抄原项目: 使用 next.bgm.tv 的 staffs/persons API
    const response = await fetch(
      `https://next.bgm.tv/p1/subjects/${subjectId}/staffs/persons`,
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
    
    // 照抄原项目的数据处理方式 - StaffResponse.fromJson
    const staffList = (jsonData.data || []).map((item: any) => ({
      // Staff - 照抄 Staff.fromJson
      staff: {
        id: item.staff?.id ?? 0,
        name: item.staff?.name ?? '',
        nameCN: item.staff?.nameCN ?? '',
        type: item.staff?.type ?? 0,
        info: item.staff?.info ?? '',
        comment: item.staff?.comment ?? 0,
        lock: item.staff?.lock ?? false,
        nsfw: item.staff?.nsfw ?? false,
        images: item.staff?.images ? {
          large: item.staff.images.large ?? '',
          medium: item.staff.images.medium ?? '',
          small: item.staff.images.small ?? '',
          grid: item.staff.images.grid ?? '',
        } : null,
      },
      // Positions - 照抄 Position.fromJson
      positions: (item.positions || []).map((pos: any) => ({
        type: {
          id: pos.type?.id ?? 0,
          en: pos.type?.en ?? '',
          cn: pos.type?.cn ?? '',
          jp: pos.type?.jp ?? '',
        },
        summary: pos.summary ?? '',
        appearEps: pos.appearEps ?? '',
      })),
    }))

    return NextResponse.json({
      data: staffList,
      total: jsonData.total ?? staffList.length,
    })
  } catch (error) {
    console.error('Failed to fetch staff:', error)
    return NextResponse.json(
      { error: 'Failed to fetch staff' },
      { status: 500 }
    )
  }
}
