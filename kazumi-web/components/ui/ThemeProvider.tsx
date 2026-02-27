/**
 * ThemeProvider - 主题提供者组件
 * 
 * 功能:
 * - 从 localStorage 读取主题设置
 * - 应用主题模式 (浅色/深色/跟随系统)
 * - 应用主题色到 CSS 变量
 */

'use client'

import { useEffect, useState, createContext, useContext, ReactNode } from 'react'

const THEME_KEY = 'kazumi_theme_settings'

type ThemeMode = 'light' | 'dark' | 'system'

interface ThemeSettings {
  mode: ThemeMode
  primaryColor: string
}

interface ThemeContextValue {
  settings: ThemeSettings
  updateSettings: (settings: Partial<ThemeSettings>) => void
}

const DEFAULT_SETTINGS: ThemeSettings = {
  mode: 'system',
  primaryColor: '#FF6B6B',
}

// 根据主色生成色阶
function generateColorPalette(hex: string): Record<string, string> {
  // 将 hex 转换为 RGB
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  
  // 生成不同亮度的色阶
  const lighten = (factor: number) => {
    const newR = Math.round(r + (255 - r) * factor)
    const newG = Math.round(g + (255 - g) * factor)
    const newB = Math.round(b + (255 - b) * factor)
    return `rgb(${newR}, ${newG}, ${newB})`
  }
  
  const darken = (factor: number) => {
    const newR = Math.round(r * (1 - factor))
    const newG = Math.round(g * (1 - factor))
    const newB = Math.round(b * (1 - factor))
    return `rgb(${newR}, ${newG}, ${newB})`
  }
  
  return {
    '50': lighten(0.95),
    '100': lighten(0.9),
    '200': lighten(0.7),
    '300': lighten(0.5),
    '400': lighten(0.25),
    '500': `rgb(${r}, ${g}, ${b})`,
    '600': darken(0.1),
    '700': darken(0.25),
    '800': darken(0.4),
    '900': darken(0.55),
  }
}

const ThemeContext = createContext<ThemeContextValue | null>(null)

export function useTheme() {
  const context = useContext(ThemeContext)
  if (!context) {
    throw new Error('useTheme must be used within ThemeProvider')
  }
  return context
}

interface ThemeProviderProps {
  children: ReactNode
}

export function ThemeProvider({ children }: ThemeProviderProps) {
  const [settings, setSettings] = useState<ThemeSettings>(DEFAULT_SETTINGS)
  const [mounted, setMounted] = useState(false)

  // 加载设置
  useEffect(() => {
    try {
      const saved = localStorage.getItem(THEME_KEY)
      if (saved) {
        const parsed = JSON.parse(saved)
        setSettings({ ...DEFAULT_SETTINGS, ...parsed })
      }
    } catch (e) {
      console.error('Failed to load theme settings:', e)
    }
    setMounted(true)
  }, [])

  // 应用主题
  useEffect(() => {
    if (!mounted) return

    const root = document.documentElement
    
    // 应用主题模式
    if (settings.mode === 'dark') {
      root.classList.add('dark')
    } else if (settings.mode === 'light') {
      root.classList.remove('dark')
    } else {
      // 跟随系统
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
      if (mediaQuery.matches) {
        root.classList.add('dark')
      } else {
        root.classList.remove('dark')
      }
      
      // 监听系统主题变化
      const handler = (e: MediaQueryListEvent) => {
        if (e.matches) {
          root.classList.add('dark')
        } else {
          root.classList.remove('dark')
        }
      }
      mediaQuery.addEventListener('change', handler)
      return () => mediaQuery.removeEventListener('change', handler)
    }
  }, [settings.mode, mounted])

  // 应用主题色
  useEffect(() => {
    if (!mounted) return

    const root = document.documentElement
    const palette = generateColorPalette(settings.primaryColor)
    
    // 设置 CSS 变量
    Object.entries(palette).forEach(([key, value]) => {
      root.style.setProperty(`--color-primary-${key}`, value)
    })
    
    // 设置主色变量
    root.style.setProperty('--primary-color', settings.primaryColor)
    
    // 更新 meta theme-color
    const metaThemeColor = document.querySelector('meta[name="theme-color"]')
    if (metaThemeColor) {
      metaThemeColor.setAttribute('content', settings.primaryColor)
    }
  }, [settings.primaryColor, mounted])

  const updateSettings = (newSettings: Partial<ThemeSettings>) => {
    const updated = { ...settings, ...newSettings }
    setSettings(updated)
    try {
      localStorage.setItem(THEME_KEY, JSON.stringify(updated))
    } catch (e) {
      console.error('Failed to save theme settings:', e)
    }
  }

  return (
    <ThemeContext.Provider value={{ settings, updateSettings }}>
      {children}
    </ThemeContext.Provider>
  )
}
