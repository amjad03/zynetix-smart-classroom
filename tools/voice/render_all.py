#!/usr/bin/env python3
"""Renders, signs and publishes the English narration of every chapter, one audio pack per chapter.

    python3 tools/voice/render_all.py [--workers 2] [--only pack1,pack2] [--once]

For each chapter whose committed lessons all have voice lines (and that nobody is editing right
now: its folder is clean in git), in priority order (1st PUC, then 2nd PUC; physics, chemistry,
maths and biology first):
  1. tools/voice/render.py <pack> en, on onnxruntime (KOKORO_ONNX_DIR), one thread per chapter and
     --workers chapters side by side; only lines that changed are rendered, and each line's length
     goes back into the lesson (voice[].ms.en);
  2. pack-builder audio-cli: the signed audio pack content/dist/audio/<pack>-audio-en-<ver>.zpack,
     signed with PACK_SIGNING_KEY_FILE / PACK_KEY_ID (the production key, outside the repo);
  3. pack-builder audio-index-cli: adds it to content/audio/audio-index.json and signs the index;
  4. tools/voice/publish_audio.sh uploads the pack and the index to the GitHub release
     (audio-en-v1), when this machine may; otherwise they wait in content/dist/audio for it;
  5. the Opus clips (not in git) are deleted: the signed pack holds them, and they are restored
     from it when a line later changes, so only that line is rendered again.
Lesson lengths, clips.json and the index are committed every few chapters (only those files, and
a lesson only when all it changes is ms). Safe to stop and start again: everything it knows is in
those files. Touch <scratchpad or $RENDER_STOP> to stop after the chapters in progress.
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import threading
import time
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CONTENT = REPO / 'content'
DIST = CONTENT / 'dist' / 'audio'
INDEX = CONTENT / 'audio' / 'audio-index.json'
BUILDER = REPO / 'tools' / 'pack-builder' / 'dist'
PY = os.environ.get('VOICE_PYTHON', sys.executable)
STOP = Path(os.environ.get('RENDER_STOP', str(REPO / '.render-stop')))
LANG = 'en'
SUBJECTS = ['physics', 'chemistry', 'maths', 'biology']
TRAILER = os.environ.get('COMMIT_TRAILER', '')
lock = threading.Lock()


def log(msg):
    print(time.strftime('%H:%M:%S'), msg, flush=True)


def git(*args, check=True, retries=20):
    for i in range(retries):
        r = subprocess.run(['git', *args], cwd=REPO, capture_output=True, text=True)
        if r.returncode == 0 or 'index.lock' not in r.stderr:
            if check and r.returncode:
                raise RuntimeError(f'git {" ".join(args[:3])}: {r.stderr.strip()[:400]}')
            return r
        time.sleep(3 + i)
    raise RuntimeError('git index stayed locked')


def priority(pack):
    year = 0 if pack.startswith('puc1-') else 1 if pack.startswith('puc2-') else 2
    subj = pack.split('-', 2)[1] if '-' in pack else ''
    return (year, SUBJECTS.index(subj) if subj in SUBJECTS else len(SUBJECTS), pack)


def committed_lessons(pack):
    """The chapter's lessons as committed (HEAD), {stem: lesson}."""
    r = git('ls-tree', '--name-only', 'HEAD', f'content/packs/{pack}/lessons/', check=False)
    out = {}
    for path in r.stdout.split():
        if path.endswith('.json'):
            out[Path(path).stem] = json.loads(git('show', f'HEAD:{path}').stdout)
    return out


def lines_of(lessons):
    """{(lessonId, clip): sha} of every English voice line."""
    sha = lambda t: hashlib.sha256(t.encode('utf-8')).hexdigest()[:16]
    out = {}
    for l in lessons.values():
        for b in l['blocks']:
            for i, line in enumerate(b.get('voice') or [], start=1):
                t = line.get('say', {}).get(LANG)
                if t:
                    out[(l['id'], line.get('clip') or f"{b['id']}.{i}")] = sha(t)
    return out


def strip_ms(x):
    if isinstance(x, dict):
        return {k: strip_ms(v) for k, v in x.items() if k != 'ms'}
    if isinstance(x, list):
        return [strip_ms(v) for v in x]
    return x


def dirty_files(pack):
    r = git('status', '--porcelain', '--', f'content/packs/{pack}')
    return [l[3:] for l in r.stdout.splitlines()]


def only_ms_changed(path):
    """True when the working copy of a lesson differs from HEAD only in voice line lengths."""
    head = git('show', f'HEAD:{path}', check=False)
    if head.returncode:
        return False
    try:
        return strip_ms(json.loads(head.stdout)) == strip_ms(json.loads((REPO / path).read_text()))
    except (ValueError, OSError):
        return False


def index():
    return json.loads(INDEX.read_text()) if INDEX.exists() else {'packs': []}


def entry(pack):
    return next((p for p in index()['packs'] if p['packId'] == pack and p['lang'] == LANG), None)


def ready_lessons(pack, partial=False):
    """The committed lessons nobody is editing (clean in git, or changed only in line lengths) that
    have voice lines: {stem: lesson}. Unless partial, every lesson of the chapter must be ready."""
    lessons = committed_lessons(pack)
    dirty = {Path(f).stem for f in dirty_files(pack) if '/lessons/' in f and not only_ms_changed(f)}
    ready = {k: l for k, l in lessons.items() if k not in dirty and any(b.get('voice') for b in l['blocks'])}
    return ready if partial or (lessons and len(ready) == len(lessons)) else {}


def status(pack, partial=False):
    """'todo' | 'done' | 'wait' (no committed voice lines yet, or someone is editing the chapter)."""
    ready = ready_lessons(pack, partial)
    if not ready:
        return 'wait'
    cj = CONTENT / 'audio' / pack / LANG / 'clips.json'
    if not cj.exists():
        return 'todo'
    c = json.loads(cj.read_text())
    ids = {l['id'] for l in ready.values()}
    have = {(x['lessonId'], x['clip']): x['sha'] for x in c['clips'] if x['lessonId'] in ids}
    e = entry(pack)
    return 'done' if have == lines_of(ready) and e and e['version'] == c['version'] else 'todo'


def restore(pack):
    """Puts back the Opus clips of the last signed pack, so only changed lines render again."""
    e = entry(pack)
    out = CONTENT / 'audio' / pack / LANG
    if not e or not (DIST / e['url']).exists():
        return
    with zipfile.ZipFile(DIST / e['url']) as z:
        for n in z.namelist():
            if n.startswith('audio/') and '..' not in n and not (out / n).exists():
                (out / n).parent.mkdir(parents=True, exist_ok=True)
                (out / n).write_bytes(z.read(n))


def tracked(path):
    return git('ls-files', '--error-unmatch', str(path.relative_to(REPO)), check=False).returncode == 0


def render(pack, partial=False):
    t0 = time.time()
    restore(pack)
    lessons = ','.join(sorted(ready_lessons(pack, partial)))
    env = {**os.environ, 'VOICE_THREADS': '1', 'OMP_NUM_THREADS': '1'}
    r = subprocess.run([PY, '-u', str(REPO / 'tools/voice/render.py'), pack, LANG, '--lessons', lessons], cwd='/tmp', env=env, capture_output=True, text=True)
    tail = [l for l in r.stdout.splitlines() if 'clips,' in l or 'render speed' in l]
    if r.returncode:
        raise RuntimeError(f'render {pack}: {(r.stderr or r.stdout).strip()[-600:]}')
    log(f'{pack}: rendered in {(time.time() - t0) / 60:.1f} min; ' + ' | '.join(tail))
    return tail


def publish(pack, published_key):
    """Signs the audio pack, adds it to the signed index, uploads, deletes the Opus intermediates."""
    r = subprocess.run(['node', str(BUILDER / 'audio-cli.js'), pack, LANG], cwd=REPO, capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(f'build {pack}: {r.stderr.strip()[-600:]}')
    file = r.stdout.split()[0]
    with lock:
        r = subprocess.run(['node', str(BUILDER / 'audio-index-cli.js'), str(INDEX.parent), str(DIST / file)], cwd=REPO, capture_output=True, text=True)
        if r.returncode:
            raise RuntimeError(f'index {pack}: {r.stderr.strip()[-600:]}')
        res = json.loads(r.stdout)
        if published_key and res['publicKey'] != published_key:
            sys.exit(f'refusing: {file} is signed with a key the boards do not trust ({res["publicKey"][:12]}…)')
        if res['replaced'] and (DIST / res['replaced']['url']).exists():
            (DIST / res['replaced']['url']).unlink()
    log(f'{pack}: {file} {res["entry"]["size"] / 1048576:.1f} MB, {res["entry"]["clips"]} clips, {res["entry"]["ms"] / 60000:.1f} min, indexed')
    upload([file], res['replaced'] and res['replaced']['url'])
    out = CONTENT / 'audio' / pack / LANG / 'audio'
    for f in list(out.rglob('*.opus')) if out.exists() else []:
        if not tracked(f):
            f.unlink()
    for d in sorted(out.rglob('*'), reverse=True) if out.exists() else []:
        if d.is_dir() and not any(d.iterdir()):
            d.rmdir()


upload_ok = [True]


def upload(files, old=None):
    if os.environ.get('NO_UPLOAD') or not upload_ok[0]:
        return
    with lock:
        cmd = [str(REPO / 'tools/voice/publish_audio.sh'), *[str(DIST / f) for f in files]]
        r = subprocess.run(cmd, cwd=REPO, capture_output=True, text=True, env={**os.environ, 'DELETE_ASSET': old or ''})
        if r.returncode:
            upload_ok[0] = False  # no point trying for every chapter; the packs wait in content/dist/audio
            log(f'upload failed, packs stay in {DIST} for tools/voice/publish_audio.sh: {(r.stderr or r.stdout).strip()[-300:]}')
        else:
            log(f'uploaded {", ".join(files)} + index')


def commit(packs):
    """Commits the lesson lengths, clips.json and the index for these chapters (only those files)."""
    with lock:
        files = []
        for p in packs:
            files += [f for f in dirty_files(p) if f.endswith('.json') and '/lessons/' in f and only_ms_changed(f)]
            cj = f'content/audio/{p}/{LANG}/clips.json'
            if git('status', '--porcelain', '--', cj).stdout.strip():
                files.append(cj)
        files += [str(x.relative_to(REPO)) for x in (INDEX, INDEX.with_name(INDEX.name + '.sig')) if x.exists()]
        files = [f for f in files if git('status', '--porcelain', '--', f).stdout.strip()]
        if not files:
            return
        git('add', '--', *files)
        msg = f'Voice: English narration for {len(packs)} chapter(s) ({", ".join(packs[:4])}{"…" if len(packs) > 4 else ""})\n\n' \
              f'Kokoro-82M (Apache-2.0) am_michael via onnxruntime; line lengths, clips.json and the signed audio index.'
        if TRAILER:
            msg += '\n\n' + TRAILER
        r = git('commit', '-m', msg, '--', *files, check=False)
        if r.returncode:
            log(f'commit failed: {r.stderr.strip()[:300]}')
            return
        for i in range(4):
            if git('push', 'origin', 'HEAD', check=False).returncode == 0:
                log(f'committed and pushed {len(files)} files')
                return
            time.sleep(15 * (i + 1))
        log('push failed; the commit is local and goes with the next push')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--workers', type=int, default=2)
    ap.add_argument('--only', help='comma-separated pack dirs')
    ap.add_argument('--once', action='store_true', help='one pass, then stop')
    ap.add_argument('--partial', default='puc1-physics-units-and-measurement',
                    help='chapters published with only the lessons that are ready (the rest wait for every lesson)')
    ap.add_argument('--batch', type=int, default=6, help='commit every N chapters')
    a = ap.parse_args()
    if not os.environ.get('KOKORO_ONNX_DIR'):
        sys.exit('set KOKORO_ONNX_DIR (kokoro-v1.0.onnx + voices-v1.0.bin)')
    if not os.environ.get('PACK_SIGNING_KEY_FILE'):
        log('warning: no PACK_SIGNING_KEY_FILE: packs are signed with the dev key, which boards do not trust')
    # The production key boards trust, as committed: every pack and the index must verify against it.
    trusted = json.loads(git('show', 'HEAD:apps/board/assets/packs/trusted-key.json').stdout)
    published_key = trusted['ed25519'] if trusted['keyId'] == os.environ.get('PACK_KEY_ID') else None
    STOP.unlink(missing_ok=True)
    packs = sorted((p.name for p in (CONTENT / 'packs').iterdir() if (p / 'lessons').is_dir()), key=priority)
    if a.only:
        want = a.only.split(',')
        packs = [p for p in packs if p in want]
    while True:
        partial = set(a.partial.split(','))
        st = {p: status(p, p in partial) for p in packs}
        todo = [p for p in packs if st[p] == 'todo']
        log(f'{sum(v == "done" for v in st.values())} done, {len(todo)} to render, {sum(v == "wait" for v in st.values())} waiting for voice lines')
        if not todo and (a.once or all(v == 'done' for v in st.values())):
            break
        pending = []
        with ThreadPoolExecutor(a.workers) as ex:
            def job(p):
                if STOP.exists():
                    return
                if shutil.disk_usage(REPO).free < 1.5e9:
                    log(f'{p}: skipped, less than 1.5 GB free on disk')
                    STOP.touch()
                    return
                try:
                    if status(p, p in partial) != 'todo':
                        return
                    render(p, p in partial)
                    publish(p, published_key)
                    with lock:
                        pending.append(p)
                        batch = list(pending) if len(pending) >= a.batch else None
                        if batch:
                            pending.clear()
                    if batch:
                        commit(batch)
                except Exception as e:  # one chapter's problem (a bad line) does not stop the rest
                    log(f'{p}: FAILED {e}')
            list(ex.map(job, todo))
        if pending:
            commit(pending)
        if STOP.exists() or a.once:
            break
        if not todo:
            time.sleep(600)  # wait for more chapters' voice lines to be committed
    log('stopped')


if __name__ == '__main__':
    main()
