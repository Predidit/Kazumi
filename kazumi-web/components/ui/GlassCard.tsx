import React from 'react'
import { cn } from '@/lib/utils/cn'
import { GlassPanel, GlassPanelProps } from './GlassPanel'

export interface GlassCardProps extends Omit<GlassPanelProps, 'rounded'> {
  /**
   * Whether to show hover effect
   * @default true
   */
  hoverable?: boolean
  /**
   * Whether the card is clickable/interactive
   * @default false
   */
  interactive?: boolean
  /**
   * Padding size
   * @default 'md'
   */
  padding?: 'none' | 'sm' | 'md' | 'lg' | 'xl'
  /**
   * Border radius size
   * @default 'glass' (16px)
   */
  rounded?: 'glass' | 'glass-lg'
  /**
   * Click handler
   */
  onClick?: () => void
}

/**
 * GlassCard - Card component with semi-transparent glass background
 * 
 * Extends GlassPanel with card-specific styling including hover effects,
 * padding options, and interactive states. Uses warm color palette.
 * 
 * Requirements: 10.1, 10.2, 10.6, 10.7
 */
export const GlassCard = React.forwardRef<HTMLDivElement, GlassCardProps>(
  (
    {
      hoverable = true,
      interactive = false,
      padding = 'md',
      rounded = 'glass',
      className,
      onClick,
      children,
      ...props
    },
    ref
  ) => {
    const paddingClasses = {
      none: '',
      sm: 'p-3',
      md: 'p-4',
      lg: 'p-6',
      xl: 'p-8',
    }

    return (
      <GlassPanel
        ref={ref}
        rounded={rounded}
        className={cn(
          // Padding
          paddingClasses[padding],
          // Hover effect
          hoverable && 'transition-all duration-300 hover:shadow-glass-hover hover:-translate-y-0.5',
          // Interactive states
          interactive && 'cursor-pointer active:scale-[0.98]',
          // Spring animation
          'spring-animation',
          className
        )}
        onClick={onClick}
        role={interactive ? 'button' : undefined}
        tabIndex={interactive ? 0 : undefined}
        {...props}
      >
        {children}
      </GlassPanel>
    )
  }
)

GlassCard.displayName = 'GlassCard'
