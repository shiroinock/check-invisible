#!/bin/sh
set -eu
LC_ALL=C
export LC_ALL

usage() {
  cat <<'EOF'
Usage:
  check-invisible.sh [--all|--glassworm] [path ...]

Modes:
  --all        Detect common invisible/control Unicode characters. Default.
  --glassworm  Detect only variation selectors used by GlassWorm-style hiding.

Inputs:
  With path arguments, scans those files/directories.
  Without arguments, scans git-tracked files when inside a git repository.
  Outside git, scans the current directory recursively.

Exit status:
  0  no suspicious characters found
  1  suspicious characters found
  2  usage or scanner error
EOF
}

mode=all
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "${1:-}" = "--all" ]; then
  mode=all
  shift
elif [ "${1:-}" = "--glassworm" ]; then
  mode=glassworm
  shift
fi

list_inputs() {
  if [ "$#" -gt 0 ]; then
    for input in "$@"; do
      if [ -d "$input" ]; then
        find "$input" \
          \( -name .git -o -name node_modules -o -name vendor -o -name dist -o -name build -o -name target \) -prune \
          -o -type f -print
      elif [ -f "$input" ]; then
        printf '%s\n' "$input"
      fi
    done
    return
  fi

  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files
  else
    find . \
      \( -name .git -o -name node_modules -o -name vendor -o -name dist -o -name build -o -name target \) -prune \
      -o -type f -print
  fi
}

scan_file() {
  file=$1
  awk -v file="$file" -v mode="$mode" '
    BEGIN {
      found = 0
      for (i = 1; i < 256; i++) {
        ord[sprintf("%c", i)] = i
      }

      n = 0

      add("glassworm variation selector", "\357\270[\200-\217]")
      add("glassworm variation selector supplement", "\363\240[\204-\206][\200-\277]|\363\240\207[\200-\257]")

      if (mode != "glassworm") {
        add("ascii control", "[\001-\010\013\014\016-\037\177]")
        add("c1 control", "\302[\200-\237]")
        add("non-breaking space", "\302\240")
        add("soft hyphen", "\302\255")
        add("ogham space mark", "\341\232\200")
        add("mongolian vowel separator", "\341\240\216")
        add("unicode space/zero-width/bidi mark", "\342\200[\200-\217]")
        add("line separator/paragraph separator/bidi control/narrow nbsp", "\342\200[\250-\257]")
        add("unicode space/format control", "\342\201[\237-\257]")
        add("ideographic space", "\343\200\200")
        add("bom/zero-width no-break space", "\357\273\277")
        add("unicode tag/control character", "\363\240[\200-\201][\200-\277]")
      }
    }

    function add(label, pattern) {
      n++
      labels[n] = label
      patterns[n] = pattern
    }

    function byte(s, i) {
      return ord[substr(s, i, 1)]
    }

    function codepoint(s,    b1, b2, b3, b4) {
      b1 = byte(s, 1)
      if (length(s) == 1) return b1
      b2 = byte(s, 2)
      if (length(s) == 2) return (b1 - 192) * 64 + (b2 - 128)
      b3 = byte(s, 3)
      if (length(s) == 3) return (b1 - 224) * 4096 + (b2 - 128) * 64 + (b3 - 128)
      b4 = byte(s, 4)
      return (b1 - 240) * 262144 + (b2 - 128) * 4096 + (b3 - 128) * 64 + (b4 - 128)
    }

    function hex(n,    digits, out, d) {
      digits = "0123456789ABCDEF"
      if (n == 0) return "0"
      out = ""
      while (n > 0) {
        d = n % 16
        out = substr(digits, d + 1, 1) out
        n = int(n / 16)
      }
      return out
    }

    function cp(n,    h) {
      h = hex(n)
      while (length(h) < 4) h = "0" h
      return "U+" h
    }

    {
      line = $0
      if (substr(line, length(line), 1) == "\015") {
        line = substr(line, 1, length(line) - 1)
      }

      for (i = 1; i <= n; i++) {
        rest = line
        offset = 0
        while (match(rest, patterns[i])) {
          token = substr(rest, RSTART, RLENGTH)
          printf "%s:%d:%d: %s [%s]\n", file, NR, offset + RSTART, cp(codepoint(token)), labels[i]
          found = 1
          offset += RSTART + RLENGTH - 1
          rest = substr(rest, RSTART + RLENGTH)
        }
      }
    }

    END {
      exit found ? 1 : 0
    }
  ' "$file"
}

list_inputs "$@" | (
  status=0
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    if ! scan_file "$file"; then
      status=1
    fi
  done
  exit "$status"
)
