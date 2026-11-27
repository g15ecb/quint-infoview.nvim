#!/bin/sh
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
q=${QUINT:-quint}
version=$("$q" --version)
spec="$root/tests/fixtures/spec"
out="$root/tests/fixtures/quint-$version"
rm -rf "$out"
mkdir -p "$out"
work=$(mktemp -d)
cd "$work" || exit 1
"$q" run "$spec/mutex.qnt" --main mutexBuggy --mbt --out-itf "$out/run-violation_{seq}.itf.json" > "$out/run-violation.txt" 2>&1
"$q" run "$spec/mutex.qnt" --main mutexOk > "$out/run-ok.txt" 2>&1
"$q" run "$spec/mutex.qnt" --main mutexUnreached > "$out/run-warning.txt" 2>&1
"$q" run "$spec/mutex.qnt" --main mutex > "$out/run-runtime-error.txt" 2>&1
"$q" run "$spec/tyerr.qnt" > "$out/run-type-error.txt" 2>&1
"$q" test "$spec/mutex_test.qnt" > "$out/test.txt" 2>&1
if command -v java > /dev/null; then
  "$q" verify "$spec/mutex.qnt" --main mutexBuggy --max-steps 4 --out-itf "$out/verify-violation.itf.json" > "$out/verify-violation.txt" 2>&1
  "$q" verify "$spec/mutex.qnt" --main mutexOk --max-steps 4 > "$out/verify-ok.txt" 2>&1
fi
rm -rf "$work"
sed -i.bak "s|$spec|SPEC|g" "$out"/*.txt && rm "$out"/*.bak
ls "$out"
