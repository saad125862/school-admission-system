import { useState } from 'react'
import { api, type ClassInfo, type Hold } from '../api'
import { usePolling } from '../hooks'
import { Alert, IconInbox, Spinner } from './ui'

type Props = {
  student: string | null
  onApplied: (hold: Hold) => void
  onNeedStudent: () => void
}

function SeatCard({ c, index, busy, onApply }: { c: ClassInfo; index: number; busy: boolean; onApply: () => void }) {
  const total = Math.max(1, c.totalSeats)
  const conf = (c.confirmedSeats / total) * 100
  const held = (c.heldSeats / total) * 100
  const full = c.availableSeats === 0
  const few = !full && c.availableSeats / total <= 0.1

  return (
    <article className="class-card" style={{ ['--i' as string]: index }}>
      <div className="cc-top">
        <h3>{c.name}</h3>
        {full ? <span className="pill full">Full</span> : few ? <span className="pill few">Few left</span> : null}
      </div>

      <div>
        <div className="avail">
          <span className="num" key={c.availableSeats}>
            {c.availableSeats}
          </span>
          <span className="lbl">seats available</span>
        </div>
        <div
          className="meter"
          role="img"
          aria-label={`${c.confirmedSeats} confirmed, ${c.heldSeats} on hold, ${c.availableSeats} available`}
          style={{ marginTop: 12 }}
        >
          <span className="conf" style={{ width: `${conf}%` }} />
          <span className="held" style={{ width: `${held}%` }} />
        </div>
      </div>

      <div className="stats">
        <div className="stat">
          <b>{c.totalSeats}</b>
          <span>Total</span>
        </div>
        <div className="stat">
          <b>{c.heldSeats}</b>
          <span>
            <i className="dot held" />
            On hold
          </span>
        </div>
        <div className="stat">
          <b>{c.confirmedSeats}</b>
          <span>
            <i className="dot conf" />
            Confirmed
          </span>
        </div>
      </div>

      <button className="btn block" onClick={onApply} disabled={busy || full}>
        {busy && <Spinner />}
        {full ? 'Full' : busy ? 'Applying…' : 'Apply'}
      </button>
    </article>
  )
}

export default function ClassList({ student, onApplied, onNeedStudent }: Props) {
  const { data, error, loading } = usePolling(() => api.listClasses(), 3000)
  const [busy, setBusy] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)

  async function apply(c: ClassInfo) {
    setActionError(null)
    if (!student) {
      onNeedStudent()
      setActionError('Please enter a valid 17-digit birth registration number at the top of the page first.')
      return
    }
    setBusy(c.id)
    try {
      onApplied(await api.apply(c.id, student))
    } catch (e) {
      setActionError(`Could not apply to "${c.name}": ${e instanceof Error ? e.message : 'unknown error'}`)
    } finally {
      setBusy(null)
    }
  }

  return (
    <section aria-labelledby="classes-h">
      <div className="section-head">
        <div>
          <h2 id="classes-h">Classes</h2>
          <p>Pick a class and shift. A seat is held for you while you pay the admission fee.</p>
        </div>
        <span className="live">
          <i /> Live seat counts
        </span>
      </div>

      {error && <Alert kind="error">{error}</Alert>}
      {actionError && <Alert kind="error">{actionError}</Alert>}

      {loading && !data && (
        <div className="grid" aria-label="Loading classes">
          {[0, 1, 2].map((i) => (
            <div className="skeleton" key={i} />
          ))}
        </div>
      )}

      {data && data.length === 0 && (
        <div className="empty">
          <IconInbox />
          <h3>No classes yet</h3>
          <p>Ask the school admin to create one.</p>
        </div>
      )}

      {data && data.length > 0 && (
        <div className="grid">
          {data.map((c, i) => (
            <SeatCard key={c.id} c={c} index={i} busy={busy === c.id} onApply={() => apply(c)} />
          ))}
        </div>
      )}
    </section>
  )
}
