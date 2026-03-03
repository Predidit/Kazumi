import React from 'react'
import { cn } from '@/lib/utils/cn'
import { GlassPanel, GlassPanelProps } from './GlassPanel'

export interface GlassPillProps extends Omit<GlassPanelProps, 'rounded' | 'blur'> {
  /**
   * Size variant
   * @default 'md'
   */
  size?: 'sm' | 'md' | 'lg'
  /**
   * Color variant using warm palette
   * @default 'default'
   */
  variant?: 'default' | 'rose' | 'cream' | 'taupe' | 'blush' | 'primary'
  /**
   * Whether the pill is interactive (button-like)
   * @default false
   */
  interactive?: boolean
  /**
   * Icon element to display before text
   */
  icon?: React.ReactNode
  /**
   * Click handler
   */
  onClick?: () => void
  children?: React.ReactNode
}

/**
 * GlassPill - Pill-shaped component for tags and buttons
 * 
 * Compact, rounded component with glass effect for displaying tags,
 * labels, or small interactive buttons. Supports warm color palette
 * (dusty rose, cream, taupe) and Material Symbols icons.
 * 
 * Requirements: 10.1, 10.2, 10.6, 10.7
 */
export const GlassPill = React.forwardRef<HTMLDivElement, GlassPillProps>(
  (
    {
      size = 'md',
      variant = 'default',
      interactive = false,
      icon,
      className,
      onClick,
      children,
      ...props
    },
    ref
  ) => {
    const sizeClasses = {
      sm: 'px-2.5 py-1 text-xs',
      md: 'px-3 py-1.5 text-sm',
      lg: 'px-4 py-2 text-base',
    }

    const variantStyles = {
      default: {
        backgroundColor: 'rgba(255, 255, 255, 0.7)',
        color: '#2d2d2d',
      },
      rose: {
        backgroundColor: 'rgba(232, 213, 213, 0.8)', // Dusty rose
        color: '#6b4848',
      },
      cream: {
        backgroundColor: 'rgba(245, 241, 232, 0.8)', // Cream
        color: '#5a5347',
      },
      taupe: {
        backgroundColor: 'rgba(217, 207, 193, 0.8)', // Taupe
        color: '#4a4338',
      },
      blush: {
        backgroundColor: 'rgba(244, 228, 228, 0.8)', // Light blush
        color: '#6b4848',
      },
      primary: {
        backgroundColor: 'rgba(255, 107, 107, 0.2)',
        color: '#C92A2A',
      },
    }

    return (
      <GlassPanel
        ref={ref}
        rounded="full"
        blur="normal"
        shadow={false}
        className={cn(
          // Base styling
          'inline-flex items-center gap-1.5 font-medium',
          // Size
          sizeClasses[size],
          // Interactive states
          interactive && 'cursor-pointer transition-all duration-200 hover:scale-105 active:scale-95',
          // Ensure minimum touch target for interactive pills
          interactive && size === 'sm' && 'min-h-[44px] min-w-[44px]',
          className
        )}
        style={variantStyles[variant]}
        onClick={onClick}
        role={interactive ? 'button' : undefined}
        tabIndex={interactive ? 0 : undefined}
        {...props}
      >
        {icon && <span className="flex items-center">{icon}</span>}
        {children}
      </GlassPanel>
    )
  }
)

GlassPill.displayName = 'GlassPill'
