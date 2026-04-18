import { NextRequest, NextResponse } from 'next/server'

/**
 * GET /api/plugins/test/roads
 * 插件章节测试 - 返回播放列表
 * 照抄原项目的 querychapterRoads
 */
export async function GET(request: NextRequest) {
  const url = request.nextUrl.searchParams.get('url')
  const pluginName = request.nextUrl.searchParams.get('plugin')

  if (!url || !pluginName) {
    return NextResponse.json({ error: 'Missing url or plugin' }, { status: 400 })
  }

  try {
    // 加载插件配置
    const pluginsResponse = await fetch(new URL('/plugins/index.json', request.url))
    const plugins = await pluginsResponse.json()
    const plugin = plugins.find((p: any) => p.name === pluginName)

    if (!plugin) {
      return NextResponse.json({ error: 'Plugin not found' }, { status: 404 })
    }

    if (!plugin.chapterRoads) {
      return NextResponse.json({ roads: [] })
    }

    // 发起请求获取章节页面
    const headers: Record<string, string> = {
      'User-Agent': plugin.userAgent || 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
    }
    if (plugin.referer) {
      headers['Referer'] = plugin.referer
    }

    const response = await fetch(url, { headers })

    if (!response.ok) {
      return NextResponse.json({ 
        error: `Roads request failed: ${response.status}`,
        roads: []
      })
    }

    const html = await response.text()

    // 简单的章节解析 (Web 端简化版)
    const roads: Array<{ name: string; data: string[]; identifier: string[] }> = []
    
    // 尝试提取章节列表
    // 这是简化版本，实际应该使用 XPath
    const episodeRegex = /<a[^>]*href=["']([^"']+)["'][^>]*>([^<]*第?\d+[话集期]?[^<]*)</gi
    const episodes: Array<{ name: string; url: string }> = []
    let match
    while ((match = episodeRegex.exec(html)) !== null && episodes.length < 100) {
      const [, href, text] = match
      if (text.trim() && href) {
        episodes.push({
          name: text.trim(),
          url: href.startsWith('http') ? href : `${plugin.baseURL}${href}`
        })
      }
    }

    if (episodes.length > 0) {
      roads.push({
        name: '默认线路',
        data: episodes.map(e => e.url),
        identifier: episodes.map(e => e.name)
      })
    }

    return NextResponse.json({ roads })
  } catch (error) {
    console.error('Plugin test roads error:', error)
    return NextResponse.json({
      error: error instanceof Error ? error.message : 'Test failed',
      roads: []
    })
  }
}
