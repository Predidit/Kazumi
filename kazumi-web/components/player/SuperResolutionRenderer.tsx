/**
 * Super Resolution Renderer Component
 * 使用 anime4k-webgpu 实现实时视频超分辨率
 * 
 * 工作原理:
 * 1. 将 video 元素的内容渲染到 canvas
 * 2. 使用 WebGPU 着色器处理每一帧
 * 3. 输出到 canvas 显示
 */

'use client'

import { useEffect, useRef, useState, useCallback } from 'react'
import { useSuperResolutionStore, SUPER_RESOLUTION_LABELS } from '@/lib/hooks/useSuperResolution'

interface SuperResolutionRendererProps {
  videoRef: React.RefObject<HTMLVideoElement>
  enabled?: boolean
  className?: string
}

export function SuperResolutionRenderer({
  videoRef,
  enabled = true,
  className = '',
}: SuperResolutionRendererProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const animationFrameRef = useRef<number | null>(null)
  const renderCleanupRef = useRef<(() => void) | null>(null)
  
  const { type, hideWarning } = useSuperResolutionStore()
  const [isInitialized, setIsInitialized] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [showWarning, setShowWarning] = useState(false)
  const [webGPUSupported, setWebGPUSupported] = useState<boolean | null>(null)

  // Check WebGPU support
  const checkWebGPU = useCallback(async () => {
    if (typeof window === 'undefined') return false
    try {
      if (!navigator.gpu) return false
      const adapter = await navigator.gpu.requestAdapter()
      return !!adapter
    } catch {
      return false
    }
  }, [])

  // Initialize super resolution
  const initSuperResolution = useCallback(async () => {
    const video = videoRef.current
    const canvas = canvasRef.current
    
    if (!video || !canvas || type === 1) {
      setIsInitialized(false)
      return
    }

    // Check WebGPU support
    const supported = await checkWebGPU()
    setWebGPUSupported(supported)
    
    if (!supported) {
      setError('WebGPU 不支持')
      return
    }

    // Show warning if not hidden
    if (!hideWarning) {
      setShowWarning(true)
      return
    }

    try {
      setError(null)
      
      // Set canvas size to 2x video size for upscaling
      const updateCanvasSize = () => {
        if (video.videoWidth && video.videoHeight) {
          canvas.width = video.videoWidth * 2
          canvas.height = video.videoHeight * 2
        }
      }
      
      video.addEventListener('loadedmetadata', updateCanvasSize)
      updateCanvasSize()

      // Dynamic import anime4k-webgpu
      const anime4k = await import('anime4k-webgpu')
      const { render, CNNx2M, CNNx2UL, GANUUL } = anime4k

      // Build pipeline based on type
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const pipelineBuilder: any = type === 2
        ? (device: GPUDevice, inputTexture: GPUTexture) => {
            const upscale = new CNNx2M({ device, inputTexture })
            return [upscale]
          }
        : (device: GPUDevice, inputTexture: GPUTexture) => {
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

      setIsInitialized(true)
      console.log(`Super Resolution: initialized with ${SUPER_RESOLUTION_LABELS[type]} mode`)

      // Cleanup function
      renderCleanupRef.current = () => {
        video.removeEventListener('loadedmetadata', updateCanvasSize)
        setIsInitialized(false)
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      setError(message)
      console.error('Super Resolution: init failed', err)
    }
  }, [videoRef, type, hideWarning, checkWebGPU])

  // Handle warning confirmation
  const handleConfirmWarning = useCallback(() => {
    setShowWarning(false)
    useSuperResolutionStore.getState().setHideWarning(true)
    initSuperResolution()
  }, [initSuperResolution])

  // Initialize when type changes or video loads
  useEffect(() => {
    if (!enabled || type === 1) {
      // Cleanup if disabled
      if (renderCleanupRef.current) {
        renderCleanupRef.current()
        renderCleanupRef.current = null
      }
      setIsInitialized(false)
      return
    }

    const video = videoRef.current
    if (!video) return

    // Wait for video to be ready
    const handleCanPlay = () => {
      initSuperResolution()
    }

    if (video.readyState >= 3) {
      initSuperResolution()
    } else {
      video.addEventListener('canplay', handleCanPlay)
    }

    return () => {
      video.removeEventListener('canplay', handleCanPlay)
      if (renderCleanupRef.current) {
        renderCleanupRef.current()
        renderCleanupRef.current = null
      }
    }
  }, [enabled, type, videoRef, initSuperResolution])

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current)
      }
      if (renderCleanupRef.current) {
        renderCleanupRef.current()
      }
    }
  }, [])

  // Don't render if disabled
  if (!enabled || type === 1) {
    return null
  }

  return (
    <>
      {/* Super Resolution Canvas - overlays video */}
      <canvas
        ref={canvasRef}
        className={`absolute inset-0 w-full h-full object-contain pointer-events-none ${
          isInitialized ? 'opacity-100' : 'opacity-0'
        } ${className}`}
        style={{ zIndex: 1 }}
      />

      {/* Status Indicator */}
      {isInitialized && (
        <div className="absolute top-2 right-2 z-20 px-2 py-1 rounded bg-black/50 text-xs text-green-400 flex items-center gap-1">
          <span className="material-symbols-rounded text-sm">auto_awesome</span>
          <span>SR {SUPER_RESOLUTION_LABELS[type]}</span>
        </div>
      )}

      {/* Error Display */}
      {error && (
        <div className="absolute top-2 right-2 z-20 px-2 py-1 rounded bg-red-500/80 text-xs text-white">
          SR Error: {error}
        </div>
      )}

      {/* Warning Modal */}
      {showWarning && (
        <div className="absolute inset-0 z-50 flex items-center justify-center bg-black/80">
          <div className="bg-white/10 backdrop-blur-xl rounded-2xl p-6 max-w-sm mx-4">
            <div className="flex items-center gap-3 mb-4">
              <span className="material-symbols-rounded text-3xl text-yellow-400">warning</span>
              <h3 className="text-lg font-medium text-white">超分辨率提示</h3>
            </div>
            <p className="text-white/80 text-sm mb-4">
              超分辨率功能会使用 GPU 加速处理视频，可能会增加设备功耗和发热。
              当前模式: <strong>{SUPER_RESOLUTION_LABELS[type]}</strong>
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => {
                  setShowWarning(false)
                  useSuperResolutionStore.getState().setType(1)
                }}
                className="flex-1 py-2 rounded-xl bg-white/10 text-white hover:bg-white/20 transition-colors"
              >
                取消
              </button>
              <button
                onClick={handleConfirmWarning}
                className="flex-1 py-2 rounded-xl bg-primary-500 text-white hover:bg-primary-600 transition-colors"
              >
                继续
              </button>
            </div>
            <label className="flex items-center gap-2 mt-4 text-sm text-white/60">
              <input
                type="checkbox"
                onChange={(e) => {
                  if (e.target.checked) {
                    useSuperResolutionStore.getState().setHideWarning(true)
                  }
                }}
                className="rounded"
              />
              不再显示此提示
            </label>
          </div>
        </div>
      )}
    </>
  )
}
