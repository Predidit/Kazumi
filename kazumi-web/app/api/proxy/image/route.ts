import { NextRequest, NextResponse } from 'next/server'

/**
 * GET /api/proxy/image
 * 图片代理 - 解决 lain.bgm.tv 等域名的 CORS 问题
 */
export async function GET(request: NextRequest) {
  const url = request.nextUrl.searchParams.get('url')

  if (!url) {
    return NextResponse.json({ error: 'Missing url parameter' }, { status: 400 })
  }

  try {
    // 验证 URL 是否为允许的域名
    const parsedUrl = new URL(url)
    const allowedHosts = ['lain.bgm.tv', 'api.bgm.tv', 'bangumi.tv']
    
    if (!allowedHosts.some(host => parsedUrl.hostname.includes(host))) {
      return NextResponse.json({ error: 'Domain not allowed' }, { status: 403 })
    }

    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
        'Referer': 'https://bangumi.tv/',
        'Accept': 'image/*,*/*;q=0.8',
      },
    })

    if (!response.ok) {
      return NextResponse.json(
        { error: `Failed to fetch image: ${response.status}` },
        { status: response.status }
      )
    }

    const contentType = response.headers.get('content-type') || 'image/jpeg'
    const buffer = await response.arrayBuffer()

    return new NextResponse(buffer, {
      headers: {
        'Content-Type': contentType,
        'Cache-Control': 'public, max-age=86400, stale-while-revalidate=604800',
        'Access-Control-Allow-Origin': '*',
      },
    })
  } catch (error) {
    console.error('Image proxy error:', error)
    return NextResponse.json(
      { error: 'Failed to proxy image' },
      { status: 500 }
    )
  }
}
