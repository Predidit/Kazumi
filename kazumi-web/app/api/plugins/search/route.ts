import { NextRequest, NextResponse } from 'next/server'
import { JSDOM } from 'jsdom'

/**
 * GET /api/plugins/search
 * 使用插件搜索番剧 - 照抄 Plugin.queryBangumi
 * 
 * 原项目使用 xpath_selector_html_parser 库:
 * - parse(htmlString).documentElement! 解析 HTML
 * - htmlElement.queryXPath(searchList).nodes.forEach 遍历结果
 * - element.queryXPath(searchName).node!.text?.trim() 获取名称
 * - element.queryXPath(searchResult).node!.attributes['href'] 获取链接
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
  'zh-TW,zh;q=0.9,zh;q=0.8,en-US;q=0.7,en;q=0.6',
]

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const keyword = searchParams.get('keyword')
  const pluginName = searchParams.get('plugin')

  if (!keyword) {
    return NextResponse.json(
      { error: 'keyword is required' },
      { status: 400 }
    )
  }

  try {
    // 获取所有插件配置
    const baseUrl = request.nextUrl.origin
    const pluginsResponse = await fetch(`${baseUrl}/plugins/index.json`)
    const plugins = await pluginsResponse.json()

    // 如果指定了插件名，只搜索该插件
    const pluginsToSearch = pluginName 
      ? plugins.filter((p: any) => p.name === pluginName)
      : plugins

    const allResults: { pluginName: string; name: string; src: string }[] = []

    // 照抄原项目: 并发搜索所有插件
    const searchPromises = pluginsToSearch.map(async (plugin: any) => {
      try {
        const result = await searchWithPlugin(plugin, keyword)
        return result
      } catch (err) {
        // 照抄原项目: 静默处理错误，不影响其他插件
        console.error(`Plugin ${plugin.name} search failed:`, err instanceof Error ? err.message : err)
        return { pluginName: plugin.name, data: [] }
      }
    })

    const results = await Promise.all(searchPromises)
    
    // 合并所有结果
    for (const result of results) {
      for (const item of result.data) {
        allResults.push({
          pluginName: result.pluginName,
          name: item.name,
          src: item.src,
        })
      }
    }

    return NextResponse.json({
      results: allResults,
    })
  } catch (error) {
    console.error('Failed to search with plugins:', error)
    return NextResponse.json(
      { error: 'Failed to search' },
      { status: 500 }
    )
  }
}

/**
 * 带超时的 fetch - 照抄原项目的 12 秒超时
 * 添加重定向跟随支持
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
      redirect: 'follow', // 跟随重定向
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

/**
 * 使用 XPath 查询单个节点 - 照抄原项目 element.queryXPath(xpath).node
 * 
 * 同样需要处理相对路径问题
 */
function queryXPathNode(document: Document, contextNode: Node, xpath: string): Node | null {
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
    9, // XPathResult.FIRST_ORDERED_NODE_TYPE
    null
  )
  return result.singleNodeValue
}

/**
 * 使用单个插件搜索 - 照抄 Plugin.queryBangumi
 */
async function searchWithPlugin(plugin: any, keyword: string): Promise<{ pluginName: string; data: { name: string; src: string }[] }> {
  // 照抄原项目: 构建搜索URL
  const queryURL = plugin.searchURL.replace('@keyword', encodeURIComponent(keyword))
  
  // 照抄原项目: Utils.getRandomAcceptedLanguage()
  const acceptLanguage = ACCEPT_LANGUAGE_LIST[Math.floor(Math.random() * ACCEPT_LANGUAGE_LIST.length)]

  // 照抄原项目: Utils.getRandomUA()
  const userAgent = plugin.userAgent || USER_AGENTS_LIST[Math.floor(Math.random() * USER_AGENTS_LIST.length)]

  let response: Response

  try {
    if (plugin.usePost) {
      // POST 请求 - 照抄原项目
      const uri = new URL(queryURL)
      const queryParams = Object.fromEntries(uri.searchParams)
      const postUri = `${uri.protocol}//${uri.host}${uri.pathname}`

      response = await fetchWithTimeout(postUri, {
        method: 'POST',
        headers: {
          'referer': `${plugin.baseURL}/`,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept-Language': acceptLanguage,
          'Connection': 'keep-alive',
          'User-Agent': userAgent,
        },
        body: new URLSearchParams(queryParams),
      })
    } else {
      // GET 请求 - 照抄原项目
      response = await fetchWithTimeout(queryURL, {
        headers: {
          'referer': `${plugin.baseURL}/`,
          'Accept-Language': acceptLanguage,
          'Connection': 'keep-alive',
          'User-Agent': userAgent,
        },
      })
    }
  } catch (fetchError) {
    // 照抄原项目: 网络错误时返回空结果
    if (fetchError instanceof Error) {
      if (fetchError.name === 'AbortError') {
        console.error(`Plugin ${plugin.name}: Request timeout (${REQUEST_TIMEOUT}ms)`)
      } else {
        console.error(`Plugin ${plugin.name}: Network error - ${fetchError.message}`)
      }
    }
    return { pluginName: plugin.name, data: [] }
  }

  // 检查响应状态
  if (!response.ok) {
    console.error(`Plugin ${plugin.name}: HTTP ${response.status}`)
    return { pluginName: plugin.name, data: [] }
  }

  const htmlString = await response.text()
  const searchItems: { name: string; src: string }[] = []

  try {
    // 照抄原项目: var htmlElement = parse(htmlString).documentElement!
    // 使用 JSDOM 解析 HTML (支持 document.evaluate XPath)
    const dom = new JSDOM(htmlString)
    const document = dom.window.document

    // 照抄原项目: htmlElement.queryXPath(searchList).nodes.forEach
    const listNodes = queryXPathNodes(document, document, plugin.searchList)
    
    for (const element of listNodes) {
      try {
        // 照抄原项目: element.queryXPath(searchName).node!.text?.trim()
        const nameNode = queryXPathNode(document, element, plugin.searchName)
        
        // 照抄原项目: element.queryXPath(searchResult).node!.attributes['href']
        const resultNode = queryXPathNode(document, element, plugin.searchResult)
        
        let name = ''
        let src = ''
        
        // 获取名称 - 照抄原项目: .text?.trim()
        if (nameNode) {
          name = (nameNode.textContent || '').trim()
        }
        
        // 获取链接 - 照抄原项目: .attributes['href']
        // 源项目直接保存 href，不做任何处理
        // 在 changeEpisode 中会检查是否包含 baseUrl
        if (resultNode && resultNode instanceof dom.window.Element) {
          src = resultNode.getAttribute('href') || ''
        }
        
        if (name && src) {
          searchItems.push({ name, src })
          // 照抄原项目的日志格式 - 注意: src 可能已经是完整URL
          if (src.startsWith('http')) {
            console.log(`Plugin: ${plugin.name} ${name} ${src}`)
          } else {
            console.log(`Plugin: ${plugin.name} ${name} ${plugin.baseURL}${src}`)
          }
        }
      } catch (parseErr) {
        // 照抄原项目: catch (_) {} - 静默忽略单个项目的解析错误
      }
    }
  } catch (parseError) {
    console.error(`XPath parse error for ${plugin.name}:`, parseError)
  }

  return {
    pluginName: plugin.name,
    data: searchItems,
  }
}
