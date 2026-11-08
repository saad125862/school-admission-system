// Captures the README screenshots. Requires the stack running (docker compose up), the Flutter web build served
// (cd mobile && flutter build web && python -m http.server 5174 -d build/web) and Chrome installed.
import puppeteer from 'puppeteer-core'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import fs from 'node:fs'

const API = process.env.API_URL ?? 'http://localhost:8080'
const WEB = process.env.WEB_URL ?? 'http://localhost:3000'
const APP = process.env.FLUTTER_URL ?? 'http://localhost:5174'
const CHROME = process.env.CHROME_PATH ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe'
const STUDENT = '20152691234567890'
const THEME = process.env.THEME ?? 'dark' // 'dark' | 'light'
const out = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../docs/screenshots')
fs.mkdirSync(out, { recursive: true })

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
const api = async (p, init = {}) => (await fetch(API + p, init)).json().catch(() => null)

async function freshHold(className, student) {
  const classes = await api('/classes')
  const c = classes.find((x) => x.name === className)
  const mine = await api('/me/holds', { headers: { 'X-Student-Id': student } })
  const old = mine.find((h) => h.classId === c.id && h.status === 'HELD')
  if (old) return old.holdId
  return (await api(`/classes/${c.id}/holds`, { method: 'POST', headers: { 'X-Student-Id': student } })).holdId
}

// the demo student also has a confirmed admission, so "My applications" shows both a HELD and a CONFIRMED row
async function ensureConfirmed(className, student) {
  const classes = await api('/classes')
  const c = classes.find((x) => x.name === className)
  const mine = await api('/me/holds', { headers: { 'X-Student-Id': student } })
  if (mine.some((h) => h.classId === c.id && h.status === 'CONFIRMED')) return
  const hold = await api(`/classes/${c.id}/holds`, { method: 'POST', headers: { 'X-Student-Id': student } })
  await api(`/holds/${hold.holdId}/confirm`, { method: 'POST', headers: { 'X-Student-Id': student } })
}
await ensureConfirmed('Class 8 - Morning Shift', STUDENT)

const browser = await puppeteer.launch({ executablePath: CHROME, headless: true, args: ['--no-sandbox'] })
const holdId = await freshHold('Class 6 - Day Shift', STUDENT)

// ---------- Web (React) ----------
{
  const page = await browser.newPage()
  await page.setViewport({ width: 1000, height: 720, deviceScaleFactor: 1.5 })
  await page.emulateMediaFeatures([{ name: 'prefers-color-scheme', value: THEME }])
  await page.goto(WEB, { waitUntil: 'networkidle0' })
  const setLs = (kv) => page.evaluate((o) => Object.entries(o).forEach(([k, v]) => localStorage.setItem(k, v)), kv)
  const shot = async (name, fullPage = true) => { await sleep(900); await page.screenshot({ path: `${out}/${name}.png`, fullPage }) }

  await setLs({ studentId: STUDENT, tab: 'classes', holdId: '', theme: THEME })
  await page.reload({ waitUntil: 'networkidle0' }); await shot('web-classes', true)
  await setLs({ tab: 'mine', holdId: '' })
  await page.reload({ waitUntil: 'networkidle0' }); await shot('web-my-applications')
  await setLs({ tab: 'mine', holdId })
  await page.reload({ waitUntil: 'networkidle0' }); await shot('web-application')
  await setLs({ tab: 'create', holdId: '' })
  await page.reload({ waitUntil: 'networkidle0' }); await shot('web-create-class')

  const sw = await browser.newPage()
  await sw.setViewport({ width: 1100, height: 900, deviceScaleFactor: 1.2 })
  await sw.goto(API + '/swagger', { waitUntil: 'networkidle0' })
  await sleep(800)
  await sw.screenshot({ path: `${out}/swagger.png` })
}

// ---------- Flutter app (web build in a phone-sized viewport) ----------
if (!process.env.SKIP_APP) {
  const page = await browser.newPage()
  await page.setViewport({ width: 390, height: 780, deviceScaleFactor: 2, isMobile: true, hasTouch: true })
  await page.goto(APP, { waitUntil: 'networkidle0' })
  await page.evaluate((s) => localStorage.setItem('flutter.studentId', JSON.stringify(s)), STUDENT)
  const open = async () => { await page.goto(APP, { waitUntil: 'networkidle0' }); await sleep(2500) }
  const tap = async (x, y) => { await page.touchscreen.tap(x, y); await sleep(1200) }
  const shot = async (name) => { await sleep(500); await page.screenshot({ path: `${out}/${name}.png` }) }
  const NAV_Y = 740

  await open(); await shot('app-classes')
  await tap(195, NAV_Y); await shot('app-my-applications')
  await tap(195, 168)    // first application card
  await sleep(1500); await shot('app-application')
  await open(); await tap(325, NAV_Y); await shot('app-create-class')
}

await browser.close()
console.log('screenshots written to', out)
