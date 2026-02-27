'use client'

import { usePathname } from 'next/navigation'
import Link from 'next/link'

interface NavItem {
  href: string
  icon: string
  label: string
}

const navItems: NavItem[] = [
  { href: '/', icon: 'home', label: '首页' },
  { href: '/calendar', icon: 'calendar_month', label: '时间表' },
  { href: '/search', icon: 'search', label: '搜索' },
  { href: '/favorites', icon: 'favorite', label: '收藏' },
  { href: '/settings', icon: 'settings', label: '设置' },
]

/**
 * Bottom Navigation Component
 * iOS-style tab bar with liquid glass effect
 * 
 * Accessibility features:
 * - ARIA labels for all navigation items
 * - Current page indication with aria-current
 * - Keyboard navigation support
 * - Focus indicators
 * 
 * Requirements: 15.1, 15.2
 */
export function Navigation() {
  const pathname = usePathname()

  // Hide navigation on player page
  if (pathname.includes('/watch/')) {
    return null
  }

  return (
    <nav 
      className="fixed bottom-0 left-0 right-0 z-50 safe-area-bottom"
      role="navigation"
      aria-label="主导航"
    >
      <div className="mx-4 mb-4 rounded-3xl bg-white/70 backdrop-blur-xl border border-white/30 shadow-lg">
        <ul 
          className="flex items-center justify-around py-2"
          role="menubar"
          aria-label="导航菜单"
        >
          {navItems.map((item) => {
            const isActive = pathname === item.href
            
            return (
              <li key={item.href} role="none">
                <Link
                  href={item.href}
                  role="menuitem"
                  aria-label={item.label}
                  aria-current={isActive ? 'page' : undefined}
                  className={`
                    flex flex-col items-center justify-center
                    min-w-[64px] min-h-[44px] px-3 py-2
                    rounded-2xl transition-all duration-200
                    focus-visible:outline focus-visible:outline-2 
                    focus-visible:outline-offset-2 focus-visible:outline-primary-500
                    ${isActive 
                      ? 'bg-primary-500 text-white scale-105' 
                      : 'text-primary-600 hover:bg-primary-100'
                    }
                  `}
                >
                  <span 
                    className="material-symbols" 
                    style={{ 
                      fontSize: '24px',
                      fontVariationSettings: isActive ? "'FILL' 1" : "'FILL' 0"
                    }}
                    aria-hidden="true"
                  >
                    {item.icon}
                  </span>
                  <span className="text-xs mt-1 font-medium">
                    {item.label}
                  </span>
                </Link>
              </li>
            )
          })}
        </ul>
      </div>
    </nav>
  )
}
