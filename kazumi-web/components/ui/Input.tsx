import React from 'react'
import { cn } from '@/lib/utils/cn'

export interface InputProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'size'> {
  /**
   * Input size variant
   * @default 'md'
   */
  size?: 'sm' | 'md' | 'lg'
  /**
   * Material Symbols icon name to display before input
   */
  icon?: string
  /**
   * Material Symbols icon name to display after input (e.g., clear button)
   */
  iconRight?: string
  /**
   * Handler for right icon click
   */
  onIconRightClick?: () => void
  /**
   * Error state
   * @default false
   */
  error?: boolean
  /**
   * Error message to display
   */
  errorMessage?: string
  /**
   * Helper text to display below input
   */
  helperText?: string
  /**
   * Label for the input
   */
  label?: string
  /**
   * Whether the input takes full width
   * @default true
   */
  fullWidth?: boolean
}

/**
 * Input - Text input component with glass styling
 * 
 * Implements iOS 26 liquid glass aesthetic with:
 * - Glass morphism background with backdrop blur
 * - Focus indicators for accessibility (Requirement 15.1)
 * - Material Symbols icons
 * - Smooth transitions
 * - Warm color palette
 * 
 * Requirements: 10.1, 10.2, 15.1
 */
export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  (
    {
      size = 'md',
      icon,
      iconRight,
      onIconRightClick,
      error = false,
      errorMessage,
      helperText,
      label,
      fullWidth = true,
      className,
      disabled,
      ...props
    },
    ref
  ) => {
    // Size classes - ensure minimum 44px touch target
    const sizeClasses = {
      sm: 'min-h-[44px] px-3 py-2 text-sm',
      md: 'min-h-[44px] px-4 py-3 text-base',
      lg: 'min-h-[48px] px-5 py-4 text-lg',
    }

    const iconSizes = {
      sm: '20px',
      md: '24px',
      lg: '28px',
    }

    const renderIcon = (iconName: string, onClick?: () => void) => (
      <span
        className={cn(
          'material-symbols-rounded flex-shrink-0 text-gray-500',
          onClick && 'cursor-pointer hover:text-gray-700 transition-colors'
        )}
        style={{ fontSize: iconSizes[size] }}
        onClick={onClick}
        role={onClick ? 'button' : undefined}
        tabIndex={onClick ? 0 : undefined}
        aria-hidden={!onClick}
      >
        {iconName}
      </span>
    )

    return (
      <div className={cn('flex flex-col gap-1.5', fullWidth && 'w-full')}>
        {/* Label */}
        {label && (
          <label className="text-sm font-medium text-gray-700 px-1">
            {label}
          </label>
        )}

        {/* Input container */}
        <div
          className={cn(
            // Base glass styling
            'flex items-center gap-2',
            'bg-white/70 backdrop-blur-glass',
            'rounded-glass',
            'border border-white/30',
            'shadow-glass',
            'transition-all duration-200',
            // GPU acceleration
            'gpu-accelerated',
            // Focus-within for container focus state
            'focus-within:border-[#FF6B6B]/50',
            'focus-within:shadow-[0_0_0_3px_rgba(255,107,107,0.1)]',
            'focus-within:bg-white/80',
            // Error state
            error && 'border-red-400/50 focus-within:border-red-500/50',
            error && 'focus-within:shadow-[0_0_0_3px_rgba(239,68,68,0.1)]',
            // Disabled state
            disabled && 'opacity-50 cursor-not-allowed bg-gray-100/50',
            // Size
            sizeClasses[size],
            fullWidth && 'w-full'
          )}
        >
          {/* Left icon */}
          {icon && renderIcon(icon)}

          {/* Input element */}
          <input
            ref={ref}
            disabled={disabled}
            className={cn(
              // Reset default styles
              'flex-1 bg-transparent outline-none',
              'text-gray-800 placeholder:text-gray-400',
              // Font
              'font-medium',
              // Disabled
              disabled && 'cursor-not-allowed',
              className
            )}
            aria-invalid={error}
            aria-describedby={
              errorMessage
                ? `${props.id}-error`
                : helperText
                ? `${props.id}-helper`
                : undefined
            }
            {...props}
          />

          {/* Right icon */}
          {iconRight && renderIcon(iconRight, onIconRightClick)}
        </div>

        {/* Error message */}
        {error && errorMessage && (
          <p
            id={`${props.id}-error`}
            className="text-sm text-red-500 px-1 flex items-center gap-1"
            role="alert"
          >
            <span className="material-symbols-rounded" style={{ fontSize: '16px' }}>
              error
            </span>
            {errorMessage}
          </p>
        )}

        {/* Helper text */}
        {!error && helperText && (
          <p
            id={`${props.id}-helper`}
            className="text-sm text-gray-500 px-1"
          >
            {helperText}
          </p>
        )}
      </div>
    )
  }
)

Input.displayName = 'Input'
