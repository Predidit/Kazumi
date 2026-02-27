/**
 * API Response Cache - 性能优化缓存层
 * 
 * 功能:
 * - 内存缓存 API 响应
 * - 支持 TTL (Time To Live)
 * - 支持 stale-while-revalidate 模式
 * - 自动清理过期缓存
 * - 请求去重 (防止重复并发请求)
 */

interface CacheEntry<T> {
  data: T
  timestamp: number
  ttl: number
}

// 请求去重 - 防止同一时间多次请求同一 URL
const pendingRequests = new Map<string, Promise<unknown>>()

class MemoryCache {
  private cache = new Map<string, CacheEntry<unknown>>()
  private cleanupInterval: NodeJS.Timeout | null = null

  constructor() {
    // 每分钟清理过期缓存
    if (typeof window !== 'undefined') {
      this.cleanupInterval = setInterval(() => this.cleanup(), 60000)
    }
  }

  /**
   * 获取缓存数据
   * @param key 缓存键
   * @returns 缓存数据或 null
   */
  get<T>(key: string): T | null {
    const entry = this.cache.get(key) as CacheEntry<T> | undefined
    if (!entry) return null

    const now = Date.now()
    const isExpired = now - entry.timestamp > entry.ttl

    if (isExpired) {
      this.cache.delete(key)
      return null
    }

    return entry.data
  }

  /**
   * 获取缓存数据（包括过期数据，用于 stale-while-revalidate）
   * @param key 缓存键
   * @returns { data, isStale } 或 null
   */
  getWithStale<T>(key: string): { data: T; isStale: boolean } | null {
    const entry = this.cache.get(key) as CacheEntry<T> | undefined
    if (!entry) return null

    const now = Date.now()
    const isStale = now - entry.timestamp > entry.ttl

    return { data: entry.data, isStale }
  }

  /**
   * 设置缓存数据
   * @param key 缓存键
   * @param data 数据
   * @param ttl 过期时间（毫秒），默认 5 分钟
   */
  set<T>(key: string, data: T, ttl: number = 5 * 60 * 1000): void {
    this.cache.set(key, {
      data,
      timestamp: Date.now(),
      ttl,
    })
  }

  /**
   * 删除缓存
   * @param key 缓存键
   */
  delete(key: string): void {
    this.cache.delete(key)
  }

  /**
   * 清除所有缓存
   */
  clear(): void {
    this.cache.clear()
  }

  /**
   * 清除匹配前缀的缓存
   * @param prefix 缓存键前缀
   */
  clearByPrefix(prefix: string): void {
    const keysToDelete: string[] = []
    this.cache.forEach((_, key) => {
      if (key.startsWith(prefix)) {
        keysToDelete.push(key)
      }
    })
    keysToDelete.forEach(key => this.cache.delete(key))
  }

  /**
   * 清理过期缓存
   */
  private cleanup(): void {
    const now = Date.now()
    const keysToDelete: string[] = []
    this.cache.forEach((entry, key) => {
      if (now - entry.timestamp > entry.ttl * 2) {
        keysToDelete.push(key)
      }
    })
    keysToDelete.forEach(key => this.cache.delete(key))
  }

  /**
   * 销毁缓存实例
   */
  destroy(): void {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval)
    }
    this.cache.clear()
  }
}

// 全局缓存实例
export const apiCache = new MemoryCache()

// 缓存 TTL 常量
export const CACHE_TTL = {
  SHORT: 1 * 60 * 1000,      // 1 分钟 - 实时数据
  MEDIUM: 5 * 60 * 1000,     // 5 分钟 - 一般数据
  LONG: 30 * 60 * 1000,      // 30 分钟 - 静态数据
  VERY_LONG: 60 * 60 * 1000, // 1 小时 - 很少变化的数据
}

/**
 * 带缓存的 fetch 函数
 * @param url 请求 URL
 * @param options fetch 选项
 * @param cacheOptions 缓存选项
 */
export async function cachedFetch<T>(
  url: string,
  options?: RequestInit,
  cacheOptions?: {
    ttl?: number
    key?: string
    staleWhileRevalidate?: boolean
  }
): Promise<T> {
  const cacheKey = cacheOptions?.key || url
  const ttl = cacheOptions?.ttl || CACHE_TTL.MEDIUM
  const staleWhileRevalidate = cacheOptions?.staleWhileRevalidate ?? true

  // 尝试从缓存获取
  if (staleWhileRevalidate) {
    const cached = apiCache.getWithStale<T>(cacheKey)
    if (cached) {
      if (!cached.isStale) {
        return cached.data
      }
      // 返回 stale 数据，同时在后台刷新
      fetchAndCache<T>(url, options, cacheKey, ttl).catch(console.error)
      return cached.data
    }
  } else {
    const cached = apiCache.get<T>(cacheKey)
    if (cached) {
      return cached
    }
  }

  // 缓存未命中，发起请求
  return fetchAndCache<T>(url, options, cacheKey, ttl)
}

async function fetchAndCache<T>(
  url: string,
  options: RequestInit | undefined,
  cacheKey: string,
  ttl: number
): Promise<T> {
  // 请求去重 - 如果已有相同请求在进行中，复用该请求
  const existingRequest = pendingRequests.get(cacheKey)
  if (existingRequest) {
    return existingRequest as Promise<T>
  }

  const requestPromise = (async () => {
    try {
      const response = await fetch(url, options)
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      const data = await response.json()
      apiCache.set(cacheKey, data, ttl)
      return data
    } finally {
      // 请求完成后移除
      pendingRequests.delete(cacheKey)
    }
  })()

  pendingRequests.set(cacheKey, requestPromise)
  return requestPromise
}

/**
 * 预加载数据到缓存
 * @param urls 要预加载的 URL 列表
 */
export function prefetchUrls(urls: string[]): void {
  urls.forEach((url) => {
    cachedFetch(url).catch(() => {
      // 预加载失败静默处理
    })
  })
}
