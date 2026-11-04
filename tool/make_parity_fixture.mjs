// Writes test/fixtures/web_parity.json: what the WEB app's own helpers answer for a set of inputs.
// The Dart test then checks that the mobile app words things identically.
//   node --experimental-strip-types tool/make_parity_fixture.mjs     (Node 22 or newer, run from this folder)
import { writeFileSync } from 'node:fs'
import { PRESENCE, needsAttention, peopleText } from '../../web/src/lib/presence/labels.ts'
import { fmtTime, fmtRange, fmtDate, fmtDateTime } from '../../web/src/lib/time.ts'
import { friendlyError } from '../../web/src/lib/errors.ts'
import { whepUrl } from '../../web/src/lib/presence/whep.ts'

const presenceKeys = Object.keys(PRESENCE)
const out = {
  presence: PRESENCE,
  needsAttention: [
    ...presenceKeys.map((p) => ({ presence: p, discrepancy: null, expect: needsAttention({ presence: p, discrepancy: null }) })),
    ...presenceKeys.map((p) => ({ presence: p, discrepancy: 'scheduled_but_empty', expect: needsAttention({ presence: p, discrepancy: 'scheduled_but_empty' }) })),
    { presence: null, discrepancy: 'scheduled_but_empty', expect: needsAttention({ presence: undefined, discrepancy: 'scheduled_but_empty' }) },
    { presence: null, discrepancy: 'occupied_not_scheduled', expect: needsAttention({ presence: undefined, discrepancy: 'occupied_not_scheduled' }) },
    { presence: null, discrepancy: null, expect: needsAttention({ presence: undefined, discrepancy: null }) },
  ],
  peopleText: [null, 0, 1, 2, 15].flatMap((count) => [null, true, false].map((occ) => ({ count, occupied: occ, expect: peopleText(count, occ) }))),
  times: ['00:00:00', '00:05:00', '09:00:00', '11:59:00', '12:00:00', '12:30:00', '13:05:00', '23:59:00', '07:30'].map((t) => ({ t, expect: fmtTime(t) })),
  ranges: [['08:00:00', '09:30:00'], ['12:00:00', '13:00:00'], ['00:00:00', '23:59:00']].map(([a, b]) => ({ a, b, expect: fmtRange(a, b) })),
  dates: ['2026-11-09', '2026-01-01', '2026-12-31', '2027-02-28', '2028-02-29', '2026-11-03'].map((d) => ({ d, expect: fmtDate(d) })),
  dateTimes: ['2026-11-03T08:12:45.123+00:00', '2026-11-09T05:30:00Z', '2026-12-31T16:05:00Z', '2026-06-01T00:00:00Z', '2026-06-01T04:00:00Z'].map((iso) => ({
    iso,
    expect: fmtDateTime(iso, 'Asia/Manila'),
  })),
  errors: [
    'new row violates exclusion constraint "no_room_double_booking"',
    'no_instructor_double_booking',
    'conflicting key value violates exclusion constraint "no_room_double_request"',
    'no_instructor_double_request',
    'start is outside school hours',
    'new row violates row-level security policy for table "x"',
    'permission denied for table y',
    'Failed to fetch',
    'NetworkError when attempting to fetch resource',
    'a note is required when rejecting a request',
    'that time has already passed',
  ].map((m) => ({ message: m, expect: friendlyError(new Error(m)) })),
  whepUrls: [
    ['http://192.168.1.50:8889', 'lrc-301'],
    ['http://192.168.1.50:8889/', 'lrc-301'],
    ['http://192.168.1.50:8889///', '/rooms/lrc-301/'],
    ['https://cams.school.edu', 'a/b'],
  ].map(([g, s]) => ({ gateway: g, stream: s, expect: whepUrl(g, s) })),
}
writeFileSync(new URL('../test/fixtures/web_parity.json', import.meta.url), JSON.stringify(out, null, 2) + '\n')
console.log('wrote test/fixtures/web_parity.json')
