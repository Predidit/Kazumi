import React from 'react'
import { cn } from '@/lib/utils/cn'

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /**
   * Button size variant
   * @default 'md'
   */
  size?: 'sm' | 'md' | 'lg' | 'icon'
  /**
   * Button color variant using warm palette
   * @default 'default'
   */
  variant?: 'default' | 'primary' | 'rose' | 'cream' | 'ghost' | 'outline'
  /**
   * Material Symbols icon name (e.g., 'play_arrow', 'favorite', 'search')
   */
  icon?: string
  /**
   * Icon position relative to text
   * @default 'left'
   */
  iconPosition?: 'left' | 'right'
  /**
   * Whether button is in loading state
   * @default false
   */
  loading?: boolean
  /**
   * Whether button takes full width
   * @default false
   */
  fullWidth?: boolean
  children?: React.ReactNode
}

/**
 * Button - Interactive button component with Material Symbols icons
 * 
 * Implements iOS 26 liquid glass aesthetic with:
 * - Material Symbols icons (no emoji)
 * - Minimum 44px touch targets for accessibility (Requirement 10.4)
 * - Spring animations with natural easing (Requirement 10.8)
 * - Glass morphism effects
 * - Warm color palette
 * 
 * Requirements: 10.4, 10.5, 10.8, 15.1
 */
export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      size = 'md',
      variant = 'default',
      icon,
      iconPosition = 'left',
      loading = false,
      fullWidth = false,
      className,
      disabled,
      children,
      ...props
    },
    ref
  ) => {
    // Size classes - all ensure minimum 44px touch target
    const sizeClasses = {
      sm: 'min-h-[44px] min-w-[44px] px-4 py-2 text-sm',
      md: 'min-h-[44px] min-w-[44px] px-6 py-3 text-base',
      lg: 'min-h-[48px] min-w-[48px] px-8 py-4 text-lg',
      icon: 'h-[44px] w-[44px] p-0', // Square icon button
    }

    // Variant styles
    const variantClasses = {
      default: 'bg-white/70 text-gray-800 hover:bg-white/80 active:bg-white/60',
      primary: 'bg-[#FF6B6B]/90 text-white hover:bg-[#FF6B6B] active:bg-[#FF6B6B]/80',
      rose: 'bg-[#E8D5D5]/80 text-[#6b4848] hover:bg-[#E8D5D5]/90 active:bg-[#E8D5D5]/70',
      cream: 'bg-[#F5F1E8]/80 text-[#5a5347] hover:bg-[#F5F1E8]/90 active:bg-[#F5F1E8]/70',
      ghost: 'bg-transparent text-gray-800 hover:bg-white/20 active:bg-white/10',
      outline: 'bg-transparent border-2 border-white/50 text-gray-800 hover:bg-white/20 active:bg-white/10',
    }

    const renderIcon = (iconName: string) => (
      <span 
        className="material-symbols-rounded flex-shrink-0" 
        style={{ fontSize: size === 'lg' ? '28px' : size === 'sm' ? '20px' : '24px' }}
        aria-hidden="true"
      >
        {iconName}
      </span>
    )

    const renderLoadingIcon = () => (
      <span 
        className="material-symbols-rounded animate-spin flex-shrink-0" 
        style={{ fontSize: size === 'lg' ? '28px' : size === 'sm' ? '20px' : '24px' }}
        aria-hidden="true"
      >
        progress_activity
      </span>
    )

    return (
      <button
        ref={ref}
        disabled={disabled || loading}
        className={cn(
          // Base styles
          'inline-flex items-center justify-center gap-2 font-medium',
          'rounded-full',
          'transition-all duration-300',
          // Spring animation with cubic-bezier for natural bounce
          'active:scale-95',
          'spring-animation',
          // GPU acceleration for smooth animations
          'gpu-accelerated',
          // Focus indicator for accessibility (Requirement 15.1)
          'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2',
          'focus-visible:outline-[#FF6B6B]/80',
          // Backdrop blur for glass effect
          'backdrop-blur-glass',
          // Size
          sizeClasses[size],
          // Variant
          variantClasses[variant],
          // Full width
          fullWidth && 'w-full',
          // Disabled state
          (disabled || loading) && 'opacity-50 cursor-not-allowed',
          // Shadow
          'shadow-glass hover:shadow-glass-hover',
          className
        )}
        aria-busy={loading}
        {...props}
      >
        {loading && renderLoadingIcon()}
        {!loading && icon && iconPosition === 'left' && renderIcon(icon)}
        {children && <span className="flex-1">{children}</span>}
        {!loading && icon && iconPosition === 'right' && renderIcon(icon)}
      </button>
    )
  }
)

Button.displayName = 'Button'
