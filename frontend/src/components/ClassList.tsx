import { useState } from 'react'
import { api, type ClassInfo, type Hold } from '../api'
import { usePolling } from '../hooks'

type Props = {
  student: string | null
  onApplied: (hold: Hold) => void
  onNeedStudent: () => void
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
      <h2 id="classes-h">Classes</h2>
      <p className="muted">Seat numbers update automatically every few seconds.</p>
      {error && (
        <div className="alert error" role="alert">
          {error}
        </div>
      )}
      {actionError && (
        <div className="alert error" role="alert">
          {actionError}
        </div>
      )}
      {loading && !data && <p>Loading classes…</p>}
      {data && data.length === 0 && <p>No classes yet. Ask the school admin to create one.</p>}
      {data && data.length > 0 && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Class</th>
                <th>Total</th>
                <th>On hold</th>
                <th>Confirmed</th>
                <th>Available</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {data.map((c) => (
                <tr key={c.id}>
                  <td>{c.name}</td>
                  <td>{c.totalSeats}</td>
                  <td>{c.heldSeats}</td>
                  <td>{c.confirmedSeats}</td>
                  <td>
                    <strong>{c.availableSeats}</strong>
                  </td>
                  <td>
                    <button onClick={() => apply(c)} disabled={busy === c.id || c.availableSeats === 0}>
                      {c.availableSeats === 0 ? 'Full' : busy === c.id ? 'Applying…' : 'Apply'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  )
}
