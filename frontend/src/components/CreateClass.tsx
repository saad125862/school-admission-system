import { useState, type FormEvent } from 'react'
import { api } from '../api'

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
      <h2 id="create-h">Create a class (school admin)</h2>
      <p className="muted">Each shift is its own class with its own seat limit, e.g. "Class 6 - Morning Shift".</p>
      <form onSubmit={submit} className="form">
        <label>
          Class name
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Class 6 - Morning Shift" />
        </label>
        <label>
          Total seats
          <input
            value={seats}
            onChange={(e) => setSeats(e.target.value)}
            inputMode="numeric"
            placeholder="120"
          />
        </label>
        <button type="submit" disabled={busy}>
          {busy ? 'Creating…' : 'Create class'}
        </button>
      </form>
      {error && (
        <div className="alert error" role="alert">
          {error}
        </div>
      )}
      {success && (
        <div className="alert ok" role="status">
          {success}
        </div>
      )}
    </section>
  )
}
