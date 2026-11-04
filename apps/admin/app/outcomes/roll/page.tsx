'use client';
import { Shell, useApi } from '@zynetix/web-ui';
import { NAV } from '../../../lib/nav';
import { Band, Bar, EXAM_NAMES, LEVEL_LABEL, Readiness, Spark, pct, subjectName, useQuery } from '../../../lib/outcomes';

type T = { id: string; title: string; subject: string | null; chapterNumber: number | null; chapterTitle: string; p: number; n: number; level: string; last: string };
type RollReport = {
  section: { id: string; label: string; rollCount: number }; roll: number; answers: number; correct: number; overall: number | null;
  weeks: string[]; trend: (number | null)[]; bySubject: { subject: string; mastery: number | null; topics: number; mastered: number; stuck: number }[];
  topics: T[]; stuck: T[]; strong: T[]; readiness: Readiness[];
};

/** One roll number's report (no names anywhere): for a parents' meeting or a remedial plan. Printable. */
export default function RollPage() {
  const q = useQuery();
  const section = q?.get('section'), roll = q?.get('roll');
  const { data, error } = useApi<RollReport>(section && roll ? `/v1/admin/outcomes/sections/${section}/rolls/${roll}` : null);
  const n = Number(roll);
  return (
    <Shell product="College Admin" nav={NAV}>
      <p className="no-print">
        <a href={`/outcomes/section?id=${section ?? ''}`}>← Section</a>
        {data && n > 1 && <> · <a href={`/outcomes/roll?section=${section}&roll=${n - 1}`}>Roll {n - 1}</a></>}
        {data && n < data.section.rollCount && <> · <a href={`/outcomes/roll?section=${section}&roll=${n + 1}`}>Roll {n + 1}</a></>}
        {' · '}<button className="secondary" onClick={() => print()}>Print</button>
      </p>
      <h1>Roll {roll} · {data?.section.label ?? ''}</h1>
      {error && <p className="error">{error}</p>}
      {data && (
        <>
          <div className="kpis">
            <div className="kpi"><b className="metric">{pct(data.overall)}</b>overall mastery</div>
            <div className="kpi"><b className="metric">{data.answers}</b>answers ({pct(data.answers ? data.correct / data.answers : null)} correct)</div>
            <div className="kpi"><b className="metric">{data.strong.length}</b>topics mastered</div>
            <div className="kpi"><b className="metric">{data.stuck.length}</b>topics stuck</div>
          </div>
          <div className="grid2">
            <div className="card table-wrap">
              <h2 style={{ marginTop: 0 }}>By subject</h2>
              <table>
                <thead><tr><th>Subject</th><th>Mastery</th><th>Topics</th><th>Mastered</th><th>Stuck</th></tr></thead>
                <tbody>{data.bySubject.map((s) => (
                  <tr key={s.subject}><td>{subjectName(s.subject)}</td><td style={{ minWidth: 110 }}><div className="metric">{pct(s.mastery)}</div><Bar value={s.mastery} /></td><td className="metric">{s.topics}</td><td className="metric">{s.mastered}</td><td className="metric">{s.stuck}</td></tr>
                ))}</tbody>
              </table>
              <h2>Mastery by week</h2>
              <Spark values={data.trend} weeks={data.weeks} width={320} height={60} />
            </div>
            <div className="card table-wrap">
              <h2 style={{ marginTop: 0 }}>Exam readiness</h2>
              <table>
                <thead><tr><th>Exam</th><th>Readiness</th><th>Topics seen</th></tr></thead>
                <tbody>{data.readiness.map((r) => (
                  <tr key={r.exam}><td>{EXAM_NAMES[r.exam] ?? r.exam}</td><td><Band r={r} /></td><td className="metric">{r.topicsSeen} of {r.topics}</td></tr>
                ))}</tbody>
              </table>
            </div>
          </div>
          <div className="grid2">
            <div className="card">
              <h2 style={{ marginTop: 0 }}>Needs help with</h2>
              {data.stuck.length === 0 ? <p className="muted">Nothing stuck right now.</p> : (
                <ul>{data.stuck.map((t) => <li key={t.id}><b>{t.title}</b> <span className="muted">· {subjectName(t.subject)} · {pct(t.p)} from {t.n} answers</span></li>)}</ul>
              )}
            </div>
            <div className="card">
              <h2 style={{ marginTop: 0 }}>Strong in</h2>
              {data.strong.length === 0 ? <p className="muted">No topic mastered yet.</p> : (
                <ul>{data.strong.slice(0, 10).map((t) => <li key={t.id}><b>{t.title}</b> <span className="muted">· {subjectName(t.subject)} · {pct(t.p)}</span></li>)}</ul>
              )}
            </div>
          </div>
          <div className="card table-wrap">
            <h2 style={{ marginTop: 0 }}>Every topic answered</h2>
            <table>
              <thead><tr><th>Subject</th><th>Ch.</th><th>Topic</th><th>Level</th><th>Estimate</th><th>Answers</th><th>Last answered</th></tr></thead>
              <tbody>{data.topics.map((t) => (
                <tr key={t.id}><td>{subjectName(t.subject)}</td><td className="metric">{t.chapterNumber}</td><td>{t.title}</td><td>{LEVEL_LABEL[t.level]}</td><td className="metric">{pct(t.p)}</td><td className="metric">{t.n}</td><td>{t.last}</td></tr>
              ))}</tbody>
            </table>
          </div>
        </>
      )}
    </Shell>
  );
}
