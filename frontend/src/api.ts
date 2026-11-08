export type ClassInfo = {
  id: string
  name: string
  totalSeats: number
  heldSeats: number
  confirmedSeats: number
  availableSeats: number
}

export type HoldStatus = 'HELD' | 'CONFIRMED' | 'EXPIRED' | 'CANCELLED'

export type Hold = {
  holdId: string
  classId: string
  studentId?: string
  status: HoldStatus
  expiresAt: string
}

export type MyHold = {
  holdId: string
  classId: string
  className: string
  status: HoldStatus
  expiresAt: string
}

declare global {
  interface Window {
    __CONFIG__?: { API_URL?: string }
  }
}

/** Backend URL: runtime config.js (Docker) > VITE_API_URL (Vercel build) > local default. */
export function apiBase(): string {
  const url = window.__CONFIG__?.API_URL || import.meta.env.VITE_API_URL || 'http://localhost:8080'
  return String(url).replace(/\/+$/, '')
}

export const STUDENT_ID_RX = /^\d{17}$/

export class ApiError extends Error {
  status: number
  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

const FALLBACK: Record<number, string> = {
  400: 'Some of the information you entered is not valid. Please check it and try again.',
  404: 'We could not find that item. It may have been removed.',
  409: 'That action is not possible right now (for example, no seats left or the time has run out).',
  500: 'Something went wrong on the server. Please try again in a moment.',
  502: 'The server is temporarily unavailable. Please try again in a moment.',
  503: 'The server is temporarily unavailable. Please try again in a moment.',
}

async function request<T>(path: string, init: RequestInit & { student?: string } = {}): Promise<T> {
  const headers: Record<string, string> = {}
  if (init.body) headers['Content-Type'] = 'application/json'
  if (init.student) headers['X-Student-Id'] = init.student
  let res: Response
  try {
    res = await fetch(apiBase() + path, { ...init, headers })
  } catch {
    throw new ApiError('Cannot reach the server. Please check your internet connection and try again.', 0)
  }
  if (res.status === 204) return undefined as T
  let data: unknown = null
  try {
    data = await res.json()
  } catch {
    /* non-JSON body */
  }
  if (!res.ok) {
    const msg = (data as { error?: string } | null)?.error
    throw new ApiError(msg || FALLBACK[res.status] || `Unexpected error (${res.status}). Please try again.`, res.status)
  }
  return data as T
}

export const api = {
  listClasses: () => request<ClassInfo[]>('/classes'),
  createClass: (name: string, totalSeats: number) =>
    request<{ id: string; name: string; totalSeats: number }>('/classes', {
      method: 'POST',
      body: JSON.stringify({ name, totalSeats }),
    }),
  apply: (classId: string, student: string) =>
    request<Hold>(`/classes/${classId}/holds`, { method: 'POST', student }),
  getHold: (holdId: string) => request<Hold>(`/holds/${holdId}`),
  confirm: (holdId: string, student: string) =>
    request<{ holdId: string; status: HoldStatus }>(`/holds/${holdId}/confirm`, { method: 'POST', student }),
  cancel: (holdId: string, student: string) => request<void>(`/holds/${holdId}`, { method: 'DELETE', student }),
  myHolds: (student: string) => request<MyHold[]>('/me/holds', { student }),
}
