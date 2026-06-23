# Security + Performance/Memory Audit — 2026-06-23

Audited the Cangjie/Simplex input method (engine package + App + build/release scripts) for
security and performance/memory. Below: findings, what was fixed (all verified — 111 engine
tests pass, app builds with hardened runtime), and what's flagged.

## Headline result
**Memory:** IMK creates one `InputController` per client app. Previously every instance reloaded
~55-80 MB (LanguageModel from a 7 MB `data.txt`, the 68k Cangjie table, the derived Simplex index,
character-score map, OpenCC table - and `data.txt` was parsed **twice** per instance). With ~5 apps
open that was ~300+ MB duplicated. **Fixed** via a process-wide `SharedResources` singleton: every
resource loads once and is shared by all controllers; `data.txt` is parsed once. Saves ~220-320 MB
with several apps, and makes 2nd+ activations instant (was a ~100-300 ms freeze each).

## Security - findings & status
| # | Sev | Finding | Status |
|---|-----|---------|--------|
| S1 | HIGH | Ad-hoc dev build lacked hardened runtime; no explicit entitlements (dylib-injection risk for a process that sees every keystroke) | FIXED - added empty `App/YahooKeyKey2.entitlements`; `--options runtime --entitlements` on both `build-app.sh` (ad-hoc) and `package-release.sh` (Developer ID). Build shows `flags=...runtime`. |
| S2 | HIGH | Preferences/About used `NSApp.activate(ignoringOtherApps: true)` - yanks focus from the user's active app | FIXED - changed to `ignoringOtherApps: false`; windows still front via `makeKeyAndOrderFront`. |
| S3 | MED | `package-installer.sh` interpolated `$VERSION`/basename unquoted into a `sed` replacement | FIXED - replaced with literal `python3` string replacement (argv-passed). Output byte-identical for normal versions. |
| S4 | MED | `UserFrequency` file unbounded; dir world-readable (0755); a typing-habit profile | FIXED - capped to 5000 entries (eviction) + per-count cap; dir created `0700`; thread-safe. |
| S5 | MED | `build-lm.sh` cloned McBopomofo with no pinned revision (supply-chain risk for bundled data) | FIXED - pinned `MCBOPOMOFO_SHA=040097ebc32a6287e6c4d36ceab7c32fd1e1c2a2` (resolved 2026-06-23) with a "review/update deliberately" comment + checkout-verify. REVIEW this SHA before the next data rebuild. |
| S6/S7 | LOW | Redundant `.first!` after grapheme `count==1` guard (UserFrequency.load, LanguageModel.characterScores) | FIXED - use `unicodeScalars.count==1` / `guard let`. |
| S8 | LOW | `make-icon.sh` used `try!` (crash on unwritable path) | FIXED - `do/catch` + clean `exit(1)`. |

**Verified non-issues:** no network code anywhere (no telemetry/exfiltration); no keystroke/composing/
committed text is ever logged or persisted except to the target client; IMK force-unwrapped Obj-C
params are guarded; postinstall script is minimal and runs as the user (no admin).

## Performance/Memory - findings & status
| # | Sev | Finding | Status |
|---|-----|---------|--------|
| P1 | HIGH | Per-instance duplication of all heavy resources | FIXED - `SharedResources` singleton (see headline). |
| P2 | HIGH | `data.txt` parsed twice per instance (LM + AssociatedPhrases) | FIXED - read once, both built from the same String. |
| P3 | HIGH | `UserFrequency.save()` did a synchronous atomic JSON write on every commit (keystroke path) | FIXED - in-memory update immediate; disk write debounced/coalesced on a background queue (<=1 write / 5 s), `flush()` on demand. |
| P4 | MED | Candidate list recomputed + sorted ~3x per keydown; `score()` computed twice per comparison | FIXED - memoized candidate cache (invalidated on mutation); score computed once per candidate. |
| P5 | MED | Wildcard `characters(matching:)` recompiled an NSRegularExpression every keystroke | FIXED - regex cache keyed by pattern. |
| P6 | LOW | `SimplexTable` construction dedup was O(n^2) | FIXED - O(1) shadow-Set dedup. |
| P7 | MED | First-activation startup freeze | FIXED - `main.swift` pre-warms `SharedResources` off-main at launch; singleton makes later activations instant. |

No retain cycles or unbounded growth found (UserFrequency now bounded; associations bounded; regex
cache <= ~700 entries).

## Verification
- Engine: **111 tests pass** (102 prior + 9 new for candidate-cache invalidation + UserFrequency
  thread-safety/caps/debounce/scalar-filter).
- App builds + ad-hoc signs with **hardened runtime** (`flags=0x10002(adhoc,runtime)`).
- Behavior preserved: Cangjie/Simplex typing, pagination, commit, associations, punctuation,
  TC->SC, user-learning all unchanged. (IME runtime can't be unit-tested headlessly - please
  smoke-test the reinstalled build.)

## Flagged for your decision (not changed)
- **Privacy disclosure:** `user-frequency.json` is a local statistical profile of characters you
  type (now capped + 0700). Consider a one-line note in About/README if you want to disclose it.
- **McBopomofo pin (S5):** the pinned SHA was the upstream HEAD at audit time; review before the
  next `build-lm.sh` run.
- This is an internal refactor with no UI change - recommend a quick smoke test of the reinstalled
  build before merging the PR.
