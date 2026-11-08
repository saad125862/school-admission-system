import { api } from '../api'
import { usePolling } from '../hooks'

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
      <h2 id="mine-h">My applications</h2>
      {!student && (
        <div className="alert error" role="alert">
          Enter your 17-digit birth registration number at the top to see your applications.
        </div>
      )}
      {error && (
        <div className="alert error" role="alert">
          {error}
        </div>
      )}
      {student && loading && !data && <p>Loading…</p>}
      {student && data && data.length === 0 && <p>You have no applications yet. Go to Classes and apply.</p>}
      {student && data && data.length > 0 && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Class</th>
                <th>Status</th>
                <th>Expires</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {data.map((h) => {
                const status = h.status === 'HELD' && new Date(h.expiresAt).getTime() <= now ? 'EXPIRED' : h.status
                return (
                  <tr key={h.holdId}>
                    <td>{h.className}</td>
                    <td>
                      <span className={`badge ${status}`}>{status}</span>
                    </td>
                    <td>{status === 'HELD' ? new Date(h.expiresAt).toLocaleTimeString() : '—'}</td>
                    <td>
                      <button className="secondary" onClick={() => onOpen(h.holdId)}>
                        View
                      </button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}
    </section>
  )
}
