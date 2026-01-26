import { NextRequest, NextResponse } from 'next/server'
import { JSDOM } from 'jsdom'

/**
 * GET /api/plugins/roads
 * 获取播放列表 (线路) - 照抄 Plugin.querychapterRoads
 * 
 * 原项目使用 xpath_selector_html_parser 库:
 * - parse(htmlString).documentElement! 解析 HTML
 * - htmlElement.queryXPath(chapterRoads).nodes.forEach 遍历线路
 * - element.queryXPath(chapterResult).nodes.forEach 遍历章节
 * - item.node.attributes['href'] 获取链接
 * - item.node.text 获取名称
 * 
 * 原项目超时设置: connectTimeout: 12000ms, receiveTimeout: 12000ms
 */

// 照抄原项目: 12秒超时
const REQUEST_TIMEOUT = 12000

// 照抄原项目的 userAgentsList - lib/utils/constants.dart
const USER_AGENTS_LIST = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.1',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36 Edg/134.0.0.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36 Edg/136.0.0.0',
]

// 照抄原项目的 acceptLanguageList - lib/utils/constants.dart
const ACCEPT_LANGUAGE_LIST = [
  'zh-CN,zh;q=0.9',
  'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
  'zh-CN,zh-TW;q=0.9,zh;q=0.8,en-US;q=0.7,en;q=0.6',
]

/**
 * 带超时的 fetch - 照抄原项目的 12 秒超时
 */
async function fetchWithTimeout(
  url: string, 
  options: RequestInit, 
  timeout: number = REQUEST_TIMEOUT
): Promise<Response> {
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), timeout)
  
  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    })
    return response
  } finally {
    clearTimeout(timeoutId)
  }
}

/**
 * 使用 XPath 查询节点列表 - 照抄原项目 htmlElement.queryXPath(xpath).nodes
 * 
 * 关键: 原项目的 xpath_selector_html_parser 库在处理相对 XPath 时，
 * 会自动将 // 开头的路径转换为相对于上下文节点的路径。
 * 
 * 在 JavaScript 的 document.evaluate 中:
 * - "//" 开头的 XPath 会从文档根开始搜索
 * - "./" 或 "." 开头的 XPath 会从上下文节点开始搜索
 * 
 * 为了匹配原项目行为，当上下文节点不是 document 时，
 * 需要将 "//" 转换为 ".//" 或 "descendant-or-self::"
 */
function queryXPathNodes(document: Document, contextNode: Node, xpath: string): Node[] {
  // 如果上下文节点不是 document，且 XPath 以 // 开头，转换为相对路径
  let adjustedXPath = xpath
  if (contextNode !== document && contextNode !== document.documentElement) {
    if (xpath.startsWith('//')) {
      // 将 // 转换为 .// 使其相对于上下文节点
      adjustedXPath = '.' + xpath
    }
  }
  
  const result = document.evaluate(
    adjustedXPath,
    contextNode,
    null,
    5, // XPathResult.ORDERED_NODE_ITERATOR_TYPE
    null
  )
  
  const nodes: Node[] = []
  let node: Node | null
  while ((node = result.iterateNext())) {
    nodes.push(node)
  }
  return nodes
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const url = searchParams.get('url')
  const pluginName = searchParams.get('plugin')

  if (!url || !pluginName) {
    return NextResponse.json(
      { error: 'url and plugin are required' },
      { status: 400 }
    )
  }

  try {
    // 获取插件配置
    const baseUrl = request.nextUrl.origin
    const pluginsResponse = await fetch(`${baseUrl}/plugins/index.json`)
    const plugins = await pluginsResponse.json()
    const plugin = plugins.find((p: any) => p.name === pluginName)

    if (!plugin) {
      return NextResponse.json(
        { error: `Plugin ${pluginName} not found` },
        { status: 404 }
      )
    }

    // 照抄原项目 querychapterRoads: 预处理URL
    // if (!url.contains('https')) { url = url.replaceAll('http', 'https'); }
    // if (url.contains(baseUrl)) { queryURL = url; } else { queryURL = baseUrl + url; }
    let queryURL = url
    
    // 照抄原项目: 如果 URL 不包含 https，把 http 替换成 https
    if (!queryURL.includes('https')) {
      queryURL = queryURL.replace(/http/g, 'https')
    }
    
    // 照抄原项目: 如果 URL 包含 baseUrl，直接使用；否则拼接 baseUrl
    // 注意: baseURL 可能以 / 结尾，需要处理
    const baseURLWithoutTrailingSlash = plugin.baseURL.replace(/\/$/, '')
    const baseURLHttps = baseURLWithoutTrailingSlash.replace(/^http:/, 'https:')
    
    if (!queryURL.includes(baseURLHttps) && !queryURL.includes(baseURLWithoutTrailingSlash)) {
      // URL 不包含 baseUrl，需要拼接
      // 如果 queryURL 以 / 开头，直接拼接；否则加上 /
      if (queryURL.startsWith('/')) {
        queryURL = baseURLWithoutTrailingSlash + queryURL
      } else if (queryURL.startsWith('http')) {
        // 已经是完整 URL，不需要拼接
      } else {
        queryURL = baseURLWithoutTrailingSlash + '/' + queryURL
      }
    }

    // 照抄原项目: Utils.getRandomAcceptedLanguage()
    const acceptLanguage = ACCEPT_LANGUAGE_LIST[Math.floor(Math.random() * ACCEPT_LANGUAGE_LIST.length)]

    // 照抄原项目: Utils.getRandomUA()
    const userAgent = plugin.userAgent || USER_AGENTS_LIST[Math.floor(Math.random() * USER_AGENTS_LIST.length)]

    let response: Response
    try {
      response = await fetchWithTimeout(queryURL, {
        headers: {
          'referer': `${plugin.baseURL}/`,
          'Accept-Language': acceptLanguage,
          'Connection': 'keep-alive',
          'User-Agent': userAgent,
        },
      })
    } catch (fetchError) {
      // 照抄原项目: 网络错误时返回空结果
      if (fetchError instanceof Error) {
        if (fetchError.name === 'AbortError') {
          console.error(`Plugin ${plugin.name}: Request timeout (${REQUEST_TIMEOUT}ms)`)
        } else {
          console.error(`Plugin ${plugin.name}: Network error - ${fetchError.message}`)
        }
      }
      return NextResponse.json({ roads: [] })
    }

    // 检查响应状态
    if (!response.ok) {
      console.error(`Plugin ${plugin.name}: HTTP ${response.status}`)
      return NextResponse.json({ roads: [] })
    }

    const htmlString = await response.text()
    const roadList: { name: string; data: string[]; identifier: string[] }[] = []

    try {
      // 照抄原项目: var htmlElement = parse(htmlString).documentElement!
      // 使用 JSDOM 解析 HTML (支持 document.evaluate XPath)
      const dom = new JSDOM(htmlString)
      const document = dom.window.document

      // 照抄原项目: htmlElement.queryXPath(chapterRoads).nodes.forEach
      const roadNodes = queryXPathNodes(document, document, plugin.chapterRoads)
      
      let count = 1
      for (const element of roadNodes) {
        try {
          const chapterUrlList: string[] = []
          const chapterNameList: string[] = []

          // 照抄原项目: element.queryXPath(chapterResult).nodes.forEach
          const chapterNodes = queryXPathNodes(document, element, plugin.chapterResult)
          
          for (const item of chapterNodes) {
            // 照抄原项目: item.node.attributes['href']
            let itemUrl = ''
            if (item instanceof dom.window.Element) {
              itemUrl = item.getAttribute('href') || ''
            }
            
            // 照抄原项目: item.node.text
            const itemName = (item.textContent || '').trim()
            
            if (itemUrl) {
              chapterUrlList.push(itemUrl)
              // 照抄原项目: itemName.replaceAll(RegExp(r'\s+'), '')
              chapterNameList.push(itemName.replace(/\s+/g, ''))
            }
          }

          // 照抄原项目: if (chapterUrlList.isNotEmpty && chapterNameList.isNotEmpty)
          if (chapterUrlList.length > 0 && chapterNameList.length > 0) {
            roadList.push({
              name: `播放列表${count}`,
              data: chapterUrlList,
              identifier: chapterNameList,
            })
            count++
          }
        } catch (parseErr) {
          // 照抄原项目: catch (_) {} - 静默忽略单个项目的解析错误
        }
      }
    } catch (parseError) {
      console.error(`XPath parse error for ${plugin.name}:`, parseError)
    }

    return NextResponse.json({ roads: roadList })
  } catch (error) {
    console.error('Failed to get roads:', error)
    return NextResponse.json(
      { error: 'Failed to get roads' },
      { status: 500 }
    )
  }
}
