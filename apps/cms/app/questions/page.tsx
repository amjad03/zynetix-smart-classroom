'use client';
import { useState } from 'react';
import { EXAMS, L10nInput, Shell, api, errorText, useApi, type L10n } from '@zynetix/web-ui';
import { NAV } from '../../lib/nav';

type Q = { id: string; chapterId: string; topicId?: string; format?: 'mcq' | 'assertion_reason' | 'case_based' | 'multi_correct' | 'numeric'; passage?: L10n; stem: L10n; options: L10n[]; answer: number; answers?: number[]; numericAnswer?: number; tolerance?: number; explanation?: L10n; exams: string[]; difficulty: string; pyq?: { exam: string; year: number; verified: boolean }; tags: string[] };

const FORMAT_TAG: Record<string, string> = { case_based: 'Case', assertion_reason: 'A–R', multi_correct: 'Multi', numeric: 'Numeric' };
const blankOptions = () => [{ en: '' }, { en: '' }, { en: '' }, { en: '' }];

/** The correct answer as listed in the table. */
function answerText(q: Q): string {
  if (q.format === 'numeric') return `${q.numericAnswer ?? '?'}${q.tolerance ? ` ± ${q.tolerance}` : ''}`;
  if (q.format === 'multi_correct') return (q.answers ?? [q.answer]).map((i) => 'ABCD'[i]).join(', ');
  return `${'ABCD'[q.answer]}. ${q.options[q.answer]?.en ?? ''}`;
}

const AR = [
  'Both A and R are true, and R is the correct explanation of A.',
  'Both A and R are true, but R is not the correct explanation of A.',
  'A is true, but R is false.',
  'A is false, but R is true.',
];

/** Question bank, tagged by exam, difficulty and PYQ year. */
export default function Questions() {
  const [f, setF] = useState({ chapterId: '', exam: '', difficulty: '', pyqYear: '', q: '' });
  const qs = new URLSearchParams(Object.entries(f).filter(([, v]) => v)).toString();
  const { data, error, reload } = useApi<Q[]>(`/v1/cms/questions?${qs}`);
  const { data: chapters } = useApi<{ id: string; title: L10n; subject: string; year: string; questions: number }[]>('/v1/cms/chapters');
  const [edit, setEdit] = useState<Q>();
  return (
    <Shell product="Content CMS" nav={NAV}>
      <h1>Question bank</h1>
      <div className="card row">
        <label style={{ flex: 2 }}>Chapter<select value={f.chapterId} onChange={(e) => setF({ ...f, chapterId: e.target.value })}>
          <option value="">All</option>
          {chapters?.filter((c) => c.questions > 0 || c.id === f.chapterId).map((c) => <option key={c.id} value={c.id}>{c.title.en} ({c.questions})</option>)}
        </select></label>
        <label>Exam<select value={f.exam} onChange={(e) => setF({ ...f, exam: e.target.value })}><option value="">Any</option>{EXAMS.map((x) => <option key={x}>{x}</option>)}</select></label>
        <label>Difficulty<select value={f.difficulty} onChange={(e) => setF({ ...f, difficulty: e.target.value })}><option value="">Any</option><option>easy</option><option>medium</option><option>hard</option></select></label>
        <label>PYQ year<input style={{ width: 90 }} value={f.pyqYear} onChange={(e) => setF({ ...f, pyqYear: e.target.value })} /></label>
        <label style={{ flex: 2 }}>Search<input value={f.q} onChange={(e) => setF({ ...f, q: e.target.value })} /></label>
        <button onClick={() => setEdit({ id: '', chapterId: f.chapterId, stem: { en: '' }, options: [{ en: '' }, { en: '' }, { en: '' }, { en: '' }], answer: 0, exams: ['PUC'], difficulty: 'easy', tags: [] })}>New question</button>
      </div>
      {error && <p className="error">{error}</p>}
      {edit && <Editor q={edit} chapters={chapters ?? []} onDone={() => { setEdit(undefined); reload(); }} />}
      <div className="card table-wrap">
        <table>
          <thead><tr><th>Id</th><th>Question</th><th>Exams</th><th>Level</th><th>PYQ</th><th /></tr></thead>
          <tbody>
            {data?.map((q) => (
              <tr key={q.id}>
                <td>{q.id}</td>
                <td>{q.format && q.format !== 'mcq' && <span className="tag">{FORMAT_TAG[q.format]}</span>}{q.stem.en}<div className="muted">✔ {answerText(q)}</div></td>
                <td>{q.exams.map((e) => <span key={e} className="tag">{e}</span>)}</td>
                <td>{q.difficulty}</td>
                <td>{q.pyq ? `${q.pyq.exam} ${q.pyq.year}${q.pyq.verified ? ' ✔' : ' (unverified)'}` : '—'}</td>
                <td><button className="secondary" onClick={() => setEdit(q)}>Edit</button></td>
              </tr>
            ))}
          </tbody>
        </table>
        {data?.length === 0 && <p className="muted">No questions match.</p>}
      </div>
    </Shell>
  );
}

function Editor({ q: initial, chapters, onDone }: { q: Q; chapters: { id: string; title: L10n }[]; onDone: () => void }) {
  const [q, setQ] = useState<Q>(initial), [err, setErr] = useState('');
  const isNew = !initial.id;
  return (
    <div className="card">
      <h2>{isNew ? 'New question' : q.id}</h2>
      <div className="row">
        {isNew && <label>Id<input value={q.id} onChange={(e) => setQ({ ...q, id: e.target.value })} placeholder="mot-q20" /></label>}
        <label style={{ flex: 1 }}>Chapter<select value={q.chapterId} onChange={(e) => setQ({ ...q, chapterId: e.target.value })}><option value="">Choose…</option>{chapters.map((c) => <option key={c.id} value={c.id}>{c.title.en}</option>)}</select></label>
        <label>Topic id<input value={q.topicId ?? ''} onChange={(e) => setQ({ ...q, topicId: e.target.value || undefined })} /></label>
      </div>
      <div className="row">
        <label>Format<select value={q.format ?? 'mcq'} onChange={(e) => {
          const format = e.target.value as Q['format'];
          // Only the chosen format's fields are kept, so the strict schema accepts the save.
          const base: Q = { ...q, format, answers: undefined, numericAnswer: undefined, tolerance: undefined, options: q.options.length === 4 ? q.options : blankOptions() };
          setQ(format === 'assertion_reason'
            ? { ...base, stem: q.stem.en ? q.stem : { en: 'Assertion (A): \nReason (R): ' }, options: AR.map((en) => ({ en })) }
            : format === 'numeric'
              ? { ...base, options: [], answer: 0, numericAnswer: q.numericAnswer ?? 0, tolerance: q.tolerance }
              : format === 'multi_correct'
                ? { ...base, answers: q.answers ?? [q.answer] }
                : { ...base, passage: format === 'case_based' ? q.passage ?? { en: '' } : undefined });
        }}>
          <option value="mcq">Multiple choice</option><option value="assertion_reason">Assertion–Reason (CBSE)</option><option value="case_based">Case-based (CBSE)</option>
          <option value="multi_correct">More than one correct (JEE Advanced)</option><option value="numeric">Numeric answer (JEE)</option>
        </select></label>
      </div>
      {q.format === 'case_based' && <L10nInput label="Case / passage (shown above the question)" value={q.passage} onChange={(passage) => setQ({ ...q, passage })} multiline />}
      <L10nInput label="Question" value={q.stem} onChange={(stem) => setQ({ ...q, stem })} multiline />
      {q.format === 'numeric' && (
        <div className="row">
          <label>Answer (number)<input type="number" step="any" value={q.numericAnswer ?? ''} onChange={(e) => setQ({ ...q, numericAnswer: e.target.value === '' ? undefined : Number(e.target.value) })} /></label>
          <label>Tolerance ± (0 = exact)<input type="number" step="any" min={0} value={q.tolerance ?? ''} onChange={(e) => setQ({ ...q, tolerance: e.target.value === '' ? undefined : Number(e.target.value) })} /></label>
        </div>
      )}
      {q.format !== 'numeric' && q.options.map((o, i) => (
        <div className="row" key={i}>
          {q.format === 'multi_correct'
            ? <label style={{ flexDirection: 'row', alignItems: 'center' }}><input type="checkbox" checked={(q.answers ?? []).includes(i)} onChange={(e) => {
                const answers = (e.target.checked ? [...(q.answers ?? []), i] : (q.answers ?? []).filter((x) => x !== i)).sort();
                setQ({ ...q, answers, answer: answers[0] ?? 0 });
              }} /> {'ABCD'[i]}</label>
            : <label style={{ flexDirection: 'row', alignItems: 'center' }}><input type="radio" checked={q.answer === i} onChange={() => setQ({ ...q, answer: i })} /> {'ABCD'[i]}</label>}
          <div style={{ flex: 1 }}><L10nInput label={`Option ${'ABCD'[i]}`} value={o} onChange={(v) => setQ({ ...q, options: q.options.map((x, j) => (j === i ? v : x)) })} /></div>
        </div>
      ))}
      <L10nInput label="Explanation" value={q.explanation} onChange={(explanation) => setQ({ ...q, explanation: explanation.en || explanation.kn ? explanation : undefined })} multiline />
      <div className="row">
        <fieldset style={{ border: 0, padding: 0 }}><legend className="muted">Exams</legend>
          {EXAMS.map((e) => <label key={e} style={{ flexDirection: 'row', display: 'inline-flex', marginRight: 10 }}><input type="checkbox" checked={q.exams.includes(e)} onChange={(ev) => setQ({ ...q, exams: ev.target.checked ? [...q.exams, e] : q.exams.filter((x) => x !== e) })} /> {e}</label>)}
        </fieldset>
        <label>Difficulty<select value={q.difficulty} onChange={(e) => setQ({ ...q, difficulty: e.target.value })}><option>easy</option><option>medium</option><option>hard</option></select></label>
        <label>PYQ exam<select value={q.pyq?.exam ?? ''} onChange={(e) => setQ({ ...q, pyq: e.target.value ? { exam: e.target.value, year: q.pyq?.year ?? new Date().getFullYear() - 1, verified: q.pyq?.verified ?? false } : undefined })}><option value="">Not a PYQ</option>{EXAMS.map((x) => <option key={x}>{x}</option>)}</select></label>
        {q.pyq && <>
          <label>Year<input type="number" value={q.pyq.year} onChange={(e) => setQ({ ...q, pyq: { ...q.pyq!, year: Number(e.target.value) } })} /></label>
          <label style={{ flexDirection: 'row', alignItems: 'center' }}><input type="checkbox" checked={q.pyq.verified} onChange={(e) => setQ({ ...q, pyq: { ...q.pyq!, verified: e.target.checked } })} /> Checked against the paper</label>
        </>}
      </div>
      {err && <p className="error">{err}</p>}
      <div className="row">
        <button onClick={async () => {
          const { pyqVerified, updatedAt, ...body } = q as any;
          try { await api(`/v1/cms/questions/${q.id}`, { method: 'PUT', body }); onDone(); } catch (e) { setErr(errorText(e)); }
        }}>Save</button>
        <button className="secondary" onClick={onDone}>Cancel</button>
      </div>
    </div>
  );
}
