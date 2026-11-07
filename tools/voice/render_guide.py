#!/usr/bin/env python3
"""Renders the board's voice guide (the first-use tour on Home) as small Ogg Opus clips, with the
same voice and machinery as the lessons (render.py: Kokoro-82M am_michael, Apache-2.0).

    KOKORO_ONNX_DIR=<dir with kokoro-v1.0.onnx + voices-v1.0.bin> \
        python tools/voice/render_guide.py

Writes apps/board/assets/guide/<id>.opus and guide.json ({en: {id: {file, ms, text}}}). Lines whose
text has not changed are kept. Kannada is shown as captions for now (no Kannada guide voice yet).
The lines must match guideSteps() in apps/board/lib/features/app/tour.dart.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render  # noqa: E402

OUT = render.REPO / 'apps' / 'board' / 'assets' / 'guide'

LINES = {
    'guide-1': 'Tap the big blue button to start your class.',
    'guide-2': 'These four cards teach any chapter, open the board, quiz the class, or find a 3D model.',
    'guide-3': 'When you feel confident, switch on Show all tools.',
    'guide-4': 'Stuck? Tap What do I do now? It tells you the next step, and can undo.',
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    idx_file = OUT / 'guide.json'
    old = json.loads(idx_file.read_text()) if idx_file.exists() else {}
    have = old.get('en', {})
    tts = None
    out = {}
    for gid, text in LINES.items():
        f = OUT / f'{gid}.opus'
        prev = have.get(gid)
        if prev and prev.get('text') == text and f.exists():
            out[gid] = prev
            continue
        tts = tts or render.Kokoro(render.VOICES['en']['voice'])
        ms = render.encode(tts.say(text), tts.sr, f)
        out[gid] = {'file': f.name, 'ms': ms, 'text': text}
        print(gid, ms, 'ms')
    idx_file.write_text(json.dumps({'voice': render.VOICES['en'], 'en': out}, indent=1, ensure_ascii=False) + '\n')


if __name__ == '__main__':
    main()
