/**
 * Episode-related type definitions
 * Based on Bangumi API episode structures
 */

export interface Episode {
  id: number
  type: number // 0=main, 1=SP, 2=OP, 3=ED
  name: string
  nameCn: string
  ep: number
  sort: number
  airdate: string
  duration: string
  desc: string
  subjectId: number
  comment: number
  disc: number
  durationSeconds: number
}

export interface EpisodeResponse {
  data: Episode[]
  total: number
  limit: number
  offset: number
}
