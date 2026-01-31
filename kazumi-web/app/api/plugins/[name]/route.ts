import { NextRequest, NextResponse } from 'next/server'
import { Api } from '@/lib/api/config'

/**
 * GET /api/plugins/[name]
 * 获取单个插件配置 - 照抄 PluginHTTP.getPlugin
 * 
 * 原项目从远程规则仓库获取插件配置:
 * https://raw.githubusercontent.com/Predidit/KazumiRules/main/{name}.json
 */
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ name: string }> }
) {
  const { name } = await params

  if (!name) {
    return NextResponse.json(
      { error: 'Plugin name is required' },
      { status: 400 }
    )
  }

  try {
    // 照抄原项目: 从远程规则仓库获取插件配置
    const response = await fetch(`${Api.pluginShop}${name}.json`, {
      headers: {
        'User-Agent': 'Kazumi/1.0',
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(10000),
    })

    if (!response.ok) {
      // 如果远程获取失败，尝试从本地获取
      const baseUrl = request.nextUrl.origin
      const localResponse = await fetch(`${baseUrl}/plugins/index.json`)
      const plugins = await localResponse.json()
      const plugin = plugins.find((p: any) => p.name === name)
      
      if (plugin) {
        return NextResponse.json(plugin)
      }
      
      return NextResponse.json(
        { error: `Plugin ${name} not found` },
        { status: 404 }
      )
    }

    const plugin = await response.json()
    return NextResponse.json(plugin)
  } catch (error) {
    console.error(`Failed to fetch plugin ${name}:`, error)
    
    // 回退到本地
    try {
      const baseUrl = request.nextUrl.origin
      const localResponse = await fetch(`${baseUrl}/plugins/index.json`)
      const plugins = await localResponse.json()
      const plugin = plugins.find((p: any) => p.name === name)
      
      if (plugin) {
        return NextResponse.json(plugin)
      }
    } catch (fallbackError) {
      console.error('Fallback error:', fallbackError)
    }
    
    return NextResponse.json(
      { error: `Failed to fetch plugin ${name}` },
      { status: 500 }
    )
  }
}
