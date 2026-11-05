#!/usr/bin/env python3
"""Renders a chapter's video-style narration: one clip per lesson reveal step (the lesson
`voice` lines), as small mono Ogg Opus files, with each clip's duration.

    python tools/voice/render.py <packDir> <en|kn> [--lessons t1,t2] [--limit N] [--version 1.0.0]

Writes content/audio/<packDir>/<lang>/clips.json and audio/<lesson>/<clip>.opus beside it, and
the rendered length of each line back into the lesson (voice[].ms.<lang>). Clips whose line
has not changed are kept, so re-running after an edit only renders what changed. Then build the
signed audio pack:  pnpm --filter @zynetix/pack-builder build-audio <packDir> <lang>

English runs on onnxruntime when KOKORO_ONNX_DIR is set (see Kokoro below); render_all.py renders
and publishes every chapter that way.

Voices (free, and licensed for commercial use; never a CC-BY-NC model such as facebook/mms-tts-kan):
  en  Kokoro-82M (hexgrad/Kokoro-82M, Apache-2.0), voice am_michael
  kn  Indic Parler-TTS (ai4bharat/indic-parler-tts, Apache-2.0), speaker Suresh
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CONTENT = REPO / 'content'
SR_OUT = 24000  # Opus at 24 kHz mono: plenty for speech
BITRATE = os.environ.get('VOICE_BITRATE', '24k')
LEAD_MS, TAIL_MS = 120, 220  # a breath before and after each line

VOICES = {
    'en': {'model': 'hexgrad/Kokoro-82M', 'voice': 'am_michael', 'licence': 'Apache-2.0'},
    'kn': {'model': 'ai4bharat/indic-parler-tts', 'voice': 'Suresh', 'licence': 'Apache-2.0'},
}
KN_DESCRIPTION = os.environ.get(
    'KN_DESCRIPTION',
    "Suresh speaks at a moderate pace with a calm, warm and clear voice, like a patient teacher. "
    "The recording is of very high quality, with the speaker's voice sounding clear and very close up.",
)


# model.safetensors of ai4bharat/indic-parler-tts (its LFS oid on huggingface.co).
INDIC_PARLER_SHA256 = 'c68daecb60f80c8f1faf0a6d2e6ddd6de8e224fb19750f3e9a33bca43c552c90'


def check_sha(f: Path, want: str):
    h = hashlib.sha256()
    with open(f, 'rb') as fh:
        for chunk in iter(lambda: fh.read(1 << 24), b''):
            h.update(chunk)
    if h.hexdigest() != want:
        sys.exit(f'{f} is not the official Indic Parler-TTS release (sha256 {h.hexdigest()})')


def line_sha(text: str) -> str:
    return hashlib.sha256(text.encode('utf-8')).hexdigest()[:16]


def reveal_steps(b, questions):
    """Mirrors revealSteps in packages/lesson-schema."""
    if b['type'] == 'class_quiz' and b.get('style') == 'pause':
        return 2 * len(b['questionIds'])
    if b['type'] == 'pyq' and b.get('style') == 'solve':
        q = questions.get(b['questionIds'][0])
        return 1 + (len(q['solution']) if q and q.get('solution') else 1)
    if not b.get('reveal'):
        return 1
    n = {
        'intro': len(b.get('cards', [])),
        'concept': (1 if b.get('hero') else 0) + len(b.get('cards', [])) + len(b.get('points', [])),
        'example': len(b.get('steps', [])) + 2,
        'recap': len(b.get('points', [])) + (1 if b.get('next') else 0),
    }.get(b['type'], 1)
    return max(1, n)


def _espeak_setup():
    import misaki.espeak  # noqa: F401  (sets up espeak-ng for words not in its dictionary)
    from phonemizer.backend.espeak.wrapper import EspeakWrapper
    # espeakng-loader's bundled library looks for its data at a build path; the system
    # espeak-ng (apt install libespeak-ng1 espeak-ng-data) works when it is there.
    lib = Path('/usr/lib/x86_64-linux-gnu/libespeak-ng.so.1')
    if lib.exists():
        EspeakWrapper.set_library(str(lib))
        EspeakWrapper.set_data_path(str(lib.parent / 'espeak-ng-data'))


class Kokoro:
    """Kokoro-82M. With KOKORO_ONNX_DIR (kokoro-v1.0.onnx + voices-v1.0.bin from
    github.com/thewh1teagle/kokoro-onnx, the same Apache-2.0 weights exported to ONNX) it runs on
    onnxruntime: no torch, about 0.58 s of compute per second of audio on one CPU thread, so run a
    few chapters side by side (VOICE_THREADS threads each). The text goes through the same misaki
    G2P and the same style row as the torch KPipeline, so the voice is the same."""

    def __init__(self, voice):
        _espeak_setup()
        self.voice, self.sr, self.speed = voice, 24000, 0.94
        d = os.environ.get('KOKORO_ONNX_DIR')
        if d:
            import onnxruntime as rt
            from kokoro_onnx import Kokoro as KO
            from misaki import en, espeak
            o = rt.SessionOptions()
            o.intra_op_num_threads = int(os.environ.get('VOICE_THREADS', '1'))
            o.inter_op_num_threads = 1
            sess = rt.InferenceSession(str(Path(d) / 'kokoro-v1.0.onnx'), o, providers=['CPUExecutionProvider'])
            self.ko = KO.from_session(sess, str(Path(d) / 'voices-v1.0.bin'))
            self.style = self.ko.get_voice_style(voice)
            self.g2p = en.G2P(trf=False, british=False, fallback=espeak.EspeakFallback(british=False), unk='')
            self.pipe = None
        else:
            from kokoro import KPipeline
            self.pipe = KPipeline(lang_code='a', repo_id='hexgrad/Kokoro-82M')

    def say(self, text):
        import numpy as np
        if self.pipe is None:
            from kokoro_onnx.chunker import split_phonemes
            parts = []
            for para in [t for t in text.split('\n') if t.strip()]:
                ps, _ = self.g2p(para)
                for chunk in split_phonemes(ps, 510):
                    parts.append(self.ko._create_audio(chunk, self.style, self.speed)[0])
            return np.concatenate(parts)
        parts = [a for _, _, a in self.pipe(text, voice=self.voice, speed=self.speed, split_pattern=r'\n+')]
        return np.concatenate([p.numpy() if hasattr(p, 'numpy') else p for p in parts])


class IndicParler:
    def __init__(self, speaker):
        import torch
        from parler_tts import ParlerTTSForConditionalGeneration
        from transformers import AutoTokenizer
        torch.set_num_threads(os.cpu_count() or 4)
        # The official repo is gated (accept its terms on huggingface.co, then `huggingface-cli login`).
        # INDIC_PARLER_PATH may point at a local copy instead; its weights are checked against the
        # official release so a mirror can only be the same Apache-2.0 model.
        name = os.environ.get('INDIC_PARLER_PATH', 'ai4bharat/indic-parler-tts')
        if os.path.isdir(name):
            check_sha(Path(name) / 'model.safetensors', INDIC_PARLER_SHA256)
        self.torch = torch
        self.model = ParlerTTSForConditionalGeneration.from_pretrained(name).eval()
        self.tok = AutoTokenizer.from_pretrained(name)
        self.desc_tok = AutoTokenizer.from_pretrained(self.model.config.text_encoder._name_or_path)
        self.sr = self.model.config.sampling_rate
        d = self.desc_tok(KN_DESCRIPTION, return_tensors='pt')
        self.desc = (d.input_ids, d.attention_mask)

    def say(self, text):
        p = self.tok(text, return_tensors='pt')
        self.torch.manual_seed(7)  # the same voice every time
        with self.torch.inference_mode():
            out = self.model.generate(input_ids=self.desc[0], attention_mask=self.desc[1], prompt_input_ids=p.input_ids, prompt_attention_mask=p.attention_mask)
        return out.cpu().numpy().squeeze()


def encode(audio, sr, out: Path):
    """Float audio → trimmed, padded, loudness-normalised mono Ogg Opus at SR_OUT. Returns ms."""
    import numpy as np
    import soundfile as sf
    a = np.asarray(audio, dtype='float32')
    # Trim near-silence at the ends, then a short, even breath before and after.
    thr = max(1e-3, 0.02 * float(np.abs(a).max() or 1))
    idx = np.where(np.abs(a) > thr)[0]
    if len(idx):
        a = a[max(0, idx[0] - int(0.02 * sr)): idx[-1] + int(0.06 * sr)]
    a = np.concatenate([np.zeros(int(sr * LEAD_MS / 1000), 'float32'), a, np.zeros(int(sr * TAIL_MS / 1000), 'float32')])
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix='.wav') as wav:
        sf.write(wav.name, a, sr)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav.name, '-af', 'loudnorm=I=-18:TP=-2:LRA=7', '-ar', str(SR_OUT), '-ac', '1',
                        '-c:a', 'libopus', '-b:a', BITRATE, '-application', 'voip', '-map_metadata', '-1', str(out)], check=True)
    return probe_ms(out)


def probe_ms(f: Path) -> int:
    r = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(f)], capture_output=True, text=True, check=True)
    return round(float(r.stdout.strip()) * 1000)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('pack')
    ap.add_argument('lang', choices=['en', 'kn'])
    ap.add_argument('--lessons', help='comma-separated lesson files (t1,t2); all when absent')
    ap.add_argument('--limit', type=int, help='render at most N new clips (e.g. a slow CPU voice)')
    ap.add_argument('--version', default=None, help='audio pack version (default: bump patch when clips change)')
    a = ap.parse_args()

    root = CONTENT / 'packs' / a.pack
    out = CONTENT / 'audio' / a.pack / a.lang
    questions = {q['id']: q for q in json.loads((root / 'questions.json').read_text())}
    old = json.loads((out / 'clips.json').read_text()) if (out / 'clips.json').exists() else {'version': '0.0.0', 'clips': []}
    have = {(c['lessonId'], c['clip']): c for c in old['clips']}
    files = sorted((root / 'lessons').glob('*.json'))
    if a.lessons:
        want = {x.strip() for x in a.lessons.split(',')}
        files = [f for f in files if f.stem in want]

    tts = None
    clips, rendered, stats = [], 0, []
    ms_of = {}
    for f in files:
        lesson = json.loads(f.read_text())
        changed = False
        for b in lesson['blocks']:
            voice = b.get('voice')
            if not voice:
                continue
            if len(voice) != reveal_steps(b, questions):
                sys.exit(f"{lesson['id']}/{b['id']}: {len(voice)} voice lines for {reveal_steps(b, questions)} steps")
            for i, line in enumerate(voice, start=1):
                text = line['say'].get(a.lang)
                if not text:
                    continue
                cid = line.get('clip') or f"{b['id']}.{i}"
                rel = f'audio/{f.stem}/{cid}.opus'
                prev = have.get((lesson['id'], cid))
                if prev and prev['sha'] == line_sha(text) and (out / prev['file']).exists():
                    clip = prev
                elif a.limit is not None and rendered >= a.limit:
                    continue
                else:
                    if tts is None:
                        t0 = time.time()
                        tts = Kokoro(VOICES['en']['voice']) if a.lang == 'en' else IndicParler(VOICES['kn']['voice'])
                        print(f'loaded {VOICES[a.lang]["model"]} in {time.time() - t0:.0f} s', flush=True)
                    t0 = time.time()
                    audio = tts.say(text)
                    secs = time.time() - t0
                    ms = encode(audio, tts.sr, out / rel)
                    stats.append((secs, ms))
                    rendered += 1
                    print(f'{lesson["id"]}/{cid}: {ms / 1000:.1f} s audio in {secs:.1f} s ({(out / rel).stat().st_size / 1024:.1f} KB)', flush=True)
                    clip = {'lessonId': lesson['id'], 'blockId': b['id'], 'step': i, 'clip': cid, 'file': rel, 'ms': ms, 'sha': line_sha(text)}
                clips.append(clip)
                ms_of[(lesson['id'], cid)] = (clip['sha'], clip['ms'])
                if line.get('ms', {}).get(a.lang) != clip['ms']:
                    line['ms'] = {**line.get('ms', {}), a.lang: clip['ms']}
                    changed = True
        if changed:
            # The lesson keeps each line's rendered length (Self-Learning plans with it; silent steps
            # wait it). Re-read the file first: someone may have edited it while this chapter rendered,
            # so only lines that still say what was rendered get their length.
            fresh = json.loads(f.read_text())
            dirty = False
            for b in fresh['blocks']:
                for i, line in enumerate(b.get('voice') or [], start=1):
                    text = line.get('say', {}).get(a.lang)
                    got = ms_of.get((fresh['id'], line.get('clip') or f"{b['id']}.{i}"))
                    if text and got and got[0] == line_sha(text) and line.get('ms', {}).get(a.lang) != got[1]:
                        line['ms'] = {**line.get('ms', {}), a.lang: got[1]}
                        dirty = True
            if dirty:
                f.write_text(json.dumps(fresh, indent=1, ensure_ascii=False) + '\n')

    # Lessons not re-rendered this time keep their clips.
    done = {(c['lessonId'], c['clip']) for c in clips}
    if a.lessons:
        clips += [c for k, c in have.items() if k not in done and (out / c['file']).exists() and c['file'].split('/')[1] not in want]
    version = a.version or old['version']
    if not a.version and rendered:
        maj, mi, pa = map(int, old['version'].split('.'))
        version = f'{maj}.{mi}.{pa + 1}' if old['version'] != '0.0.0' else '1.0.0'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'clips.json').write_text(json.dumps({'version': version, 'voice': VOICES[a.lang], 'clips': clips}, indent=1, ensure_ascii=False) + '\n')
    total = sum(c['ms'] for c in clips)
    size = sum((out / c['file']).stat().st_size for c in clips)
    print(f'{len(clips)} clips, {total / 60000:.1f} min, {size / 1024:.0f} KB, version {version}; rendered {rendered} now', flush=True)
    if stats:
        rt = sum(s for s, _ in stats) / (sum(m for _, m in stats) / 1000)
        print(f'render speed: {rt:.2f} s of compute per second of audio on this machine', flush=True)


if __name__ == '__main__':
    main()
