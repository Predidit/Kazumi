'use client'

/**
 * 超分辨率设置页面
 * 照抄原项目 lib/pages/settings/super_resolution_settings.dart
 * 
 * 使用 anime4k-webgpu 实现基于 WebGPU 的实时视频超分辨率
 * 需要 iOS 26+ / Safari 26+ 或支持 WebGPU 的浏览器
 */

import { useEffect } from 'react'
import Link from 'next/link'
import { SettingItem, SettingSection } from '@/components/ui'
import {
  useSuperResolution,
  SUPER_RESOLUTION_LABELS,
  SUPER_RESOLUTION_DESCRIPTIONS,
  type SuperResolutionType,
} from '@/lib/hooks/useSuperResolution'

export default function SuperResolutionSettingsPage() {
  const {
    type,
    hideWarning,
    webGPUSupported,
    setType,
    setHideWarning,
    checkWebGPUSupport,
  } = useSuperResolution()

  // Check WebGPU support on mount
  useEffect(() => {
    checkWebGPUSupport()
  }, [checkWebGPUSupport])

  const options: SuperResolutionType[] = [1, 2, 3]

  return (
    <div className="min-h-screen safe-area-all">
      <main className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="flex items-center gap-3 mb-6">
          <Link
            href="/settings/player"
            className="w-10 h-10 flex items-center justify-center rounded-full bg-primary-100 hover:bg-primary-200 transition-colors"
          >
            <span className="material-symbols-rounded text-primary-600">arrow_back</span>
          </Link>
          <h1 className="text-2xl font-bold text-primary-900">超分辨率</h1>
        </div>

        {/* Content */}
        <div className="max-w-2xl mx-auto pb-24">
          {/* WebGPU Status */}
          <SettingSection title="WebGPU 状态">
            <div className="p-4">
              <div className="flex items-center gap-3">
                <div className={`w-3 h-3 rounded-full ${
                  webGPUSupported === null
                    ? 'bg-yellow-500 animate-pulse'
                    : webGPUSupported
                    ? 'bg-green-500'
                    : 'bg-red-500'
                }`} />
                <span className="text-primary-700">
                  {webGPUSupported === null
                    ? '正在检测...'
                    : webGPUSupported
                    ? 'WebGPU 已支持'
                    : 'WebGPU 不支持'}
                </span>
              </div>
              {webGPUSupported === false && (
                <p className="mt-2 text-sm text-red-500">
                  您的浏览器不支持 WebGPU。超分辨率功能需要 iOS 26+ / Safari 26+ 或其他支持 WebGPU 的浏览器。
                </p>
              )}
              {webGPUSupported && (
                <p className="mt-2 text-sm text-primary-500">
                  超分辨率使用 GPU 加速，可能会增加设备功耗和发热。
                </p>
              )}
            </div>
          </SettingSection>

          {/* Mode Selection - 照抄原项目的 RadioTile 样式 */}
          <SettingSection title="超分辨率模式">
            <div className="p-2">
              <p className="px-2 pb-3 text-sm text-primary-500">
                超分辨率基于 Anime4K 算法，使用 WebGPU 在客户端实时处理视频帧
              </p>
              {options.map((option) => (
                <button
                  key={option}
                  onClick={() => webGPUSupported !== false && setType(option)}
                  disabled={webGPUSupported === false && option !== 1}
                  className={`w-full p-4 mb-2 rounded-xl text-left transition-all ${
                    type === option
                      ? 'bg-primary-500 text-white'
                      : webGPUSupported === false && option !== 1
                      ? 'bg-primary-50 text-primary-300 cursor-not-allowed'
                      : 'bg-primary-50 text-primary-700 hover:bg-primary-100'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="font-medium">{SUPER_RESOLUTION_LABELS[option]}</div>
                      <div className={`text-sm mt-1 ${
                        type === option ? 'text-white/80' : 'text-primary-500'
                      }`}>
                        {SUPER_RESOLUTION_DESCRIPTIONS[option]}
                      </div>
                    </div>
                    {type === option && (
                      <span className="material-symbols-rounded">check_circle</span>
                    )}
                  </div>
                </button>
              ))}
            </div>
          </SettingSection>

          {/* Default Behavior */}
          <SettingSection title="默认行为">
            <SettingItem
              type="switch"
              title="关闭提示"
              description="关闭每次启用超分辨率时的提示"
              checked={hideWarning}
              onChange={setHideWarning}
            />
          </SettingSection>

          {/* Technical Info */}
          <SettingSection title="技术说明">
            <div className="p-4 space-y-3 text-sm text-primary-600">
              <div className="flex items-start gap-2">
                <span className="material-symbols-rounded text-primary-400 text-lg">info</span>
                <p>
                  <strong>Efficiency 模式</strong>: 使用 CNNx2M 算法，速度快，适合性能较低的设备
                </p>
              </div>
              <div className="flex items-start gap-2">
                <span className="material-symbols-rounded text-primary-400 text-lg">info</span>
                <p>
                  <strong>Quality 模式</strong>: 使用 CNNx2UL + GANUUL 算法，画质更好，但需要更多 GPU 资源
                </p>
              </div>
              <div className="flex items-start gap-2">
                <span className="material-symbols-rounded text-primary-400 text-lg">warning</span>
                <p>
                  超分辨率会将视频分辨率提升 2 倍，可能会增加设备功耗。建议在电量充足时使用。
                </p>
              </div>
            </div>
          </SettingSection>
        </div>
      </main>
    </div>
  )
}
