/**
 * Danmaku Comment Parser Utility
 * 
 * This utility parses danmaku comments from DanDanPlay API format into
 * a structured format suitable for rendering in the video player.
 * The parser handles the p parameter format and converts color values
 * from decimal to hexadecimal format.
 */

import type { DanmakuComment, Danmaku } from '@/types/danmaku';

/**
 * Parses a danmaku comment from DanDanPlay API format.
 * 
 * The p parameter format is: "time,type,color,source,pool,userId,mode"
 * - time: Float representing seconds from video start
 * - type: Integer representing comment type (1=scroll, 4=bottom, 5=top)
 * - color: Decimal integer representing RGB color
 * - source: String identifying the comment source
 * - pool: Integer representing comment pool
 * - userId: String representing the user ID
 * - mode: Integer representing display mode
 * 
 * @param comment - The raw danmaku comment from DanDanPlay API
 * @returns Parsed danmaku object ready for rendering
 * 
 * @example
 * ```typescript
 * // Parse a scrolling comment at 10.5 seconds with white color
 * const comment: DanmakuComment = {
 *   p: "10.5,1,16777215,dandanplay,0,user123,1",
 *   m: "这个场景太棒了！"
 * };
 * const danmaku = parseDanmakuComment(comment);
 * // Returns: {
 * //   message: "这个场景太棒了！",
 * //   time: 10.5,
 * //   type: 1,
 * //   color: "#ffffff",
 * //   source: "dandanplay"
 * // }
 * ```
 * 
 * @example
 * ```typescript
 * // Parse a top comment at 30 seconds with red color
 * const comment: DanmakuComment = {
 *   p: "30.0,5,16711680,bilibili,0,user456,1",
 *   m: "笑死我了"
 * };
 * const danmaku = parseDanmakuComment(comment);
 * // Returns: {
 * //   message: "笑死我了",
 * //   time: 30.0,
 * //   type: 5,
 * //   color: "#ff0000",
 * //   source: "bilibili"
 * // }
 * ```
 */
export function parseDanmakuComment(comment: DanmakuComment): Danmaku {
  // Split the p parameter by comma
  const params = comment.p.split(',');
  
  // Extract the required parameters with fallback values
  // 照抄原项目的 Danmaku.fromJson 格式: time,type,color,source
  const time = params[0] ? parseFloat(params[0]) : 0;
  const type = params[1] ? parseInt(params[1], 10) : 1; // 默认滚动弹幕
  const colorDecimal = params[2] ? parseInt(params[2], 10) : 16777215; // 默认白色
  const source = params[3] || '';
  
  // Convert decimal color to hexadecimal format
  // Ensure the hex string is always 6 characters (padded with zeros)
  // 处理 NaN 情况
  const validColor = isNaN(colorDecimal) ? 16777215 : colorDecimal;
  const colorHex = `#${validColor.toString(16).padStart(6, '0')}`;
  
  return {
    message: comment.m || '',
    time: isNaN(time) ? 0 : time,
    type: isNaN(type) ? 1 : type,
    color: colorHex,
    source
  };
}
