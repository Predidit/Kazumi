/**
 * Video Proxy API Route
 * 代理视频请求以绕过 CORS 限制
 * 支持 M3U8/MP4/FLV 等格式
 */

import { NextRequest, NextResponse } from 'next/server'

export const runtime = 'nodejs'

// 禁用响应体大小限制
export const dynamic = 'force-dynamic'

// 随机 User-Agent - 使用 iOS Safari
function getRandomUA(): string {
  const userAgents = [
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15',
  ]
  return userAgents[Math.floor(Math.random() * userAgents.length)]
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const videoUrl = searchParams.get('url')
    const referer = searchParams.get('referer') || ''
    
    if (!videoUrl) {
      return NextResponse.json({ error: '缺少视频 URL' }, { status: 400 })
    }

    // 解码 URL
    const decodedUrl = decodeURIComponent(videoUrl)
    
    // 获取 Range 头（支持视频 seek）
    const range = request.headers.get('range')
    
    // 构建请求头
    const headers: HeadersInit = {
      'User-Agent': getRandomUA(),
      'Accept': '*/*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Accept-Encoding': 'identity', // 不压缩，方便流式传输
    }
    
    if (range) {
      headers['Range'] = range
    }
    
    // 添加 Referer（某些视频源需要）
    if (referer) {
      headers['Referer'] = referer
    } else {
      // 尝试从 URL 提取 origin 作为 referer
      try {
        const urlObj = new URL(decodedUrl)
        headers['Referer'] = urlObj.origin + '/'
      } catch {}
    }

    // 请求视频
    const response = await fetch(decodedUrl, {
      method: 'GET',
      headers,
      // @ts-ignore - Node.js fetch 支持
      redirect: 'follow',
    })

    if (!response.ok && response.status !== 206) {
      console.error(`Video proxy failed: ${response.status} for ${decodedUrl}`)
      return NextResponse.json(
        { error: `视频请求失败: ${response.status}` },
        { status: response.status }
      )
    }

    // 获取响应头
    let contentType = response.headers.get('content-type') || ''
    const contentLength = response.headers.get('content-length')
    const contentRange = response.headers.get('content-range')
    const acceptRanges = response.headers.get('accept-ranges')

    // 根据 URL 推断内容类型
    if (!contentType || contentType === 'application/octet-stream') {
      if (decodedUrl.includes('.m3u8')) {
        contentType = 'application/vnd.apple.mpegurl'
      } else if (decodedUrl.includes('.mp4')) {
        contentType = 'video/mp4'
      } else if (decodedUrl.includes('.flv')) {
        contentType = 'video/x-flv'
      } else if (decodedUrl.includes('.ts')) {
        contentType = 'video/mp2t'
      } else {
        contentType = 'video/mp4'
      }
    }

    // 构建响应头
    const responseHeaders: HeadersInit = {
      'Content-Type': contentType,
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
      'Access-Control-Allow-Headers': 'Range, Content-Type',
      'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Accept-Ranges',
      'Cache-Control': 'public, max-age=3600',
    }

    if (contentLength) {
      responseHeaders['Content-Length'] = contentLength
    }
    if (contentRange) {
      responseHeaders['Content-Range'] = contentRange
    }
    if (acceptRanges) {
      responseHeaders['Accept-Ranges'] = acceptRanges
    } else {
      responseHeaders['Accept-Ranges'] = 'bytes'
    }

    // 返回视频流
    return new NextResponse(response.body, {
      status: response.status,
      headers: responseHeaders,
    })
  } catch (error) {
    console.error('Video proxy error:', error)
    return NextResponse.json(
      { error: '视频代理请求失败' },
      { status: 500 }
    )
  }
}

export async function HEAD(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const videoUrl = searchParams.get('url')
    
    if (!videoUrl) {
      return NextResponse.json({ error: '缺少视频 URL' }, { status: 400 })
    }

    const decodedUrl = decodeURIComponent(videoUrl)
    
    const response = await fetch(decodedUrl, {
      method: 'HEAD',
      headers: {
        'User-Agent': getRandomUA(),
      },
    })

    const contentType = response.headers.get('content-type') || 'video/mp4'
    const contentLength = response.headers.get('content-length')

    return new NextResponse(null, {
      status: 200,
      headers: {
        'Content-Type': contentType,
        'Content-Length': contentLength || '0',
        'Accept-Ranges': 'bytes',
        'Access-Control-Allow-Origin': '*',
      },
    })
  } catch (error) {
    return NextResponse.json({ error: 'HEAD 请求失败' }, { status: 500 })
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
      'Access-Control-Allow-Headers': 'Range, Content-Type',
      'Access-Control-Max-Age': '86400',
    },
  })
}
