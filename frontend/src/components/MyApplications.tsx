import { api } from '../api'
import { usePolling } from '../hooks'
import { Alert, IconChevron, IconInbox } from './ui'

type Props = {
  student: string | null
  onOpen: (holdId: string) => void
}

export default function MyApplications({ student, onOpen }: Props) {
  const { data, error, loading } = usePolling(
    () => (student ? api.myHolds(student) : Promise.resolve([])),
    4000,
    [student],
  )
  const now = Date.now()

  return (
    <section aria-labelledby="mine-h">
      <div className="section-head">
        <div>
          <h2 id="mine-h">My applications</h2>
          <p>Every application for this student, newest first.</p>
        </div>
        {student && (
          <span className="live">
            <i /> Auto-updating
          </span>
        )}
      </div>

      {!student && <Alert kind="info">Enter your 17-digit birth registration number at the top to see your applications.</Alert>}
      {error && <Alert kind="error">{error}</Alert>}
      {student && loading && !data && (
        <div className="list">
          {[0, 1].map((i) => (
            <div className="skeleton" style={{ height: 76 }} key={i} />
          ))}
        </div>
      )}
      {student && data && data.length === 0 && (
        <div className="empty">
          <IconInbox />
          <h3>No applications yet</h3>
          <p>Go to Classes and apply for a seat.</p>
        </div>
      )}
      {student && data && data.length > 0 && (
        <div className="list">
          {data.map((h, i) => {
            const status = h.status === 'HELD' && new Date(h.expiresAt).getTime() <= now ? 'EXPIRED' : h.status
            return (
              <button className="row-card" key={h.holdId} onClick={() => onOpen(h.holdId)} style={{ ['--i' as string]: i }}>
                <div>
                  <h3>{h.className}</h3>
                  <small>{status === 'HELD' ? `Hold expires at ${new Date(h.expiresAt).toLocaleTimeString()}` : `Application ${h.holdId}`}</small>
                </div>
                <div className="row-end">
                  <span className={`pill ${status}`}>{status}</span>
                  <span className="chev">
                    <IconChevron size={18} />
                  </span>
                </div>
              </button>
            )
          })}
        </div>
      )}
    </section>
  )
}
