/**
 * SettingItem - 设置项组件
 * 可复用的设置项，支持开关、滑块、导航等类型
 */

'use client'

import Link from 'next/link'
import { ToggleSwitch } from './ToggleSwitch'
import { Slider } from './Slider'

// 基础设置项 Props
interface BaseSettingItemProps {
  title: string
  description?: string
  icon?: string
  className?: string
}

// 开关类型
interface SwitchSettingItemProps extends BaseSettingItemProps {
  type: 'switch'
  checked: boolean
  onChange: (checked: boolean) => void
}

// 导航类型
interface NavigationSettingItemProps extends BaseSettingItemProps {
  type: 'navigation'
  href: string
  value?: string
}

// 滑块类型
interface SliderSettingItemProps extends BaseSettingItemProps {
  type: 'slider'
  value: number
  min: number
  max: number
  step?: number
  onChange: (value: number) => void
  formatValue?: (value: number) => string
}

// 按钮类型
interface ButtonSettingItemProps extends BaseSettingItemProps {
  type: 'button'
  onClick: () => void
  buttonIcon?: string
  loading?: boolean
}

// 自定义类型
interface CustomSettingItemProps extends BaseSettingItemProps {
  type: 'custom'
  children: React.ReactNode
}

export type SettingItemProps =
  | SwitchSettingItemProps
  | NavigationSettingItemProps
  | SliderSettingItemProps
  | ButtonSettingItemProps
  | CustomSettingItemProps

export function SettingItem(props: SettingItemProps) {
  const { title, description, icon, className = '' } = props

  // 渲染左侧内容
  const renderLeft = () => (
    <div className="flex items-center gap-3 flex-1 min-w-0">
      {icon && (
        <div className="w-8 h-8 flex items-center justify-center rounded-lg bg-primary-100">
          <span className="material-symbols-rounded text-primary-500 text-lg">{icon}</span>
        </div>
      )}
      <div className="flex-1 min-w-0">
        <p className="font-medium text-primary-900">{title}</p>
        {description && (
          <p className="text-sm text-primary-500 truncate">{description}</p>
        )}
      </div>
    </div>
  )

  // 开关类型
  if (props.type === 'switch') {
    return (
      <div className={`flex items-center justify-between p-4 ${className}`}>
        {renderLeft()}
        <ToggleSwitch checked={props.checked} onChange={props.onChange} />
      </div>
    )
  }

  // 导航类型
  if (props.type === 'navigation') {
    return (
      <Link href={props.href}>
        <div className={`flex items-center justify-between p-4 hover:bg-primary-50 active:bg-primary-100 transition-colors ${className}`}>
          {renderLeft()}
          <div className="flex items-center gap-2">
            {props.value && (
              <span className="text-sm text-primary-500">{props.value}</span>
            )}
            <span className="material-symbols-rounded text-primary-400">chevron_right</span>
          </div>
        </div>
      </Link>
    )
  }

  // 滑块类型
  if (props.type === 'slider') {
    return (
      <div className={`p-4 ${className}`}>
        <div className="flex items-center justify-between mb-3">
          <p className="font-medium text-primary-900">{title}</p>
          <span className="text-sm text-primary-500">
            {props.formatValue ? props.formatValue(props.value) : props.value}
          </span>
        </div>
        {description && (
          <p className="text-sm text-primary-500 mb-3">{description}</p>
        )}
        <Slider
          value={props.value}
          min={props.min}
          max={props.max}
          step={props.step}
          onChange={props.onChange}
          showValue={false}
        />
      </div>
    )
  }

  // 按钮类型
  if (props.type === 'button') {
    return (
      <button
        onClick={props.onClick}
        disabled={props.loading}
        className={`w-full flex items-center justify-between p-4 hover:bg-primary-50 active:bg-primary-100 transition-colors disabled:opacity-50 ${className}`}
      >
        {renderLeft()}
        <span className="material-symbols-rounded text-primary-500">
          {props.loading ? 'hourglass_empty' : (props.buttonIcon || 'chevron_right')}
        </span>
      </button>
    )
  }

  // 自定义类型
  if (props.type === 'custom') {
    return (
      <div className={`p-4 ${className}`}>
        <div className="mb-3">
          <p className="font-medium text-primary-900">{title}</p>
          {description && (
            <p className="text-sm text-primary-500">{description}</p>
          )}
        </div>
        {props.children}
      </div>
    )
  }

  return null
}

/**
 * SettingSection - 设置分组
 */
export function SettingSection({
  title,
  children,
  className = '',
}: {
  title?: string
  children: React.ReactNode
  className?: string
}) {
  return (
    <div className={`mb-6 ${className}`}>
      {title && (
        <h2 className="text-sm font-medium text-primary-500 mb-2 px-1">{title}</h2>
      )}
      <div className="bg-white/80 backdrop-blur-glass rounded-2xl border border-glass-border overflow-hidden divide-y divide-primary-100">
        {children}
      </div>
    </div>
  )
}
