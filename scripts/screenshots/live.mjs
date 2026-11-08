// Captures screenshots of the DEPLOYED app (Vercel web + Render API + Neon DB).
// Usage: node live.mjs [webUrl] [apiUrl]
import puppeteer from 'puppeteer-core'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const WEB = process.argv[2] ?? 'https://school-admission-system-ebon.vercel.app'
const API = (process.argv[3] ?? 'https://school-admission-system-pzr4.onrender.com').replace(/\/$/, '')
const CHROME = process.env.CHROME_PATH ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe'
const STUDENT = '20152691234567890'
const out = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../docs/screenshots')
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
const api = async (p, init = {}) => (await fetch(API + p, init)).json().catch(() => null)

const classes = await api('/classes') // also wakes the free Render instance
const cls = classes.find((x) => x.name === 'Class 6 - Day Shift') ?? classes[0]
const mine = await api('/me/holds', { headers: { 'X-Student-Id': STUDENT } })
let holdId = mine.find((h) => h.classId === cls.id && h.status === 'HELD')?.holdId
if (!holdId) holdId = (await api(`/classes/${cls.id}/holds`, { method: 'POST', headers: { 'X-Student-Id': STUDENT } })).holdId

const browser = await puppeteer.launch({ executablePath: CHROME, headless: true, args: ['--no-sandbox'] })
const page = await browser.newPage()
await page.setViewport({ width: 1000, height: 720, deviceScaleFactor: 1.5 })
await page.emulateMediaFeatures([{ name: 'prefers-color-scheme', value: 'dark' }])
await page.goto(WEB, { waitUntil: 'networkidle0', timeout: 120000 })
await page.evaluate((s, h) => {
  localStorage.setItem('studentId', s); localStorage.setItem('tab', 'mine'); localStorage.setItem('holdId', h); localStorage.setItem('theme', 'dark')
}, STUDENT, holdId)
await page.reload({ waitUntil: 'networkidle0', timeout: 120000 })
await sleep(1500)
await page.screenshot({ path: `${out}/web-live-application.png`, fullPage: true })
await browser.close()
console.log('saved web-live-application.png from', WEB)
