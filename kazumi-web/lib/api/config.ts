/**
 * API 配置 - 照抄 Kazumi 的 api.dart
 */

// Bangumi API 配置
export const BANGUMI_API_BASE = 'https://api.bgm.tv'
export const BANGUMI_NEXT_API_BASE = 'https://next.bgm.tv'
export const BANGUMI_HEADERS = {
  'User-Agent': 'Kazumi/1.9.4 (https://github.com/Predidit/Kazumi)',
  'Accept': 'application/json',
}

export const Api = {
  // 当前版本
  version: '1.9.4',
  // 规则API级别
  apiLevel: 5,
  // 项目主页
  projectUrl: 'https://kazumi.app/',
  // Github 项目主页
  sourceUrl: 'https://github.com/Predidit/Kazumi',
  // 规则仓库
  pluginShop: 'https://raw.githubusercontent.com/Predidit/KazumiRules/main/',
  // 弹弹官网
  dandanIndex: 'https://www.dandanplay.com/',
  // Bangumi 官网
  bangumiIndex: 'https://bangumi.tv/',

  // bangumi API Domain
  bangumiAPIDomain: 'https://api.bgm.tv',
  // 番剧信息
  bangumiInfoByID: '/v0/subjects/{0}',
  // 条目搜索
  bangumiRankSearch: '/v0/search/subjects?limit={0}&offset={1}',
  // 从条目ID获取角色信息
  bangumiCharacterByID: '/v0/subjects/{0}/characters',
  // 从条目ID获取剧集ID
  bangumiEpisodeByID: '/v0/episodes',

  // Bangumi Next API Domain
  bangumiAPINextDomain: 'https://next.bgm.tv',
  // 每日放送
  bangumiCalendar: '/p1/calendar',
  // 番剧趋势
  bangumiTrendsNext: '/p1/trending/subjects',
  // 番剧信息
  bangumiInfoByIDNext: '/p1/subjects/{0}',
  // 番剧评论
  bangumiCommentsByIDNext: '/p1/subjects/{0}/comments?limit={1}&offset={2}',
  // 番剧剧集评论
  bangumiEpisodeCommentsByIDNext: '/p1/episodes/{0}/comments',
  // 番剧角色信息
  bangumiCharacterInfoByCharacterIDNext: '/p1/characters/{0}',
  // 番剧角色评论
  bangumiCharacterCommentsByIDNext: '/p1/characters/{0}/comments',
  // 番剧工作人员信息
  bangumiStaffByIDNext: '/p1/subjects/{0}/staffs/persons',

  // DanDanPlay API Domain
  dandanAPIDomain: 'https://api.dandanplay.net',
  // 获取弹幕
  dandanAPIComment: '/api/v2/comment/',
  // 检索弹弹番剧元数据
  dandanAPISearch: '/api/v2/search/anime',
  // 获取弹弹番剧元数据
  dandanAPIInfo: '/api/v2/bangumi/',
  // 获取弹弹番剧元数据（通过BGM番剧ID）
  dandanAPIInfoByBgmBangumiId: '/api/v2/bangumi/bgmtv/{0}',
}

/**
 * 格式化URL - 照抄 Api.formatUrl
 */
export function formatUrl(url: string, params: (string | number)[]): string {
  let result = url
  for (let i = 0; i < params.length; i++) {
    result = result.replace(`{${i}}`, String(params[i]))
  }
  return result
}

/**
 * 默认动画标签 - 照抄原项目的 defaultAnimeTags
 */
export const defaultAnimeTags = [
  '日常',
  '搞笑',
  '原创',
  '校园',
  '恋爱',
  '奇幻',
  '冒险',
  '战斗',
  '机战',
  '治愈',
  '百合',
  '后宫',
  '悬疑',
  '推理',
  '科幻',
  '运动',
  '音乐',
  '偶像',
  '美食',
  '职场',
  '历史',
  '战争',
  '恐怖',
  '惊悚',
]
