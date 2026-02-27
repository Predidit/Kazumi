/**
 * Episode ID Construction Utility
 * 
 * This utility constructs unique episode IDs for DanDanPlay API integration.
 * The Episode ID format enables correct danmaku fetching by combining anime ID
 * with episode number in a standardized way.
 */

/**
 * Constructs an Episode ID from anime ID and episode number.
 * 
 * Formula: animeId * 10000 + episode
 * 
 * This creates a unique identifier that DanDanPlay API uses to fetch
 * danmaku comments for a specific episode.
 * 
 * @param animeId - The DanDanPlay anime ID
 * @param episode - The episode number (1-based)
 * @returns The constructed Episode ID
 * 
 * @example
 * ```typescript
 * // For anime ID 123 and episode 5
 * const episodeId = constructEpisodeId(123, 5);
 * // Returns: 1230005
 * ```
 * 
 * @example
 * ```typescript
 * // For anime ID 456 and episode 12
 * const episodeId = constructEpisodeId(456, 12);
 * // Returns: 4560012
 * ```
 */
export function constructEpisodeId(animeId: number, episode: number): number {
  return animeId * 10000 + episode;
}
