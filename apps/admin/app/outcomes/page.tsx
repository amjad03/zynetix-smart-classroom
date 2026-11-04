'use client';
import { useState } from 'react';
import { Shell, useApi } from '@zynetix/web-ui';
import { NAV } from '../../lib/nav';
import { Bar, College, Delta, DemoBadge, Spark, pct, subjectName, week } from '../../lib/outcomes';

type Row = {
  sectionId: string; subject: string; teacher: string | null; trend: (number | null)[]; answersPerWeek: number[]; mastery: number | null; change: number | null;
  topicsTaught: number; topicsAssessed: number; topicsMastered: number; stuckShare: number | null; answers: number; accuracy: number | null; rollsAssessed: number;
};
type Overview = {
  college: College; weeks: string[];
  sections: { id: string; label: string; year: string; board: string; subjects: string[]; rollCount: number }[];
  rows: Row[];
  stuckTopics: { sectionId: string; section: string; subject: string; topicId: string; title: string; chapter: string; stuck: number; assessed: number; share: number }[];
};

const avg = (xs: (number | null)[]) => {
  const v = xs.filter((x): x is number => x != null);
  return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null;
};

/** Outcomes dashboard: what each section understands, subject by subject, week by week. */
export default function Outcomes() {
  const { data, error } = useApi<Overview>('/v1/admin/outcomes?weeks=8');
  const [subject, setSubject] = useState<string>('all');
  const subjects = [...new Set(data?.sections.flatMap((s) => s.subjects))];
  const rows = data?.rows.filter((r) => subject === 'all' || r.subject === subject) ?? [];
  const live = rows.filter((r) => r.answers > 0);
  const label = (id: string) => data?.sections.find((s) => s.id === id)?.label ?? id;
  const rollsAssessed = data?.sections.reduce((a, s) => a + Math.max(0, ...data.rows.filter((r) => r.sectionId === s.id).map((r) => r.rollsAssessed)), 0) ?? 0;
  const rollsTotal = data?.sections.reduce((a, s) => a + s.rollCount, 0) ?? 0;
  return (
    <Shell product="College Admin" nav={NAV}>
      <h1>Outcomes <DemoBadge college={data?.college} /></h1>
      <p className="muted">What each section understands, from every answer given on the boards (roll numbers only). A topic is mastered at 75%, stuck under 50%, judged after 2+ answers.</p>
      {error && <p className="error">{error}</p>}
      <div className="sub-tabs">
        <button className={subject === 'all' ? '' : 'secondary'} onClick={() => setSubject('all')}>All subjects</button>
        {subjects.map((s) => <button key={s} className={s === subject ? '' : 'secondary'} onClick={() => setSubject(s)}>{subjectName(s)}</button>)}
      </div>
      <div className="kpis">
        <div className="kpi"><b className="metric">{pct(avg(live.map((r) => r.mastery)))}</b>class mastery now</div>
        <div className="kpi"><b className="metric">{live.reduce((a, r) => a + r.topicsMastered, 0)} / {rows.reduce((a, r) => a + r.topicsTaught, 0)}</b>topics mastered / taught</div>
        <div className="kpi"><b className="metric">{pct(avg(live.map((r) => r.stuckShare)))}</b>of roll numbers stuck, per topic</div>
        <div className="kpi"><b className="metric">{rollsAssessed} / {rollsTotal}</b>roll numbers assessed</div>
      </div>

      {data?.sections.filter((sec) => rows.some((r) => r.sectionId === sec.id)).map((sec) => (
        <div className="card table-wrap" key={sec.id}>
          <h2 style={{ marginTop: 0 }}><a className="plain" href={`/outcomes/section?id=${sec.id}`}>{sec.label}</a> <span className="tag">{sec.rollCount} roll numbers</span></h2>
          <table>
            <thead><tr><th>Subject</th><th>Lecturer</th><th>Class mastery by week</th><th>Now</th><th>8-week change</th><th>Taught → mastered</th><th>Roll nos. stuck per topic</th><th /></tr></thead>
            <tbody>{rows.filter((r) => r.sectionId === sec.id).map((r) => (
              <tr key={r.subject}>
                <td><b>{subjectName(r.subject)}</b></td>
                <td>{r.teacher ?? <span className="muted">not on timetable</span>}</td>
                <td><Spark values={r.trend} weeks={data.weeks} /></td>
                <td className="metric"><b>{pct(r.mastery)}</b></td>
                <td className="metric"><Delta d={r.change} /></td>
                <td style={{ minWidth: 150 }}>
                  <div className="metric">{r.topicsTaught} taught · <b>{r.topicsMastered}</b> mastered</div>
                  <Bar value={r.topicsTaught ? Math.min(1, r.topicsMastered / r.topicsTaught) : 0} />
                </td>
                <td style={{ minWidth: 110 }}><div className="metric">{pct(r.stuckShare)}</div><Bar value={r.stuckShare} kind="stuck" /></td>
                <td><a href={`/outcomes/section?id=${sec.id}&subject=${r.subject}`}>Roll numbers →</a></td>
              </tr>
            ))}</tbody>
          </table>
        </div>
      ))}

      <div>
        <div className="card table-wrap">
          <h2 style={{ marginTop: 0 }}>Lecturer and section comparison</h2>
          <p className="muted">Same subject, side by side. Mastery is the class estimate now; change is over the last 8 weeks.</p>
          <table>
            <thead><tr><th>Subject</th><th>Section</th><th>Lecturer</th><th>Mastery</th><th>Change</th><th>Answers per roll no.</th></tr></thead>
            <tbody>{[...live].sort((a, b) => a.subject.localeCompare(b.subject) || (b.mastery ?? 0) - (a.mastery ?? 0)).map((r) => (
              <tr key={`${r.sectionId}|${r.subject}`}>
                <td>{subjectName(r.subject)}</td><td>{label(r.sectionId)}</td><td>{r.teacher ?? '–'}</td>
                <td style={{ minWidth: 110 }}><div className="metric">{pct(r.mastery)}</div><Bar value={r.mastery} /></td>
                <td className="metric"><Delta d={r.change} /></td>
                <td className="metric">{r.rollsAssessed ? Math.round(r.answers / r.rollsAssessed) : '–'}</td>
              </tr>
            ))}</tbody>
          </table>
        </div>
        <div className="card table-wrap">
          <h2 style={{ marginTop: 0 }}>Where roll numbers are stuck</h2>
          <p className="muted">Topics with the largest share of assessed roll numbers under 50%. The board offers a re-teach for these.</p>
          <table>
            <thead><tr><th>Topic</th><th>Section</th><th>Stuck</th></tr></thead>
            <tbody>{data?.stuckTopics.filter((t) => subject === 'all' || t.subject === subject).map((t) => (
              <tr key={`${t.sectionId}|${t.topicId}`}>
                <td><a className="plain" href={`/outcomes/section?id=${t.sectionId}&subject=${t.subject}`}><b>{t.title}</b></a><div className="muted" style={{ fontSize: 12 }}>{subjectName(t.subject)} · {t.chapter}</div></td>
                <td>{t.section}</td>
                <td style={{ minWidth: 120 }}><div className="metric">{t.stuck} of {t.assessed} ({pct(t.share)})</div><Bar value={t.share} kind="stuck" /></td>
              </tr>
            ))}</tbody>
          </table>
        </div>
      </div>
      {data && <p className="muted">Weeks run Monday to Sunday, {week(data.weeks[0])} to this week.</p>}
    </Shell>
  );
}
