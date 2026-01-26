'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { GlassPanel } from '@/components/ui/GlassPanel'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils/cn'

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>
}

const STORAGE_KEY = 'pwa-install-dismissed-v2'

/**
 * InstallPrompt - PWA install prompt component
 * 
 * Features:
 * - Detects installability
 * - Shows custom install UI with liquid glass styling
 * - Handles iOS Safari "Add to Home Screen" instructions
 * - Remembers user dismissal permanently
 * 
 * Requirements: 11.2
 */
export function InstallPrompt() {
  const [deferredPrompt, setDeferredPrompt] = useState<BeforeInstallPromptEvent | null>(null)
  const [showPrompt, setShowPrompt] = useState(false)
  const [isIOS, setIsIOS] = useState(false)
  const [isStandalone, setIsStandalone] = useState(true) // Default to true to prevent flash
  const hasCheckedRef = useRef(false)

  useEffect(() => {
    // Only run once
    if (hasCheckedRef.current) return
    hasCheckedRef.current = true

    // Check if user has dismissed the prompt before - FIRST CHECK
    const dismissed = localStorage.getItem(STORAGE_KEY)
    if (dismissed) {
      setIsStandalone(true) // Keep hidden
      return
    }

    // Check if already installed (standalone mode)
    const standalone = window.matchMedia('(display-mode: standalone)').matches
      || (window.navigator as unknown as { standalone?: boolean }).standalone === true
    setIsStandalone(standalone)
    
    if (standalone) {
      return
    }

    // Check if iOS
    const iOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !(window as unknown as { MSStream?: unknown }).MSStream
    setIsIOS(iOS)

    // Listen for beforeinstallprompt event (Chrome, Edge, etc.)
    const handleBeforeInstallPrompt = (e: Event) => {
      e.preventDefault()
      // Double-check dismissal before showing
      if (localStorage.getItem(STORAGE_KEY)) {
        return
      }
      setDeferredPrompt(e as BeforeInstallPromptEvent)
      setShowPrompt(true)
    }

    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)

    // Show iOS prompt after a delay if not installed and not dismissed
    let timer: NodeJS.Timeout | undefined
    if (iOS && !standalone) {
      timer = setTimeout(() => {
        // Double-check dismissal status before showing
        if (!localStorage.getItem(STORAGE_KEY)) {
          setShowPrompt(true)
        }
      }, 3000)
    }

    return () => {
      if (timer) clearTimeout(timer)
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
    }
  }, [])

  const handleInstall = useCallback(async () => {
    if (!deferredPrompt) return

    await deferredPrompt.prompt()
    const { outcome } = await deferredPrompt.userChoice

    if (outcome === 'accepted') {
      setShowPrompt(false)
    }

    setDeferredPrompt(null)
  }, [deferredPrompt])

  const handleDismiss = useCallback(() => {
    setShowPrompt(false)
    setIsStandalone(true) // Prevent any future showing
    localStorage.setItem(STORAGE_KEY, Date.now().toString())
  }, [])

  // Don't show if already installed
  if (isStandalone || !showPrompt) {
    return null
  }

  return (
    <div className="fixed bottom-20 left-4 right-4 z-50 animate-slide-up safe-area-bottom">
      <GlassPanel className="p-4">
        <div className="flex items-start gap-4">
          {/* App Icon */}
          <div className="flex-shrink-0 w-12 h-12 rounded-xl bg-gradient-to-br from-[#FF6B6B] to-[#e53935] flex items-center justify-center">
            <span className="material-symbols-rounded text-white text-2xl">
              play_circle
            </span>
          </div>

          {/* Content */}
          <div className="flex-1 min-w-0">
            <h3 className="font-semibold text-gray-900 mb-1">
              安装番剧播放器
            </h3>
            
            {isIOS ? (
              <p className="text-sm text-gray-600 mb-3">
                点击 <span className="material-symbols-rounded text-base align-middle">ios_share</span> 然后选择「添加到主屏幕」
              </p>
            ) : (
              <p className="text-sm text-gray-600 mb-3">
                安装应用以获得更好的体验，支持离线访问
              </p>
            )}

            {/* Actions */}
            <div className="flex items-center gap-2">
              {!isIOS && deferredPrompt && (
                <Button
                  variant="primary"
                  size="sm"
                  icon="download"
                  onClick={handleInstall}
                >
                  安装
                </Button>
              )}
              <Button
                variant="ghost"
                size="sm"
                onClick={handleDismiss}
              >
                稍后
              </Button>
            </div>
          </div>

          {/* Close button */}
          <button
            onClick={handleDismiss}
            className={cn(
              'flex-shrink-0 p-2 rounded-full',
              'hover:bg-gray-100 transition-colors',
              'focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary-500'
            )}
            aria-label="关闭"
          >
            <span className="material-symbols-rounded text-gray-500">
              close
            </span>
          </button>
        </div>
      </GlassPanel>
    </div>
  )
}
