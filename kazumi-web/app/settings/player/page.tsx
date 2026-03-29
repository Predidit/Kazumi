/**
 * Player Settings Page - 照抄原项目的 player_settings.dart
 */

'use client'

import Link from 'next/link'
import { SettingItem, SettingSection } from '@/components/ui'
import { usePlayerSettings, ASPECT_RATIO_MAP } from '@/lib/hooks/usePlayerSettings'

export default function PlayerSettingsPage() {
  const { settings, loaded, updateSetting } = usePlayerSettings()

  if (!loaded) {
    return (
      <div className="min-h-screen safe-area-all flex items-center justify-center">
        <div className="w-8 h-8 border-3 border-primary-500/30 border-t-primary-500 rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="min-h-screen safe-area-all">
      <main className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="flex items-center gap-3 mb-6">
          <Link
            href="/settings"
            className="w-10 h-10 flex items-center justify-center rounded-full bg-primary-100 hover:bg-primary-200 transition-colors"
          >
            <span className="material-symbols-rounded text-primary-600">arrow_back</span>
          </Link>
          <h1 className="text-2xl font-bold text-primary-900">播放设置</h1>
        </div>

        {/* Content */}
        <div className="max-w-2xl mx-auto pb-24">
          {/* 播放行为 */}
          <SettingSection title="播放行为">
            <SettingItem
              type="switch"
              title="自动跳转"
              description="跳转到上次播放位置"
              checked={settings.playResume}
              onChange={(v) => updateSetting('playResume', v)}
            />
            <SettingItem
              type="switch"
              title="自动连播"
              description="当前视频播放完毕后自动播放下一集"
              checked={settings.autoPlayNext}
              onChange={(v) => updateSetting('autoPlayNext', v)}
            />
            <SettingItem
              type="switch"
              title="广告过滤"
              description="强制启用HLS广告过滤"
              checked={settings.forceAdBlocker}
              onChange={(v) => updateSetting('forceAdBlocker', v)}
            />
            <SettingItem
              type="switch"
              title="禁用动画"
              description="禁用播放器内的过渡动画"
              checked={settings.playerDisableAnimations}
              onChange={(v) => updateSetting('playerDisableAnimations', v)}
            />
            <SettingItem
              type="switch"
              title="隐身模式"
              description="不保留观看记录"
              checked={settings.privateMode}
              onChange={(v) => updateSetting('privateMode', v)}
            />
          </SettingSection>

          {/* 调试选项 */}
          <SettingSection title="调试选项">
            <SettingItem
              type="switch"
              title="错误提示"
              description="显示播放器内部错误提示"
              checked={settings.showPlayerError}
              onChange={(v) => updateSetting('showPlayerError', v)}
            />
            <SettingItem
              type="switch"
              title="调试模式"
              description="记录播放器内部日志"
              checked={settings.playerDebugMode}
              onChange={(v) => updateSetting('playerDebugMode', v)}
            />
          </SettingSection>

          {/* 超分辨率 - 照抄原项目 */}
          <SettingSection title="画质增强">
            <SettingItem
              type="navigation"
              title="超分辨率"
              description="基于 Anime4K 的实时视频超分辨率 (需要 WebGPU)"
              href="/settings/player/super-resolution"
            />
          </SettingSection>

          {/* 默认倍速 */}
          <SettingSection title="默认倍速">
            <SettingItem
              type="slider"
              title="播放倍速"
              value={settings.defaultPlaySpeed}
              min={0.5}
              max={2}
              step={0.25}
              onChange={(v) => updateSetting('defaultPlaySpeed', v)}
              formatValue={(v) => `${v}x`}
            />
          </SettingSection>

          {/* 默认视频比例 */}
          <SettingSection title="默认视频比例">
            <SettingItem
              type="custom"
              title="视频比例"
            >
              <div className="flex flex-wrap gap-2">
                {Object.entries(ASPECT_RATIO_MAP).map(([key, label]) => (
                  <button
                    key={key}
                    onClick={() => updateSetting('defaultAspectRatioType', parseInt(key))}
                    className={`px-4 py-2 rounded-full text-sm transition-colors ${
                      settings.defaultAspectRatioType === parseInt(key)
                        ? 'bg-primary-500 text-white'
                        : 'bg-primary-100 text-primary-700 hover:bg-primary-200'
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </SettingItem>
          </SettingSection>

          {/* 跳过时长 */}
          <SettingSection title="跳过时长">
            <SettingItem
              type="slider"
              title="顶栏跳过按钮"
              description="顶栏跳过按钮的秒数"
              value={settings.buttonSkipTime}
              min={10}
              max={120}
              step={10}
              onChange={(v) => updateSetting('buttonSkipTime', v)}
              formatValue={(v) => `${v}秒`}
            />
            <SettingItem
              type="slider"
              title="方向键快进/快退"
              description="左右方向键的快进/快退秒数"
              value={settings.arrowKeySkipTime}
              min={0}
              max={15}
              step={1}
              onChange={(v) => updateSetting('arrowKeySkipTime', v)}
              formatValue={(v) => `${v}秒`}
            />
          </SettingSection>
        </div>
      </main>
    </div>
  )
}
