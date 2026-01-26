/**
 * Retry utility with exponential backoff
 * 
 * Implements exponential backoff retry logic for API calls
 * 
 * Requirements: 13.5
 */

export interface RetryOptions {
  /** Maximum number of retry attempts */
  maxRetries?: number
  /** Initial delay in milliseconds */
  initialDelay?: number
  /** Maximum delay in milliseconds */
  maxDelay?: number
  /** Backoff multiplier */
  backoffMultiplier?: number
  /** Function to determine if error is retryable */
  isRetryable?: (error: unknown) => boolean
  /** Callback on each retry attempt */
  onRetry?: (attempt: number, error: unknown, delay: number) => void
}

const DEFAULT_OPTIONS: Required<RetryOptions> = {
  maxRetries: 3,
  initialDelay: 1000,
  maxDelay: 30000,
  backoffMultiplier: 2,
  isRetryable: (error: unknown) => {
    // Retry on network errors and 5xx server errors
    if (error instanceof TypeError && error.message.includes('fetch')) {
      return true
    }
    if (error instanceof Error && 'status' in error) {
      const status = (error as Error & { status: number }).status
      return status >= 500 || status === 429
    }
    return true
  },
  onRetry: () => {},
}

/**
 * Calculate delay with exponential backoff and jitter
 */
function calculateDelay(
  attempt: number,
  initialDelay: number,
  maxDelay: number,
  backoffMultiplier: number
): number {
  // Exponential backoff: delay = initialDelay * (multiplier ^ attempt)
  const exponentialDelay = initialDelay * Math.pow(backoffMultiplier, attempt)
  
  // Add jitter (±25%) to prevent thundering herd
  const jitter = exponentialDelay * 0.25 * (Math.random() * 2 - 1)
  
  // Cap at maxDelay
  return Math.min(exponentialDelay + jitter, maxDelay)
}

/**
 * Sleep for specified milliseconds
 */
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms))
}

/**
 * Execute a function with retry logic and exponential backoff
 * 
 * @param fn - Async function to execute
 * @param options - Retry options
 * @returns Promise with the result of fn
 * @throws Last error if all retries fail
 * 
 * @example
 * ```ts
 * const data = await withRetry(
 *   () => fetch('/api/data').then(r => r.json()),
 *   { maxRetries: 3, initialDelay: 1000 }
 * )
 * ```
 */
export async function withRetry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {}
): Promise<T> {
  const opts = { ...DEFAULT_OPTIONS, ...options }
  let lastError: unknown

  for (let attempt = 0; attempt <= opts.maxRetries; attempt++) {
    try {
      return await fn()
    } catch (error) {
      lastError = error

      // Check if we should retry
      if (attempt >= opts.maxRetries || !opts.isRetryable(error)) {
        throw error
      }

      // Calculate delay for next attempt
      const delay = calculateDelay(
        attempt,
        opts.initialDelay,
        opts.maxDelay,
        opts.backoffMultiplier
      )

      // Notify about retry
      opts.onRetry(attempt + 1, error, delay)

      // Wait before retrying
      await sleep(delay)
    }
  }

  throw lastError
}

/**
 * Create a fetch wrapper with retry logic
 * 
 * @param baseOptions - Default retry options
 * @returns Fetch function with retry
 */
export function createRetryFetch(baseOptions: RetryOptions = {}) {
  return async function retryFetch(
    input: RequestInfo | URL,
    init?: RequestInit,
    retryOptions?: RetryOptions
  ): Promise<Response> {
    const opts = { ...baseOptions, ...retryOptions }
    
    return withRetry(async () => {
      const response = await fetch(input, init)
      
      // Throw on error status codes to trigger retry
      if (!response.ok && opts.isRetryable?.({ status: response.status })) {
        const error = new Error(`HTTP ${response.status}: ${response.statusText}`) as Error & { status: number }
        error.status = response.status
        throw error
      }
      
      return response
    }, opts)
  }
}

/**
 * Default retry fetch instance
 */
export const retryFetch = createRetryFetch({
  maxRetries: 3,
  initialDelay: 1000,
  backoffMultiplier: 2,
})
