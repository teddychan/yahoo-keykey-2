#!/bin/bash
# Regression tests for tools/resolve-dragon-kit.sh — the block that decides whether the
# vendor/dragon-kit in a workspace may be built against, refreshed, or refused.
#
#   ./tools/test-resolve-dragon-kit.sh
#
# Everything runs against throwaway local git repos under a mktemp workspace: no network, no
# reliance on dragon-kit's real tag history, and the real vendor/dragon-kit is never touched. A
# full run is about a second, which is the point — the states below differ only in git metadata,
# and each one costs minutes to reach through tools/build-app.sh.
#
# Every case asserts the exit status AND the operator-facing message on the stream it belongs on.
# The message is half the behaviour here: these errors are read by someone whose build just
# stopped, and a wrong one sends them to the wrong remedy (the incident that started all of this
# was an operator having to guess that vendor/dragon-kit needed deleting by hand).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVER="$ROOT/tools/resolve-dragon-kit.sh"

# Hermetic git: the fixtures must not pick up the operator's ~/.gitconfig (commit.gpgsign, a
# default branch name, an absent user identity on a CI runner).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME="KeyKey Test" GIT_AUTHOR_EMAIL="test@example.invalid"
export GIT_COMMITTER_NAME="KeyKey Test" GIT_COMMITTER_EMAIL="test@example.invalid"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/keykey-resolve-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
OUT="$WORK/stdout" ERR="$WORK/stderr"

PIN="v3.1.0"          # what most cases pin against
DUAL_PIN="v3.2.0"     # a pin whose commit also carries a sample-* tag
OLD_TAG="v3.0.1"      # an older release, for the stale-workspace cases

CASES=0 FAILURES=0

# ---------------------------------------------------------------- fixtures

# A stand-in for the dragon-kit remote, carrying the same shape of tag history: a vX.Y.Z library
# series, plus a sample-vX.Y.Z series that lands on some of the SAME commits. sample-v1.4.0 is
# annotated and v3.2.0 lightweight so `git describe --exact-match` reliably prefers the sample
# tag — that is the real hazard reproduced deterministically (dragon-kit's own 808d5a7 carries
# v2.0.0 and sample-v1.2.0, and describe there answers sample-v1.2.0).
build_remote() {
  local r="$WORK/kit-remote"
  git init -q -b main "$r"
  printf 'kit %s\n' "$OLD_TAG" > "$r/VERSION"; git -C "$r" add VERSION
  git -C "$r" commit -qm "kit $OLD_TAG"; git -C "$r" tag "$OLD_TAG"
  printf 'kit %s\n' "$PIN" > "$r/VERSION"
  git -C "$r" commit -qam "kit $PIN"; git -C "$r" tag "$PIN"
  printf 'kit %s\n' "$DUAL_PIN" > "$r/VERSION"
  git -C "$r" commit -qam "kit $DUAL_PIN"
  git -C "$r" tag "$DUAL_PIN"
  git -C "$r" tag -a sample-v1.4.0 -m "sample app 1.4.0"
  # file:// so --depth 1 produces a real shallow clone instead of git's "local clone" shortcut.
  REMOTE_URL="file://$r"
}

# A workspace whose vendor/dragon-kit is a shallow clone of <tag> — exactly what the build script
# itself leaves behind: detached, clean, no branch.
fixture() {  # $1 = workspace name, $2 = tag; echoes the kit dir
  local kit="$WORK/$1/vendor/dragon-kit"
  mkdir -p "$(dirname "$kit")"
  git clone -q --depth 1 --branch "$2" "$REMOTE_URL" "$kit" 2>/dev/null
  printf '%s' "$kit"
}

# ---------------------------------------------------------------- harness

start() { CASES=$((CASES + 1)); printf '\n[%d] %s\n' "$CASES" "$1"; }
ok()    { printf '     ok   %s\n' "$1"; }
bad()   { printf '     FAIL %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

run() {  # $1 = kit dir, $2 = pin (default $PIN), $3 = clone url (default $REMOTE_URL)
  "$RESOLVER" "$1" "${2:-$PIN}" "${3:-$REMOTE_URL}" >"$OUT" 2>"$ERR"
  STATUS=$?
}

# that <description> <command...> — the command runs at the call site with normal expansion,
# so an assertion reads as the shell condition it is.
that() {
  local what="$1"; shift
  if "$@"; then ok "$what"; else bad "$what"; fi
}

status_is()    { if [ "$STATUS" -eq "$1" ]; then ok "exit status $1"; else bad "exit status: want $1, got $STATUS"; fi; }
stderr_has()   { if grep -qF -- "$1" "$ERR"; then ok "stderr: \"$1\""; else bad "stderr lacks \"$1\"$(dump)"; fi; }
stderr_lacks() { if grep -qF -- "$1" "$ERR"; then bad "stderr should not mention \"$1\"$(dump)"; else ok "stderr silent on \"$1\""; fi; }
stdout_has()   { if grep -qF -- "$1" "$OUT"; then ok "stdout: \"$1\""; else bad "stdout lacks \"$1\"$(dump)"; fi; }
quiet()        { if [ ! -s "$OUT" ] && [ ! -s "$ERR" ]; then ok "said nothing at all"; else bad "expected silence$(dump)"; fi; }

dump() { printf '\n          --- stdout ---\n%s\n          --- stderr ---\n%s' "$(sed 's/^/          /' "$OUT")" "$(sed 's/^/          /' "$ERR")"; }

head_sha()  { git -C "$1" rev-parse HEAD 2>/dev/null; }
head_tags() { git -C "$1" tag --points-at HEAD 2>/dev/null | tr '\n' ' ' | sed 's/ $//'; }

# No staging directory may survive a run, on any exit path — that is the cleanup trap's job.
no_leftovers() {
  local leftovers; leftovers="$(find "$(dirname "$1")" -maxdepth 1 -name 'dragon-kit.incoming*' 2>/dev/null)"
  if [ -z "$leftovers" ]; then ok "no staging leftovers"; else bad "staging leftovers: $leftovers"; fi
}

build_remote

# ---------------------------------------------------------------- cases

start "absent vendor/dragon-kit is cloned at the pin (the fresh-CI path)"
kit="$WORK/fresh/vendor/dragon-kit"          # note: vendor/ does not exist either
run "$kit"
status_is 0
stdout_has "==> Cloning DragonKit $PIN into vendor/ (not committed)"
that "cloned checkout is at $PIN" test "$(head_tags "$kit")" = "$PIN"
no_leftovers "$kit"

start "a checkout at the exact pinned tag is used silently"
kit="$(fixture at-pin "$PIN")"
before="$(head_sha "$kit")"
run "$kit"
status_is 0
quiet
that "checkout untouched" test "$(head_sha "$kit")" = "$before"

start "a dual-tagged pinned commit is recognised as the pin (git describe gets this wrong)"
kit="$(fixture dual-tag "$DUAL_PIN")"
before="$(head_sha "$kit")"
described="$(git -C "$kit" describe --tags --exact-match HEAD 2>/dev/null)"
that "fixture HEAD carries both tag series" test "$(head_tags "$kit")" = "sample-v1.4.0 $DUAL_PIN"
that "precondition: describe answers \"$described\", not the pin" test "$described" != "$DUAL_PIN"
run "$kit" "$DUAL_PIN"
status_is 0
quiet
that "checkout untouched — not re-cloned every build" test "$(head_sha "$kit")" = "$before"

start "a clean checkout at an older tag is refreshed to the pin"
kit="$(fixture stale-tag "$OLD_TAG")"
run "$kit"
status_is 0
stdout_has "==> vendor/dragon-kit is at $OLD_TAG, not the pinned $PIN; re-cloning at the pin"
that "checkout is now at $PIN" test "$(head_tags "$kit")" = "$PIN"
no_leftovers "$kit"

start "a plain directory inside a git repo is not mistaken for a checkout (git -C walks up)"
parent="$WORK/parent-repo"
git init -q -b parent-branch-must-never-be-reported "$parent"
kit="$parent/vendor/dragon-kit"
mkdir -p "$kit"; : > "$kit/half-written-clone"
run "$kit"
status_is 1
stderr_has "exists but is not a git checkout"
stderr_has "Remove it and re-run: rm -rf $kit"
stderr_lacks "parent-branch-must-never-be-reported"
that "directory left for the operator to remove" test -e "$kit/half-written-clone"

start "a diverged co-development branch warns and builds"
kit="$(fixture codev-branch "$PIN")"
git -C "$kit" checkout -q -b kit-codev
echo "local kit work" >> "$kit/VERSION"; git -C "$kit" commit -qam "co-development commit"
before="$(head_sha "$kit")"
run "$kit"
status_is 0
stderr_has "WARNING: vendor/dragon-kit is on branch 'kit-codev', not a checkout of the pinned"
stderr_has "Remove vendor/dragon-kit to build against the pinned tag."
that "still on the branch" test "$(git -C "$kit" symbolic-ref --short HEAD)" = "kit-codev"
that "co-development commit preserved" test "$(head_sha "$kit")" = "$before"

start "a dirty branch sitting on the pinned tag still warns and builds"
kit="$(fixture codev-at-pin "$PIN")"
git -C "$kit" checkout -q -b kit-codev          # branch, but HEAD is exactly the pinned commit
echo "uncommitted kit work" >> "$kit/VERSION"
run "$kit"
status_is 0
stderr_has "WARNING: vendor/dragon-kit is on branch 'kit-codev', not a checkout of the pinned"
that "edit preserved — a branch is never replaced" grep -q "uncommitted kit work" "$kit/VERSION"

start "a dirty detached checkout stops the build"
kit="$(fixture dirty-detached "$OLD_TAG")"
echo "stray edit" >> "$kit/VERSION"
before="$(head_sha "$kit")"
run "$kit"
status_is 1
stderr_has "ERROR: vendor/dragon-kit is detached with uncommitted changes"
stderr_has "co-develop the kit, or discard them: rm -rf $kit"
that "edit preserved" grep -q "stray edit" "$kit/VERSION"
that "not re-cloned over" test "$(head_sha "$kit")" = "$before"

start "a clean but UNTAGGED detached commit stops the build (never discarded)"
kit="$(fixture untagged-detached "$PIN")"
echo "unpushed local kit commit" >> "$kit/VERSION"
git -C "$kit" commit -qam "local commit on a detached HEAD"
before="$(head_sha "$kit")"; short="$(git -C "$kit" rev-parse --short HEAD)"
that "fixture HEAD carries no tag and the tree is clean" test -z "$(head_tags "$kit")"
run "$kit"
status_is 1
stderr_has "ERROR: vendor/dragon-kit is detached at commit $short and carries no tag,"
stderr_has "that commit disposable — it may be local work no remote has"
that "the local commit survives" test "$(head_sha "$kit")" = "$before"
no_leftovers "$kit"

start "an untracked file at the pinned tag stops the build (About would misreport it)"
kit="$(fixture dirty-at-pin "$PIN")"
echo "scratch" > "$kit/NOTES.txt"          # untracked, not modified: `git diff` would miss this
before="$(head_sha "$kit")"
run "$kit"
status_is 1
stderr_has "ERROR: vendor/dragon-kit is detached with uncommitted changes"
stderr_has "Refused even when HEAD carries $PIN"
that "untracked file preserved" test -f "$kit/NOTES.txt"
that "checkout untouched" test "$(head_sha "$kit")" = "$before"

start "a failed clone leaves the existing checkout intact"
kit="$(fixture failed-clone "$OLD_TAG")"        # stale, so a re-clone is attempted
before="$(head_sha "$kit")"
run "$kit" "$PIN" "file://$WORK/no-such-remote"
status_is 1
stderr_has "ERROR: could not clone DragonKit $PIN from file://$WORK/no-such-remote"
stderr_has "checkout (if any) was left untouched and was NOT built against"
that "existing checkout still at $OLD_TAG" test "$(head_tags "$kit")" = "$OLD_TAG"
that "existing checkout unchanged" test "$(head_sha "$kit")" = "$before"
no_leftovers "$kit"

start "staging is unique: a re-clone cannot delete a directory it does not own"
kit="$(fixture unique-staging "$OLD_TAG")"
decoy="$(dirname "$kit")/dragon-kit.incoming"   # what a concurrent/interrupted run used to own
mkdir -p "$decoy"; echo "another run's clone" > "$decoy/sentinel"
run "$kit"
status_is 0
that "the fixed-path staging dir was not clobbered" test -f "$decoy/sentinel"
that "re-clone still landed on $PIN" test "$(head_tags "$kit")" = "$PIN"

# ---------------------------------------------------------------- summary

printf '\n----------------------------------------------------------------\n'
if [ "$FAILURES" -eq 0 ]; then
  printf 'PASS — %d cases, 0 failures\n' "$CASES"
  exit 0
fi
printf 'FAIL — %d cases, %d failed assertion(s)\n' "$CASES" "$FAILURES"
exit 1
