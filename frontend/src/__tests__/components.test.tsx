import { act, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from '../App'
import { api, ApiError } from '../api'
import ApplicationView from '../components/ApplicationView'
import ClassList from '../components/ClassList'

const STUDENT = '20152691234567890'
const cls = (over = {}) => ({ id: 'c_1', name: 'Class 6 - Morning Shift', totalSeats: 120, heldSeats: 15, confirmedSeats: 80, availableSeats: 25, ...over })

describe('ClassList', () => {
  it('shows seat counts and the Apply button', async () => {
    vi.spyOn(api, 'listClasses').mockResolvedValue([cls()])
    render(<ClassList student={STUDENT} onApplied={() => {}} onNeedStudent={() => {}} />)
    expect(await screen.findByText('Class 6 - Morning Shift')).toBeInTheDocument()
    expect(screen.getByText('120')).toBeInTheDocument()
    expect(screen.getByText('25')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Apply' })).toBeEnabled()
  })

  it('disables a full class and explains a sold-out error in plain language', async () => {
    vi.spyOn(api, 'listClasses').mockResolvedValue([cls({ availableSeats: 0, id: 'c_full', name: 'Full class' }), cls({ id: 'c_2', name: 'Almost' })])
    vi.spyOn(api, 'apply').mockRejectedValue(new ApiError('No seats are available in this class.', 409))
    render(<ClassList student={STUDENT} onApplied={() => {}} onNeedStudent={() => {}} />)
    expect(await screen.findByRole('button', { name: 'Full' })).toBeDisabled()
    await userEvent.click(screen.getByRole('button', { name: 'Apply' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('No seats are available in this class.')
  })

  it('asks for a valid student id instead of calling the API', async () => {
    vi.spyOn(api, 'listClasses').mockResolvedValue([cls()])
    const apply = vi.spyOn(api, 'apply')
    render(<ClassList student={null} onApplied={() => {}} onNeedStudent={() => {}} />)
    await userEvent.click(await screen.findByRole('button', { name: 'Apply' }))
    expect(await screen.findByRole('alert')).toHaveTextContent(/17-digit/)
    expect(apply).not.toHaveBeenCalled()
  })
})

describe('ApplicationView countdown', () => {
  beforeEach(() => vi.useFakeTimers({ shouldAdvanceTime: true }))
  afterEach(() => vi.useRealTimers())

  it('flips to EXPIRED and disables payment when the time runs out, without a reload', async () => {
    const expiresAt = new Date(Date.now() + 2000).toISOString()
    vi.spyOn(api, 'getHold').mockResolvedValue({ holdId: 'h_1', classId: 'c_1', status: 'HELD', expiresAt })
    render(<ApplicationView holdId="h_1" student={STUDENT} onBack={() => {}} />)

    expect(await screen.findByText(/Time left/)).toBeInTheDocument()
    const pay = screen.getByRole('button', { name: 'Pay admission fee' })
    expect(pay).toBeEnabled()

    await act(async () => {
      await vi.advanceTimersByTimeAsync(3000)
    })
    await waitFor(() => expect(screen.getByText('EXPIRED')).toBeInTheDocument())
    expect(screen.getByRole('button', { name: 'Pay admission fee' })).toBeDisabled()
  })
})

describe('App', () => {
  afterEach(() => vi.restoreAllMocks())

  it('validates the student id and remembers it across reloads', async () => {
    vi.spyOn(api, 'listClasses').mockResolvedValue([])
    const { unmount } = render(<App />)
    const input = screen.getByLabelText(/birth registration number/i)
    await userEvent.type(input, '123')
    expect(screen.getByRole('alert')).toHaveTextContent(/exactly 17 digits/)
    await userEvent.clear(input)
    await userEvent.type(input, STUDENT)
    expect(screen.queryByText(/exactly 17 digits/)).not.toBeInTheDocument()
    unmount()

    render(<App />)
    expect(screen.getByLabelText(/birth registration number/i)).toHaveValue(STUDENT)
  })
})
