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
#   on a branch            -> WARNING, build against it (kit co-development; never touched)
#   detached + dirty       -> ERROR, stop
#   detached, clean, @pin  -> silent, build (the common case)
#   detached, clean, @tag  -> re-clone at the pin, and say so
#   detached, clean, no tag-> ERROR, stop
#   not a git checkout     -> ERROR, stop
#   absent                 -> clone at the pin (the fresh-CI path)
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

  if [ -n "$KIT_BRANCH" ]; then
    # Checked FIRST, ahead of both the tag and the dirty test: a branch is the operator's own
    # work, so it is never replaced and never refused, and that has to hold whatever its HEAD
    # currently points at. A branch that happens to sit on the pinned commit is still a branch —
    # the next commit moves it — so it warns from the moment it exists rather than going quiet
    # until it diverges. Deliberately a warning and not an error: pointing vendor/ at a kit branch
    # is how the kit is co-developed. Say so loudly, because it links a different kit than the pin
    # claims and About's "Built with · DragonKit vX.Y.Z" row would then misreport it.
    echo "WARNING: vendor/dragon-kit is on branch '$KIT_BRANCH', not a checkout of the pinned" >&2
    echo "         $DRAGONKIT_TAG; building against it as-is (this is how the kit is co-developed)." >&2
    echo "         About's \"Built with · DragonKit vX.Y.Z\" row will report that branch's kit, not" >&2
    echo "         the pin. Remove vendor/dragon-kit to build against the pinned tag." >&2
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
  elif printf '%s\n' "$KIT_TAGS" | grep -qxF "$DRAGONKIT_TAG"; then
    : # At the pin, detached and clean — the common case. Use it, silently.
  elif [ -n "$KIT_TAGS" ]; then
    # A RECOGNISED older tag with a clean tree: an established workspace left on an older pin.
    # Nothing here is the operator's — the checkout is reproduced exactly by cloning that tag from
    # the remote — so bring it to the pin rather than failing the build. Only this case is
    # refreshed automatically.
    KIT_AT="$(printf '%s' "$KIT_TAGS" | tr '\n' ' ')"
    echo "==> vendor/dragon-kit is at ${KIT_AT% }, not the pinned $DRAGONKIT_TAG; re-cloning at the pin"
    KIT_NEEDS_CLONE=1
  else
    # Detached, clean, and on no tag at all. A clean tree does NOT prove the commit is published:
    # it is equally a local commit made on a detached HEAD, which nothing but this directory
    # holds, and re-cloning would silently destroy it. Deciding otherwise needs a round-trip to
    # the kit remote to ask whether the commit exists there, which is a network call this script
    # should not make just to classify a directory — so stop and let the operator say.
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
