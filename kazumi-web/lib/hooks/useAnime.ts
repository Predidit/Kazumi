/**
 * Custom React hook for anime data fetching and management
 * 照抄 Kazumi 的数据获取逻辑
 */

import { useState, useEffect, useCallback } from 'react'
import { useAnimeState } from '@/lib/store'
import type { AnimeDetail } from '@/types/anime'
import type { Character } from '@/types/character'

interface UseAnimeOptions {
  autoFetch?: boolean
}

interface UseAnimeResult {
  anime: AnimeDetail | null
  loading: boolean
  error: Error | null
  fetchAnime: (id: number) => Promise<void>
  clearAnime: () => void
}

/**
 * Hook for managing anime data - 照抄原项目的 InfoController
 */
export function useAnime(
  animeId?: number,
  options: UseAnimeOptions = {}
): UseAnimeResult {
  const { autoFetch = true } = options
  const { currentAnime, setCurrentAnime } = useAnimeState()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  /**
   * Fetch anime details by ID - 照抄 BangumiHTTP.getBangumiInfoByID
   */
  const fetchAnime = useCallback(
    async (id: number) => {
      setLoading(true)
      setError(null)

      try {
        const response = await fetch(`/api/bangumi/subject/${id}`)
        if (!response.ok) throw new Error('获取番剧信息失败')
        const anime = await response.json()
        setCurrentAnime(anime)
      } catch (err) {
        const error = err instanceof Error ? err : new Error(String(err))
        setError(error)
        console.error('Failed to fetch anime:', error)
      } finally {
        setLoading(false)
      }
    },
    [setCurrentAnime]
  )

  /**
   * Clear current anime
   */
  const clearAnime = useCallback(() => {
    setCurrentAnime(null)
    setError(null)
  }, [setCurrentAnime])

  /**
   * Auto-fetch anime on mount if animeId is provided
   */
  useEffect(() => {
    if (animeId && autoFetch) {
      fetchAnime(animeId)
    }
  }, [animeId, autoFetch, fetchAnime])

  return {
    anime: currentAnime,
    loading,
    error,
    fetchAnime,
    clearAnime,
  }
}

/**
 * Hook for fetching anime episodes - 照抄 BangumiHTTP.getBangumiEpisodeByID
 */
export function useEpisodes(subjectId: number | undefined) {
  const [episodes, setEpisodes] = useState<any[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const fetchEpisodes = useCallback(async () => {
    if (!subjectId) return
    setLoading(true)
    setError(null)
    try {
      const response = await fetch(`/api/bangumi/episodes?subject_id=${subjectId}&limit=100`)
      if (!response.ok) throw new Error('获取剧集列表失败')
      const data = await response.json()
      setEpisodes(data.data || [])
    } catch (err) {
      setError(err instanceof Error ? err : new Error(String(err)))
    } finally {
      setLoading(false)
    }
  }, [subjectId])

  useEffect(() => {
    if (subjectId) fetchEpisodes()
  }, [subjectId, fetchEpisodes])

  return { episodes, loading, error, refetch: fetchEpisodes }
}

/**
 * Hook for fetching anime characters - 照抄 BangumiHTTP.getCharatersByBangumiID
 */
export function useCharacters(subjectId: number | undefined) {
  const [characters, setCharacters] = useState<Character[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const fetchCharacters = useCallback(async () => {
    if (!subjectId) return
    setLoading(true)
    setError(null)
    try {
      const response = await fetch(`/api/bangumi/characters?subject_id=${subjectId}`)
      if (!response.ok) throw new Error('获取角色列表失败')
      const data = await response.json()
      setCharacters(data || [])
    } catch (err) {
      setError(err instanceof Error ? err : new Error(String(err)))
    } finally {
      setLoading(false)
    }
  }, [subjectId])

  useEffect(() => {
    if (subjectId) fetchCharacters()
  }, [subjectId, fetchCharacters])

  return { characters, loading, error, refetch: fetchCharacters }
}

/**
 * Hook for fetching anime comments - 照抄 BangumiHTTP.getBangumiCommentsByID
 */
export function useComments(subjectId: number | undefined) {
  const [comments, setComments] = useState<any[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const fetchComments = useCallback(async () => {
    if (!subjectId) return
    setLoading(true)
    setError(null)
    try {
      const response = await fetch(`/api/bangumi/comments?subject_id=${subjectId}`)
      if (!response.ok) throw new Error('获取评论列表失败')
      const data = await response.json()
      // 照抄原项目: API 返回 { commentList: [...], total: N }
      const commentList = data.commentList || data || []
      // 添加 id 字段
      const commentsWithId = commentList.map((item: any, index: number) => ({
        ...item,
        id: item.id || index,
      }))
      setComments(commentsWithId)
    } catch (err) {
      setError(err instanceof Error ? err : new Error(String(err)))
    } finally {
      setLoading(false)
    }
  }, [subjectId])

  return { comments, loading, error, fetchComments }
}

/**
 * Hook for fetching anime staff - 照抄 BangumiHTTP.getBangumiStaffByID
 */
export function useStaff(subjectId: number | undefined) {
  const [staff, setStaff] = useState<any[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const fetchStaff = useCallback(async () => {
    if (!subjectId) return
    setLoading(true)
    setError(null)
    try {
      const response = await fetch(`/api/bangumi/staff?subject_id=${subjectId}`)
      if (!response.ok) throw new Error('获取制作人员列表失败')
      const data = await response.json()
      // 照抄原项目: API 返回 { data: [...], total: N }
      let staffList: any[] = []
      if (Array.isArray(data?.data)) {
        staffList = data.data.map((item: any) => {
          const staffInfo = item?.staff || {}
          const positions = Array.isArray(item?.positions) ? item.positions : []
          const firstPosition = positions[0]
          const relation = firstPosition?.type?.cn || firstPosition?.type?.jp || firstPosition?.type?.en || ''
          return {
            id: staffInfo.id,
            name: staffInfo.name || '',
            name_cn: staffInfo.nameCN || '',
            images: staffInfo.images || null,
            relation,
          }
        })
      } else if (Array.isArray(data)) {
        staffList = data
      }
      setStaff(staffList)
    } catch (err) {
      setError(err instanceof Error ? err : new Error(String(err)))
    } finally {
      setLoading(false)
    }
  }, [subjectId])

  return { staff, loading, error, fetchStaff }
}
