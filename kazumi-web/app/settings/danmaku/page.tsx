/**
 * Danmaku Settings Page - 照抄原项目的弹幕设置
 */

'use client'

import Link from 'next/link'
import { SettingItem, SettingSection } from '@/components/ui'
import { useDanmakuState } from '@/lib/store'

export default function DanmakuSettingsPage() {
  const {
    enabled,
    opacity,
    speed,
    fontSize,
    area,
    hideTop,
    hideBottom,
    hideScroll,
    duration,
    lineHeight,
    followSpeed,
    massive,
    border,
    showColor,
    fontWeight,
    sourceBiliBili,
    sourceGamer,
    sourceDanDan,
    setEnabled,
    setOpacity,
    setSpeed,
    setFontSize,
    setArea,
    setHideTop,
    setHideBottom,
    setHideScroll,
    setDuration,
    setLineHeight,
    setFollowSpeed,
    setMassive,
    setBorder,
    setShowColor,
    setFontWeight,
    setSourceBiliBili,
    setSourceGamer,
    setSourceDanDan,
  } = useDanmakuState()

  return (
    <div className="min-h-screen safe-area-all">
      <main className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="flex items-center gap-3 mb-6">
          <Link
            href="/settings"
            className="w-10 h-10 flex items-center justify-center rounded-full bg-primary-100 hover:bg-primary-200 transition-colors"
          >
            <span className="material-symbols-rounded text-primary-600">arrow_back</span>
          </Link>
          <h1 className="text-2xl font-bold text-primary-900">弹幕设置</h1>
        </div>

        {/* Content */}
        <div className="max-w-2xl mx-auto pb-24">
          {/* 弹幕来源 */}
          <SettingSection title="弹幕来源">
            <SettingItem
              type="switch"
              title="BiliBili"
              checked={sourceBiliBili}
              onChange={setSourceBiliBili}
            />
            <SettingItem
              type="switch"
              title="Gamer"
              checked={sourceGamer}
              onChange={setSourceGamer}
            />
            <SettingItem
              type="switch"
              title="DanDan"
              checked={sourceDanDan}
              onChange={setSourceDanDan}
            />
          </SettingSection>

          {/* 弹幕屏蔽 - 照抄原项目 */}
          <SettingSection title="弹幕屏蔽">
            <SettingItem
              type="navigation"
              title="关键词屏蔽"
              href="/settings/danmaku/shield"
            />
          </SettingSection>

          {/* 弹幕显示 */}
          <SettingSection title="弹幕显示">
            <SettingItem
              type="switch"
              title="显示弹幕"
              description="开启或关闭弹幕显示"
              checked={enabled}
              onChange={setEnabled}
            />
            <SettingItem
              type="slider"
              title="弹幕区域"
              value={area}
              min={0}
              max={1}
              step={0.125}
              onChange={setArea}
              formatValue={(v) => `${Math.round(v * 100)}%`}
            />
            <SettingItem
              type="slider"
              title="弹幕持续时间"
              value={duration}
              min={2}
              max={16}
              step={1}
              onChange={setDuration}
              formatValue={(v) => `${v}秒`}
            />
            <SettingItem
              type="slider"
              title="弹幕行高"
              value={lineHeight}
              min={0}
              max={3}
              step={0.1}
              onChange={setLineHeight}
              formatValue={(v) => v.toFixed(1)}
            />
            <SettingItem
              type="slider"
              title="弹幕速度"
              value={speed}
              min={0.5}
              max={2}
              step={0.1}
              onChange={setSpeed}
              formatValue={(v) => `${v.toFixed(1)}x`}
            />
            <SettingItem
              type="switch"
              title="弹幕跟随视频倍速"
              description="开启后弹幕速度会随视频倍速而改变"
              checked={followSpeed}
              onChange={setFollowSpeed}
            />
            <SettingItem
              type="switch"
              title="顶部弹幕"
              checked={!hideTop}
              onChange={(v) => setHideTop(!v)}
            />
            <SettingItem
              type="switch"
              title="底部弹幕"
              checked={!hideBottom}
              onChange={(v) => setHideBottom(!v)}
            />
            <SettingItem
              type="switch"
              title="滚动弹幕"
              checked={!hideScroll}
              onChange={(v) => setHideScroll(!v)}
            />
            <SettingItem
              type="switch"
              title="海量弹幕"
              description="弹幕过多时进行叠加绘制"
              checked={massive}
              onChange={setMassive}
            />
          </SettingSection>

          {/* 弹幕样式 */}
          <SettingSection title="弹幕样式">
            <SettingItem
              type="switch"
              title="弹幕描边"
              checked={border}
              onChange={setBorder}
            />
            <SettingItem
              type="switch"
              title="弹幕颜色"
              checked={showColor}
              onChange={setShowColor}
            />
            <SettingItem
              type="slider"
              title="字体大小"
              value={fontSize}
              min={10}
              max={32}
              step={1}
              onChange={setFontSize}
              formatValue={(v) => `${Math.round(v)}px`}
            />
            <SettingItem
              type="slider"
              title="字体字重"
              value={fontWeight}
              min={1}
              max={9}
              step={1}
              onChange={setFontWeight}
              formatValue={(v) => `${v}`}
            />
            <SettingItem
              type="slider"
              title="弹幕不透明度"
              value={opacity}
              min={0.1}
              max={1}
              step={0.1}
              onChange={setOpacity}
              formatValue={(v) => `${Math.round(v * 100)}%`}
            />
          </SettingSection>

          {/* 预览 */}
          <SettingSection title="预览">
            <div className="p-4">
              <div 
                className="relative h-32 bg-gray-900 rounded-xl overflow-hidden"
                style={{ opacity: enabled ? 1 : 0.5 }}
              >
                {enabled && (
                  <>
                    <div 
                      className="absolute whitespace-nowrap text-white animate-marquee"
                      style={{ 
                        fontSize: `${fontSize}px`, 
                        opacity,
                        fontWeight: fontWeight * 100,
                        top: '20%',
                        animationDuration: `${duration / speed}s`,
                        textShadow: border ? '1px 1px 2px black, -1px -1px 2px black' : 'none',
                      }}
                    >
                      这是一条测试弹幕
                    </div>
                    <div 
                      className="absolute whitespace-nowrap animate-marquee"
                      style={{ 
                        fontSize: `${fontSize}px`, 
                        opacity,
                        fontWeight: fontWeight * 100,
                        color: showColor ? '#FFD700' : 'white',
                        top: '50%',
                        animationDuration: `${(duration + 2) / speed}s`,
                        animationDelay: '1s',
                        textShadow: border ? '1px 1px 2px black, -1px -1px 2px black' : 'none',
                      }}
                    >
                      弹幕预览效果
                    </div>
                  </>
                )}
                {!enabled && (
                  <div className="absolute inset-0 flex items-center justify-center text-primary-500">
                    弹幕已关闭
                  </div>
                )}
              </div>
            </div>
          </SettingSection>
        </div>
      </main>

      <style jsx>{`
        @keyframes marquee {
          from { transform: translateX(100%); }
          to { transform: translateX(-100%); }
        }
        .animate-marquee {
          animation: marquee linear infinite;
        }
      `}</style>
    </div>
  )
}
