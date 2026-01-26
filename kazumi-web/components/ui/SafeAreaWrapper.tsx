import React from 'react'
import { cn } from '@/lib/utils/cn'

export interface SafeAreaWrapperProps extends React.HTMLAttributes<HTMLDivElement> {
  /**
   * Which safe area insets to apply
   * @default 'all'
   */
  insets?: 'all' | 'top' | 'bottom' | 'left' | 'right' | 'horizontal' | 'vertical' | 'none'
  /**
   * Additional padding to add beyond safe area insets (in px)
   */
  additionalPadding?: {
    top?: number
    bottom?: number
    left?: number
    right?: number
  }
  /**
   * Whether to use the wrapper as a flex container
   * @default false
   */
  flex?: boolean
  /**
   * Flex direction when flex is true
   * @default 'column'
   */
  flexDirection?: 'row' | 'column'
  children?: React.ReactNode
}

/**
 * SafeAreaWrapper - Component that respects iOS safe area insets
 * 
 * Handles safe area insets for iOS devices with notch, dynamic island,
 * and home indicator. Uses CSS env(safe-area-inset-*) to ensure content
 * doesn't render within system UI areas.
 * 
 * Requirements: 10.5
 */
export const SafeAreaWrapper = React.forwardRef<HTMLDivElement, SafeAreaWrapperProps>(
  (
    {
      insets = 'all',
      additionalPadding,
      flex = false,
      flexDirection = 'column',
      className,
      style,
      children,
      ...props
    },
    ref
  ) => {
    // Build safe area classes based on insets prop
    const safeAreaClasses = {
      all: 'safe-area-all',
      top: 'safe-area-top',
      bottom: 'safe-area-bottom',
      left: 'safe-area-left',
      right: 'safe-area-right',
      horizontal: 'safe-area-left safe-area-right',
      vertical: 'safe-area-top safe-area-bottom',
      none: '',
    }

    // Build additional padding style
    const paddingStyle: React.CSSProperties = {}
    if (additionalPadding) {
      if (additionalPadding.top) {
        paddingStyle.paddingTop = `calc(env(safe-area-inset-top) + ${additionalPadding.top}px)`
      }
      if (additionalPadding.bottom) {
        paddingStyle.paddingBottom = `calc(env(safe-area-inset-bottom) + ${additionalPadding.bottom}px)`
      }
      if (additionalPadding.left) {
        paddingStyle.paddingLeft = `calc(env(safe-area-inset-left) + ${additionalPadding.left}px)`
      }
      if (additionalPadding.right) {
        paddingStyle.paddingRight = `calc(env(safe-area-inset-right) + ${additionalPadding.right}px)`
      }
    }

    return (
      <div
        ref={ref}
        className={cn(
          // Safe area insets
          safeAreaClasses[insets],
          // Flex container
          flex && 'flex',
          flex && flexDirection === 'row' && 'flex-row',
          flex && flexDirection === 'column' && 'flex-col',
          className
        )}
        style={{
          ...paddingStyle,
          ...style,
        }}
        {...props}
      >
        {children}
      </div>
    )
  }
)

SafeAreaWrapper.displayName = 'SafeAreaWrapper'

/**
 * SafeAreaView - Convenience component for full-screen safe area layouts
 * 
 * Pre-configured SafeAreaWrapper with common settings for full-screen views.
 * Includes flex column layout and all safe area insets.
 */
export const SafeAreaView = React.forwardRef<HTMLDivElement, Omit<SafeAreaWrapperProps, 'flex' | 'flexDirection'>>(
  (props, ref) => {
    return (
      <SafeAreaWrapper
        ref={ref}
        flex
        flexDirection="column"
        insets="all"
        className={cn('min-h-screen', props.className)}
        {...props}
      />
    )
  }
)

SafeAreaView.displayName = 'SafeAreaView'

/**
 * SafeAreaTop - Convenience component for top safe area only
 * 
 * Useful for navigation bars and headers.
 */
export const SafeAreaTop = React.forwardRef<HTMLDivElement, Omit<SafeAreaWrapperProps, 'insets'>>(
  (props, ref) => {
    return <SafeAreaWrapper ref={ref} insets="top" {...props} />
  }
)

SafeAreaTop.displayName = 'SafeAreaTop'

/**
 * SafeAreaBottom - Convenience component for bottom safe area only
 * 
 * Useful for tab bars and bottom navigation.
 */
export const SafeAreaBottom = React.forwardRef<HTMLDivElement, Omit<SafeAreaWrapperProps, 'insets'>>(
  (props, ref) => {
    return <SafeAreaWrapper ref={ref} insets="bottom" {...props} />
  }
)

SafeAreaBottom.displayName = 'SafeAreaBottom'
