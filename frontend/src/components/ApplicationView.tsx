import { useEffect, useState } from 'react'
import { api, type Hold } from '../api'
import { formatRemaining, useNow, usePolling } from '../hooks'

type Props = {
  holdId: string
  student: string | null
  onBack: () => void
}

const LABEL: Record<string, string> = {
  HELD: 'On hold – pay the admission fee to keep your seat',
  CONFIRMED: 'Admission confirmed',
  EXPIRED: 'Expired – the time ran out and the seat was released',
  CANCELLED: 'Cancelled',
}

export default function ApplicationView({ holdId, student, onBack }: Props) {
  const [pollMs, setPollMs] = useState(3000)
  const { data: hold, error, refresh } = usePolling<Hold>(() => api.getHold(holdId), pollMs, [holdId])
  const now = useNow()
  const [busy, setBusy] = useState<'pay' | 'cancel' | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)

  const msLeft = hold ? new Date(hold.expiresAt).getTime() - now : 0
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

  return (
    <section aria-labelledby="app-h">
      <button className="link" onClick={onBack}>
        ← Back
      </button>
      <h2 id="app-h">Your application</h2>
      {error && !hold && (
        <div className="alert error" role="alert">
          {error}
        </div>
      )}
      {!hold && !error && <p>Loading…</p>}
      {hold && status && (
        <div className="card">
          <p>
            Application <code>{hold.holdId}</code>
          </p>
          <p>
            Status: <span className={`badge ${status}`}>{status}</span>
          </p>
          <p>{LABEL[status]}</p>
          {status === 'HELD' && (
            <p className="countdown" aria-live="polite">
              Time left: <strong>{formatRemaining(msLeft)}</strong>
            </p>
          )}
          <div className="row">
            <button onClick={pay} disabled={status !== 'HELD' || busy !== null || !student}>
              {busy === 'pay' ? 'Processing…' : 'Pay admission fee'}
            </button>
            <button className="secondary" onClick={cancel} disabled={status !== 'HELD' || busy !== null || !student}>
              {busy === 'cancel' ? 'Cancelling…' : 'Cancel'}
            </button>
          </div>
        </div>
      )}
      {!student && (
        <div className="alert error" role="alert">
          Enter your 17-digit birth registration number at the top to pay or cancel.
        </div>
      )}
      {error && hold && (
        <div className="alert error" role="alert">
          {error}
        </div>
      )}
      {actionError && (
        <div className="alert error" role="alert">
          {actionError}
        </div>
      )}
      {notice && !actionError && (
        <div className="alert ok" role="status">
          {notice}
        </div>
      )}
    </section>
  )
}
