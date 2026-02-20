/**
 * Character and staff-related type definitions
 * Based on Bangumi API character and staff structures
 */

import { Images } from './anime'

export interface Character {
  id: number
  type: number
  name: string
  relation: string
  summary: string
  images: Images
  actors: Actor[]
}

export interface Actor {
  id: number
  type: number
  name: string
  shortSummary: string
  career: string[]
  locked: boolean
  images: Images
}

export interface StaffResponse {
  data: StaffItem[]
  total: number
}

export interface StaffItem {
  staff: Staff
  positions: Position[]
}

export interface Staff {
  id: number
  type: number
  name: string
  nameCN: string
  info: string
  career: string[]
  comment: number
  lock: boolean
  nsfw: boolean
}

export interface Position {
  type: PositionType
  summary: string
  appearEps: string
}

export interface PositionType {
  id: number
  en: string
  cn: string
  jp: string
}
