'use client';
import { BOARD_NAMES, Shell, useApi } from '@zynetix/web-ui';
import { NAV } from '../../lib/nav';
import { Band, EXAM_NAMES, Readiness, pct } from '../../lib/outcomes';

type R = { sections: { sectionId: string; label: string; board: string; year: string; exams: Readiness[] }[] };

/** Exam readiness per section: the same honest bands the board shows, from each exam's tagged questions. */
export default function ReadinessPage() {
  const { data, error } = useApi<R>('/v1/admin/outcomes/readiness');
  const exams = [...new Set(data?.sections.flatMap((s) => s.exams.map((e) => e.exam)))];
  const order = ['PUC', 'CBSE', 'KCET', 'COMEDK', 'NEET', 'JEE', 'JEE_ADV', 'CUET'];
  exams.sort((a, b) => order.indexOf(a) - order.indexOf(b));
  return (
    <Shell product="College Admin" nav={NAV}>
      <h1>Exam readiness</h1>
      <p className="muted">
        For each exam, mastery over only the questions tagged for that exam, topic by topic.
        <b> Exam-ready</b>: 75%+ with at least 60% of the exam&apos;s topics seen. <b>On track</b>: 50%+. <b>Needs work</b>: under 50%.
        <b> Not enough data</b>: fewer than 20 tagged answers or under 20% of topics seen. Hover a band for the numbers behind it.
      </p>
      {error && <p className="error">{error}</p>}
      <div className="card table-wrap">
        <table>
          <thead><tr><th>Section</th>{exams.map((e) => <th key={e}>{EXAM_NAMES[e] ?? e}</th>)}</tr></thead>
          <tbody>{data?.sections.map((s) => (
            <tr key={s.sectionId}>
              <td><a className="plain" href={`/outcomes/section?id=${s.sectionId}`}><b>{s.label}</b></a><div className="muted" style={{ fontSize: 12 }}>{BOARD_NAMES[s.board]}</div></td>
              {exams.map((e) => {
                const r = s.exams.find((x) => x.exam === e);
                return <td key={e}>{r ? <><Band r={r} /><div className="muted metric" style={{ fontSize: 12, marginTop: 4 }}>{r.score == null ? '–' : pct(r.score)} · {pct(r.coverage)} of topics</div></> : <span className="muted">not sitting</span>}</td>;
              })}
            </tr>
          ))}</tbody>
        </table>
      </div>
      <p className="muted">Topics seen means 2+ answers in that topic on that exam&apos;s questions. Early in the year most sections are honestly &quot;On track&quot; or &quot;Not enough data&quot;: readiness rises as more of the syllabus is taught and quizzed.</p>
    </Shell>
  );
}
