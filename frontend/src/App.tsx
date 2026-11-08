import { useState } from 'react'
import { STUDENT_ID_RX, type Hold } from './api'
import ApplicationView from './components/ApplicationView'
import ClassList from './components/ClassList'
import CreateClass from './components/CreateClass'
import MyApplications from './components/MyApplications'
import './index.css'

type Tab = 'classes' | 'create' | 'mine'

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

export default function App() {
  const [studentInput, setStudentInput] = useState(() => load('studentId'))
  const [tab, setTab] = useState<Tab>(() => (load('tab') as Tab) || 'classes')
  const [holdId, setHoldId] = useState<string | null>(() => load('holdId') || null)

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

  return (
    <div className="container">
      <header>
        <h1>School Admission System</h1>
        <div className="student">
          <label htmlFor="student-id">Student birth registration number (17 digits)</label>
          <input
            id="student-id"
            value={studentInput}
            onChange={(e) => changeStudent(e.target.value)}
            inputMode="numeric"
            maxLength={17}
            placeholder="20152691234567890"
            aria-invalid={!!studentError}
          />
          {studentError && (
            <div className="field-error" role="alert">
              {studentError}
            </div>
          )}
        </div>
        <nav>
          <button className={tab === 'classes' ? 'tab active' : 'tab'} onClick={() => go('classes')}>
            Classes
          </button>
          <button className={tab === 'mine' ? 'tab active' : 'tab'} onClick={() => go('mine')}>
            My applications
          </button>
          <button className={tab === 'create' ? 'tab active' : 'tab'} onClick={() => go('create')}>
            Create class (admin)
          </button>
        </nav>
      </header>
      <main>
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
    </div>
  )
}
