# Optional frequency-ranked & adaptive candidate order (issue #85)

**Date:** 2026-08-12
**Issue:** [#85](https://github.com/teddychan/yahoo-keykey-2/issues/85) — "Frequency-ranked &
adaptive as an option"
**Ships in:** 2.13.0

## The problem

From the issue, filed by a long-time 速成 user:

> For the long time users of simplex, we remembered all the candidate in sequence. It would be
> easier and more user friendly for us if the candidate table doesn't change with the pick up
> frequency.

Yahoo! KeyKey 2 learns. `UserFrequency` counts every single character the user commits and adds
`log(1 + count) * 10` to that character's ranking score, so characters you pick often drift toward
the front of the candidate list. For a typist who learned the classic layout by muscle memory, a
list that keeps rearranging itself is worse than one that never moves: the position they reach for
is no longer the position the character is in.

Nothing today can turn that off.

## What ships

One toggle, **設定… ▸ 一般 ▸ 輸入方式 ▸ 依選字習慣調整候選字順序**, on by default so no existing
install changes behaviour.

**On** (today's behaviour, plus 聯想): characters the user commits are counted, and that count
ranks both the composition candidates (倉頡 / 速成 / 拼音) and the 聯想 suggestions.

**Off**: candidates and 聯想 come out in their built-in order and stay there, and nothing is
counted. Already-learned counts are **kept on disk**, so turning it back on resumes where it left
off rather than starting over.

"Built-in order" is per table, and is static in every case:

| Mode | Order with the toggle off |
| --- | --- |
| 五代倉頡 / 速成 | the bundled corpus language-model character ranking |
| 三代倉頡 / 速成 | the original Yahoo! KeyKey table's native line order |
| 拼音 | the language model's own ordering |
| 聯想 | the language model's phrase scores |

## Architecture

### The gate

Adaptive ranking reaches the user through exactly one closure and two learning sites, all in
`App/InputController.swift`:

- `userRank: (Character) -> Double`, built once in `init` and handed to all three engines. The
  engines add its result to a static dictionary rank when sorting candidates; the Pinyin walker
  adds it when ordering candidates within a chosen span. Return zero and every one of them falls
  back to its static order — a property the engine tests already pin.
- `userFreq.record(_:)` on a single-character composition commit.
- `userFreq.record(_:)` on an 聯想 pick (**new** — see below).

So the feature is a gate on one closure and two calls. **No engine needs to know the setting
exists**, which is why `KeyKeyEngine` stays free of any `Preferences` dependency.

### The policy

`AdaptiveCandidateOrder`, a third enum in `App/KeyEventPolicy.swift` alongside `KeyEventPolicy`
and `SessionEndPolicy`. That file exists to hold pure, IMK-free decisions so they can be unit
tested — `InputController` needs a live `IMKServer` and cannot be — and its header explains why
they share one file: `tools/build-app.sh` compiles an explicit list of `App/` sources, so a new
file costs a build-script edit for no benefit at this size.

```swift
static func bonus(for char: Character, enabled: Bool,
                  learned: (Character) -> Double) -> Double
static func characterToLearn(fromCommitted text: String, enabled: Bool) -> Character?
static func characterToLearn(fromAssociationSuffix suffix: String, enabled: Bool) -> Character?
```

Two `characterToLearn` overloads rather than one with a mode flag, because the rules genuinely
differ: a composition commit is learned only when the whole committed text is one character
(`UserFrequency` counts characters), while an 聯想 pick learns the first character of the suffix
whatever the phrase's length.

`Preferences.adaptiveCandidateOrderEnabled` is read live at each call, exactly as every other
setting in this app is, so the toggle applies to the next composition with no engine rebuild and
no notification.

### 聯想 becomes frequency-ranked

This is the one piece that is new functionality rather than a gate.

`AssociatedPhrases` sorted each character's phrases **once at load**, kept the top 20, and
discarded the scores; `associations(for:)` returned that frozen array. Ranking it by a live,
changing bonus means ordering has to happen per query instead.

The struct now keeps `(phrase, score)` pairs — still deduped and still capped at 20 per bucket at
load, because the cap bounds memory and a phrase below the top 20 by LM score is not reachable in
the 9-per-page window anyway — and `associations(for:userRank:)` re-sorts on
`score + userRank(continuation)`. The parameter defaults to `{ _ in 0 }`, matching the engines'
convention, so the off path and every existing caller get the unchanged static order.

**The bonus applies to the phrase's continuation character, not its first.** The first character
is the bucket's index key and is identical for every phrase in it, so its bonus is a constant that
reorders nothing. The continuation — 係 in 關係 — is the character the user is actually choosing
to add, and is what the existing 聯想只顯示接續字 option already displays.

Cost is a sort of at most 20 elements, once per commit.

### Determinism

Both sorts get an explicit source-index tie-break, the same one `CangjieEngine` and
`SimplexEngine` already use for their table offsets. Swift's `sorted(by:)` is not a stable sort,
so `sorted(by: { $0.score > $1.score })` left equal-scoring phrases in an arbitrary order. That
was always a latent defect; it becomes load-bearing here for two reasons:

1. At load, the score sort decides **which 20 phrases survive the cap** — so an arbitrary
   tie-break decides which phrases the user can ever see.
2. At query time, a promise that the order "does not change based on your selections" is only
   true if the order is reproducible in the first place.

Equal-scoring 聯想 phrases may therefore sit in slightly different positions than before, with the
toggle on or off. That is the fix, and it belongs in the release notes.

### Learning from 聯想 picks

Picking 關係 records 係. The user selected that character, it goes into the document, and it is
the same per-character store the composition candidates use — so a character learned in 聯想 also
surfaces earlier when typed by code, and vice versa. Without it, 聯想 could only inherit what was
learned elsewhere and would never learn from its own use.

## Files

| File | Change |
| --- | --- |
| `Packages/KeyKeyEngine/Sources/KeyKeyEngine/AssociatedPhrases.swift` | keep scores; query-time re-sort with the user bonus; tie-breaks on both sorts |
| `App/KeyEventPolicy.swift` | `AdaptiveCandidateOrder` |
| `App/Preferences.swift` | `adaptiveCandidateOrderEnabled`, default `true`, registered |
| `App/InputController.swift` | store `userRank`; gate both learn sites; pass `userRank` to `associations` |
| `App/SettingsModel.swift` | computed forwarder (plain `Bool` needs no stored-property treatment) |
| `App/GeneralPane.swift` | `Toggle` + `.dragonAnnotation` in the 輸入方式 section |
| `App/{en,es,fr,ja,ko,zh-Hans,zh-Hant}.lproj/Localizable.strings` | 2 setting strings + the 2.13.0 What's New strings, ×7 |
| `App/WhatsNewConfig.swift` | 2.13.0 notes |
| `CHANGELOG.md`, `README.md`, `docs/RELEASE.md` | see below |
| `App/Info.plist` | `2.12.1` → `2.13.0` |

The package sources under `Packages/KeyKeyApp/Sources/KeyKeyApp/` are **symlinks** to `App/`, so
each app file is a single edit.

## Tests

- `KeyEventPolicyTests` — the gate: zero bonus when disabled, the learned value when enabled;
  `characterToLearn` nil when disabled, nil for a multi-character commit, nil for an empty commit,
  the character itself for a single-character commit; the association overload taking the suffix's
  first character and nil when disabled.
- `AssociatedPhrasesTests` — a zero bonus preserves the static LM order; a bonus on a
  continuation character lifts that phrase; equal scores resolve by source order at both the cap
  and the query.
- `PreferencesTests` — default is `true`, round-trips, and the key is added to **both** `tearDown`
  and `testRegisterDefaultsSuppliesSensibleFirstLaunchValues` (registered defaults outlive a
  `removeObject`, so a key missing from that second list could pass by accident).
- `ConfigContentTests` — updated to the 2.13.0 date and the new What's New key. These
  deliberately pin the shipping release so a stale pane cannot ship; they fail until updated.

## Documentation corrections this release must make

- `README.md:96` presents adaptation as unconditional, and `:130` calls 三代 "Yahoo's original
  native order" — true only once the new toggle is off. Both are made inaccurate by this change.
- `docs/RELEASE.md:136-144` and `:171-174` still describe the appcast mirror to the marketing-site
  repo as live and say it "is dropped at the next **minor** release". `.github/workflows/release.yml`
  retired it in 2.12.0 and no longer passes `appcast_mirror_repo`. 2.13.0 **is** the next minor, so
  anyone following that doc for a manual release would push to an external repo for no reason.
- The `/* What's New pane (2.12.0) */` comment in all seven `.strings` files is stale, and the
  `keykey.whatsNew.copyrightNotice` key is replaced rather than left behind.

`docs/yahoo-keykey-2/appcast.xml` is **not** touched — the release workflow publishes it after the
tag, and it must keep describing the latest published release until then.

## Deliberately out of scope

- **A "reset learned data" button.** Not asked for, and the Uninstall pane already removes the
  whole support directory. Registering `true` means no migration is needed either.
- **The variation-selector mismatch.** `characterToLearn` uses `text.count == 1`, which counts
  grapheme clusters, so a CJK character carrying a variation selector is recorded — but
  `UserFrequency.load` accepts only single-scalar keys, so it is silently dropped on the next
  launch. Real, pre-existing, and a change to the persistence contract with its own hardening
  tests. Filed separately.

## Verification

`swift test` in both packages, then `tools/run-debug.sh`, which installs **Yahoo KeyKey 2 Debug**
under its own bundle id **and its own Application Support directory** — so hand-testing cannot
train or wipe the installed release IME's counts.

Manual matrix:

1. 倉頡, 速成 and 拼音, each on 五代 and 三代 where applicable.
2. Seed learning with the toggle on: commit one character repeatedly, confirm it moves forward.
3. Turn the toggle off: the order returns to the built-in one and stays there across restarts.
4. Type more with it off, turn it back on: the pre-existing ranking returns, and nothing typed
   while off has been learned.
5. 聯想: confirm suggestions reorder with the toggle on and do not with it off.
6. A large 速成 or `*`-wildcard composition, for the per-candidate preference read.
