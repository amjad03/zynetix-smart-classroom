'use client';
import { useEffect, useState } from 'react';
import { SUBJECT_NAMES, Shell, api, errorText, useApi } from '@zynetix/web-ui';
import { DAYS, NAV, Section } from '../../lib/nav';

type Slot = { day: number; period: number; start: string; end: string; subject: string; teacher?: string };

/** Weekly timetable per section: periods down, days across. */
export default function Timetable() {
  const { data: sections } = useApi<Section[]>('/v1/admin/sections');
  const [sectionId, setSectionId] = useState('');
  const { data } = useApi<Slot[]>(sectionId ? `/v1/admin/sections/${sectionId}/timetable` : null);
  const [slots, setSlots] = useState<Slot[]>([]), [periods, setPeriods] = useState(6), [msg, setMsg] = useState('');
  useEffect(() => { if (sections?.length && !sectionId) setSectionId(sections[0].id); }, [sections, sectionId]);
  useEffect(() => { if (data) { setSlots(data); setPeriods(Math.max(4, ...data.map((s) => s.period))); } }, [data]);

  const at = (day: number, period: number) => slots.find((s) => s.day === day && s.period === period);
  const timeOf = (period: number) => slots.find((s) => s.period === period) ?? { start: '', end: '' };
  const setCell = (day: number, period: number, subject: string) => setSlots((all) => {
    const rest = all.filter((s) => !(s.day === day && s.period === period));
    const t = timeOf(period);
    return subject ? [...rest, { day, period, subject, start: t.start || '09:00', end: t.end || '09:40' }] : rest;
  });
  const setTime = (period: number, key: 'start' | 'end', v: string) => setSlots((all) => all.map((s) => (s.period === period ? { ...s, [key]: v } : s)));

  return (
    <Shell product="College Admin" nav={NAV}>
      <h1>Timetable</h1>
      <div className="card row">
        <label>Section<select value={sectionId} onChange={(e) => setSectionId(e.target.value)}>{sections?.map((s) => <option key={s.id} value={s.id}>{s.label}</option>)}</select></label>
        <button className="secondary" onClick={() => setPeriods((p) => p + 1)}>+ Period</button>
        <div style={{ flex: 1 }} />
        <button onClick={async () => {
          try { const r = await api(`/v1/admin/sections/${sectionId}/timetable`, { method: 'PUT', body: slots.map(({ teacher, ...s }) => (teacher ? { ...s, teacher } : s)) }); setMsg(`Saved ${r.saved} periods.`); }
          catch (e) { setMsg(errorText(e)); }
        }}>Save</button>
      </div>
      {msg && <p className={msg.startsWith('Saved') ? '' : 'error'}>{msg}</p>}
      <div className="card table-wrap">
        <table>
          <thead><tr><th>Period</th><th>Time</th>{DAYS.map((d) => <th key={d}>{d}</th>)}</tr></thead>
          <tbody>
            {Array.from({ length: periods }, (_, i) => i + 1).map((p) => (
              <tr key={p}>
                <td>P{p}</td>
                <td style={{ whiteSpace: 'nowrap' }}>
                  <input style={{ width: 70 }} value={timeOf(p).start} onChange={(e) => setTime(p, 'start', e.target.value)} placeholder="09:00" />–
                  <input style={{ width: 70 }} value={timeOf(p).end} onChange={(e) => setTime(p, 'end', e.target.value)} placeholder="09:40" />
                </td>
                {DAYS.map((_, d) => (
                  <td key={d}>
                    <select value={at(d + 1, p)?.subject ?? ''} onChange={(e) => setCell(d + 1, p, e.target.value)}>
                      <option value="">—</option>
                      {(sections?.find((x) => x.id === sectionId)?.subjects ?? []).map((s) => <option key={s} value={s}>{SUBJECT_NAMES[s] ?? s}</option>)}
                      <option value="other">other</option>
                    </select>
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Shell>
  );
}
