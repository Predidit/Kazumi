import { NextRequest, NextResponse } from 'next/server'

/**
 * GET /api/plugins/test/search
 * 插件搜索测试 - 返回原始 HTML 和解析结果
 * 照抄原项目的 testSearchRequest + testQueryBangumi
 */
export async function GET(request: NextRequest) {
  const keyword = request.nextUrl.searchParams.get('keyword')
  const pluginName = request.nextUrl.searchParams.get('plugin')

  if (!keyword || !pluginName) {
    return NextResponse.json({ error: 'Missing keyword or plugin' }, { status: 400 })
  }

  try {
    // 加载插件配置
    const pluginsResponse = await fetch(new URL('/plugins/index.json', request.url))
    const plugins = await pluginsResponse.json()
    const plugin = plugins.find((p: any) => p.name === pluginName)

    if (!plugin) {
      return NextResponse.json({ error: 'Plugin not found' }, { status: 404 })
    }

    // 构建搜索 URL
    const searchUrl = plugin.searchURL.replace('{keyword}', encodeURIComponent(keyword))
    const fullUrl = searchUrl.startsWith('http') ? searchUrl : `${plugin.baseURL}${searchUrl}`

    // 发起搜索请求
    const headers: Record<string, string> = {
      'User-Agent': plugin.userAgent || 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
    }
    if (plugin.referer) {
      headers['Referer'] = plugin.referer
    }

    const response = await fetch(fullUrl, {
      method: plugin.usePost ? 'POST' : 'GET',
      headers,
    })

    if (!response.ok) {
      return NextResponse.json({ 
        error: `Search request failed: ${response.status}`,
        html: '',
        results: []
      })
    }

    const html = await response.text()

    // 简单的 XPath 解析 (Web 端简化版)
    // 实际项目中可能需要使用 cheerio 或其他 HTML 解析库
    const results: Array<{ name: string; src: string }> = []
    
    // 尝试使用正则提取链接和标题
    // 这是简化版本，实际应该使用 XPath
    const linkRegex = /<a[^>]*href=["']([^"']+)["'][^>]*>([^<]*)</gi
    let match
    while ((match = linkRegex.exec(html)) !== null && results.length < 20) {
      const [, href, text] = match
      if (text.trim() && href) {
        results.push({
          name: text.trim(),
          src: href.startsWith('http') ? href : `${plugin.baseURL}${href}`
        })
      }
    }

    return NextResponse.json({
      html: html.slice(0, 50000), // 限制返回的 HTML 长度
      results,
    })
  } catch (error) {
    console.error('Plugin test search error:', error)
    return NextResponse.json({
      error: error instanceof Error ? error.message : 'Test failed',
      html: '',
      results: []
    })
  }
}
