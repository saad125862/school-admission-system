import { useEffect, useState } from 'react'
import { STUDENT_ID_RX, type Hold } from './api'
import ApplicationView from './components/ApplicationView'
import ClassList from './components/ClassList'
import CreateClass from './components/CreateClass'
import MyApplications from './components/MyApplications'
import { IconCap, IconCheck, IconGrid, IconList, IconMoon, IconPlus, IconSun, IconUser } from './components/ui'
import './index.css'

type Tab = 'classes' | 'create' | 'mine'
const TABS: Tab[] = ['classes', 'mine', 'create']

function load(key: string): string {
  try {
    return localStorage.getItem(key) ?? ''
  } catch {
    return ''
  }
}
function save(key: string, value: string) {
  try {
    localStorage.setItem(key, value)
  } catch {
    /* storage unavailable: app still works, it just will not remember */
  }
}

function initialTheme(): 'light' | 'dark' {
  const saved = load('theme')
  if (saved === 'light' || saved === 'dark') return saved
  return typeof window !== 'undefined' && window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

export default function App() {
  const [studentInput, setStudentInput] = useState(() => load('studentId'))
  const [tab, setTab] = useState<Tab>(() => (TABS.includes(load('tab') as Tab) ? (load('tab') as Tab) : 'classes'))
  const [holdId, setHoldId] = useState<string | null>(() => load('holdId') || null)
  const [theme, setTheme] = useState<'light' | 'dark'>(initialTheme)

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
    save('theme', theme)
  }, [theme])

  const trimmed = studentInput.trim()
  const student = STUDENT_ID_RX.test(trimmed) ? trimmed : null
  const studentError = trimmed !== '' && !student ? 'The birth registration number must be exactly 17 digits.' : null

  function changeStudent(v: string) {
    setStudentInput(v)
    save('studentId', v)
  }
  function go(t: Tab) {
    setTab(t)
    save('tab', t)
    setHoldId(null)
    save('holdId', '')
  }
  function openHold(id: string) {
    setHoldId(id)
    save('holdId', id)
  }
  function applied(h: Hold) {
    setTab('mine')
    save('tab', 'mine')
    openHold(h.holdId)
  }
  function back() {
    setHoldId(null)
    save('holdId', '')
  }

  const view = holdId ? `hold-${holdId}` : tab

  return (
    <>
      <div className="topbar">
        <div className="topbar-inner">
          <div className="brand">
            <div className="brand-mark">
              <IconCap size={22} />
            </div>
            <div>
              <h1>School Admission System</h1>
              <small>First come, first served</small>
            </div>
          </div>
          <button
            className="icon-btn"
            onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
            aria-label={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
            title="Toggle theme"
          >
            {theme === 'dark' ? <IconSun size={18} /> : <IconMoon size={18} />}
          </button>
        </div>
      </div>

      <div className="shell">
        <div className="hero">
          <h2>
            Secure your child&apos;s <span>seat in minutes</span>
          </h2>
          <p>Apply, hold a seat, and pay the admission fee before the timer ends. Seat counts update live.</p>
        </div>

        <div className="identity">
          <label htmlFor="student-id">
            <IconUser size={14} /> Student birth registration number (17 digits)
          </label>
          <div className="field">
            <input
              id="student-id"
              value={studentInput}
              onChange={(e) => changeStudent(e.target.value)}
              inputMode="numeric"
              maxLength={17}
              placeholder="20152691234567890"
              aria-invalid={!!studentError}
              autoComplete="off"
            />
            <span className={`tick${student ? ' on' : ''}`}>
              <IconCheck size={20} />
            </span>
          </div>
          {studentError ? (
            <div className="field-error" role="alert">
              {studentError}
            </div>
          ) : (
            <div className="hint">This is your identity here. There is no login. It is remembered on this device.</div>
          )}
        </div>

        <nav className="tabs" aria-label="Sections">
          <span className="indicator" style={{ transform: `translateX(${TABS.indexOf(holdId ? 'mine' : tab) * 100}%)` }} />
          <button className={tab === 'classes' && !holdId ? 'tab active' : 'tab'} onClick={() => go('classes')}>
            <IconGrid size={17} /> <span>Classes</span>
          </button>
          <button className={tab === 'mine' || holdId ? 'tab active' : 'tab'} onClick={() => go('mine')}>
            <IconList size={17} /> <span>My applications</span>
          </button>
          <button className={tab === 'create' && !holdId ? 'tab active' : 'tab'} onClick={() => go('create')}>
            <IconPlus size={17} /> <span>Create class</span>
          </button>
        </nav>

        <main className="page" key={view}>
          {holdId ? (
            <ApplicationView holdId={holdId} student={student} onBack={back} />
          ) : tab === 'classes' ? (
            <ClassList student={student} onApplied={applied} onNeedStudent={() => undefined} />
          ) : tab === 'mine' ? (
            <MyApplications student={student} onOpen={openHold} />
          ) : (
            <CreateClass />
          )}
        </main>

        <footer>Payment is simulated for this demo.</footer>
      </div>
    </>
  )
}
