/**
 * ToggleSwitch - 开关组件
 * 照抄 iOS 风格的开关
 */

'use client'

export interface ToggleSwitchProps {
  checked: boolean
  onChange: (checked: boolean) => void
  disabled?: boolean
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

export function ToggleSwitch({
  checked,
  onChange,
  disabled = false,
  size = 'md',
  className = '',
}: ToggleSwitchProps) {
  const sizes = {
    sm: { width: 'w-[40px]', height: 'h-[24px]', thumb: 'w-[18px] h-[18px]', translate: 'translate-x-[16px]', padding: 'top-[3px] left-[3px]' },
    md: { width: 'w-[52px]', height: 'h-[32px]', thumb: 'w-[24px] h-[24px]', translate: 'translate-x-[20px]', padding: 'top-[4px] left-[4px]' },
    lg: { width: 'w-[64px]', height: 'h-[40px]', thumb: 'w-[32px] h-[32px]', translate: 'translate-x-[24px]', padding: 'top-[4px] left-[4px]' },
  }

  const s = sizes[size]

  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => !disabled && onChange(!checked)}
      className={`
        relative ${s.width} ${s.height} rounded-full transition-colors
        ${checked ? 'bg-primary-500' : 'bg-primary-300'}
        ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
        ${className}
      `}
    >
      <span
        className={`
          absolute ${s.padding} ${s.thumb} bg-white rounded-full shadow transition-transform
          ${checked ? s.translate : 'translate-x-0'}
        `}
      />
    </button>
  )
}
