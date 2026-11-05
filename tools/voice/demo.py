#!/usr/bin/env python3
"""Joins the v5-demo frames (one per reveal step, from the screenshot harness) with each step's
narration clip into one MP4, every frame on screen for exactly its clip plus the player's gap,
so the sync can be watched and heard.

    flutter test --update-goldens screenshots/screens_test.dart --plain-name v5-demo   (in apps/board)
    python tools/voice/demo.py <en|kn> [--pack puc1-physics-units-and-measurement]

Writes apps/board/screenshots/v5/demo-<lang>.mp4.
"""
import argparse
import json
import subprocess
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BOARD = REPO / 'apps' / 'board'
WAIT_MS = 1500  # a step that asks the class: the teacher's moment before Next (in the demo only)


def run(*cmd):
    subprocess.run(cmd, check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('lang', choices=['en', 'kn'])
    ap.add_argument('--pack', default='puc1-physics-units-and-measurement')
    a = ap.parse_args()
    frames_dir = BOARD / 'build' / 'demo' / a.lang
    tl = json.loads((frames_dir / 'timeline.json').read_text())
    audio_root = REPO / 'content' / 'audio' / a.pack / a.lang
    out = BOARD / 'screenshots' / 'v5' / f'demo-{a.lang}.mp4'
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        concat_v, concat_a = [], []
        total = 0
        for i, f in enumerate(tl['frames']):
            hold = f['ms'] + tl['gapMs'] + (WAIT_MS if f['waits'] else 0)
            total += hold
            if f.get('wait'):
                # Its line and the gap, then the step with its "Your turn" label until Next.
                concat_v.append(f"file '{frames_dir / f['png']}'\nduration {(f['ms'] + tl['gapMs']) / 1000:.3f}")
                concat_v.append(f"file '{frames_dir / f['wait']}'\nduration {WAIT_MS / 1000:.3f}")
            else:
                concat_v.append(f"file '{frames_dir / f['png']}'\nduration {hold / 1000:.3f}")
            clip = audio_root / 'audio' / f['clip'].split('/audio/', 1)[1]
            wav = tmp / f'{i:03d}.wav'
            # The clip, then silence up to the frame's length: picture and voice stay in step.
            run('ffmpeg', '-v', 'error', '-y', '-i', str(clip), '-af', f'apad=whole_dur={hold / 1000:.3f}', '-ar', '48000', '-ac', '1', str(wav))
            concat_a.append(f"file '{wav}'")
        concat_v.append(f"file '{frames_dir / tl['frames'][-1]['png']}'")  # the concat demuxer needs the last frame twice
        (tmp / 'v.txt').write_text('\n'.join(concat_v) + '\n')
        (tmp / 'a.txt').write_text('\n'.join(concat_a) + '\n')
        run('ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', str(tmp / 'a.txt'), '-c:a', 'pcm_s16le', str(tmp / 'voice.wav'))
        run('ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', str(tmp / 'v.txt'), '-i', str(tmp / 'voice.wav'),
            '-vf', 'fps=25,format=yuv420p', '-c:v', 'libx264', '-preset', 'medium', '-tune', 'stillimage', '-crf', '24',
            '-c:a', 'aac', '-b:a', '96k', '-movflags', '+faststart', '-shortest', str(out))
    print(f'{out.relative_to(REPO)}: {len(tl["frames"])} steps, {total / 60000:.1f} min, {out.stat().st_size / 1e6:.1f} MB')


if __name__ == '__main__':
    main()
