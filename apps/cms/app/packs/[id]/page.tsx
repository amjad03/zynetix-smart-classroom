'use client';
import { use, useEffect, useState } from 'react';
import { BLOCK_TYPES, type BlockType } from '@zynetix/lesson-schema';
import { L10nInput, Shell, api, errorText, useApi, type L10n } from '@zynetix/web-ui';
import { NAV } from '../../../lib/nav';
import { clean, fieldsFor, newBlock, type Field } from '../../../lib/blocks';

type Block = Record<string, any> & { id: string; type: BlockType };
type Lesson = { id: string; chapterId: string; topicId: string; title: L10n; minutes: number; blocks: Block[] };
type Chapter = { id: string; title: L10n; topics: { id: string; title: L10n }[]; packId: string | null };

/** Block editor: one topic's lesson as an ordered list of blocks. */
export default function PackEditor({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { data: lessons, reload } = useApi<Lesson[]>(`/v1/cms/packs/${id}/lessons`);
  const { data: chapters } = useApi<Chapter[]>('/v1/cms/chapters');
  const chapter = chapters?.find((c) => c.packId === id);
  const [topicId, setTopicId] = useState<string>();
  const [lesson, setLesson] = useState<Lesson>();
  const [open, setOpen] = useState<string>();
  const [msg, setMsg] = useState('');

  useEffect(() => {
    if (!chapter || !lessons) return;
    const t = topicId ?? chapter.topics[0]?.id;
    if (!t) return;
    setTopicId(t);
    const topic = chapter.topics.find((x) => x.id === t)!;
    setLesson(structuredClone(lessons.find((l) => l.topicId === t)) ?? { id: `${t}.lesson`, chapterId: chapter.id, topicId: t, title: topic.title, minutes: 40, blocks: [] });
  }, [chapter, lessons, topicId]);

  const setBlock = (i: number, b: Block) => setLesson((l) => l && { ...l, blocks: l.blocks.map((x, j) => (j === i ? b : x)) });
  const move = (i: number, d: number) => setLesson((l) => {
    if (!l || i + d < 0 || i + d >= l.blocks.length) return l;
    const blocks = [...l.blocks];
    [blocks[i], blocks[i + d]] = [blocks[i + d], blocks[i]];
    return { ...l, blocks };
  });

  return (
    <Shell product="Content CMS" nav={NAV}>
      <h1>{chapter?.title.en ?? id}</h1>
      <div className="row">
        <label style={{ flex: 1 }}>Topic<select value={topicId ?? ''} onChange={(e) => { setTopicId(e.target.value); setMsg(''); }}>
          {chapter?.topics.map((t) => <option key={t.id} value={t.id}>{t.title.en}{lessons?.some((l) => l.topicId === t.id) ? '' : ' (no lesson yet)'}</option>)}
        </select></label>
      </div>
      {chapter && chapter.topics.length === 0 && <p className="muted">This chapter has no topics yet. Add them with PUT /v1/cms/chapters/:id/topics.</p>}
      {lesson && (
        <>
          <div className="card">
            <L10nInput label="Lesson title" value={lesson.title} onChange={(title) => setLesson({ ...lesson, title })} />
            <label>Minutes<input type="number" value={lesson.minutes} onChange={(e) => setLesson({ ...lesson, minutes: Number(e.target.value) })} /></label>
          </div>
          {lesson.blocks.map((b, i) => (
            <div className="card" key={b.id}>
              <div className="row" style={{ justifyContent: 'space-between' }}>
                <button className="link" onClick={() => setOpen(open === b.id ? undefined : b.id)}>
                  <strong>{i + 1}. {b.type}</strong> <span className="muted">{b.id} · {preview(b)}</span>
                </button>
                <div className="row">
                  <button className="secondary" onClick={() => move(i, -1)} aria-label="Move up">↑</button>
                  <button className="secondary" onClick={() => move(i, 1)} aria-label="Move down">↓</button>
                  <button className="secondary" onClick={() => setLesson({ ...lesson, blocks: lesson.blocks.filter((_, j) => j !== i) })}>Delete</button>
                </div>
              </div>
              {open === b.id && <BlockForm block={b} onChange={(nb) => setBlock(i, nb)} />}
            </div>
          ))}
          <div className="card row">
            <label>Add block<select value="" onChange={(e) => {
              const nb = newBlock(e.target.value as BlockType, lesson.blocks.map((b) => b.id)) as Block;
              setLesson({ ...lesson, blocks: [...lesson.blocks, nb] });
              setOpen(nb.id);
            }}>
              <option value="">Choose type…</option>
              {BLOCK_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select></label>
            <div style={{ flex: 1 }} />
            <button onClick={async () => {
              try {
                await api(`/v1/cms/packs/${id}/lessons/${lesson.topicId}`, { method: 'PUT', body: { ...lesson, blocks: lesson.blocks.map(clean) } });
                setMsg('Saved. Publish a new version from Packs to send it to boards.');
                reload();
              } catch (e) { setMsg(errorText(e)); }
            }}>Save lesson</button>
          </div>
          {msg && <p className={msg.startsWith('Saved') ? '' : 'error'}>{msg}</p>}
        </>
      )}
    </Shell>
  );
}

function preview(b: Block): string {
  const t = b.heading?.en ?? b.title?.en ?? b.problem?.en ?? b.caption?.en ?? b.aim?.en ?? b.body?.en ?? (b.questionIds ? b.questionIds.join(', ') : '') ?? '';
  return t.length > 70 ? `${t.slice(0, 70)}…` : t;
}

function BlockForm({ block, onChange }: { block: Block; onChange: (b: Block) => void }) {
  const set = (k: string, v: unknown) => onChange({ ...block, [k]: v });
  return <div style={{ marginTop: 12 }}>{fieldsFor(block.type).map((f) => <FieldInput key={f.key} f={f} value={block[f.key]} set={(v) => set(f.key, v)} />)}</div>;
}

function FieldInput({ f, value, set }: { f: Field; value: any; set: (v: unknown) => void }) {
  switch (f.kind) {
    case 'l10n':
    case 'l10nLong':
      return <L10nInput label={f.label} value={value} onChange={set} multiline={f.kind === 'l10nLong'} />;
    case 'l10nList': {
      const items: L10n[] = value ?? [];
      return (
        <div style={{ marginBottom: 8 }}>
          {items.map((it, i) => (
            <div key={i} className="row">
              <div style={{ flex: 1 }}><L10nInput label={`${f.label} ${i + 1}`} value={it} onChange={(v) => set(items.map((x, j) => (j === i ? v : x)))} /></div>
              <button className="secondary" onClick={() => set(items.filter((_, j) => j !== i))}>Remove</button>
            </div>
          ))}
          <button className="secondary" onClick={() => set([...items, { en: '' }])}>+ {f.label}</button>
        </div>
      );
    }
    case 'ids':
      return <label>{f.label}<input value={(value ?? []).join(', ')} onChange={(e) => set(e.target.value.split(',').map((s) => s.trim()).filter(Boolean))} /></label>;
    case 'number':
      return <label>{f.label}<input type="number" value={value ?? ''} onChange={(e) => set(e.target.value === '' ? undefined : Number(e.target.value))} /></label>;
    case 'bool':
      return <label style={{ flexDirection: 'row', alignItems: 'center' }}><input type="checkbox" checked={!!value} onChange={(e) => set(e.target.checked || undefined)} /> {f.label}</label>;
    case 'select':
      return <label>{f.label}<select value={value ?? ''} onChange={(e) => set(e.target.value)}>{f.options!.map((o) => <option key={o}>{o}</option>)}</select></label>;
    default:
      return <label>{f.label}<input value={value ?? ''} onChange={(e) => set(e.target.value)} /></label>;
  }
}
