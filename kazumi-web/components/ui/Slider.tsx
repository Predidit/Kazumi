/**
 * Slider - 滑块组件
 * 照抄 iOS 风格的滑块
 */

'use client'

export interface SliderProps {
  value: number
  min: number
  max: number
  step?: number
  onChange: (value: number) => void
  disabled?: boolean
  showValue?: boolean
  formatValue?: (value: number) => string
  className?: string
}

export function Slider({
  value,
  min,
  max,
  step = 1,
  onChange,
  disabled = false,
  showValue = true,
  formatValue,
  className = '',
}: SliderProps) {
  const displayValue = formatValue ? formatValue(value) : value.toString()

  return (
    <div className={`w-full ${className}`}>
      {showValue && (
        <div className="flex justify-end mb-1">
          <span className="text-sm text-primary-500">{displayValue}</span>
        </div>
      )}
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => onChange(parseFloat(e.target.value))}
        disabled={disabled}
        className={`
          w-full h-2 bg-primary-200 rounded-lg appearance-none cursor-pointer
          accent-primary-500
          disabled:opacity-50 disabled:cursor-not-allowed
        `}
      />
    </div>
  )
}
