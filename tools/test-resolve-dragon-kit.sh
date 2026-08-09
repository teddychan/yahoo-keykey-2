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

# Resolved once, BEFORE any case puts a shim on PATH: the concurrency case below drives the
# resolver with a fake `git` in front, and that shim has to be able to reach the real one.
REAL_GIT="$(command -v git)"

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

# The owner's reproduction, as a fixture: a checkout that is detached, clean and sitting on a
# PUBLISHED stale tag — so the remote verification passes and the refresh goes ahead — which also
# holds a branch and a commit that exist in no remote and are reachable from nothing but that
# branch. Sets $kit and $hidden rather than echoing, because a command substitution would run it
# in a subshell and lose $hidden.
stale_with_local_work() {  # $1 = workspace name; sets $kit and $hidden
  kit="$(fixture "$1" "$OLD_TAG")"
  git -C "$kit" checkout -q -b hidden-work
  echo "work no remote has" >> "$kit/VERSION"
  git -C "$kit" commit -qam "unpushed local commit"
  hidden="$(git -C "$kit" rev-parse HEAD)"
  git -C "$kit" checkout -q --detach "refs/tags/$OLD_TAG"   # back to the published stale tag
}

# ---------------------------------------------------------------- harness

start() { CASES=$((CASES + 1)); printf '\n[%d] %s\n' "$CASES" "$1"; }
ok()    { printf '     ok   %s\n' "$1"; }
bad()   { printf '     FAIL %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

run() {  # $1 = kit dir, $2 = pin (default $PIN), $3 = clone url (default $REMOTE_URL)
  "$RESOLVER" "$1" "${2:-$PIN}" "${3:-$REMOTE_URL}" >"$OUT" 2>"$ERR"
  STATUS=$?
}

# As run(), with $1 prepended to PATH — for the case that needs a `git` shim in front of the real
# one. In a subshell so the shim cannot leak into any later case.
run_with_path() {  # $1 = dir to prepend to PATH, then as run()
  local shim_dir="$1"; shift
  ( PATH="$shim_dir:$PATH"; "$RESOLVER" "$1" "${2:-$PIN}" "${3:-$REMOTE_URL}" >"$OUT" 2>"$ERR" )
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

# `ls -di` rather than stat(1), whose flags differ between BSD and GNU. An inode is what a type
# check cannot tell you: the reproduction that opened round 5 reported before_type=Regular File and
# after_type=Directory, but a delete-then-recreate of the same TYPE would have read as untouched.
# shellcheck disable=SC2012  # find prints inodes only on GNU (-printf '%i'); these paths are our
# own mktemp fixtures, so ls's weakness with exotic filenames cannot bite here.
inode() { ls -di "$1" 2>/dev/null | awk '{print $1}'; }

# Lines of a shell script that RUN rm or mv, as opposed to naming one in a comment or printing one
# as advice in an operator-facing message ("... start clean: rm -rf vendor/dragon-kit"). The
# leading alternation is what makes it a command position and not the "rm" inside "perform"; the
# quote in it catches `trap 'rm -rf ...'`.
# shellcheck disable=SC2329  # invoked indirectly, as an argument to `that`
destructive_lines() {
  grep -nE "(^|[[:space:]]|[;&|(]|')(rm|mv)[[:space:]]" "$1" \
    | grep -vE '^[0-9]+:[[:space:]]*#' \
    | grep -vE '^[0-9]+:[[:space:]]*echo '
}

# Survival asserted by OBJECT ID, not by ref name: a branch or tag name can be recreated by a fresh
# clone or by hand, but only the original repository still holds the object underneath it. This is
# the assertion the owner's reproduction turned on, and the one a re-cloning resolver cannot pass.
# shellcheck disable=SC2329  # invoked indirectly, as an argument to `that`
holds_commit() { git -C "$1" rev-parse --verify -q "$2^{commit}" >/dev/null; }

# No staging directory may exist after a run, on any exit path. Round 2 cloned beside KIT_DIR and
# swapped, and this asserted the cleanup trap ran; the swap is gone (the clone lands directly in
# KIT_DIR now, so there is no delete to make safe), and this asserts the mechanism has not crept
# back — a stray dragon-kit.incoming in vendor/ means someone reintroduced a rename over a path
# this script does not own.
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
stdout_has "==> vendor/dragon-kit is at $OLD_TAG, not the pinned $PIN; fetching the pin into it"
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

start "a failed clone leaves no half-made checkout behind (the absent path)"
kit="$WORK/failed-clone/vendor/dragon-kit"      # absent, so a clone is attempted
# Against a remote that answers but has no $PIN. This is the ONLY path that still clones: a stale
# checkout is refreshed in place and never reaches the clone, so its own failure mode is a fetch
# that fails — covered among the update-in-place cases at the end.
run "$kit" "$PIN" "$NO_PIN_URL"
status_is 1
stderr_has "ERROR: could not clone DragonKit $PIN from $NO_PIN_URL"
stderr_has "checkout (if any) was left untouched and was NOT built against"
that "no checkout was left behind" test ! -e "$kit"
no_leftovers "$kit"

start "a fresh clone touches nothing beside its own destination"
kit="$WORK/unique-staging/vendor/dragon-kit"    # absent: the only state that clones at all
mkdir -p "$(dirname "$kit")"
# dragon-kit.incoming is the staging path round 2 used and round 5 retired. It stands in here for
# any neighbour in vendor/ that is not this run's business — the leftovers of an interrupted build,
# or a clone another process is writing into. Round 2 cleared this exact path by name.
decoy="$(dirname "$kit")/dragon-kit.incoming"
mkdir -p "$decoy"; echo "another run's clone" > "$decoy/sentinel"
run "$kit"
status_is 0
that "the neighbour was not clobbered" test -f "$decoy/sentinel"
that "the clone still landed on $PIN" test "$(head_tags "$kit")" = "$PIN"
that "and it landed at $kit itself, not staged and renamed in" test -d "$kit/.git"

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
: > "$kit/.git/keykey-same-repo-sentinel"       # survives only if this .git is never replaced
run "$kit"
status_is 0
stdout_has "==> vendor/dragon-kit is at $OLD_TAG, not the pinned $PIN; fetching the pin into it"
that "checkout is now at $PIN" test "$(head_tags "$kit")" = "$PIN"
that "the same repository was updated, not a new one" test -f "$kit/.git/keykey-same-repo-sentinel"
no_leftovers "$kit"

start "a published ANNOTATED stale tag is refreshed too (the naive ls-remote compare fails here)"
kit="$(fixture published-annotated "$ANNOT_TAG")"
: > "$kit/.git/keykey-same-repo-sentinel"
unpeeled="$(git ls-remote --tags "$REMOTE_URL" "refs/tags/$ANNOT_TAG" | awk '{print $1}')"
# Asserted as a PRECONDITION so this case cannot pass vacuously: if refs/tags/$ANNOT_TAG ever
# starts reporting the commit itself, the fixture has stopped reproducing the hazard and should
# say so rather than going quietly green.
that "precondition: refs/tags/$ANNOT_TAG reports a tag object, not the commit" test "$unpeeled" != "$(head_sha "$kit")"
run "$kit"
status_is 0
stdout_has "==> vendor/dragon-kit is at $ANNOT_TAG, not the pinned $PIN; fetching the pin into it"
that "checkout is now at $PIN" test "$(head_tags "$kit")" = "$PIN"
that "the same repository was updated, not a new one" test -f "$kit/.git/keykey-same-repo-sentinel"
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

# ------------------------------------------- a stale checkout is UPDATED IN PLACE, never replaced
#
# The bug these pin: the refresh above was `rm -rf` plus a fresh clone. Verifying HEAD against the
# remote made that safe for HEAD and for nothing else — a repository's other branches, tags,
# stashes and reflogs are not reachable from HEAD, so no verification could ever speak for them,
# and they went with the directory. Reproduced by the owner against 13f7150 on a checkout that was
# detached and clean at a published stale tag with an unpushed branch beside it: the resolver
# verified, re-cloned, exited 0, and the branch and its commit were gone.
#
# Every case here asserts the surviving OBJECT, not just the ref name.

start "an unpushed local BRANCH and its commit survive a successful refresh"
stale_with_local_work hidden-branch
that "fixture: detached and clean at the published $OLD_TAG" test "$(head_tags "$kit")" = "$OLD_TAG"
that "fixture: and holding a branch no remote has" test "$(git -C "$kit" rev-parse -q --verify refs/heads/hidden-work)" = "$hidden"
run "$kit"
status_is 0
stdout_has "==> vendor/dragon-kit is at $OLD_TAG, not the pinned $PIN; fetching the pin into it"
that "the refresh landed on $PIN" test "$(head_tags "$kit")" = "$PIN"
that "the branch ref survives" test "$(git -C "$kit" rev-parse -q --verify refs/heads/hidden-work)" = "$hidden"
that "and so does the commit object under it" holds_commit "$kit" "$hidden"
no_leftovers "$kit"

start "a local TAG elsewhere in the repository survives a successful refresh"
stale_with_local_work local-tag-elsewhere
git -C "$kit" tag scratch-2026-08 "$hidden"
git -C "$kit" branch -q -D hidden-work          # the tag is now the ONLY ref holding that commit
run "$kit"
status_is 0
that "the refresh landed on $PIN" test "$(head_tags "$kit")" = "$PIN"
that "the unrelated tag still points where it did" test "$(git -C "$kit" rev-parse -q --verify refs/tags/scratch-2026-08)" = "$hidden"
that "and so does the commit object under it" holds_commit "$kit" "$hidden"

start "the refreshed checkout ends DETACHED at the pin, with the pin's tag ref present locally"
kit="$(fixture ends-detached "$OLD_TAG")"
run "$kit"
status_is 0
that "HEAD is detached, not on a branch" test -z "$(git -C "$kit" symbolic-ref -q --short HEAD)"
that "HEAD is the pinned commit" test "$(head_sha "$kit")" = "$(git -C "$kit" rev-parse --verify "refs/tags/$PIN^{commit}")"
that "refs/tags/$PIN is a local ref, not a bare FETCH_HEAD" git -C "$kit" show-ref --verify --quiet "refs/tags/$PIN"
that "so --points-at HEAD names the pin" test "$(head_tags "$kit")" = "$PIN"
that "and the tree is clean" test -z "$(git -C "$kit" status --porcelain)"
# Not an inference — run the resolver again. A refresh that detached at an unnamed commit would
# leave the NEXT build stopping on "carries no tag"; the silent at-the-pin path is the proof.
run "$kit"
status_is 0
quiet

start "a FAILED fetch leaves HEAD and every local ref exactly as they were"
stale_with_local_work failed-fetch
git -C "$kit" tag scratch-2026-08 "$hidden"
before="$(head_sha "$kit")"
refs_before="$(git -C "$kit" show-ref | sort)"
# $NO_PIN_URL answers the verification lookup for $OLD_TAG but carries no $PIN, so the refresh gets
# past verification and then fails at the fetch itself — the half-moved case.
run "$kit" "$PIN" "$NO_PIN_URL"
status_is 1
stderr_has "ERROR: could not fetch DragonKit $PIN into $kit"
stderr_has "Nothing was deleted and HEAD did not move"
that "HEAD did not move" test "$(head_sha "$kit")" = "$before"
that "still at $OLD_TAG, which is a usable kit" test "$(head_tags "$kit")" = "$OLD_TAG"
that "every local ref is byte-for-byte unchanged" test "$(git -C "$kit" show-ref | sort)" = "$refs_before"
that "the hidden commit object survives" holds_commit "$kit" "$hidden"
no_leftovers "$kit"

start "a repository already holding a DIFFERENT $PIN tag is preserved, not clobbered"
stale_with_local_work moved-pin
git -C "$kit" tag "$PIN" "$hidden"              # the pin's NAME, re-pointed at local work
pin_before="$(git -C "$kit" rev-parse -q --verify "refs/tags/$PIN")"
before="$(head_sha "$kit")"
that "fixture: the local $PIN names the local commit, not the remote's" test "$pin_before" != "$(git ls-remote --tags "$REMOTE_URL" "refs/tags/$PIN" | awk '{print $1}')"
run "$kit"
status_is 1
stderr_has "ERROR: could not fetch DragonKit $PIN into $kit"
stderr_has "carries a DIFFERENT $PIN"
that "the local $PIN tag was not overwritten" test "$(git -C "$kit" rev-parse -q --verify "refs/tags/$PIN")" = "$pin_before"
that "HEAD did not move" test "$(head_sha "$kit")" = "$before"
that "the local commit object survives" holds_commit "$kit" "$hidden"
no_leftovers "$kit"

# --------------------------- an existing filesystem object is NEVER deleted or replaced
#
# The bug these pin: round 4 fixed the refresh path and left the create path destructive. It
# classified with `[ ! -d "$KIT_DIR" ]` — "not a DIRECTORY", which is true of a regular file and of
# a dangling symlink, not just of an absent path — and the branch that selected ended in
# `rm -rf "$KIT_DIR"; mv "$KIT_STAGING" "$KIT_DIR"`. The owner's reproduction against bd250ba, on a
# plain file at vendor/dragon-kit: status=0, before_type=Regular File, after_type=Directory.
#
# The rule now, stated as one sentence because every previous round was a special case of it: the
# resolver may UPDATE a verified repository in place, or CREATE a genuinely absent one, and must
# never delete or replace an existing filesystem object.
#
# Preservation is asserted by INODE or by contents wherever a type check would miss a
# delete-then-recreate — before_type/after_type is what caught this one, and it would not have
# caught a file replaced by a file.

start "a regular FILE at vendor/dragon-kit is preserved, and the build stops"
kit="$WORK/regular-file/vendor/dragon-kit"
mkdir -p "$(dirname "$kit")"
printf 'not a checkout\n' > "$kit"
before_ino="$(inode "$kit")"
that "fixture: a regular file, which \`[ ! -d ]\` reads as absent" test -f "$kit"
run "$kit"
status_is 1
stderr_has "is a regular file"
stderr_has "deletes or replaces what it finds at that path"
that "it is still a regular file, not a checkout" test -f "$kit"
that "the same file — not deleted and recreated" test "$(inode "$kit")" = "$before_ino"
that "with its contents intact" grep -q "not a checkout" "$kit"
no_leftovers "$kit"

start "a DANGLING symlink is preserved, and its target is not created"
kit="$WORK/dangling-symlink/vendor/dragon-kit"
mkdir -p "$(dirname "$kit")"
target="$WORK/dangling-symlink/moved-away"
ln -s "$target" "$kit"
that "fixture: a symlink is there" test -L "$kit"
that "fixture: and it resolves to nothing, so \`-e\` reads it as absent" test ! -e "$kit"
run "$kit"
status_is 1
stderr_has "which does not exist"
stderr_has "clone the pin: rm $kit"
that "the link survives" test -L "$kit"
that "still pointing where it did" test "$(readlink "$kit")" = "$target"
that "and nothing was created at its target" test ! -e "$target"
no_leftovers "$kit"

start "a stale checkout reached through a SYMLINK is neither fetched into nor checked out"
# The operator's own DragonKit clone, kept elsewhere and linked in — a repository this build does
# not own. It sits on the PUBLISHED $OLD_TAG, so the remote verification would pass and an
# unguarded resolver would refresh it: move its HEAD, and leave refs/tags/$PIN behind in it.
ext="$WORK/external-stale-kit"
git clone -q --depth 1 --branch "$OLD_TAG" "$REMOTE_URL" "$ext" 2>/dev/null
kit="$WORK/symlinked-stale/vendor/dragon-kit"
mkdir -p "$(dirname "$kit")"
ln -s "$ext" "$kit"
before="$(head_sha "$ext")"
refs_before="$(git -C "$ext" show-ref | sort)"
that "fixture: the link resolves to a checkout at the published $OLD_TAG" test "$(head_tags "$kit")" = "$OLD_TAG"
run "$kit"
status_is 1
stderr_has "is a symlink to $ext,"
stderr_has "in a repository this build does not"
stderr_has "remove the link and re-run to clone the pin here: rm $kit"
that "the target's HEAD did not move" test "$(head_sha "$ext")" = "$before"
that "every ref in the target is byte-for-byte unchanged" test "$(git -C "$ext" show-ref | sort)" = "$refs_before"
that "the pin was not fetched into it" test -z "$(git -C "$ext" tag -l "$PIN")"
that "no fetch was attempted at all" test ! -e "$ext/.git/FETCH_HEAD"
that "and the link itself survives" test -L "$kit"
no_leftovers "$kit"

start "a symlinked checkout that IS the pin is still used silently (the guard is narrow)"
ext="$WORK/external-kit-at-pin"
git clone -q --depth 1 --branch "$PIN" "$REMOTE_URL" "$ext" 2>/dev/null
kit="$WORK/symlinked-at-pin/vendor/dragon-kit"
mkdir -p "$(dirname "$kit")"
ln -s "$ext" "$kit"
before="$(head_sha "$ext")"
run "$kit"
status_is 0
quiet                                            # reading a linked-in checkout is fine; writing is not
that "the target is untouched" test "$(head_sha "$ext")" = "$before"

start "a symlinked co-development BRANCH still warns and builds (the guard is narrow)"
ext="$WORK/external-kit-branch"
git clone -q --depth 1 --branch "$PIN" "$REMOTE_URL" "$ext" 2>/dev/null
git -C "$ext" checkout -q -b kit-codev
echo "local kit work" >> "$ext/VERSION"; git -C "$ext" commit -qam "co-development commit"
kit="$WORK/symlinked-branch/vendor/dragon-kit"
mkdir -p "$(dirname "$kit")"
ln -s "$ext" "$kit"
before="$(head_sha "$ext")"
run "$kit"
status_is 0
stderr_has "WARNING: vendor/dragon-kit is on branch 'kit-codev', not a checkout of the pinned"
that "still on the branch" test "$(git -C "$ext" symbolic-ref --short HEAD)" = "kit-codev"
that "and the co-development commit is untouched" test "$(head_sha "$ext")" = "$before"

start "a target that APPEARS during the fresh-clone path is never deleted"
kit="$WORK/appearing-target/vendor/dragon-kit"
# The race the delete-then-swap lost, made deterministic: the classification sees an absent path,
# and something exists by the time the clone runs. A `git` shim on PATH creates it at exactly that
# moment — no sleeps, no background jobs — and the window it stands for is the real one. Round 4
# `rm -rf`'d whatever was there after a successful clone and reported success.
shim="$WORK/appearing-target-shim"
mkdir -p "$shim"
cat > "$shim/git" <<SHIM
#!/bin/bash
if [ "\$1" = clone ]; then printf 'another run got here first\n' > "$kit"; fi
exec "$REAL_GIT" "\$@"
SHIM
chmod +x "$shim/git"
run_with_path "$shim" "$kit"
status_is 1
stderr_has "ERROR: could not clone DragonKit $PIN from $REMOTE_URL"
stderr_has "was deleted or replaced"
that "what appeared is still there" test -f "$kit"
that "with its contents intact" grep -q "another run got here first" "$kit"
no_leftovers "$kit"

start "a failed clone leaves the surrounding workspace exactly as it was"
kit="$WORK/failed-clone-neighbours/vendor/dragon-kit"
mkdir -p "$(dirname "$kit")"
sibling="$(dirname "$kit")/sparkle"                  # vendor/ holds more than the kit
mkdir -p "$sibling"; echo "vendored" > "$sibling/marker"
decoy="$(dirname "$kit")/dragon-kit.incoming"        # an interrupted round-2 run's leftovers
mkdir -p "$decoy"; echo "another run's clone" > "$decoy/sentinel"
run "$kit" "$PIN" "$NO_PIN_URL"
status_is 1
that "no half-made checkout was left behind" test ! -e "$kit"
that "the vendored sibling survives" test -f "$sibling/marker"
that "and so does a leftover this run does not own" test -f "$decoy/sentinel"

start "the resolver contains no path that deletes or replaces vendor/dragon-kit"
# Structural, and deliberately not behavioural. The cases above can only cover states someone
# thought of, and each of the four rounds of this bug was a state nobody had: an unidentified
# checkout, a locally tagged commit, a repository with an unpushed branch beside HEAD, a plain
# file. `rm` and `mv` are the two primitives all four needed, so assert the script RUNS neither and
# the whole class is shut, including the next state nobody has thought of.
that "the resolver runs no rm and no mv" test -z "$(destructive_lines "$RESOLVER")"
# Not vacuous: the same grep, over a file that has the three shapes this script has actually worn.
probe="$WORK/destructive-probe.sh"
cat > "$probe" <<'PROBE'
  rm -rf "$KIT_DIR"
  mv "$KIT_STAGING" "$KIT_DIR"
  trap 'rm -rf "$KIT_STAGING"' EXIT
PROBE
that "precondition: the grep finds all three when they ARE there" test "$(destructive_lines "$probe" | wc -l | tr -d ' ')" = "3"
# And the resolver is not passing merely because the words are absent: it still PRINTS that remedy
# on every error path, which is the distinction the grep has to draw.
# shellcheck disable=SC2016  # a literal $KIT_DIR is the point — this greps the script's text
that "precondition: and it still prints \"rm -rf \$KIT_DIR\" as advice" grep -qF -- 'rm -rf $KIT_DIR' "$RESOLVER"

# ---------------------------------------------------------------- summary

printf '\n----------------------------------------------------------------\n'
if [ "$FAILURES" -eq 0 ]; then
  printf 'PASS — %d cases, 0 failures\n' "$CASES"
  exit 0
fi
printf 'FAIL — %d cases, %d failed assertion(s)\n' "$CASES" "$FAILURES"
exit 1
