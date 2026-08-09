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
#   detached, clean, @tag  -> re-clone at the pin, but ONLY once the remote confirms the tag
#   detached, clean, no tag-> ERROR, stop
#   not a git checkout     -> ERROR, stop
#   absent                 -> clone at the pin (the fresh-CI path)
#
# OFFLINE CONSEQUENCE, deliberate: refreshing a stale tagged checkout takes one round-trip to the
# kit remote, so with no network (or no credentials) that case now STOPS the build instead of
# re-cloning. A local `git tag` is not evidence of publication, and the only way to tell the two
# apart is to ask the remote; erring the other way deletes commits that exist nowhere else. The
# remedy is in the error text and is always the same: rm -rf vendor/dragon-kit rebuilds at the pin.
# Every other path stays offline, so ordinary builds are unaffected.
set -euo pipefail

KIT_DIR="$1"
DRAGONKIT_TAG="$2"
DRAGONKIT_URL="$3"

KIT_NEEDS_CLONE=""
if [ ! -d "$KIT_DIR" ]; then
  echo "==> Cloning DragonKit $DRAGONKIT_TAG into vendor/ (not committed)"
  KIT_NEEDS_CLONE=1
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
    # ONLY state replaced automatically — and replacing means `rm -rf`, so it is allowed only
    # after the remote has confirmed the checkout is reproducible.
    #
    # A tag at HEAD is NOT that confirmation on its own. `git tag` writes a ref in this clone and
    # contacts nothing, so a tag is exactly as local as the commit under it: an operator who
    # committed on a detached HEAD and tagged it had that commit deleted by the re-clone below —
    # the same data loss the untagged case further down exists to prevent, one step further in.
    # The NAME is no evidence either: `v9.9.9` is as easy to write locally as `local-only`, so
    # nothing here keys off a vX.Y.Z pattern. Only the remote can answer, so ask it.
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
      echo "       error is above). Refreshing this checkout means DELETING it, and a tag is not" >&2
      echo "       proof of publication until the remote says so, so it is preserved instead." >&2
      echo "       With no network a stale checkout stops the build rather than refreshing; that" >&2
      echo "       is the safe direction, because guessing the other way destroys commits no" >&2
      echo "       remote has. Reconnect and re-run, or discard the checkout to rebuild at the" >&2
      echo "       pin: rm -rf $KIT_DIR" >&2
      exit 1
    fi
    # Only refs for tags AT HEAD were requested, so any line whose object id is HEAD is one of
    # them resolving to this very commit — which is precisely the proof required, and it reads the
    # same for a lightweight tag (id on refs/tags/X) and an annotated one (id on refs/tags/X^{}).
    if printf '%s\n' "$KIT_REMOTE_REFS" | awk -v sha="$KIT_HEAD" '$1 == sha { found = 1 } END { exit !found }'; then
      echo "==> vendor/dragon-kit is at $KIT_AT, not the pinned $DRAGONKIT_TAG; re-cloning at the pin"
      KIT_NEEDS_CLONE=1
    else
      echo "ERROR: vendor/dragon-kit is at $KIT_AT, not the pinned $DRAGONKIT_TAG, but no tag on its" >&2
      echo "       HEAD resolves to commit $(git -C "$KIT_DIR" rev-parse --short HEAD) on $DRAGONKIT_URL." >&2
      echo "       Either the tag was never pushed, or it has been moved or recreated since — a" >&2
      echo "       local \`git tag\` contacts no remote, so a tag at HEAD proves no more about this" >&2
      echo "       commit than a clean tree does, and re-cloning could destroy the only copy of it." >&2
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

if [ -n "$KIT_NEEDS_CLONE" ]; then
  # Clone alongside, swap only on success: `rm -rf` first would leave a workspace with no kit at
  # all when the clone then fails. Re-cloning rather than `git checkout "$DRAGONKIT_TAG"` because
  # this is a --depth 1 --branch <tag> clone, which holds no object for any other tag.
  #
  # A UNIQUE staging dir, not a fixed "dragon-kit.incoming": that fixed path is one this run does
  # not own. A second build running concurrently, or the leftovers of an interrupted one, share
  # it — and the `rm -rf` that cleared it would delete a clone another process was writing into,
  # or hand this run a half-written tree as if it were a finished clone. mktemp keeps it beside
  # KIT_DIR so the swap stays a same-filesystem rename; the trap removes it on any exit path.
  mkdir -p "$(dirname "$KIT_DIR")"
  KIT_STAGING="$(mktemp -d "$KIT_DIR.incoming.XXXXXX")"
  trap 'rm -rf "$KIT_STAGING"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  if ! git clone --depth 1 --branch "$DRAGONKIT_TAG" "$DRAGONKIT_URL" "$KIT_STAGING"; then
    echo "ERROR: could not clone DragonKit $DRAGONKIT_TAG from $DRAGONKIT_URL. The existing" >&2
    echo "       checkout (if any) was left untouched and was NOT built against. Fix the network" >&2
    echo "       or credentials and re-run, or start clean: rm -rf $KIT_DIR" >&2
    exit 1
  fi
  rm -rf "$KIT_DIR"
  mv "$KIT_STAGING" "$KIT_DIR"
  trap - EXIT INT TERM
fi
