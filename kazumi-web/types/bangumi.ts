/**
 * Bangumi 数据类型 - 照抄 Kazumi 的数据模型
 */

// ============ BangumiItem - 照抄 bangumi_item.dart ============

export interface BangumiTag {
  name: string
  count: number
}

export interface BangumiItem {
  id: number
  type: number
  name: string
  nameCn: string
  summary: string
  airDate: string
  airWeekday: number
  rank: number
  images: {
    large: string
    common: string
    medium: string
    small: string
    grid: string
  }
  tags: BangumiTag[]
  alias: string[]
  ratingScore: number
  votes: number
  votesCount: number[]
  info: string
}

/**
 * 从API响应解析BangumiItem - 照抄 BangumiItem.fromJson
 */
export function parseBangumiItem(json: any): BangumiItem {
  // 解析别名
  function parseBangumiAliases(jsonData: any): string[] {
    if (jsonData.infobox && Array.isArray(jsonData.infobox)) {
      for (const item of jsonData.infobox) {
        if (item && item.key === '别名') {
          const value = item.value
          if (Array.isArray(value)) {
            return value
              .map((element: any) => {
                if (element && element.v) {
                  return String(element.v)
                }
                return ''
              })
              .filter((alias: string) => alias.length > 0)
          }
        }
      }
    }
    return []
  }

  // 解析投票数
  function parseBangumiVoteCount(jsonData: any): number[] {
    if (!jsonData.rating) {
      return []
    }
    const count = jsonData.rating.count
    // For api.bgm.tv
    if (count && typeof count === 'object' && !Array.isArray(count)) {
      return Array.from({ length: 10 }, (_, i) => count[String(i + 1)] || 0)
    }
    // For next.bgm.tv
    if (Array.isArray(count)) {
      return count.map((e: any) => Number(e) || 0)
    }
    return []
  }

  // 计算星期几
  function dateStringToWeekday(dateStr: string): number {
    try {
      const date = new Date(dateStr)
      const day = date.getDay()
      return day === 0 ? 7 : day // 周日返回7
    } catch {
      return 1
    }
  }

  const list = json.tags || []
  const tagList: BangumiTag[] = list.map((i: any) => ({
    name: i.name || '',
    count: i.count || 0,
  }))
  const bangumiAlias = parseBangumiAliases(json)
  const voteList = parseBangumiVoteCount(json)

  // nameCn 处理逻辑 - 照抄原项目
  let nameCn = json.name_cn || ''
  if (nameCn === '') {
    nameCn = json.nameCN || ''
    if (nameCn === '') {
      nameCn = json.name || ''
    }
  }

  return {
    id: json.id,
    type: json.type ?? 2,
    name: json.name || '',
    nameCn,
    summary: json.summary || '',
    airDate: json.date || '',
    airWeekday: dateStringToWeekday(json.date || '2000-11-11'),
    rank: json.rating?.rank ?? 0,
    images: json.images || {
      large: json.image || '',
      common: '',
      medium: '',
      small: '',
      grid: '',
    },
    tags: tagList,
    alias: bangumiAlias,
    ratingScore: Number((json.rating?.score ?? 0).toFixed(1)),
    votes: json.rating?.total ?? 0,
    votesCount: voteList,
    info: json.info || '',
  }
}

// ============ EpisodeInfo - 照抄 episode_item.dart ============

export interface EpisodeInfo {
  id: number
  type: number
  name: string
  nameCn: string
  sort: number
  ep: number
  airdate: string
  comment: number
  duration: string
  desc: string
  disc: number
  durationSeconds: number
}

export function parseEpisodeInfo(json: any): EpisodeInfo {
  return {
    id: json.id ?? 0,
    type: json.type ?? 0,
    name: json.name ?? '',
    nameCn: json.name_cn ?? '',
    sort: json.sort ?? 0,
    ep: json.ep ?? 0,
    airdate: json.airdate ?? '',
    comment: json.comment ?? 0,
    duration: json.duration ?? '',
    desc: json.desc ?? '',
    disc: json.disc ?? 0,
    durationSeconds: json.duration_seconds ?? 0,
  }
}

// ============ CommentItem - 照抄 comment_item.dart ============

export interface UserAvatar {
  small: string
  medium: string
  large: string
}

export interface User {
  id: number
  username: string
  nickname: string
  avatar: UserAvatar
  sign: string
  joinedAt: number
}

export interface Comment {
  rate: number
  comment: string
  updatedAt: number
}

export interface CommentItem {
  user: User
  comment: Comment
}

export function parseCommentItem(json: any): CommentItem {
  return {
    user: {
      id: json.user?.id ?? 0,
      username: json.user?.username ?? '',
      nickname: json.user?.nickname ?? '',
      avatar: {
        small: json.user?.avatar?.small ?? '',
        medium: json.user?.avatar?.medium ?? '',
        large: json.user?.avatar?.large ?? '',
      },
      sign: json.user?.sign ?? '',
      joinedAt: json.user?.joinedAt ?? 0,
    },
    comment: {
      rate: json.rate ?? 0,
      comment: json.comment ?? '',
      updatedAt: json.updatedAt ?? 0,
    },
  }
}

export interface CommentResponse {
  commentList: CommentItem[]
  total: number
}

export function parseCommentResponse(json: any): CommentResponse {
  const list = json.list || json.data || []
  return {
    commentList: list.map((i: any) => parseCommentItem(i)),
    total: json.total ?? 0,
  }
}

// ============ CharacterItem - 照抄 character_item.dart ============

export interface CharacterAvatar {
  small: string
  medium: string
  grid: string
  large: string
}

export interface ActorItem {
  id: number
  name: string
  type: number
  images: CharacterAvatar
}

export interface CharacterItem {
  id: number
  type: number
  name: string
  relation: string
  images: CharacterAvatar
  actors: ActorItem[]
}

export function parseCharacterItem(json: any): CharacterItem {
  const actors = (json.actors || []).map((actor: any) => ({
    id: actor.id ?? 0,
    name: actor.name ?? '',
    type: actor.type ?? 0,
    images: {
      small: actor.images?.small ?? '',
      medium: actor.images?.medium ?? '',
      grid: actor.images?.grid ?? '',
      large: actor.images?.large ?? '',
    },
  }))

  return {
    id: json.id ?? 0,
    type: json.type ?? 0,
    name: json.name ?? '',
    relation: json.relation ?? '未知',
    images: {
      small: json.images?.small ?? '',
      medium: json.images?.medium ?? '',
      grid: json.images?.grid ?? '',
      large: json.images?.large ?? '',
    },
    actors,
  }
}

export interface CharactersResponse {
  charactersList: CharacterItem[]
}

export function parseCharactersResponse(json: any[]): CharactersResponse {
  return {
    charactersList: json.map((i) => parseCharacterItem(i)),
  }
}

// ============ StaffItem - 照抄 staff_item.dart ============

export interface StaffImages {
  large: string
  medium: string
  small: string
  grid: string
}

export interface Staff {
  id: number
  name: string
  nameCN: string
  type: number
  info: string
  comment: number
  lock: boolean
  nsfw: boolean
  images: StaffImages | null
}

export interface PositionType {
  id: number
  en: string
  cn: string
  jp: string
}

export interface Position {
  type: PositionType
  summary: string
  appearEps: string
}

export interface StaffFullItem {
  staff: Staff
  positions: Position[]
}

export function parseStaffFullItem(json: any): StaffFullItem {
  return {
    staff: {
      id: json.staff?.id ?? 0,
      name: json.staff?.name ?? '',
      nameCN: json.staff?.nameCN ?? '',
      type: json.staff?.type ?? 0,
      info: json.staff?.info ?? '',
      comment: json.staff?.comment ?? 0,
      lock: json.staff?.lock ?? false,
      nsfw: json.staff?.nsfw ?? false,
      images: json.staff?.images
        ? {
            large: json.staff.images.large ?? '',
            medium: json.staff.images.medium ?? '',
            small: json.staff.images.small ?? '',
            grid: json.staff.images.grid ?? '',
          }
        : null,
    },
    positions: (json.positions || []).map((pos: any) => ({
      type: {
        id: pos.type?.id ?? 0,
        en: pos.type?.en ?? '',
        cn: pos.type?.cn ?? '',
        jp: pos.type?.jp ?? '',
      },
      summary: pos.summary ?? '',
      appearEps: pos.appearEps ?? '',
    })),
  }
}

export interface StaffResponse {
  data: StaffFullItem[]
  total: number
}

export function parseStaffResponse(json: any): StaffResponse {
  return {
    data: (json.data || []).map((item: any) => parseStaffFullItem(item)),
    total: json.total ?? 0,
  }
}
