#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/check-invisible-test-$$

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$tmp"

printf 'plain ascii\n' > "$tmp/clean.txt"
"$root/check-invisible.sh" "$tmp/clean.txt"
"$root/check-invisible.sh" --glassworm "$tmp/clean.txt"

printf 'safe\357\270\200\n' > "$tmp/glassworm.txt"
if "$root/check-invisible.sh" --glassworm "$tmp/glassworm.txt" >/dev/null 2>&1; then
  echo "expected GlassWorm variation selector detection" >&2
  exit 1
fi

printf 'zero\342\200\213width\n' > "$tmp/zero-width.txt"
if "$root/check-invisible.sh" --all "$tmp/zero-width.txt" >/dev/null 2>&1; then
  echo "expected zero-width character detection" >&2
  exit 1
fi

if ! "$root/check-invisible.sh" --glassworm "$tmp/zero-width.txt" >/dev/null 2>&1; then
  echo "did not expect zero-width character in GlassWorm-only mode" >&2
  exit 1
fi

echo "ok"
