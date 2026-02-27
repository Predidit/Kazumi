/**
 * Super Resolution Hook - 基于 anime4k-webgpu 实现
 * 照抄原项目 super_resolution_settings.dart
 * 
 * 超分辨率类型:
 * 1 = OFF (禁用)
 * 2 = Efficiency (效率优先 - CNNx2M)
 * 3 = Quality (质量优先 - CNNx2UL + GANUUL)
 */

import { useState, useEffect, useCallback, useRef } from 'react'
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

// 超分辨率类型 - 照抄原项目
export type SuperResolutionType = 1 | 2 | 3
export const SUPER_RESOLUTION_LABELS: Record<SuperResolutionType, string> = {
  1: 'OFF',
  2: 'Efficiency',
  3: 'Quality',
}
export const SUPER_RESOLUTION_DESCRIPTIONS: Record<SuperResolutionType, string> = {
  1: '默认禁用超分辨率',
  2: '默认启用基于Anime4K的超分辨率 (效率优先)',
  3: '默认启用基于Anime4K的超分辨率 (质量优先)',
}

// Store for super resolution settings
interface SuperResolutionStore {
  type: SuperResolutionType
  hideWarning: boolean
  webGPUSupported: boolean | null
  setType: (type: SuperResolutionType) => void
  setHideWarning: (hide: boolean) => void
  setWebGPUSupported: (supported: boolean | null) => void
}

export const useSuperResolutionStore = create<SuperResolutionStore>()(
  persist(
    (set) => ({
      type: 1, // 默认禁用
      hideWarning: false,
      webGPUSupported: null,
      setType: (type) => set({ type }),
      setHideWarning: (hideWarning) => set({ hideWarning }),
      setWebGPUSupported: (webGPUSupported) => set({ webGPUSupported }),
    }),
    {
      name: 'super-resolution-settings',
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({
        type: state.type,
        hideWarning: state.hideWarning,
      }),
    }
  )
)

// Anime4K render cleanup function type
type CleanupFunction = () => void

interface UseSuperResolutionResult {
  type: SuperResolutionType
  hideWarning: boolean
  webGPUSupported: boolean | null
  isProcessing: boolean
  error: string | null
  setType: (type: SuperResolutionType) => void
  setHideWarning: (hide: boolean) => void
  initSuperResolution: (video: HTMLVideoElement, canvas: HTMLCanvasElement) => Promise<CleanupFunction | null>
  checkWebGPUSupport: () => Promise<boolean>
}

/**
 * Hook for super resolution using anime4k-webgpu
 */
export function useSuperResolution(): UseSuperResolutionResult {
  const { type, hideWarning, webGPUSupported, setType, setHideWarning, setWebGPUSupported } = useSuperResolutionStore()
  const [isProcessing, setIsProcessing] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const cleanupRef = useRef<CleanupFunction | null>(null)

  /**
   * Check if WebGPU is supported
   */
  const checkWebGPUSupport = useCallback(async (): Promise<boolean> => {
    if (typeof window === 'undefined') {
      return false
    }
    
    try {
      if (!navigator.gpu) {
        setWebGPUSupported(false)
        return false
      }
      
      const adapter = await navigator.gpu.requestAdapter()
      if (!adapter) {
        setWebGPUSupported(false)
        return false
      }
      
      setWebGPUSupported(true)
      return true
    } catch {
      setWebGPUSupported(false)
      return false
    }
  }, [setWebGPUSupported])

  /**
   * Initialize super resolution rendering
   * Returns a cleanup function
   */
  const initSuperResolution = useCallback(async (
    video: HTMLVideoElement,
    canvas: HTMLCanvasElement
  ): Promise<CleanupFunction | null> => {
    // Clean up previous instance
    if (cleanupRef.current) {
      cleanupRef.current()
      cleanupRef.current = null
    }

    // If disabled, return null
    if (type === 1) {
      return null
    }

    // Check WebGPU support
    const supported = await checkWebGPUSupport()
    if (!supported) {
      setError('您的浏览器不支持 WebGPU，无法使用超分辨率功能')
      return null
    }

    setIsProcessing(true)
    setError(null)

    try {
      // Dynamic import to avoid SSR issues
      const anime4k = await import('anime4k-webgpu')
      const { render, CNNx2M, CNNx2UL, GANUUL } = anime4k

      // Build pipeline based on type
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const pipelineBuilder: any = type === 2
        ? // Efficiency mode - CNNx2M only
          (device: GPUDevice, inputTexture: GPUTexture) => {
            const upscale = new CNNx2M({ device, inputTexture })
            return [upscale]
          }
        : // Quality mode - CNNx2UL + GANUUL
          (device: GPUDevice, inputTexture: GPUTexture) => {
            const upscale = new CNNx2UL({ device, inputTexture })
            const restore = new GANUUL({
              device,
              inputTexture: upscale.getOutputTexture(),
            })
            return [upscale, restore]
          }

      // Start rendering
      await render({
        video,
        canvas,
        pipelineBuilder,
      })

      console.log(`Super Resolution: initialized with mode ${SUPER_RESOLUTION_LABELS[type]}`)

      // Create cleanup function
      const cleanup: CleanupFunction = () => {
        // The render function handles its own cleanup when video ends
        // We just need to clear our reference
        console.log('Super Resolution: cleanup')
      }

      cleanupRef.current = cleanup
      setIsProcessing(false)
      return cleanup
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      setError(`超分辨率初始化失败: ${message}`)
      setIsProcessing(false)
      console.error('Super Resolution: init failed', err)
      return null
    }
  }, [type, checkWebGPUSupport])

  // Check WebGPU support on mount
  useEffect(() => {
    if (webGPUSupported === null) {
      checkWebGPUSupport()
    }
  }, [webGPUSupported, checkWebGPUSupport])

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (cleanupRef.current) {
        cleanupRef.current()
      }
    }
  }, [])

  return {
    type,
    hideWarning,
    webGPUSupported,
    isProcessing,
    error,
    setType,
    setHideWarning,
    initSuperResolution,
    checkWebGPUSupport,
  }
}
