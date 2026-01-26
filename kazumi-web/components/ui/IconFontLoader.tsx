/**
 * IconFontLoader - 确保 Material Symbols 字体正确加载
 * 
 * 使用本地字体文件，加载更可靠
 */

'use client'

import { useEffect, useState } from 'react'

export function IconFontLoader({ children }: { children: React.ReactNode }) {
  const [fontLoaded, setFontLoaded] = useState(false)

  useEffect(() => {
    // 等待字体加载完成
    document.fonts.ready.then(() => {
      setFontLoaded(true)
      document.documentElement.classList.remove('icons-loading')
    }).catch(() => {
      // 即使失败也移除 loading 状态，让用户看到 fallback
      setFontLoaded(true)
      document.documentElement.classList.remove('icons-loading')
    })

    // 初始添加 loading 类
    if (!fontLoaded) {
      document.documentElement.classList.add('icons-loading')
    }
  }, [fontLoaded])

  return <>{children}</>
}
