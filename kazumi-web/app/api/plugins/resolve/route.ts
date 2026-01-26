/**
 * Plugin Video URL Resolve API Route
 * 使用 Puppeteer 加载播放页面，通过 JavaScript 注入提取视频 URL
 * 照抄 Kazumi 原项目的 WebView 实现逻辑 - webview_android_controller_impel.dart
 * 
 * 解析策略 (照抄原项目):
 * 1. useNativePlayer = false: 使用 IframeRedirectBridge 跳转到 iframe 页面
 * 2. useNativePlayer = true && useLegacyParser = true: 使用 JSBridgeDebug 监听 iframe src
 * 3. useNativePlayer = true && useLegacyParser = false: 使用 VideoBridgeDebug 监听 video 标签和 M3U8 响应
 * 
 * 技术优化 (基于 Web 搜索研究):
 * 1. 使用 page.evaluateOnNewDocument() 在页面脚本执行前注入代码 - 类似原项目的 AT_DOCUMENT_START
 * 2. 使用 CDP Network.requestWillBeSent 事件捕获所有网络请求包括 m3u8
 * 3. 使用 --disable-web-security 禁用跨域限制
 * 4. 使用 page.setBypassCSP(true) 绕过 CSP 限制
 */

import { NextRequest, NextResponse } from 'next/server'
import puppeteer, { Browser, Page, HTTPRequest, HTTPResponse, CDPSession } from 'puppeteer-core'

export const runtime = 'nodejs'

let browserInstance: Browser | null = null

interface Plugin {
  name: string
  baseURL: string
  useNativePlayer: boolean
  useLegacyParser?: boolean
  referer: string
  userAgent: string
}

// 解析超时时间 - 照抄原项目 loadingMonitorTimer 的 15 秒
// Web 环境网络延迟更大，适当增加到 18 秒
const PARSE_TIMEOUT = 18000

// 轮询间隔 - 照抄原项目每秒检查一次
const POLL_INTERVAL = 1000

// 最大重试次数 - 照抄原项目的重试逻辑
const MAX_RETRIES = 2

async function loadPlugins(baseUrl: string): Promise<Plugin[]> {
  try {
    const response = await fetch(`${baseUrl}/plugins/index.json`, { cache: 'no-store' })
    if (!response.ok) return []
    const data = await response.json()
    return Array.isArray(data) ? data : (data.plugins || [])
  } catch {
    return []
  }
}

async function getChromiumPath(): Promise<string> {
  // 优先使用环境变量 (Docker 容器中设置)
  if (process.env.PUPPETEER_EXECUTABLE_PATH) {
    return process.env.PUPPETEER_EXECUTABLE_PATH
  }
  if (process.env.CHROMIUM_PATH) {
    return process.env.CHROMIUM_PATH
  }
  
  const paths = [
    // Linux (Docker / 服务器)
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    // macOS
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    // Windows
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
    process.env.LOCALAPPDATA + '\\Google\\Chrome\\Application\\chrome.exe',
    process.env.LOCALAPPDATA + '\\Microsoft\\Edge\\Application\\msedge.exe',
  ]
  
  const fs = await import('fs')
  for (const p of paths) {
    if (p && fs.existsSync(p)) {
      console.log(`[Puppeteer] Found browser at: ${p}`)
      return p
    }
  }
  
  console.warn('[Puppeteer] No browser found, using default path')
  return '/usr/bin/chromium'
}

async function getBrowser(): Promise<Browser> {
  if (browserInstance) {
    try {
      await browserInstance.pages()
      if (browserInstance.connected) return browserInstance
    } catch {
      try { await browserInstance.close() } catch {}
      browserInstance = null
    }
  }
  
  const executablePath = await getChromiumPath()
  console.log(`[Puppeteer] Launching browser: ${executablePath}`)
  
  browserInstance = await puppeteer.launch({
    executablePath,
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      // 关键: 禁用跨域限制，允许访问 iframe 内容
      '--disable-web-security',
      '--disable-features=IsolateOrigins,site-per-process',
      '--allow-running-insecure-content',
      // 关键: 禁用自动化检测
      '--disable-blink-features=AutomationControlled',
      '--ignore-certificate-errors',
      '--autoplay-policy=no-user-gesture-required',
      // 额外优化
      '--disable-site-isolation-trials',
      '--disable-features=BlockInsecurePrivateNetworkRequests',
      // Docker 容器优化
      '--single-process',
      '--no-zygote',
      '--disable-extensions',
      '--disable-background-networking',
      '--disable-default-apps',
      '--disable-sync',
      '--disable-translate',
      '--hide-scrollbars',
      '--metrics-recording-only',
      '--mute-audio',
      '--no-first-run',
      '--safebrowsing-disable-auto-update',
    ],
  })
  
  console.log('[Puppeteer] Browser launched successfully')
  return browserInstance
}

function getRandomUA(): string {
  const userAgents = [
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15',
  ]
  return userAgents[Math.floor(Math.random() * userAgents.length)]
}

/**
 * 照抄原项目 Utils.decodeVideoSource - 从URL参数中解析 m3u8/mp4
 */
function decodeVideoSource(iframeUrl: string): string {
  try {
    const decodedUrl = decodeURIComponent(iframeUrl)
    const regExp = /(https?:\/\/[^\s"'<>]*?\.(?:m3u8|mp4))/i
    const url = new URL(decodedUrl)
    let matchedUrl = iframeUrl
    url.searchParams.forEach((value) => {
      if (regExp.test(value)) {
        const match = value.match(regExp)
        if (match) matchedUrl = match[1]
      }
    })
    return matchedUrl
  } catch {
    return iframeUrl
  }
}

/**
 * 检查URL是否为有效的视频URL - 照抄原项目的过滤逻辑
 */
function isValidUrl(url: string): boolean {
  if (!url || url.length < 10) return false
  if (url.startsWith('blob:')) return false
  if (url.includes('googleads')) return false
  if (url.includes('googlesyndication.com')) return false
  if (url.includes('google.com')) return false
  if (url.includes('adtrafficquality')) return false
  if (url.includes('prestrain.html')) return false
  if (url.includes('prestrain%2Ehtml')) return false
  return true
}

function isVideoFile(url: string): boolean {
  const lowerUrl = url.toLowerCase()
  return lowerUrl.includes('.m3u8') || lowerUrl.includes('.mp4') || lowerUrl.includes('.flv')
}

/**
 * 生成在页面加载前注入的脚本 - 照抄原项目的 AT_DOCUMENT_START 脚本
 * 这个脚本会在页面的任何脚本执行之前运行
 */
function getEarlyInjectionScript(): string {
  return `
    // 初始化全局变量
    window.__capturedVideoUrls = [];
    window.__capturedIframeUrls = [];
    window.__videoSourceFound = false;
    
    // 照抄原项目 blobParserScript - 拦截 Response.prototype.text
    const _r_text = Response.prototype.text;
    Response.prototype.text = function() {
      return new Promise((resolve, reject) => {
        _r_text.call(this).then((text) => {
          resolve(text);
          if (text.trim().startsWith('#EXTM3U')) {
            console.log('[BlobParser] M3U8 found:', this.url);
            if (!window.__capturedVideoUrls.includes(this.url)) {
              window.__capturedVideoUrls.push(this.url);
              window.__videoSourceFound = true;
            }
          }
        }).catch(reject);
      });
    };
    
    // 照抄原项目 - 拦截 XMLHttpRequest
    const _open = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url, ...rest) {
      this.addEventListener('load', () => {
        try {
          const content = this.responseText;
          if (content && content.trim().startsWith('#EXTM3U')) {
            console.log('[XHR] M3U8 found:', url);
            if (!window.__capturedVideoUrls.includes(url)) {
              window.__capturedVideoUrls.push(url);
              window.__videoSourceFound = true;
            }
          }
        } catch {}
      });
      return _open.call(this, method, url, ...rest);
    };
    
    // 照抄原项目 - 拦截 fetch
    const _fetch = window.fetch;
    window.fetch = function(...args) {
      return _fetch.apply(this, args).then(response => {
        const url = typeof args[0] === 'string' ? args[0] : args[0].url;
        if (url && (url.includes('.m3u8') || url.includes('m3u8'))) {
          console.log('[Fetch] Potential M3U8:', url);
          if (!window.__capturedVideoUrls.includes(url)) {
            window.__capturedVideoUrls.push(url);
          }
        }
        return response;
      });
    };
    
    console.log('[EarlyInjection] Scripts loaded at document start');
  `;
}

/**
 * 使用 Puppeteer 解析视频 URL - 照抄原项目的 WebView 逻辑
 * 
 * 技术优化:
 * 1. 使用 evaluateOnNewDocument 在页面脚本执行前注入代码
 * 2. 使用 CDP Network.requestWillBeSent 捕获所有网络请求
 * 3. 使用 --disable-web-security 禁用跨域限制
 */
async function resolveVideoUrl(plugin: Plugin, playUrl: string): Promise<{ videoUrl: string | null; logs: string[] }> {
  const logs: string[] = []
  let page: Page | null = null
  let cdpSession: CDPSession | null = null
  let videoUrl: string | null = null
  let isVideoSourceLoaded = false
  
  const capturedVideoUrls: string[] = []
  const capturedIframeUrls: string[] = []
  
  try {
    // 构建完整 URL - 照抄原项目
    let fullUrl = playUrl
    const baseUrlHttps = plugin.baseURL
    const baseUrlHttp = plugin.baseURL.replace('https', 'http')
    
    if (!fullUrl.includes(baseUrlHttps) && !fullUrl.includes(baseUrlHttp)) {
      if (!fullUrl.startsWith('http')) {
        fullUrl = plugin.baseURL + (fullUrl.startsWith('/') ? '' : '/') + fullUrl
      }
    }
    if (fullUrl.startsWith('http://')) {
      fullUrl = fullUrl.replace('http://', 'https://')
    }
    
    logs.push(`开始解析: ${fullUrl}`)
    logs.push(`插件: ${plugin.name}, useNativePlayer: ${plugin.useNativePlayer}, useLegacyParser: ${plugin.useLegacyParser}`)
    
    const browser = await getBrowser()
    page = await browser.newPage()
    
    // 关键优化 1: 绕过 CSP 限制
    await page.setBypassCSP(true)
    
    // 关键优化 2: 使用 evaluateOnNewDocument 在页面脚本执行前注入代码
    // 这相当于原项目的 AT_DOCUMENT_START 注入时机
    await page.evaluateOnNewDocument(getEarlyInjectionScript())
    logs.push('[优化] 已注入早期脚本 (evaluateOnNewDocument)')
    
    // 关键优化 3: 使用 CDP 监听所有网络请求，包括 m3u8
    // 这可以捕获 Puppeteer 普通请求拦截可能遗漏的请求
    try {
      cdpSession = await page.createCDPSession()
      await cdpSession.send('Network.enable')
      
      cdpSession.on('Network.requestWillBeSent', (params: { request: { url: string } }) => {
        const url = params.request.url
        if (isVideoFile(url) && isValidUrl(url)) {
          logs.push(`[CDP] 捕获视频请求: ${url}`)
          if (!capturedVideoUrls.includes(url)) {
            capturedVideoUrls.push(url)
          }
        }
      })
      
      cdpSession.on('Network.responseReceived', (params: { response: { url: string; mimeType: string } }) => {
        const url = params.response.url
        const mimeType = params.response.mimeType || ''
        if (mimeType.includes('mpegurl') || mimeType.includes('m3u8') || url.includes('.m3u8')) {
          logs.push(`[CDP] 捕获 M3U8 响应: ${url}`)
          if (isValidUrl(url) && !capturedVideoUrls.includes(url)) {
            capturedVideoUrls.push(url)
          }
        }
      })
      
      logs.push('[优化] 已启用 CDP Network 监听')
    } catch (cdpError) {
      logs.push(`[CDP] 启用失败: ${cdpError instanceof Error ? cdpError.message : String(cdpError)}`)
    }
    
    // 使用 iOS User-Agent
    const userAgent = plugin.userAgent || getRandomUA()
    await page.setUserAgent(userAgent)
    await page.setViewport({ width: 390, height: 844 }) // iPhone 14 Pro 尺寸
    
    // 设置 referer - 照抄原项目 'referer': '$baseUrl/'
    const headers: Record<string, string> = {
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Referer': plugin.referer || (plugin.baseURL + '/'),
    }
    await page.setExtraHTTPHeaders(headers)
    
    // 启用请求拦截 - 照抄原项目的 ContentBlocker
    await page.setRequestInterception(true)
    
    page.on('request', (request: HTTPRequest) => {
      const url = request.url()
      
      // 捕获视频请求
      if (isVideoFile(url) && isValidUrl(url)) {
        logs.push(`[Request] 捕获视频: ${url}`)
        if (!capturedVideoUrls.includes(url)) capturedVideoUrls.push(url)
      }
      
      // 照抄 iOS ContentBlocker - 只阻止广告，不阻止图片（某些播放器需要）
      if (
        url.includes('googleads') ||
        url.includes('googlesyndication.com') ||
        url.includes('adtrafficquality') ||
        url.includes('prestrain.html') ||
        url.includes('prestrain%2Ehtml') ||
        url.includes('devtools-detector.js')
      ) {
        request.abort()
      } else {
        request.continue()
      }
    })
    
    // 照抄 iOS blobParserScript - 监听 M3U8 响应
    page.on('response', async (response: HTTPResponse) => {
      const url = response.url()
      const contentType = response.headers()['content-type'] || ''
      
      if (contentType.includes('mpegurl') || url.includes('.m3u8')) {
        try {
          const text = await response.text()
          if (text.trim().startsWith('#EXTM3U')) {
            if (isValidUrl(url) && !capturedVideoUrls.includes(url)) {
              logs.push(`[M3U8] 捕获: ${url}`)
              capturedVideoUrls.push(url)
            }
          }
        } catch {}
      }
    })
    
    // 加载页面
    logs.push('加载页面...')
    try {
      await page.goto(fullUrl, { waitUntil: 'domcontentloaded', timeout: PARSE_TIMEOUT })
      logs.push('页面加载完成')
    } catch (e) {
      logs.push(`页面加载警告: ${e instanceof Error ? e.message : String(e)}`)
    }
    
    // 等待页面稳定 - 增加等待时间让 iframe 有时间加载
    await new Promise(resolve => setTimeout(resolve, 2000))
    
    // 注入 MutationObserver 脚本来监听动态加载的 iframe 和 video - 照抄原项目
    await page.evaluate(() => {
      // @ts-ignore
      window.__capturedVideoUrls = window.__capturedVideoUrls || []
      // @ts-ignore
      window.__capturedIframeUrls = window.__capturedIframeUrls || []
      
      // 照抄原项目: 拦截 Response.prototype.text 来捕获 M3U8
      const _r_text = Response.prototype.text
      Response.prototype.text = function() {
        return new Promise((resolve, reject) => {
          _r_text.call(this).then((text: string) => {
            resolve(text)
            if (text.trim().startsWith('#EXTM3U')) {
              console.log('[BlobParser] M3U8 found:', this.url)
              // @ts-ignore
              if (!window.__capturedVideoUrls.includes(this.url)) {
                // @ts-ignore
                window.__capturedVideoUrls.push(this.url)
              }
            }
          }).catch(reject)
        })
      }
      
      // 照抄原项目: 拦截 XMLHttpRequest 来捕获 M3U8
      const _open = XMLHttpRequest.prototype.open
      // @ts-ignore - 忽略类型检查，因为我们需要拦截所有参数
      XMLHttpRequest.prototype.open = function(method: string, url: string | URL, ...rest: unknown[]) {
        this.addEventListener('load', () => {
          try {
            const content = this.responseText
            if (content.trim().startsWith('#EXTM3U')) {
              console.log('[XHR] M3U8 found:', url)
              // @ts-ignore
              if (!window.__capturedVideoUrls.includes(url)) {
                // @ts-ignore
                window.__capturedVideoUrls.push(url)
              }
            }
          } catch {}
        })
        // @ts-ignore
        return _open.call(this, method, url, ...rest)
      }
      
      // 照抄原项目: 监听 video 元素
      function processVideoElement(video: HTMLVideoElement): boolean {
        let src = video.getAttribute('src')
        if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
          console.log('[VideoTag] Video found:', src)
          // @ts-ignore
          if (!window.__capturedVideoUrls.includes(src)) {
            // @ts-ignore
            window.__capturedVideoUrls.push(src)
          }
          return true
        }
        const sources = video.getElementsByTagName('source')
        for (let i = 0; i < sources.length; i++) {
          src = sources[i].getAttribute('src')
          if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
            console.log('[VideoTag] Video source found:', src)
            // @ts-ignore
            if (!window.__capturedVideoUrls.includes(src)) {
              // @ts-ignore
              window.__capturedVideoUrls.push(src)
            }
            return true
          }
        }
        return false
      }
      
      // 照抄原项目: 监听 iframe 元素
      function processIframeElement(iframe: HTMLIFrameElement): boolean {
        const src = iframe.getAttribute('src')
        if (src && src.trim() !== '' && 
            (src.startsWith('http') || src.startsWith('//')) && 
            !src.includes('googleads') && 
            !src.includes('adtrafficquality') && 
            !src.includes('googlesyndication.com') && 
            !src.includes('google.com') && 
            !src.includes('prestrain.html') && 
            !src.includes('prestrain%2Ehtml')) {
          console.log('[IframeTag] Iframe found:', src)
          // @ts-ignore
          if (!window.__capturedIframeUrls.includes(src)) {
            // @ts-ignore
            window.__capturedIframeUrls.push(src)
          }
          return true
        }
        return false
      }
      
      // 设置 MutationObserver
      const observer = new MutationObserver((mutations) => {
        for (const mutation of mutations) {
          if (mutation.type === 'attributes') {
            const target = mutation.target as HTMLElement
            if (target.nodeName === 'VIDEO') {
              processVideoElement(target as HTMLVideoElement)
            } else if (target.nodeName === 'IFRAME') {
              processIframeElement(target as HTMLIFrameElement)
            }
          }
          for (const node of Array.from(mutation.addedNodes)) {
            if (node.nodeType !== Node.ELEMENT_NODE) continue
            const element = node as HTMLElement
            if (element.nodeName === 'VIDEO') {
              processVideoElement(element as HTMLVideoElement)
            } else if (element.nodeName === 'IFRAME') {
              processIframeElement(element as HTMLIFrameElement)
            }
            // 检查子元素
            if (element.querySelectorAll) {
              element.querySelectorAll('video').forEach(v => processVideoElement(v as HTMLVideoElement))
              element.querySelectorAll('iframe').forEach(f => processIframeElement(f as HTMLIFrameElement))
            }
          }
        }
      })
      
      observer.observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['src']
      })
      
      // 处理已存在的元素
      document.querySelectorAll('video').forEach(v => processVideoElement(v as HTMLVideoElement))
      document.querySelectorAll('iframe').forEach(f => processIframeElement(f as HTMLIFrameElement))
    })
    
    logs.push('已注入 MutationObserver 脚本')
    
    // 根据插件配置注入不同的脚本 - 照抄 iOS 原项目
    if (!plugin.useNativePlayer) {
      // useNativePlayer = false: IframeRedirectBridge - 照抄 iOS 原项目
      logs.push('执行 IframeRedirectBridge 脚本')
      const iframeResult = await page.evaluate(() => {
        const iframes = document.getElementsByTagName('iframe')
        for (let i = 0; i < iframes.length; i++) {
          const iframe = iframes[i]
          const src = iframe.getAttribute('src')
          if (src && src.trim() !== '' && 
              (src.startsWith('http') || src.startsWith('//')) && 
              !src.includes('googleads') && 
              !src.includes('adtrafficquality') && 
              !src.includes('googlesyndication.com') && 
              !src.includes('google.com') && 
              !src.includes('prestrain.html') && 
              !src.includes('prestrain%2Ehtml')) {
            return src
          }
        }
        return null
      })
      
      if (iframeResult) {
        logs.push(`[IframeRedirect] 找到 iframe: ${iframeResult}`)
        let iframeUrl = iframeResult
        if (iframeUrl.startsWith('//')) iframeUrl = 'https:' + iframeUrl
        
        // 跳转到 iframe 页面继续解析
        try {
          await page.goto(iframeUrl, { waitUntil: 'domcontentloaded', timeout: 10000 })
          logs.push('已跳转到 iframe 页面')
          await new Promise(resolve => setTimeout(resolve, 2000))
        } catch (e) {
          logs.push(`iframe 跳转失败: ${e instanceof Error ? e.message : String(e)}`)
        }
      }
    } else if (plugin.useLegacyParser) {
      // useNativePlayer = true && useLegacyParser = true: JSBridgeDebug - 照抄 iOS 原项目
      logs.push('执行 JSBridgeDebug 脚本')
      const iframeSrcs = await page.evaluate(() => {
        const srcs: string[] = []
        const iframes = document.getElementsByTagName('iframe')
        for (let i = 0; i < iframes.length; i++) {
          const src = iframes[i].getAttribute('src')
          if (src) srcs.push(src)
        }
        return srcs
      })
      
      logs.push(`[JSBridgeDebug] iframe 数量: ${iframeSrcs.length}`)
      
      for (const src of iframeSrcs) {
        if (!isValidUrl(src)) continue
        logs.push(`[JSBridgeDebug] 处理 iframe: ${src}`)
        
        // 照抄原项目: 使用 decodeVideoSource 解析
        const encodedUrl = encodeURI(src)
        const decodedUrl = decodeVideoSource(encodedUrl)
        if (decodedUrl !== encodedUrl) {
          logs.push(`[JSBridgeDebug] 解析到视频: ${decodedUrl}`)
          videoUrl = decodedUrl
          isVideoSourceLoaded = true
          break
        }
        
        capturedIframeUrls.push(src)
      }
    }
    
    // 如果还没找到视频，执行 VideoBridgeDebug - 照抄 iOS 原项目
    if (!isVideoSourceLoaded) {
      logs.push('执行 VideoBridgeDebug 脚本')
      
      // 先检查页面上有多少 iframe 和 video
      const pageInfo = await page.evaluate(() => {
        return {
          iframeCount: document.getElementsByTagName('iframe').length,
          videoCount: document.getElementsByTagName('video').length,
          iframeSrcs: Array.from(document.getElementsByTagName('iframe')).map(f => f.src || f.getAttribute('src')).filter(Boolean),
          title: document.title,
          url: window.location.href,
        }
      })
      logs.push(`[Debug] 页面: ${pageInfo.title}`)
      logs.push(`[Debug] iframe 数量: ${pageInfo.iframeCount}, video 数量: ${pageInfo.videoCount}`)
      if (pageInfo.iframeSrcs.length > 0) {
        logs.push(`[Debug] iframe srcs: ${pageInfo.iframeSrcs.slice(0, 3).join(', ')}`)
      }
      
      const videoSrcs = await page.evaluate(() => {
        const srcs: string[] = []
        
        function processVideoElement(video: HTMLVideoElement) {
          let src = video.getAttribute('src')
          if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
            srcs.push(src)
            return
          }
          const sources = video.getElementsByTagName('source')
          for (let i = 0; i < sources.length; i++) {
            src = sources[i].getAttribute('src')
            if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
              srcs.push(src)
              return
            }
          }
        }
        
        document.querySelectorAll('video').forEach(v => processVideoElement(v as HTMLVideoElement))
        return srcs
      })
      
      for (const src of videoSrcs) {
        if (isValidUrl(src) && !capturedVideoUrls.includes(src)) {
          logs.push(`[VideoBridgeDebug] video 标签: ${src}`)
          capturedVideoUrls.push(src)
        }
      }
      
      // 如果有 iframe 但没有 video，尝试在 iframe 中查找视频
      // 注意: 使用 page.frames() 而不是 page.goto() 来访问 iframe 内容
      // 这样可以避免跳转超时的问题
      const currentUrl = page.url()
      const filteredIframeSrcs = pageInfo.iframeSrcs.filter((src: string | null) => {
        if (!src) return false
        let fullSrc = src
        if (src.startsWith('//')) fullSrc = 'https:' + src
        else if (!src.startsWith('http')) {
          try {
            fullSrc = new URL(src, currentUrl).toString()
          } catch { return false }
        }
        // 跳过与当前页面相同的 URL
        return fullSrc !== currentUrl && isValidUrl(src)
      })
      
      // 首先尝试使用 page.frames() 访问 iframe 内容
      if (capturedVideoUrls.length === 0) {
        const frames = page.frames()
        logs.push(`[Debug] 页面有 ${frames.length} 个 frame`)
        
        for (const frame of frames) {
          if (frame === page.mainFrame()) continue
          
          try {
            const frameUrl = frame.url()
            logs.push(`[Frame] 检查 frame: ${frameUrl}`)
            
            // 在 frame 中查找 video 元素
            const frameVideoSrcs = await frame.evaluate(() => {
              const srcs: string[] = []
              document.querySelectorAll('video').forEach(v => {
                const video = v as HTMLVideoElement
                let src = video.getAttribute('src')
                if (src && src.trim() !== '' && !src.startsWith('blob:')) {
                  srcs.push(src)
                }
                const sources = video.getElementsByTagName('source')
                for (let i = 0; i < sources.length; i++) {
                  src = sources[i].getAttribute('src')
                  if (src && src.trim() !== '' && !src.startsWith('blob:')) {
                    srcs.push(src)
                  }
                }
              })
              return srcs
            }).catch(() => [] as string[])
            
            for (const src of frameVideoSrcs) {
              if (isValidUrl(src) && !capturedVideoUrls.includes(src)) {
                logs.push(`[Frame] 找到视频: ${src}`)
                capturedVideoUrls.push(src)
              }
            }
            
            if (capturedVideoUrls.length > 0) break
          } catch (e) {
            logs.push(`[Frame] 访问失败: ${e instanceof Error ? e.message : String(e)}`)
          }
        }
      }
      
      // 如果 frame 中没找到，尝试跳转到 iframe URL（作为备选方案）
      if (capturedVideoUrls.length === 0 && filteredIframeSrcs.length > 0) {
        for (const iframeSrc of filteredIframeSrcs) {
          if (!iframeSrc || !isValidUrl(iframeSrc)) continue
          
          logs.push(`[Debug] 尝试进入 iframe: ${iframeSrc}`)
          let targetUrl: string = iframeSrc
          if (targetUrl.startsWith('//')) targetUrl = 'https:' + targetUrl
          
          try {
            // 使用 networkidle0 等待页面完全加载，包括 JS 重定向
            await page.goto(targetUrl, { waitUntil: 'networkidle0', timeout: 15000 })
            
            // 等待一下让页面稳定
            await new Promise(resolve => setTimeout(resolve, 2000))
            
            // 重新注入 MutationObserver 脚本
            await page.evaluate(() => {
              // @ts-ignore
              window.__capturedVideoUrls = window.__capturedVideoUrls || []
              
              function processVideoElement(video: HTMLVideoElement): boolean {
                let src = video.getAttribute('src')
                if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
                  // @ts-ignore
                  if (!window.__capturedVideoUrls.includes(src)) {
                    // @ts-ignore
                    window.__capturedVideoUrls.push(src)
                  }
                  return true
                }
                const sources = video.getElementsByTagName('source')
                for (let i = 0; i < sources.length; i++) {
                  src = sources[i].getAttribute('src')
                  if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
                    // @ts-ignore
                    if (!window.__capturedVideoUrls.includes(src)) {
                      // @ts-ignore
                      window.__capturedVideoUrls.push(src)
                    }
                    return true
                  }
                }
                return false
              }
              
              // 处理已存在的 video 元素
              document.querySelectorAll('video').forEach(v => processVideoElement(v as HTMLVideoElement))
            })
            
            // 检查 iframe 页面中的视频
            if (capturedVideoUrls.length > 0) {
              videoUrl = capturedVideoUrls.find(u => u.includes('.m3u8')) || capturedVideoUrls[0]
              isVideoSourceLoaded = true
              logs.push(`从 iframe 页面捕获: ${videoUrl}`)
              break
            }
            
            // 从注入的脚本中获取捕获的 URL
            const injectedUrls = await page.evaluate(() => {
              // @ts-ignore
              return window.__capturedVideoUrls || []
            })
            
            for (const url of injectedUrls) {
              if (isValidUrl(url) && !capturedVideoUrls.includes(url)) {
                logs.push(`[Injected iframe] 捕获视频: ${url}`)
                capturedVideoUrls.push(url)
              }
            }
            
            // 再次检查 video 标签
            const iframeVideoSrcs = await page.evaluate(() => {
              const srcs: string[] = []
              document.querySelectorAll('video').forEach(v => {
                const video = v as HTMLVideoElement
                let src = video.getAttribute('src')
                if (src && src.trim() !== '' && !src.startsWith('blob:')) {
                  srcs.push(src)
                }
                const sources = video.getElementsByTagName('source')
                for (let i = 0; i < sources.length; i++) {
                  src = sources[i].getAttribute('src')
                  if (src && src.trim() !== '' && !src.startsWith('blob:')) {
                    srcs.push(src)
                  }
                }
              })
              return srcs
            })
            
            for (const src of iframeVideoSrcs) {
              if (isValidUrl(src) && !capturedVideoUrls.includes(src)) {
                logs.push(`[iframe] video 标签: ${src}`)
                capturedVideoUrls.push(src)
              }
            }
            
            if (capturedVideoUrls.length > 0) {
              videoUrl = capturedVideoUrls.find(u => u.includes('.m3u8')) || capturedVideoUrls[0]
              isVideoSourceLoaded = true
              logs.push(`从 iframe video 标签捕获: ${videoUrl}`)
              break
            }
          } catch (e) {
            logs.push(`[Debug] iframe 加载失败: ${e instanceof Error ? e.message : String(e)}`)
          }
        }
      }
    }
    
    // 从脚本中提取视频URL - 在等待动态内容之前先检查一次
    if (!isVideoSourceLoaded && capturedVideoUrls.length === 0) {
      const scriptUrls = await page.evaluate(() => {
        const urls: string[] = []
        const scripts = Array.from(document.querySelectorAll('script'))
        for (let i = 0; i < scripts.length; i++) {
          const content = scripts[i].textContent || ''
          const patterns = [
            /player_aaaa\s*=\s*\{[^}]*"url"\s*:\s*"([^"]+)"/i,
            /MacPlayer\.PlayUrl\s*=\s*["']([^"']+)["']/i,
            // 匹配 var player_data = {..., "url": "..."} 格式
            /player_data\s*=\s*\{[^}]*"url"\s*:\s*"([^"]+)"/i,
            // 匹配 "url":"..." 格式
            /["']url["']\s*:\s*["']([^"']+\.(?:m3u8|mp4)[^"']*)['"]/gi,
            // 匹配直接的 m3u8/mp4 URL
            /["'](https?:\/\/[^"']+\.(?:m3u8|mp4)[^"']*)['"]/gi,
            // 匹配 url: "..." 格式 (不带引号的 key)
            /\burl\s*:\s*["']([^"']+\.(?:m3u8|mp4)[^"']*)['"]/gi,
          ]
          for (let j = 0; j < patterns.length; j++) {
            const pattern = patterns[j]
            let match
            if (pattern.global) pattern.lastIndex = 0
            while ((match = pattern.exec(content)) !== null) {
              if (match[1]) urls.push(match[1])
              if (!pattern.global) break
            }
          }
        }
        return urls
      })
      
      for (const url of scriptUrls) {
        if (isValidUrl(url) && !capturedVideoUrls.includes(url)) {
          logs.push(`[Script] 提取: ${url}`)
          capturedVideoUrls.push(url)
        }
      }
      
      // 如果从脚本中找到了视频，直接使用
      if (capturedVideoUrls.length > 0) {
        videoUrl = capturedVideoUrls.find(u => u.includes('.m3u8')) || capturedVideoUrls[0]
        isVideoSourceLoaded = true
        logs.push(`从脚本提取视频: ${videoUrl}`)
      }
    }
    
    // 如果 useLegacyParser 且找到了 iframe 但没解析出视频，跳转到 iframe 继续
    if (!isVideoSourceLoaded && capturedVideoUrls.length === 0 && capturedIframeUrls.length > 0) {
      let iframeUrl = capturedIframeUrls[0]
      if (iframeUrl.startsWith('//')) iframeUrl = 'https:' + iframeUrl
      
      logs.push(`跳转到 iframe 继续解析: ${iframeUrl}`)
      
      try {
        await page.goto(iframeUrl, { waitUntil: 'domcontentloaded', timeout: 10000 })
        await new Promise(resolve => setTimeout(resolve, 3000))
        
        // 再次检查网络请求捕获的视频
        if (capturedVideoUrls.length > 0) {
          videoUrl = capturedVideoUrls.find(u => u.includes('.m3u8')) || capturedVideoUrls[0]
          isVideoSourceLoaded = true
          logs.push(`从 iframe 页面捕获: ${videoUrl}`)
        }
      } catch (e) {
        logs.push(`iframe 加载失败: ${e instanceof Error ? e.message : String(e)}`)
      }
    }
    
    // 等待动态内容 - 照抄原项目的 loadingMonitorTimer
    // 原项目: Timer.periodic(const Duration(seconds: 1), (timer) => { ... })
    // 每秒检查一次，最多 15 秒（我们用 18 秒）
    const startTime = Date.now()
    let pollCount = 0
    const maxPolls = Math.floor(PARSE_TIMEOUT / POLL_INTERVAL)
    
    while (!isVideoSourceLoaded && capturedVideoUrls.length === 0 && pollCount < maxPolls) {
      await new Promise(resolve => setTimeout(resolve, POLL_INTERVAL))
      pollCount++
      
      // 照抄原项目: 每秒检查一次状态
      const elapsed = Math.floor((Date.now() - startTime) / 1000)
      if (pollCount % 3 === 0) {
        logs.push(`[Monitor] 等待视频源... ${elapsed}秒`)
      }
      
      // 从注入的脚本中获取捕获的 URL - 照抄原项目的 callback 机制
      try {
        const injectedUrls = await page.evaluate(() => {
          return {
            // @ts-ignore
            videoUrls: window.__capturedVideoUrls || [],
            // @ts-ignore
            iframeUrls: window.__capturedIframeUrls || []
          }
        })
        
        // 处理捕获的视频 URL
        for (const url of injectedUrls.videoUrls) {
          if (isValidUrl(url) && !capturedVideoUrls.includes(url)) {
            logs.push(`[Monitor] 捕获视频: ${url}`)
            capturedVideoUrls.push(url)
          }
        }
        
        // 如果找到了新的 iframe，记录下来
        const currentUrl = page.url()
        for (const iframeSrc of injectedUrls.iframeUrls) {
          if (!isValidUrl(iframeSrc)) continue
          let fullSrc = iframeSrc
          if (iframeSrc.startsWith('//')) fullSrc = 'https:' + iframeSrc
          else if (!iframeSrc.startsWith('http')) {
            try {
              fullSrc = new URL(iframeSrc, currentUrl).toString()
            } catch { continue }
          }
          if (fullSrc === currentUrl) continue
          if (!capturedIframeUrls.includes(fullSrc)) {
            logs.push(`[Monitor] 发现 iframe: ${fullSrc}`)
            capturedIframeUrls.push(fullSrc)
          }
        }
        
        // 如果有新的 iframe 但还没有视频，尝试进入 iframe
        if (capturedVideoUrls.length === 0 && capturedIframeUrls.length > 0 && pollCount === 5) {
          const iframeToTry = capturedIframeUrls[0]
          logs.push(`[Monitor] 尝试进入 iframe: ${iframeToTry}`)
          try {
            await page.goto(iframeToTry, { waitUntil: 'domcontentloaded', timeout: 8000 })
            await new Promise(resolve => setTimeout(resolve, 1500))
          } catch (e) {
            logs.push(`[Monitor] iframe 加载失败: ${e instanceof Error ? e.message : String(e)}`)
          }
        }
      } catch {}
      
      // 找到视频就退出循环
      if (capturedVideoUrls.length > 0) {
        logs.push(`[Monitor] 找到 ${capturedVideoUrls.length} 个视频源`)
        break
      }
    }
    
    // 选择最佳视频URL
    if (!isVideoSourceLoaded && capturedVideoUrls.length > 0) {
      videoUrl = capturedVideoUrls.find(u => u.includes('.m3u8')) || capturedVideoUrls[0]
      logs.push(`最终选择: ${videoUrl}`)
    }
    
    // 处理相对 URL
    if (videoUrl) {
      if (videoUrl.startsWith('//')) {
        videoUrl = 'https:' + videoUrl
      } else if (!videoUrl.startsWith('http')) {
        try {
          videoUrl = new URL(videoUrl, page.url()).toString()
        } catch {}
      }
    }
    
    if (!videoUrl) {
      logs.push('解析视频资源超时')
      logs.push('请切换到其他播放列表或视频源')
    }
    
    return { videoUrl, logs }
  } catch (error) {
    logs.push(`解析错误: ${error instanceof Error ? error.message : String(error)}`)
    return { videoUrl: null, logs }
  } finally {
    // 清理 CDP session
    if (cdpSession) {
      try {
        await cdpSession.detach()
      } catch {}
    }
    // 关闭页面
    if (page) await page.close().catch(() => {})
  }
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const playUrl = searchParams.get('url')
    const pluginName = searchParams.get('plugin')
    
    if (!playUrl || !pluginName) {
      return NextResponse.json({ error: '缺少必要参数' }, { status: 400 })
    }

    const baseUrl = new URL(request.url).origin
    const plugins = await loadPlugins(baseUrl)
    const plugin = plugins.find((p: Plugin) => p.name === pluginName)
    
    if (!plugin) {
      return NextResponse.json({ error: `插件 "${pluginName}" 未找到` }, { status: 404 })
    }

    // 照抄原项目: 实现重试机制
    let lastError: string | null = null
    let allLogs: string[] = []
    
    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      if (attempt > 0) {
        allLogs.push(`--- 第 ${attempt + 1} 次尝试 ---`)
      }
      
      const { videoUrl, logs } = await resolveVideoUrl(plugin, playUrl)
      allLogs = allLogs.concat(logs)

      if (videoUrl) {
        return NextResponse.json({ videoUrl, plugin: pluginName, playUrl, logs: allLogs })
      }
      
      lastError = logs[logs.length - 1] || '无法解析视频地址'
      
      // 如果不是最后一次尝试，等待一下再重试
      if (attempt < MAX_RETRIES) {
        allLogs.push('等待 2 秒后重试...')
        await new Promise(resolve => setTimeout(resolve, 2000))
      }
    }

    console.error(`Video resolve failed for ${pluginName} after ${MAX_RETRIES + 1} attempts:`, allLogs)
    return NextResponse.json({ 
      error: lastError || '无法解析视频地址，请尝试其他视频源', 
      logs: allLogs 
    }, { status: 404 })
  } catch (error) {
    console.error('Plugin resolve error:', error)
    return NextResponse.json({ error: '解析视频地址失败' }, { status: 500 })
  }
}
