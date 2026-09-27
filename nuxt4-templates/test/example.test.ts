import { describe, it, expect } from 'vitest'

describe('Example Test Suite', () => {
  it('should pass a basic test', () => {
    expect(1 + 1).toBe(2)
  })

  it('should test string operations', () => {
    const str = 'Hello, Vitest!'
    expect(str).toContain('Vitest')
    expect(str.length).toBeGreaterThan(0)
  })

  it('should test array operations', () => {
    const arr = [1, 2, 3, 4, 5]
    expect(arr).toHaveLength(5)
    expect(arr).toContain(3)
  })
})


