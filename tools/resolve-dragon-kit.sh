#!/bin/bash
# Resolve vendor/dragon-kit to a DragonKit checkout the build is allowed to link.
#
# Usage: resolve-dragon-kit.sh <kit-dir> <tag> <clone-url>
#
# Split out of tools/build-app.sh so it can be exercised on its own: this is a handful of
# checkout states that only differ in git metadata, and driving them through a full swiftc
# build takes minutes each. tools/test-resolve-dragon-kit.sh runs every branch below against
# throwaway local repos in about a second. The pin itself stays in build-app.sh
# (DRAGONKIT_TAG="vX.Y.Z"), which is where the DragonKit propagation SOP and
# .github/workflows/tests.yml both look for it — do not move it here.
#
# The rule the states serve: an existing checkout is reused only once it has been IDENTIFIED,
# because App's About pane reports the pinned tag as "Built with · DragonKit vX.Y.Z" whatever
# the binary actually linked. Reusing an unidentified checkout is what stranded established
# workspaces on v3.0.1 after the 3.1.0 bump — that kit has no Attribution(name:license:), so
# App/AboutConfig.swift failed to compile until the operator guessed that vendor/dragon-kit
# had to be deleted by hand.
#
#   branch, clean, @pin    -> silent, build (it IS the pin; About reports it accurately)
#   on a branch, otherwise -> WARNING, build against it (kit co-development; never replaced)
#   detached + dirty       -> ERROR, stop
#   detached, clean, @pin  -> silent, build (the common case)
#   detached, clean, @tag  -> fetch the pin INTO this repository and detach at it, but ONLY once
#                             the remote confirms the tag, and ONLY when the path is a real
#                             directory. The repository is never replaced.
#   ...the same, via a SYMLINK -> ERROR, stop (that checkout belongs to someone else)
#   ...the same, in a WORKTREE -> ERROR, stop (so does that one, and its refs are shared)
#   detached, clean, no tag-> ERROR, stop
#   not a git checkout     -> ERROR, stop
#   a file, a socket, a dangling symlink -> ERROR, stop
#   genuinely absent       -> clone AT that path (the fresh-CI path)
#
# THE INVARIANT, and it is the whole point of this script:
#
#     it may UPDATE a verified repository in place, or CREATE a genuinely absent one.
#     It must never delete or replace an existing filesystem object.
#
# Every round of this bug has been a way to delete something. `rm -rf "$KIT_DIR"` on a stale
# checkout was the first: verifying HEAD against the remote proves that HEAD is reproducible and
# nothing more — it says nothing about the other branches, tags, stashes, reflog entries and
# unreachable objects in that repository, and no amount of verification can, because none of them
# are reachable from HEAD. An operator sitting on a published stale tag with an unpushed local
# branch beside it watched the resolver verify, re-clone and exit 0, having deleted the branch and
# its only commit.
#
# The SAME `rm -rf` then survived one round longer on the create path, because the classification
# above it asked `[ ! -d "$KIT_DIR" ]` — "not a DIRECTORY", which is also true of a regular file
# and of a dangling symlink. A plain file at vendor/dragon-kit was therefore classified as absent
# and deleted: before_type=Regular File, after_type=Directory, status 0. So the delete is not
# narrowed here, it is GONE — this script runs no `rm` and no `mv` at all, and
# tools/test-resolve-dragon-kit.sh asserts that structurally rather than trusting the next reader
# to notice.
#
# OFFLINE CONSEQUENCE, deliberate: refreshing a stale tagged checkout takes one round-trip to the
# kit remote, so with no network (or no credentials) that case STOPS the build instead of
# refreshing. A local `git tag` is not evidence of publication, and the only way to tell the two
# apart is to ask the remote; erring the other way moves HEAD off commits that exist nowhere else.
# The remedy is in the error text and is always the same: rm -rf vendor/dragon-kit rebuilds at the
# pin. Every other path stays offline, so ordinary builds are unaffected.
set -euo pipefail

KIT_DIR="$1"
DRAGONKIT_TAG="$2"
DRAGONKIT_URL="$3"

KIT_NEEDS_CLONE=""
KIT_NEEDS_REFRESH=""
if [ ! -e "$KIT_DIR" ] && [ ! -L "$KIT_DIR" ]; then
  # GENUINELY ABSENT — nothing there at all — and it takes BOTH tests to say so.
  #
  # `-e` alone is not enough: it follows the link, so a DANGLING symlink reads as absent, and the
  # clone would then quietly create the link's target somewhere else in the filesystem.
  # `-d` alone (what this asked until the create path was fixed) is worse still: "not a directory"
  # is true of a regular file, and the clone branch it selected ended in `rm -rf "$KIT_DIR"`.
  echo "==> Cloning DragonKit $DRAGONKIT_TAG into vendor/ (not committed)"
  KIT_NEEDS_CLONE=1
elif [ ! -e "$KIT_DIR" ]; then
  # -L true and -e false: a DANGLING SYMLINK. Almost always an operator's link to a DragonKit
  # checkout they have since moved or deleted, which makes it a statement of intent about where
  # the kit lives — the one thing that must not be answered by silently populating it.
  echo "ERROR: $KIT_DIR is a symlink to $(readlink "$KIT_DIR")," >&2
  echo "       which does not exist, so there is no DragonKit checkout there to identify. The link" >&2
  echo "       is left exactly as it is: this script never deletes or replaces what it finds at" >&2
  echo "       that path, and cloning into it would create the link's TARGET instead, somewhere" >&2
  echo "       else entirely. Point it at a DragonKit checkout, or remove the link and re-run to" >&2
  echo "       clone the pin: rm $KIT_DIR" >&2
  exit 1
elif [ ! -d "$KIT_DIR" ]; then
  # Something is there and it is not a directory: a regular file, a socket, a symlink to one.
  # Whatever it is, this script did not put it there and cannot prove what depends on it.
  if [ -L "$KIT_DIR" ]; then
    KIT_WHAT="a symlink to $(readlink "$KIT_DIR"), which is not a directory"
  elif [ -f "$KIT_DIR" ]; then
    KIT_WHAT="a regular file"
  else
    KIT_WHAT="not a directory"
  fi
  echo "ERROR: $KIT_DIR is $KIT_WHAT, so the DragonKit the build" >&2
  echo "       would link cannot be identified. It is left exactly as it is — this script never" >&2
  echo "       deletes or replaces what it finds at that path, and an earlier version of it that" >&2
  echo "       did read a plain file as \"absent\" and cleared it without a word. Move or remove it" >&2
  echo "       yourself, then re-run to clone $DRAGONKIT_TAG there." >&2
  exit 1
else
  # Test for .git rather than asking git: `git -C <dir>` walks UP to the first enclosing
  # repository, so on a vendor/dragon-kit that is a plain directory (an interrupted clone) every
  # query below would be answered by yahoo-keykey-2 itself — the branch check reported THIS repo's
  # branch and the build went ahead against a directory holding no kit at all, failing later and
  # further away with "Could not find Package.swift".
  if [ ! -e "$KIT_DIR/.git" ]; then
    echo "ERROR: $KIT_DIR exists but is not a git checkout, so the DragonKit it would build" >&2
    echo "       cannot be identified. Remove it and re-run: rm -rf $KIT_DIR" >&2
    exit 1
  fi
  # `git tag --points-at HEAD`, not `git describe --tags --exact-match`: dragon-kit carries TWO tag
  # series on the same commits — vX.Y.Z for the library and sample-vX.Y.Z for its sample app — and
  # `describe` prints exactly one name, so on a dual-tagged commit it can name the series we are
  # not pinning against. This is not hypothetical: 808d5a7 carries both v2.0.0 and sample-v1.2.0,
  # and `describe --tags --exact-match` there answers "sample-v1.2.0". Pinned at v2.0.0 the old
  # check would therefore have called a perfectly correct checkout stale on every single build.
  # v3.1.0 happens to be singly tagged, which is the only reason this never fired. --points-at
  # lists every tag on the commit; test for membership.
  KIT_TAGS="$(git -C "$KIT_DIR" tag --points-at HEAD 2>/dev/null || true)"
  KIT_BRANCH="$(git -C "$KIT_DIR" symbolic-ref -q --short HEAD 2>/dev/null || true)"
  KIT_DIRTY="$(git -C "$KIT_DIR" status --porcelain 2>/dev/null || true)"
  KIT_AT_PIN=""
  if printf '%s\n' "$KIT_TAGS" | grep -qxF "$DRAGONKIT_TAG"; then KIT_AT_PIN=1; fi

  if [ -n "$KIT_BRANCH" ]; then
    # Checked FIRST, ahead of both the dirty and the tag tests: a branch is the operator's own
    # work, so it is NEVER replaced and never refused, whatever its HEAD points at.
    #
    # What it does is warn — but not unconditionally. A CLEAN branch sitting exactly on the pinned
    # commit is silent: its content is the pin byte for byte, so the kit is fully identified and
    # About's "Built with · DragonKit vX.Y.Z" row is accurate. Warning there anyway (as this script
    # briefly did, on the argument that the next commit will move the branch) is a warning about
    # what the checkout might become, and one that fires on a correct workspace every build is one
    # operators learn to scroll past — including on the day it means something.
    #
    # The warning starts the moment the branch stops BEING the pin — uncommitted changes, or HEAD
    # somewhere else — because from then on the build links a kit the pin does not name while
    # About still reports the pin. Deliberately a warning and not an error: pointing vendor/ at a
    # kit branch is how the kit is co-developed.
    if [ -n "$KIT_AT_PIN" ] && [ -z "$KIT_DIRTY" ]; then
      : # A branch, but its HEAD is the pinned commit and the tree is clean. Use it, silently.
    else
      echo "WARNING: vendor/dragon-kit is on branch '$KIT_BRANCH', not a checkout of the pinned" >&2
      echo "         $DRAGONKIT_TAG; building against it as-is (this is how the kit is co-developed)." >&2
      echo "         About's \"Built with · DragonKit vX.Y.Z\" row will report that branch's kit, not" >&2
      echo "         the pin. Remove vendor/dragon-kit to build against the pinned tag." >&2
    fi
  elif [ -n "$KIT_DIRTY" ]; then
    # Dirtiness outranks the tag. The tag names a COMMIT, not the working tree on top of it, so a
    # modified or untracked file at the pin is a kit no version identifies while About still says
    # the pin — which is exactly the misreport the identify-before-you-trust rule exists to stop.
    # Re-cloning would throw the edits away and building would link something unidentifiable, so
    # do neither; the operator decides. (A branch never reaches here: see above.)
    echo "ERROR: vendor/dragon-kit is detached with uncommitted changes, so the DragonKit it" >&2
    echo "       would build cannot be identified. Refused even when HEAD carries $DRAGONKIT_TAG:" >&2
    echo "       the tag names the commit, not the edited tree, and About would still report" >&2
    echo "       $DRAGONKIT_TAG for a kit that is not it. Put the changes on a branch to" >&2
    echo "       co-develop the kit, or discard them: rm -rf $KIT_DIR" >&2
    exit 1
  elif [ -n "$KIT_AT_PIN" ]; then
    : # At the pin, detached and clean — the common case. Use it, silently.
  elif [ -n "$KIT_TAGS" ]; then
    # An older tag with a clean tree: an established workspace left on an older pin. This is the
    # ONLY state the script moves automatically — and moving it means detaching HEAD somewhere
    # else, so it is allowed only after the remote has confirmed the commit that is there now is
    # reproducible. (It no longer means deleting the repository; see the refresh block below.)
    #
    # A tag at HEAD is NOT that confirmation on its own. `git tag` writes a ref in this clone and
    # contacts nothing, so a tag is exactly as local as the commit under it: an operator who
    # committed on a detached HEAD and tagged it had that commit deleted outright by the re-clone
    # this branch used to end in, and would now have it stranded in the reflog with nothing but
    # HEAD ever having referenced it — the same data loss the untagged case further down exists to
    # prevent, one step further in. The NAME is no evidence either: `v9.9.9` is as easy to write
    # locally as `local-only`, so nothing here keys off a vX.Y.Z pattern. Only the remote can
    # answer, so ask it.
    #
    # One round-trip, and only on this branch: every other path stays offline and fast. (Round 2
    # declined to add a network call for the UNTAGGED case, where the answer is knowable locally
    # and the checkout is simply refused. Here the whole question IS whether a remote has this
    # commit, so the round-trip is the point rather than a shortcut.)
    #
    # Both refs/tags/X and refs/tags/X^{} are requested. For an ANNOTATED tag, ls-remote reports
    # refs/tags/X as the tag OBJECT's id and only refs/tags/X^{} as the commit it peels to, so
    # comparing HEAD against the unpeeled line alone would never match and every annotated release
    # would be refused as unpublished. Verified against git: for an annotated tag those two lines
    # carry different ids, and the peeled one is the commit.
    #
    # HEAD may carry SEVERAL tags — dragon-kit dual-tags vX.Y.Z and sample-vX.Y.Z onto one commit,
    # 808d5a7 being a live example — so any one of them resolving to this commit on the remote
    # settles it. Asking for all of them in a single ls-remote keeps it to one round-trip and makes
    # "could not reach the remote" a single unambiguous failure rather than a per-tag guess.
    KIT_HEAD="$(git -C "$KIT_DIR" rev-parse HEAD)"
    KIT_AT="$(printf '%s' "$KIT_TAGS" | tr '\n' ' ')"; KIT_AT="${KIT_AT% }"

    # NOT THROUGH A SYMLINK. This is the only state that WRITES to an existing checkout, and a
    # symlinked vendor/dragon-kit is a repository this build does not own — an operator's own kit
    # clone, linked in from wherever they keep it, quite possibly open in another window or shared
    # by a second app's workspace. Fetching into it and detaching its HEAD moves state in a
    # repository nobody asked this script to touch, and unlike the refresh of a checkout the script
    # created itself, there is nothing here that can put it back.
    #
    # Only THIS state is refused. The two symlinked states that merely READ stay exactly as they
    # were: a clean checkout at the pin is used silently, and a branch still warns and builds,
    # because a link to a co-development kit is precisely how the kit is co-developed.
    #
    # Checked before the ls-remote below, so a refusal costs no round-trip. (A symlink further UP
    # the path — a symlinked vendor/ holding a real dragon-kit directory — is not detected; `-L`
    # answers about the last component only. Resolving the whole path instead would misfire
    # constantly on macOS, where /tmp and /var are themselves symlinks.)
    if [ -L "$KIT_DIR" ]; then
      echo "ERROR: $KIT_DIR is a symlink to $(readlink "$KIT_DIR")," >&2
      echo "       and that checkout is at $KIT_AT, not the pinned $DRAGONKIT_TAG. Refreshing it" >&2
      echo "       means fetching into it and moving its HEAD — in a repository this build does not" >&2
      echo "       own, which you linked in from elsewhere and may have open right now — so it is" >&2
      echo "       left exactly as it is. Check that checkout out at $DRAGONKIT_TAG yourself, or" >&2
      echo "       remove the link and re-run to clone the pin here: rm $KIT_DIR" >&2
      exit 1
    fi

    # NOR A LINKED WORKTREE, refused for the same reason and caught by a different test, because a
    # symlink is not how this route arrives. `git worktree add` leaves a REAL DIRECTORY whose .git
    # is a FILE holding "gitdir: ...", so `-d` up at the top is true and the `-L` above is false,
    # and this branch walked straight into someone else's repository. Twice over: a worktree SHARES
    # refs/tags with the clone that owns it, so the fetch writes refs/tags/$DRAGONKIT_TAG into that
    # clone, and the checkout then moves the worktree's HEAD. Reproduced against the round-5 script
    # — the owning clone's tags read [v3.0.1] before the run and [v3.0.1 v3.1.0] after, the worktree
    # left detached at v3.1.0, status 0. The layout is not contrived: ice-2 and yahoo-keykey-2 both
    # keep linked worktrees inside their own repo roots.
    #
    # `-f` on .git also catches a git SUBMODULE, which wears the same .git file. That is correct
    # rather than incidental — it points into the superproject's modules store, so the write lands
    # in a repository this build does not own just the same.
    #
    # Narrow like the symlink guard above, and checked here for the same two reasons: only the state
    # that WRITES is refused, and refusing before the ls-remote costs no round-trip. A worktree that
    # already IS the pin is used silently and one on a branch still warns and builds, because
    # holding the kit in a worktree is an ordinary way to co-develop it.
    if [ -f "$KIT_DIR/.git" ]; then
      KIT_OWNER="$(git -C "$KIT_DIR" rev-parse --git-common-dir)"
      echo "ERROR: $KIT_DIR is a linked git worktree of $KIT_OWNER," >&2
      echo "       and it is at $KIT_AT, not the pinned $DRAGONKIT_TAG. Refreshing it means fetching" >&2
      echo "       into it and moving its HEAD, in a repository this build does not own — and a" >&2
      echo "       worktree shares its refs with the clone that owns it, so $DRAGONKIT_TAG would be" >&2
      echo "       written into that clone as well. It is left exactly as it is. Check the worktree" >&2
      echo "       out at $DRAGONKIT_TAG yourself, or remove it and re-run to clone the pin here:" >&2
      echo "       git -C $KIT_OWNER worktree remove $KIT_DIR" >&2
      exit 1
    fi

    KIT_TAG_REFS=()
    while IFS= read -r kit_tag; do
      [ -n "$kit_tag" ] || continue
      KIT_TAG_REFS+=("refs/tags/$kit_tag" "refs/tags/$kit_tag^{}")
    done <<<"$KIT_TAGS"

    # git's own diagnosis goes to stderr ahead of ours on purpose — "Could not read from remote
    # repository" and "Repository not found" send the operator to different remedies.
    if ! KIT_REMOTE_REFS="$(git ls-remote --tags "$DRAGONKIT_URL" "${KIT_TAG_REFS[@]}")"; then
      echo "ERROR: vendor/dragon-kit is at $KIT_AT, not the pinned $DRAGONKIT_TAG, and $KIT_AT could" >&2
      echo "       not be looked up on $DRAGONKIT_URL (offline, DNS, or credentials — git's own" >&2
      echo "       error is above). Refreshing this checkout means moving HEAD off $KIT_AT, and a" >&2
      echo "       tag is not proof of publication until the remote says so, so HEAD stays put." >&2
      echo "       With no network a stale checkout stops the build rather than refreshing; that" >&2
      echo "       is the safe direction, because guessing the other way strands commits no" >&2
      echo "       remote has. Reconnect and re-run, or discard the checkout to rebuild at the" >&2
      echo "       pin: rm -rf $KIT_DIR" >&2
      exit 1
    fi
    # Only refs for tags AT HEAD were requested, so any line whose object id is HEAD is one of
    # them resolving to this very commit — which is precisely the proof required, and it reads the
    # same for a lightweight tag (id on refs/tags/X) and an annotated one (id on refs/tags/X^{}).
    if printf '%s\n' "$KIT_REMOTE_REFS" | awk -v sha="$KIT_HEAD" '$1 == sha { found = 1 } END { exit !found }'; then
      echo "==> vendor/dragon-kit is at $KIT_AT, not the pinned $DRAGONKIT_TAG; fetching the pin into it"
      KIT_NEEDS_REFRESH=1
    else
      echo "ERROR: vendor/dragon-kit is at $KIT_AT, not the pinned $DRAGONKIT_TAG, but no tag on its" >&2
      echo "       HEAD resolves to commit $(git -C "$KIT_DIR" rev-parse --short HEAD) on $DRAGONKIT_URL." >&2
      echo "       Either the tag was never pushed, or it has been moved or recreated since — a" >&2
      echo "       local \`git tag\` contacts no remote, so a tag at HEAD proves no more about this" >&2
      echo "       commit than a clean tree does, and detaching elsewhere would leave the only copy" >&2
      echo "       of it referenced by nothing but this checkout's reflog." >&2
      echo "       Push the tag if it is meant to be published, put the commit on a branch to" >&2
      echo "       co-develop the kit, or discard the checkout to rebuild at the pin:" >&2
      echo "       rm -rf $KIT_DIR" >&2
      exit 1
    fi
  else
    # Detached, clean, and on no tag at all. A clean tree does NOT prove the commit is published:
    # it is equally a local commit made on a detached HEAD, which nothing but this directory
    # holds, and re-cloning would silently destroy it. The round-trip that rescues the tagged case
    # above cannot help here — ls-remote answers about ref NAMES and this HEAD has none, so the
    # only remaining question would be whether the bare commit id is fetchable, which is neither
    # cheap nor permitted on every remote. Stop and let the operator say.
    echo "ERROR: vendor/dragon-kit is detached at commit $(git -C "$KIT_DIR" rev-parse --short HEAD) and carries no tag," >&2
    echo "       so the DragonKit it would build cannot be identified. A clean tree does not make" >&2
    echo "       that commit disposable — it may be local work no remote has — so it is neither" >&2
    echo "       built against nor re-cloned over. Put it on a branch to co-develop the kit, or" >&2
    echo "       remove the checkout to rebuild at the pin: rm -rf $KIT_DIR" >&2
    exit 1
  fi
fi

if [ -n "$KIT_NEEDS_REFRESH" ]; then
  # UPDATE THE EXISTING REPOSITORY. Nothing here deletes, replaces or moves the directory: the
  # pinned tag is fetched into the repository that is already there and HEAD is detached at it, so
  # every unrelated branch, tag, stash, reflog entry and unreachable object in it survives. The
  # `rm -rf` this block replaced could not preserve any of them, and the remote verification above
  # could not compensate — it only ever spoke for HEAD.
  #
  # Three details, each of which would itself lose local state if done casually:
  #
  # NO --force ON THE TAG REFSPEC. `refs/tags/X:refs/tags/X` without it fails outright ("would
  # clobber existing tag") when this repository already holds a DIFFERENT $DRAGONKIT_TAG — a pin
  # moved or recreated locally. That failure is the correct outcome and is why it is not forced:
  # overwriting that ref is precisely the destruction of local work this round exists to stop.
  #
  # NO --depth. The absent-checkout path clones --depth 1, so this fetch may have to deepen a
  # shallow repository, which is additive. Passing --depth against a checkout that is a FULL clone
  # would truncate its history instead — local-state loss by another name.
  #
  # THE TAG REF, NOT JUST THE COMMIT, MUST LAND. This script identifies a checkout with
  # `git tag --points-at HEAD`, so detaching at a bare FETCH_HEAD would leave the very next build
  # looking at an untagged detached HEAD and stopping. Hence a named refspec, and a check that the
  # name resolves locally afterwards.
  #
  # git's own diagnosis goes to stderr ahead of ours, as with ls-remote above: "would clobber
  # existing tag" and "couldn't find remote ref" send the operator to different remedies.
  if ! git -C "$KIT_DIR" fetch "$DRAGONKIT_URL" "refs/tags/$DRAGONKIT_TAG:refs/tags/$DRAGONKIT_TAG"; then
    echo "ERROR: could not fetch DragonKit $DRAGONKIT_TAG into $KIT_DIR (git's own error is" >&2
    echo "       above). Nothing was deleted and HEAD did not move: the checkout is still at" >&2
    echo "       $KIT_AT and still holds every branch, tag and commit it held before." >&2
    echo "       If the fetch was refused as \"would clobber existing tag\", this repository already" >&2
    echo "       carries a DIFFERENT $DRAGONKIT_TAG — a pin moved or recreated locally — and it is" >&2
    echo "       kept rather than overwritten. Settle that tag, reconnect if this was the network," >&2
    echo "       or discard the checkout to rebuild at the pin: rm -rf $KIT_DIR" >&2
    exit 1
  fi
  if ! git -C "$KIT_DIR" rev-parse --verify -q "refs/tags/$DRAGONKIT_TAG^{commit}" >/dev/null; then
    echo "ERROR: fetched DragonKit $DRAGONKIT_TAG into $KIT_DIR, but refs/tags/$DRAGONKIT_TAG does" >&2
    echo "       not resolve to a commit there, so HEAD was left where it is rather than detached" >&2
    echo "       at something this script could not identify on the next run. The checkout is" >&2
    echo "       unchanged, still at $KIT_AT. Start clean: rm -rf $KIT_DIR" >&2
    exit 1
  fi
  # -q: the resolver already said what it is doing, and git's "HEAD is now at" repeats it. The
  # tree is known clean here (dirty detached stopped further up), so this cannot discard edits.
  if ! git -C "$KIT_DIR" checkout -q --detach "refs/tags/$DRAGONKIT_TAG"; then
    echo "ERROR: fetched DragonKit $DRAGONKIT_TAG into $KIT_DIR but could not check it out (git's" >&2
    echo "       own error is above). The checkout was NOT half-moved: HEAD is still at $KIT_AT," >&2
    echo "       which is a usable kit, and the fetched objects are simply extra. Re-run once the" >&2
    echo "       cause is fixed, or start clean: rm -rf $KIT_DIR" >&2
    exit 1
  fi
fi

if [ -n "$KIT_NEEDS_CLONE" ]; then
  # Reached ONLY when nothing whatsoever was at that path — no directory, no file, not even a
  # dangling symlink — which is the one state with nothing to lose, and so the only one this script
  # is willing to create anything for. A stale checkout is refreshed in place above and never
  # arrives here.
  #
  # CLONED STRAIGHT INTO $KIT_DIR, not staged beside it and swapped in. The staging dance existed
  # only to make `rm -rf "$KIT_DIR"; mv ...` survivable, and both of those are gone, so there is
  # nothing left for it to make safe — it would now be a rename over a path this run has stopped
  # claiming to own.
  #
  # Cloning direct also hands the last word to git, which is the point: git refuses a destination
  # that already exists and is not an empty directory, and deletes nothing when it does. So if
  # anything appears here between the classification above and this line — a concurrent build, an
  # operator dropping a file in — the clone FAILS and that thing survives, where the delete-then-
  # swap would have destroyed it and reported success. Verified against git: with a regular file at
  # the destination the clone exits 128 and the file keeps its inode and its contents.
  #
  # No cleanup trap, and none needed: git removes what IT created if the clone fails (verified —
  # a --branch that does not exist leaves no destination behind), and what git did not create is
  # exactly what this script must not remove.
  mkdir -p "$(dirname "$KIT_DIR")"
  if ! git clone --depth 1 --branch "$DRAGONKIT_TAG" "$DRAGONKIT_URL" "$KIT_DIR"; then
    echo "ERROR: could not clone DragonKit $DRAGONKIT_TAG from $DRAGONKIT_URL. The existing" >&2
    echo "       checkout (if any) was left untouched and was NOT built against, and nothing at" >&2
    echo "       $KIT_DIR was deleted or replaced: that path is only ever cloned into when it is" >&2
    echo "       empty, and git refuses a destination something else has taken rather than clearing" >&2
    echo "       it. So if git's error above names an existing destination, look at what is there —" >&2
    echo "       that is another process or a stray file, not a network fault. Otherwise fix the" >&2
    echo "       network or credentials and re-run." >&2
    exit 1
  fi
fi
