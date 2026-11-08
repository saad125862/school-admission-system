import { afterEach, describe, expect, it, vi } from 'vitest'
import { api, ApiError, apiBase } from '../api'

afterEach(() => vi.unstubAllGlobals())

describe('api client', () => {
  it('turns a network failure into a readable message', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')))
    await expect(api.listClasses()).rejects.toThrow(/Cannot reach the server/)
  })

  it('surfaces the server error message and status', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(new Response(JSON.stringify({ error: 'No seats are available in this class.' }), { status: 409 })),
    )
    const err = await api.apply('c_1', '20152691234567890').catch((e) => e)
    expect(err).toBeInstanceOf(ApiError)
    expect(err.message).toBe('No seats are available in this class.')
    expect(err.status).toBe(409)
  })

  it('sends the student id header and uses a friendly fallback for non-JSON errors', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response('<html>bad gateway</html>', { status: 502 }))
    vi.stubGlobal('fetch', fetchMock)
    await expect(api.myHolds('20152691234567890')).rejects.toThrow(/temporarily unavailable/)
    const init = fetchMock.mock.calls[0][1] as RequestInit
    expect((init.headers as Record<string, string>)['X-Student-Id']).toBe('20152691234567890')
  })

  it('prefers the runtime config URL and strips trailing slashes', () => {
    window.__CONFIG__ = { API_URL: 'https://api.example.com/' }
    expect(apiBase()).toBe('https://api.example.com')
    window.__CONFIG__ = {}
  })
})
