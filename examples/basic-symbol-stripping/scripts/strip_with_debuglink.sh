#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <path-to-binary-or-library>" >&2
  exit 1
fi

binary="$1"
if [[ ! -f "$binary" ]]; then
  echo "error: '$binary' does not exist" >&2
  exit 1
fi

for candidate in llvm-objcopy objcopy; do
  if command -v "$candidate" >/dev/null 2>&1; then
    OBJCOPY="$candidate"
    break
  fi
done

if [[ -z "${OBJCOPY:-}" ]]; then
  echo "error: objcopy or llvm-objcopy not found in PATH" >&2
  exit 1
fi

dbg="${binary}.dbg"

"$OBJCOPY" --only-keep-debug "$binary" "$dbg"
"$OBJCOPY" --strip-debug "$binary"
"$OBJCOPY" --add-gnu-debuglink="$dbg" "$binary"

echo "stripped $binary"
echo "debug info saved to $dbg"
