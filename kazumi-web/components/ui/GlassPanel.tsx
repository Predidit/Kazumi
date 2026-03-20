import React from 'react'
import { cn } from '@/lib/utils/cn'

export interface GlassPanelProps extends React.HTMLAttributes<HTMLDivElement> {
  /**
   * Blur intensity: 'normal' (20px) or 'strong' (40px)
   * @default 'normal'
   */
  blur?: 'normal' | 'strong'
  /**
   * Background opacity level
   * @default 0.7
   */
  opacity?: number
  /**
   * Whether to show border
   * @default true
   */
  bordered?: boolean
  /**
   * Whether to show shadow
   * @default true
   */
  shadow?: boolean
  /**
   * Border radius size
   * @default 'glass' (16px)
   */
  rounded?: 'glass' | 'glass-lg' | 'full' | 'none'
  children?: React.ReactNode
}

/**
 * GlassPanel - Base glass UI component with backdrop-filter blur
 * 
 * Implements iOS 26 liquid glass aesthetic with frosted glass effect.
 * Uses backdrop-filter for blur and semi-transparent background.
 * Supports dark mode via CSS variables.
 * 
 * Requirements: 10.1, 10.2, 10.6, 10.7
 */
export const GlassPanel = React.forwardRef<HTMLDivElement, GlassPanelProps>(
  (
    {
      blur = 'normal',
      opacity = 0.7,
      bordered = true,
      shadow = true,
      rounded = 'glass',
      className,
      style,
      children,
      ...props
    },
    ref
  ) => {
    const blurClass = blur === 'strong' ? 'backdrop-blur-glass-strong' : 'backdrop-blur-glass'
    const roundedClass = rounded === 'none' ? '' : `rounded-${rounded}`
    
    return (
      <div
        ref={ref}
        className={cn(
          // Base glass styling - uses CSS variable for dark mode support
          'glass-panel',
          blurClass,
          roundedClass,
          // Border
          bordered && 'border border-glass-border',
          // Shadow
          shadow && 'shadow-glass dark:shadow-[0_8px_32px_0_rgba(0,0,0,0.3)]',
          // GPU acceleration
          'gpu-accelerated',
          className
        )}
        style={{
          WebkitBackdropFilter: blur === 'strong' ? 'blur(40px)' : 'blur(20px)',
          ...style,
        }}
        {...props}
      >
        {children}
      </div>
    )
  }
)

GlassPanel.displayName = 'GlassPanel'
