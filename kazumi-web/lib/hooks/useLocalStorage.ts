/**
 * Custom React hook for localStorage persistence
 * Provides type-safe localStorage access with React state synchronization
 */

import { useState, useEffect, useCallback } from 'react'

interface UseLocalStorageOptions<T> {
  serializer?: (value: T) => string
  deserializer?: (value: string) => T
  initializeWithValue?: boolean
}

/**
 * Hook for managing localStorage with React state
 * @param key - localStorage key
 * @param initialValue - Initial value if key doesn't exist
 * @param options - Serialization and initialization options
 * @returns Tuple of [value, setValue, removeValue]
 */
export function useLocalStorage<T>(
  key: string,
  initialValue: T,
  options: UseLocalStorageOptions<T> = {}
): [T, (value: T | ((prev: T) => T)) => void, () => void] {
  const {
    serializer = JSON.stringify,
    deserializer = JSON.parse,
    initializeWithValue = true,
  } = options

  // Get initial value from localStorage or use provided initial value
  const readValue = useCallback((): T => {
    // Prevent build error "window is undefined" during SSR
    if (typeof window === 'undefined') {
      return initialValue
    }

    try {
      const item = window.localStorage.getItem(key)
      return item ? deserializer(item) : initialValue
    } catch (error) {
      console.warn(`Error reading localStorage key "${key}":`, error)
      return initialValue
    }
  }, [key, initialValue, deserializer])

  // State to store our value
  const [storedValue, setStoredValue] = useState<T>(() => {
    if (initializeWithValue) {
      return readValue()
    }
    return initialValue
  })

  // Return a wrapped version of useState's setter function that
  // persists the new value to localStorage
  const setValue = useCallback(
    (value: T | ((prev: T) => T)) => {
      // Prevent build error "window is undefined" during SSR
      if (typeof window === 'undefined') {
        console.warn(
          `Tried setting localStorage key "${key}" even though environment is not a client`
        )
        return
      }

      try {
        // Allow value to be a function so we have the same API as useState
        const newValue = value instanceof Function ? value(storedValue) : value

        // Save to localStorage
        window.localStorage.setItem(key, serializer(newValue))

        // Save state
        setStoredValue(newValue)

        // Dispatch custom event so other useLocalStorage hooks can sync
        window.dispatchEvent(
          new CustomEvent('local-storage', {
            detail: { key, value: newValue },
          })
        )
      } catch (error) {
        console.warn(`Error setting localStorage key "${key}":`, error)
      }
    },
    [key, storedValue, serializer]
  )

  // Remove value from localStorage
  const removeValue = useCallback(() => {
    // Prevent build error "window is undefined" during SSR
    if (typeof window === 'undefined') {
      console.warn(
        `Tried removing localStorage key "${key}" even though environment is not a client`
      )
      return
    }

    try {
      window.localStorage.removeItem(key)
      setStoredValue(initialValue)

      // Dispatch custom event
      window.dispatchEvent(
        new CustomEvent('local-storage', {
          detail: { key, value: undefined },
        })
      )
    } catch (error) {
      console.warn(`Error removing localStorage key "${key}":`, error)
    }
  }, [key, initialValue])

  // Sync state when localStorage changes in other tabs/windows
  useEffect(() => {
    const handleStorageChange = (e: StorageEvent | CustomEvent) => {
      if ('key' in e && e.key && e.key !== key) {
        return
      }

      if ('detail' in e && e.detail.key !== key) {
        return
      }

      setStoredValue(readValue())
    }

    // Listen for changes from other tabs/windows
    window.addEventListener('storage', handleStorageChange)

    // Listen for changes from other useLocalStorage hooks in same tab
    window.addEventListener('local-storage', handleStorageChange as EventListener)

    return () => {
      window.removeEventListener('storage', handleStorageChange)
      window.removeEventListener(
        'local-storage',
        handleStorageChange as EventListener
      )
    }
  }, [key, readValue])

  return [storedValue, setValue, removeValue]
}

/**
 * Hook for managing localStorage with automatic JSON serialization
 * Convenience wrapper around useLocalStorage
 */
export function useLocalStorageJSON<T>(
  key: string,
  initialValue: T
): [T, (value: T | ((prev: T) => T)) => void, () => void] {
  return useLocalStorage(key, initialValue, {
    serializer: JSON.stringify,
    deserializer: JSON.parse,
  })
}

/**
 * Hook for managing localStorage with string values
 * Convenience wrapper around useLocalStorage
 */
export function useLocalStorageString(
  key: string,
  initialValue: string
): [string, (value: string | ((prev: string) => string)) => void, () => void] {
  return useLocalStorage(key, initialValue, {
    serializer: (value) => value,
    deserializer: (value) => value,
  })
}

/**
 * Hook for managing localStorage with number values
 * Convenience wrapper around useLocalStorage
 */
export function useLocalStorageNumber(
  key: string,
  initialValue: number
): [number, (value: number | ((prev: number) => number)) => void, () => void] {
  return useLocalStorage(key, initialValue, {
    serializer: (value) => value.toString(),
    deserializer: (value) => parseFloat(value),
  })
}

/**
 * Hook for managing localStorage with boolean values
 * Convenience wrapper around useLocalStorage
 */
export function useLocalStorageBoolean(
  key: string,
  initialValue: boolean
): [
  boolean,
  (value: boolean | ((prev: boolean) => boolean)) => void,
  () => void
] {
  return useLocalStorage(key, initialValue, {
    serializer: (value) => (value ? 'true' : 'false'),
    deserializer: (value) => value === 'true',
  })
}
