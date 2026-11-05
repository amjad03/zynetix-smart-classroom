#!/usr/bin/env bash
# Uploads signed audio packs, then the signed index, to the GitHub release the boards read
# (BoardConfig.defaultVoiceCdnBase):  tools/voice/publish_audio.sh [file.zpack ...]
# With no files it uploads every pack in content/dist/audio that the index lists. Creates the
# release (tag audio-en-v1) when it is missing. Needs gh logged in with write access to the repo.
# DELETE_ASSET=<name> also removes an older pack the index no longer lists.
set -euo pipefail
REPO_SLUG=${REPO_SLUG:-amjad03/zynetix-smart-classroom}
TAG=${AUDIO_TAG:-audio-en-v1}
root=$(cd "$(dirname "$0")/../.." && pwd)
index=$root/content/audio/audio-index.json
files=("$@")
if [ ${#files[@]} -eq 0 ]; then
  mapfile -t files < <(python3 -c 'import json,sys; [print(sys.argv[2]+"/"+p["url"]) for p in json.load(open(sys.argv[1]))["packs"]]' "$index" "$root/content/dist/audio")
fi
rel=$(gh api "repos/$REPO_SLUG/releases/tags/$TAG" --jq .id 2>/dev/null || true)
if [ -z "$rel" ]; then
  rel=$(gh api -X POST "repos/$REPO_SLUG/releases" -f tag_name="$TAG" -f target_commitish=main -F make_latest=false \
    -f name="English narration audio packs" \
    -f body="Signed per-chapter English narration for Zynetix boards: Kokoro-82M (hexgrad/Kokoro-82M, Apache-2.0), voice am_michael, Ogg Opus 24 kbps mono. Each .zpack is signed with the production pack key; audio-index.json (signed: audio-index.json.sig) lists packId, lang, version, url, sha256 and size." --jq .id)
fi
assets=$(gh api --paginate "repos/$REPO_SLUG/releases/$rel/assets?per_page=100" --jq '.[] | "\(.id) \(.name)"')
put() {  # replace an asset by name
  local f=$1 name; name=$(basename "$f")
  local old; old=$(awk -v n="$name" '$2 == n {print $1}' <<<"$assets")
  [ -n "$old" ] && gh api -X DELETE "repos/$REPO_SLUG/releases/assets/$old" >/dev/null
  for i in 1 2 3 4; do
    gh api -X POST "https://uploads.github.com/repos/$REPO_SLUG/releases/$rel/assets?name=$name" \
      -H 'Content-Type: application/octet-stream' --input "$f" --jq .name >/dev/null && return 0
    sleep $((i * 10))
  done
  return 1
}
for f in "${files[@]}"; do put "$f"; done
put "$index"
put "$index.sig"
if [ -n "${DELETE_ASSET:-}" ]; then
  old=$(awk -v n="$DELETE_ASSET" '$2 == n {print $1}' <<<"$assets")
  [ -n "$old" ] && gh api -X DELETE "repos/$REPO_SLUG/releases/assets/$old" >/dev/null
fi
echo "published ${#files[@]} pack(s) + index to https://github.com/$REPO_SLUG/releases/tag/$TAG"
