import { useState, type FormEvent } from 'react'
import { api } from '../api'
import { Alert, Spinner } from './ui'

const PRESETS = ['Class 6 - Morning Shift', 'Class 6 - Day Shift', 'Class 7 - Morning Shift', 'Class 8 - Day Shift']

export default function CreateClass() {
  const [name, setName] = useState('')
  const [seats, setSeats] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setSuccess(null)
    const n = Number(seats)
    if (!name.trim()) return setError('Please enter a class name, for example "Class 6 - Morning Shift".')
    if (!Number.isInteger(n) || n < 1) return setError('Total seats must be a whole number of at least 1.')
    setBusy(true)
    try {
      const c = await api.createClass(name.trim(), n)
      setSuccess(`Created "${c.name}" with ${c.totalSeats} seats.`)
      setName('')
      setSeats('')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create the class.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <section aria-labelledby="create-h">
      <div className="section-head">
        <div>
          <h2 id="create-h">Create a class</h2>
          <p>School admin: each shift is its own class with its own seat limit.</p>
        </div>
      </div>
      <div className="card">
        {error && <Alert kind="error">{error}</Alert>}
        {success && <Alert kind="ok">{success}</Alert>}
        <form onSubmit={submit} className="form">
          <label>
            Class name
            <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Class 6 - Morning Shift" />
          </label>
          <div className="chips" aria-label="Quick names">
            {PRESETS.map((p) => (
              <button type="button" className="chip" key={p} onClick={() => setName(p)}>
                {p}
              </button>
            ))}
          </div>
          <label>
            Total seats
            <input value={seats} onChange={(e) => setSeats(e.target.value)} inputMode="numeric" placeholder="120" />
          </label>
          <button type="submit" className="btn" disabled={busy}>
            {busy && <Spinner />}
            {busy ? 'Creating…' : 'Create class'}
          </button>
        </form>
      </div>
    </section>
  )
}
