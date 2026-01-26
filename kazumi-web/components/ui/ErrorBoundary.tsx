'use client'

import React, { Component, ErrorInfo, ReactNode } from 'react'
import { GlassPanel } from './GlassPanel'
import { Button } from './Button'

interface Props {
  children: ReactNode
  fallback?: ReactNode
  onError?: (error: Error, errorInfo: ErrorInfo) => void
}

interface State {
  hasError: boolean
  error: Error | null
}

/**
 * ErrorBoundary - Catches JavaScript errors in child components
 * 
 * Features:
 * - Catches and displays errors gracefully
 * - Provides retry functionality
 * - Logs errors for debugging
 * - Liquid glass styled error UI
 * 
 * Requirements: 13.3
 */
export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props)
    this.state = { hasError: false, error: null }
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('ErrorBoundary caught an error:', error, errorInfo)
    this.props.onError?.(error, errorInfo)
  }

  handleRetry = () => {
    this.setState({ hasError: false, error: null })
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback
      }

      return (
        <GlassPanel className="p-8 text-center">
          <div className="flex flex-col items-center gap-4">
            <span className="material-symbols-rounded text-6xl text-[#FF6B6B]">
              error_outline
            </span>
            <h2 className="text-xl font-semibold text-gray-900">
              出错了
            </h2>
            <p className="text-gray-600 max-w-md">
              页面加载时发生错误，请尝试刷新页面或稍后再试。
            </p>
            {process.env.NODE_ENV === 'development' && this.state.error && (
              <pre className="mt-4 p-4 bg-gray-100 rounded-lg text-left text-sm text-red-600 overflow-auto max-w-full">
                {this.state.error.message}
              </pre>
            )}
            <div className="flex gap-3 mt-4">
              <Button
                variant="primary"
                icon="refresh"
                onClick={this.handleRetry}
              >
                重试
              </Button>
              <Button
                variant="ghost"
                icon="home"
                onClick={() => window.location.href = '/'}
              >
                返回首页
              </Button>
            </div>
          </div>
        </GlassPanel>
      )
    }

    return this.props.children
  }
}
