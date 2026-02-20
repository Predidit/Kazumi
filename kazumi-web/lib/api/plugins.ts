/**
 * Plugin API 请求模块 - 照抄 Kazumi 的 plugin.dart 和 plugins.dart
 */

import { Api } from './config'
import {
  Plugin,
  parsePlugin,
  PluginHTTPItem,
  parsePluginHTTPItem,
  SearchItem,
  PluginSearchResponse,
  Road,
} from '@/types/plugin'

/**
 * 获取插件列表 - 照抄 PluginHTTP.getPluginList
 */
export async function getPluginList(): Promise<PluginHTTPItem[]> {
  const pluginHTTPItemList: PluginHTTPItem[] = []
  try {
    const res = await fetch(`${Api.pluginShop}index.json`)
    const jsonData = await res.json()
    for (const pluginJsonItem of jsonData) {
      try {
        const pluginHTTPItem = parsePluginHTTPItem(pluginJsonItem)
        pluginHTTPItemList.push(pluginHTTPItem)
      } catch {}
    }
  } catch (e) {
    console.error('Plugin: getPluginList error:', e)
  }
  return pluginHTTPItemList
}

/**
 * 获取单个插件 - 照抄 PluginHTTP.getPlugin
 */
export async function getPlugin(name: string): Promise<Plugin | null> {
  try {
    const res = await fetch(`${Api.pluginShop}${name}.json`)
    const jsonData = await res.json()
    return parsePlugin(jsonData)
  } catch (e) {
    console.error('Plugin: getPlugin error:', e)
    return null
  }
}

/**
 * 获取随机Accept-Language - 照抄 Utils.getRandomAcceptedLanguage
 */
function getRandomAcceptedLanguage(): string {
  const languages = [
    'zh-CN,zh;q=0.9,en;q=0.8',
    'en-US,en;q=0.9',
    'ja-JP,ja;q=0.9,en;q=0.8',
    'zh-TW,zh;q=0.9,en;q=0.8',
  ]
  return languages[Math.floor(Math.random() * languages.length)]
}

/**
 * 使用插件搜索番剧 - 照抄 Plugin.queryBangumi
 * 注意: 这个函数需要在服务端运行，因为需要解析HTML
 */
export async function queryBangumiWithPlugin(
  plugin: Plugin,
  keyword: string
): Promise<PluginSearchResponse> {
  const queryURL = plugin.searchURL.replace('@keyword', encodeURIComponent(keyword))
  const searchItems: SearchItem[] = []

  try {
    let response: Response

    if (plugin.usePost) {
      // POST 请求
      const uri = new URL(queryURL)
      const queryParams = Object.fromEntries(uri.searchParams)
      const postUri = `${uri.protocol}//${uri.host}${uri.pathname}`

      response = await fetch(postUri, {
        method: 'POST',
        headers: {
          'referer': `${plugin.baseURL}/`,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept-Language': getRandomAcceptedLanguage(),
          'Connection': 'keep-alive',
        },
        body: new URLSearchParams(queryParams),
      })
    } else {
      // GET 请求
      response = await fetch(queryURL, {
        headers: {
          'referer': `${plugin.baseURL}/`,
          'Accept-Language': getRandomAcceptedLanguage(),
          'Connection': 'keep-alive',
        },
      })
    }

    const htmlString = await response.text()
    
    // 返回HTML供服务端解析
    return {
      pluginName: plugin.name,
      data: searchItems,
      // 额外返回原始HTML供服务端XPath解析
      _rawHtml: htmlString,
    } as PluginSearchResponse & { _rawHtml: string }
  } catch (e) {
    console.error(`Plugin ${plugin.name}: search error`, e)
    return {
      pluginName: plugin.name,
      data: [],
    }
  }
}

/**
 * 获取播放列表 (线路) - 照抄 Plugin.querychapterRoads
 * 注意: 这个函数需要在服务端运行，因为需要解析HTML
 */
export async function queryChapterRoads(
  plugin: Plugin,
  url: string
): Promise<Road[]> {
  const roadList: Road[] = []

  // 预处理URL
  let queryURL = url
  if (!queryURL.includes('https')) {
    queryURL = queryURL.replace('http', 'https')
  }
  if (!queryURL.includes(plugin.baseURL)) {
    queryURL = plugin.baseURL + queryURL
  }

  try {
    const response = await fetch(queryURL, {
      headers: {
        'referer': `${plugin.baseURL}/`,
        'Accept-Language': getRandomAcceptedLanguage(),
        'Connection': 'keep-alive',
      },
    })

    const htmlString = await response.text()
    
    // 返回HTML供服务端解析
    return roadList
  } catch (e) {
    console.error(`Plugin ${plugin.name}: query roads error`, e)
    return []
  }
}

// ============ 本地插件存储管理 ============

const PLUGINS_STORAGE_KEY = 'kazumi_plugins'

/**
 * 获取本地存储的插件列表
 */
export function getLocalPlugins(): Plugin[] {
  if (typeof window === 'undefined') return []
  
  try {
    const data = localStorage.getItem(PLUGINS_STORAGE_KEY)
    if (!data) return []
    
    const plugins = JSON.parse(data)
    return plugins.map((p: any) => parsePlugin(p))
  } catch {
    return []
  }
}

/**
 * 保存插件列表到本地存储
 */
export function saveLocalPlugins(plugins: Plugin[]): void {
  if (typeof window === 'undefined') return
  
  try {
    localStorage.setItem(PLUGINS_STORAGE_KEY, JSON.stringify(plugins))
  } catch (e) {
    console.error('Failed to save plugins:', e)
  }
}

/**
 * 添加或更新插件
 */
export function updateLocalPlugin(plugin: Plugin): void {
  const plugins = getLocalPlugins()
  const index = plugins.findIndex(p => p.name === plugin.name)
  
  if (index >= 0) {
    plugins[index] = plugin
  } else {
    plugins.push(plugin)
  }
  
  saveLocalPlugins(plugins)
}

/**
 * 删除插件
 */
export function removeLocalPlugin(pluginName: string): void {
  const plugins = getLocalPlugins()
  const filtered = plugins.filter(p => p.name !== pluginName)
  saveLocalPlugins(filtered)
}

/**
 * 检查插件状态
 */
export function getPluginStatus(
  localPlugins: Plugin[],
  httpItem: PluginHTTPItem
): 'install' | 'installed' | 'update' {
  const localPlugin = localPlugins.find(p => p.name === httpItem.name)
  
  if (!localPlugin) {
    return 'install'
  }
  
  if (localPlugin.version === httpItem.version) {
    return 'installed'
  }
  
  return 'update'
}
