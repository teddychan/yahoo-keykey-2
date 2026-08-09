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
OLD_TAG="v3.0.1"      # an older release (LIGHTWEIGHT), for the stale-workspace cases
ANNOT_TAG="v3.0.2"    # an older release published as an ANNOTATED tag

CASES=0 FAILURES=0

# ---------------------------------------------------------------- fixtures

# A stand-in for the dragon-kit remote, carrying the same shape of tag history: a vX.Y.Z library
# series, plus a sample-vX.Y.Z series that lands on some of the SAME commits. sample-v1.4.0 is
# annotated and v3.2.0 lightweight so `git describe --exact-match` reliably prefers the sample
# tag — that is the real hazard reproduced deterministically (dragon-kit's own 808d5a7 carries
# v2.0.0 and sample-v1.2.0, and describe there answers sample-v1.2.0).
#
# BOTH tag object kinds are published here. A stale checkout is now verified against the remote
# before it may be replaced, and `git ls-remote refs/tags/X` answers with the TAG OBJECT's id for
# an annotated tag and the COMMIT's id for a lightweight one — so a check that compares only the
# unpeeled line works on v3.0.1 and silently refuses every annotated release. v3.0.2 is annotated
# for exactly that reason.
build_remote() {
  local r="$WORK/kit-remote"
  git init -q -b main "$r"
  printf 'kit %s\n' "$OLD_TAG" > "$r/VERSION"; git -C "$r" add VERSION
  git -C "$r" commit -qm "kit $OLD_TAG"; git -C "$r" tag "$OLD_TAG"
  printf 'kit %s\n' "$ANNOT_TAG" > "$r/VERSION"
  git -C "$r" commit -qam "kit $ANNOT_TAG"; git -C "$r" tag -a "$ANNOT_TAG" -m "kit $ANNOT_TAG"
  printf 'kit %s\n' "$PIN" > "$r/VERSION"
  git -C "$r" commit -qam "kit $PIN"; git -C "$r" tag "$PIN"
  printf 'kit %s\n' "$DUAL_PIN" > "$r/VERSION"
  git -C "$r" commit -qam "kit $DUAL_PIN"
  git -C "$r" tag "$DUAL_PIN"
  git -C "$r" tag -a sample-v1.4.0 -m "sample app 1.4.0"
  # file:// so --depth 1 produces a real shallow clone instead of git's "local clone" shortcut.
  REMOTE_URL="file://$r"

  # A second remote that ANSWERS a lookup but carries no $PIN — what a never-pushed or mistyped
  # pin looks like. Needed because a stale checkout is verified against the remote BEFORE anything
  # is deleted, so reaching the clone at all now requires the lookup to have succeeded first.
  local np="$WORK/kit-remote-no-pin.git"
  git clone -q --bare "$r" "$np"
  git -C "$np" tag -d "$PIN" >/dev/null
  NO_PIN_URL="file://$np"
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
# Against a remote that answers but has no $PIN: the stale tag verifies, and the clone that
# follows then fails for real. An unreachable URL would now stop at the verification step and
# never reach the clone at all — case 18 covers that path.
run "$kit" "$PIN" "$NO_PIN_URL"
status_is 1
stderr_has "ERROR: could not clone DragonKit $PIN from $NO_PIN_URL"
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

# ------------------------------------------------- a branch that IS the pin says nothing

start "a clean branch sitting exactly on the pinned commit is silent"
kit="$(fixture branch-at-pin "$PIN")"
git -C "$kit" checkout -q -b kit-codev          # a branch, but HEAD is the pinned commit, clean
before="$(head_sha "$kit")"
that "precondition: on a branch, clean, and at the pin" test "$(git -C "$kit" symbolic-ref --short HEAD)" = "kit-codev"
run "$kit"
status_is 0
quiet                                            # its content IS the pin, so About is accurate
that "still on the branch" test "$(git -C "$kit" symbolic-ref --short HEAD)" = "kit-codev"
that "checkout untouched — a branch is never replaced" test "$(head_sha "$kit")" = "$before"

# --------------------------------------- remote verification before a stale tag is replaced
#
# The bug these pin: a tag at HEAD was taken as proof the commit was published and reproducible,
# so a clean detached commit tagged locally — `git tag local-only`, never pushed — was re-cloned
# over and DESTROYED. `git tag` contacts no remote, so a tag says nothing a clean tree had not
# already said. A stale tagged checkout may now be replaced only once the remote confirms that a
# tag at HEAD resolves to that exact commit.
#
# The preserving cases all assert that the original commit still resolves afterwards. That is the
# assertion that actually catches this class: the reproduction turned on the commit surviving, not
# on the exit status. Grouped at the end so the numbering of the earlier cases stays put.

start "a published LIGHTWEIGHT stale tag verifies against the remote and is refreshed"
kit="$(fixture published-lightweight "$OLD_TAG")"
run "$kit"
status_is 0
stdout_has "==> vendor/dragon-kit is at $OLD_TAG, not the pinned $PIN; re-cloning at the pin"
that "checkout is now at $PIN" test "$(head_tags "$kit")" = "$PIN"
no_leftovers "$kit"

start "a published ANNOTATED stale tag is refreshed too (the naive ls-remote compare fails here)"
kit="$(fixture published-annotated "$ANNOT_TAG")"
unpeeled="$(git ls-remote --tags "$REMOTE_URL" "refs/tags/$ANNOT_TAG" | awk '{print $1}')"
# Asserted as a PRECONDITION so this case cannot pass vacuously: if refs/tags/$ANNOT_TAG ever
# starts reporting the commit itself, the fixture has stopped reproducing the hazard and should
# say so rather than going quietly green.
that "precondition: refs/tags/$ANNOT_TAG reports a tag object, not the commit" test "$unpeeled" != "$(head_sha "$kit")"
run "$kit"
status_is 0
stdout_has "==> vendor/dragon-kit is at $ANNOT_TAG, not the pinned $PIN; re-cloning at the pin"
that "checkout is now at $PIN" test "$(head_tags "$kit")" = "$PIN"
no_leftovers "$kit"

start "a LOCAL-ONLY tag stops the build, and the commit under it survives"
kit="$(fixture local-only-tag "$PIN")"
echo "unpushed local kit commit" >> "$kit/VERSION"
git -C "$kit" commit -qam "local commit on a detached HEAD"
git -C "$kit" tag v9.9.9        # release-SHAPED on purpose: a name is not evidence of publication
before="$(head_sha "$kit")"; short="$(git -C "$kit" rev-parse --short HEAD)"
that "fixture: HEAD carries a tag the remote has never heard of" test "$(head_tags "$kit")" = "v9.9.9"
that "fixture: and the tree is clean" test -z "$(git -C "$kit" status --porcelain)"
run "$kit"
status_is 1
stderr_has "ERROR: vendor/dragon-kit is at v9.9.9, not the pinned $PIN, but no tag on its"
stderr_has "HEAD resolves to commit $short on $REMOTE_URL"
stderr_has "Either the tag was never pushed, or it has been moved or recreated since"
that "the local commit survives" test "$(head_sha "$kit")" = "$before"
that "and its object is still readable" git -C "$kit" cat-file -e "$before^{commit}"
no_leftovers "$kit"

start "a locally MOVED tag whose remote commit differs stops the build and preserves it"
kit="$(fixture moved-tag "$OLD_TAG")"
echo "local kit work" >> "$kit/VERSION"
git -C "$kit" commit -qam "local commit"
git -C "$kit" tag -f "$OLD_TAG" >/dev/null 2>&1   # a real release NAME, re-pointed at local work
before="$(head_sha "$kit")"
remote_sha="$(git ls-remote --tags "$REMOTE_URL" "refs/tags/$OLD_TAG" | awk '{print $1}')"
that "fixture: the remote's $OLD_TAG is a different commit" test "$remote_sha" != "$before"
run "$kit"
status_is 1
stderr_has "ERROR: vendor/dragon-kit is at $OLD_TAG, not the pinned $PIN, but no tag on its"
that "the local commit survives" test "$(head_sha "$kit")" = "$before"
that "and its object is still readable" git -C "$kit" cat-file -e "$before^{commit}"
no_leftovers "$kit"

start "an unreachable remote stops the build and preserves the checkout (the offline cost)"
kit="$(fixture offline "$OLD_TAG")"
before="$(head_sha "$kit")"
run "$kit" "$PIN" "file://$WORK/no-such-remote"
status_is 1
stderr_has "ERROR: vendor/dragon-kit is at $OLD_TAG, not the pinned $PIN, and $OLD_TAG could"
stderr_has "With no network a stale checkout stops the build rather than refreshing"
stderr_has "pin: rm -rf $kit"
that "existing checkout still at $OLD_TAG" test "$(head_tags "$kit")" = "$OLD_TAG"
that "the commit survives" test "$(head_sha "$kit")" = "$before"
no_leftovers "$kit"

# ---------------------------------------------------------------- summary

printf '\n----------------------------------------------------------------\n'
if [ "$FAILURES" -eq 0 ]; then
  printf 'PASS — %d cases, 0 failures\n' "$CASES"
  exit 0
fi
printf 'FAIL — %d cases, %d failed assertion(s)\n' "$CASES" "$FAILURES"
exit 1
