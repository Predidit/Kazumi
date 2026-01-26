import { NextRequest, NextResponse } from 'next/server'
import { Api } from '@/lib/api/config'

// Github 镜像地址 - 照抄原项目
const GITHUB_MIRROR = 'https://mirror.ghproxy.com/'

/**
 * GET /api/plugins/list
 * 获取插件列表 - 照抄 PluginHTTP.getPluginList
 * 
 * 原项目从远程规则仓库获取插件列表:
 * https://raw.githubusercontent.com/Predidit/KazumiRules/main/index.json
 * 
 * 支持 enableGitProxy 参数使用镜像
 */
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const source = searchParams.get('source') || 'local'
  const enableGitProxy = searchParams.get('enableGitProxy') === 'true'

  try {
    if (source === 'remote') {
      // 照抄原项目: 从远程规则仓库获取
      // 如果启用了 Git 镜像，使用镜像地址
      const baseUrl = enableGitProxy 
        ? GITHUB_MIRROR + Api.pluginShop.replace('https://', '')
        : Api.pluginShop
      
      const response = await fetch(`${baseUrl}index.json`, {
        headers: {
          'User-Agent': 'Kazumi/1.0',
          'Accept': 'application/json',
        },
        // 添加超时
        signal: AbortSignal.timeout(10000),
      })

      if (!response.ok) {
        throw new Error(`Plugin shop error: ${response.status}`)
      }

      const jsonData = await response.json()

      // 照抄原项目的数据处理方式 - PluginHTTPItem.fromJson
      const pluginList = jsonData.map((item: any) => ({
        name: item.name || '',
        version: item.version || '',
        useNativePlayer: item.useNativePlayer ?? true,
        author: item.author || '',
        lastUpdate: item.lastUpdate ?? 0,
      }))

      return NextResponse.json(pluginList)
    }

    // 从本地 public/plugins/index.json 获取完整插件配置
    const baseUrl = request.nextUrl.origin
    const response = await fetch(`${baseUrl}/plugins/index.json`)
    const plugins = await response.json()
    return NextResponse.json(plugins)
  } catch (error) {
    console.error('Failed to fetch plugin list:', error)
    
    // 如果远程获取失败，回退到本地
    try {
      const baseUrl = request.nextUrl.origin
      const response = await fetch(`${baseUrl}/plugins/index.json`)
      const plugins = await response.json()
      return NextResponse.json(plugins)
    } catch (fallbackError) {
      return NextResponse.json(
        { error: 'Failed to fetch plugin list' },
        { status: 500 }
      )
    }
  }
}
