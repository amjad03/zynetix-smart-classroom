'use client';
import { useEffect, useState } from 'react';
import { Shell, api, errorText, useApi } from '@zynetix/web-ui';
import { Chapter, DAYS, NAV, Section } from '../../lib/nav';

type Booking = { id: number; sectionId: string; section: string; date: string; start: string; end: string; topicId: string; reason?: string };
type Slot = { day: number; period: number; start: string; end: string; subject: string; teacher?: string };

/**
 * A teacher is absent: pick the section and date, tap their period, choose the topic.
 * The board starts a Self-Learning period on its own at that time (it has the schedule offline).
 */
export default function Scheduler() {
  const { data: sections } = useApi<Section[]>('/v1/admin/sections');
  const { data: chapters } = useApi<Chapter[]>('/v1/admin/syllabus');
  const { data: bookings, reload } = useApi<Booking[]>('/v1/admin/self-learning');
  const [sectionId, setSectionId] = useState(''), [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [slot, setSlot] = useState<Slot>(), [topicId, setTopicId] = useState(''), [reason, setReason] = useState(''), [msg, setMsg] = useState('');
  const { data: timetable } = useApi<Slot[]>(sectionId ? `/v1/admin/sections/${sectionId}/timetable` : null);
  useEffect(() => { if (sections?.length && !sectionId) setSectionId(sections[0].id); }, [sections, sectionId]);

  const section = sections?.find((s) => s.id === sectionId);
  const day = new Date(`${date}T00:00`).getDay(); // 0 = Sunday
  const slots = timetable?.filter((s) => s.day === day) ?? [];
  const topics = (chapters ?? []).filter((c) => c.hasPack && c.year === section?.year && section && c.boards.includes(section.board) && section.subjects.includes(c.subject) && (!slot || c.subject === slot.subject))
    .flatMap((c) => c.topics.map((t) => ({ id: t.id, label: `${c.subject} · ${c.title.en} · ${t.title.en}` })));
  const titleOf = (id: string) => chapters?.flatMap((c) => c.topics.map((t) => [t.id, `${c.title.en} · ${t.title.en}`] as const)).find(([i]) => i === id)?.[1] ?? id;

  return (
    <Shell product="College Admin" nav={NAV}>
      <h1>Self-learning scheduler</h1>
      <p className="muted">When a teacher is absent, book a Self-Learning period. The board runs the lesson, examples, class quiz, recap and homework by itself. Only a teacher PIN can stop it.</p>
      <div className="card">
        <div className="row">
          <label>Section<select value={sectionId} onChange={(e) => { setSectionId(e.target.value); setSlot(undefined); }}>{sections?.map((s) => <option key={s.id} value={s.id}>{s.label}</option>)}</select></label>
          <label>Date<input type="date" value={date} onChange={(e) => { setDate(e.target.value); setSlot(undefined); }} /></label>
        </div>
        <h2>Period ({DAYS[day - 1] ?? 'Sunday'})</h2>
        {slots.length === 0 && <p className="muted">No timetable periods on this day.</p>}
        <div className="row">
          {slots.map((s) => (
            <button key={s.period} className={slot?.period === s.period ? '' : 'secondary'} onClick={() => { setSlot(s); setTopicId(''); }}>
              P{s.period} · {s.start}–{s.end} · {s.subject}{s.teacher ? ` · ${s.teacher}` : ''}
            </button>
          ))}
        </div>
        {slot && (
          <div className="row" style={{ marginTop: 12 }}>
            <label style={{ flex: 2 }}>Topic<select value={topicId} onChange={(e) => setTopicId(e.target.value)}>
              <option value="">Choose…</option>
              {topics.map((t) => <option key={t.id} value={t.id}>{t.label}</option>)}
            </select></label>
            <label style={{ flex: 1 }}>Reason<input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Lecturer on leave" /></label>
            <button disabled={!topicId} onClick={async () => {
              try {
                await api('/v1/admin/self-learning', { body: { sectionId, date, start: slot.start, end: slot.end, topicId, reason: reason || undefined } });
                setMsg('Booked. The board gets it on its next sync.');
                setSlot(undefined);
                reload();
              } catch (e) { setMsg(errorText(e)); }
            }}>Book period</button>
          </div>
        )}
        {slot && topics.length === 0 && <p className="muted">No {slot.subject} content for this year yet.</p>}
        {msg && <p className={msg.startsWith('Booked') ? '' : 'error'}>{msg}</p>}
      </div>
      <div className="card table-wrap">
        <h2>Upcoming</h2>
        <table>
          <thead><tr><th>Date</th><th>Time</th><th>Section</th><th>Topic</th><th>Reason</th><th /></tr></thead>
          <tbody>{bookings?.map((b) => (
            <tr key={b.id}><td>{b.date}</td><td>{b.start}–{b.end}</td><td>{b.section}</td><td>{titleOf(b.topicId)}</td><td>{b.reason}</td>
              <td><button className="secondary" onClick={async () => { await api(`/v1/admin/self-learning/${b.id}`, { method: 'DELETE' }); reload(); }}>Cancel</button></td></tr>
          ))}</tbody>
        </table>
        {bookings?.length === 0 && <p className="muted">Nothing booked.</p>}
      </div>
    </Shell>
  );
}
