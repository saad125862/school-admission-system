import { useEffect, useMemo, useRef, useState } from 'react'
import { api, type Hold } from '../api'
import { formatRemaining, useNow, usePolling } from '../hooks'
import { Alert, IconBack, IconCheck, Spinner } from './ui'

type Props = {
  holdId: string
  student: string | null
  onBack: () => void
}

const TITLE: Record<string, string> = {
  HELD: 'Your seat is on hold',
  CONFIRMED: 'Admission confirmed',
  EXPIRED: 'This application expired',
  CANCELLED: 'Application cancelled',
}
const LABEL: Record<string, string> = {
  HELD: 'Pay the admission fee before the timer runs out to keep your seat.',
  CONFIRMED: 'Payment received. Your seat is yours. Congratulations!',
  EXPIRED: 'The time ran out and the seat was released for other students. You can apply again.',
  CANCELLED: 'You cancelled this application and the seat was released.',
}

const R = 72
const C = 2 * Math.PI * R
const COLORS = ['#6366f1', '#14b8a6', '#f59e0b', '#ec4899', '#22c55e', '#3b82f6']

function Confetti() {
  const pieces = useMemo(
    () =>
      Array.from({ length: 26 }, (_, i) => ({
        x: `${(i * 37) % 100}%`,
        d: `${(i % 9) * 0.08}s`,
        r: `${(i * 53) % 360}deg`,
        c: COLORS[i % COLORS.length],
      })),
    [],
  )
  return (
    <div className="confetti" aria-hidden="true">
      {pieces.map((p, i) => (
        <span key={i} style={{ ['--x' as string]: p.x, ['--d' as string]: p.d, ['--r' as string]: p.r, ['--c' as string]: p.c }} />
      ))}
    </div>
  )
}

export default function ApplicationView({ holdId, student, onBack }: Props) {
  const [pollMs, setPollMs] = useState(3000)
  const { data: hold, error, refresh } = usePolling<Hold>(() => api.getHold(holdId), pollMs, [holdId])
  const now = useNow()
  const [busy, setBusy] = useState<'pay' | 'cancel' | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const totalMs = useRef(600_000) // default hold length; grows if the server reports longer

  const msLeft = hold ? new Date(hold.expiresAt).getTime() - now : 0
  if (hold?.status === 'HELD' && msLeft > totalMs.current) totalMs.current = msLeft
  const timedOut = !!hold && hold.status === 'HELD' && msLeft <= 0
  const status = timedOut ? 'EXPIRED' : hold?.status

  // When the countdown reaches zero, ask the server straight away (and keep asking quickly until it agrees).
  useEffect(() => {
    setPollMs(timedOut ? 1000 : 3000)
    if (timedOut) refresh()
  }, [timedOut, refresh])

  async function pay() {
    if (!student) return
    setBusy('pay')
    setActionError(null)
    try {
      await api.confirm(holdId, student)
      setNotice('Payment received. Your admission is confirmed!')
    } catch (e) {
      setActionError(e instanceof Error ? e.message : 'Payment failed.')
    } finally {
      setBusy(null)
      refresh()
    }
  }

  async function cancel() {
    if (!student) return
    setBusy('cancel')
    setActionError(null)
    try {
      await api.cancel(holdId, student)
      setNotice('Your application was cancelled and the seat was released.')
    } catch (e) {
      setActionError(e instanceof Error ? e.message : 'Could not cancel.')
    } finally {
      setBusy(null)
      refresh()
    }
  }

  const active = status === 'HELD'
  const frac = active && totalMs.current > 0 ? Math.max(0, Math.min(1, msLeft / totalMs.current)) : status === 'CONFIRMED' ? 1 : 0
  const urgent = active && msLeft <= 60_000

  return (
    <section aria-labelledby="app-h">
      <button className="link-btn" onClick={onBack}>
        <IconBack size={16} /> Back
      </button>

      {error && !hold && <Alert kind="error">{error}</Alert>}
      {!hold && !error && <div className="skeleton" style={{ height: 360 }} aria-label="Loading" />}

      {hold && status && (
        <div className="app-card" style={{ position: 'relative' }}>
          {status === 'CONFIRMED' && <Confetti />}
          <div className="app-top">
            <div className={`ring${urgent ? ' urgent' : ''}${status === 'CONFIRMED' ? ' done' : ''}`}>
              <svg viewBox="0 0 168 168" aria-hidden="true">
                <defs>
                  <linearGradient id="ringGrad" x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0" stopColor="#6366f1" />
                    <stop offset="1" stopColor="#14b8a6" />
                  </linearGradient>
                </defs>
                <circle className="track" cx="84" cy="84" r={R} fill="none" strokeWidth="12" />
                <circle className="bar" cx="84" cy="84" r={R} fill="none" strokeWidth="12" strokeDasharray={C} strokeDashoffset={C * (1 - frac)} />
              </svg>
              <div className="ring-center">
                {status === 'CONFIRMED' ? (
                  <div className="success-badge" style={{ margin: '0 auto' }}>
                    <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                      <path className="check-draw" d="m5 12.5 4.5 4.5L19 7.5" />
                    </svg>
                  </div>
                ) : active ? (
                  <>
                    <span className="time" aria-live="off">
                      {formatRemaining(msLeft)}
                    </span>
                    <span className="cap">Time left</span>
                  </>
                ) : (
                  <span className="time">0:00</span>
                )}
              </div>
            </div>

            <div className="app-info">
              <span className={`pill ${status}`}>{status}</span>
              <h2 id="app-h">{TITLE[status]}</h2>
              <p>{LABEL[status]}</p>
              <p className="id">
                Application <code>{hold.holdId}</code>
              </p>
            </div>
          </div>

          <div className="steps" aria-label="Progress">
            <div className="step good">
              <i>
                <IconCheck size={15} />
              </i>
              Applied
            </div>
            <div className={`step ${status === 'HELD' ? 'on' : status === 'CONFIRMED' ? 'good' : 'bad'}`}>
              <i>{status === 'CONFIRMED' ? <IconCheck size={15} /> : status === 'HELD' ? '2' : '×'}</i>
              Payment
            </div>
            <div className={`step ${status === 'CONFIRMED' ? 'good' : ''}`}>
              <i>{status === 'CONFIRMED' ? <IconCheck size={15} /> : '3'}</i>
              Confirmed
            </div>
          </div>

          <div className="app-actions">
            <button className="btn" onClick={pay} disabled={status !== 'HELD' || busy !== null || !student}>
              {busy === 'pay' && <Spinner />}
              {busy === 'pay' ? 'Processing…' : 'Pay admission fee'}
            </button>
            <button className="btn ghost danger-ghost" onClick={cancel} disabled={status !== 'HELD' || busy !== null || !student}>
              {busy === 'cancel' && <Spinner />}
              {busy === 'cancel' ? 'Cancelling…' : 'Cancel'}
            </button>
          </div>
        </div>
      )}

      <div style={{ marginTop: 16 }}>
        {!student && <Alert kind="error">Enter your 17-digit birth registration number at the top to pay or cancel.</Alert>}
        {error && hold && <Alert kind="error">{error}</Alert>}
        {actionError && <Alert kind="error">{actionError}</Alert>}
        {notice && !actionError && <Alert kind="ok">{notice}</Alert>}
      </div>
    </section>
  )
}
