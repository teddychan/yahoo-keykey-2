# What's New in Yahoo KeyKey 2

A plain-language list of changes in each version, newest first.

## 2.13.2

- **A maintenance release: nothing in the app itself changed.** No Swift file, no setting, no code
  table and no resource moved between 2.13.1 and this version. What changed sits around the app: the
  automation that builds, signs, notarizes and publishes each release, and the documentation
  describing how that is done. 倉頡, 速成 and 拼音, the candidate list, your preferences and your
  learning data all behave exactly as they did in 2.13.1.

  The only difference you can see is the version number the About and What's New panes report. If
  you are looking for a reason to update, there isn't one beyond keeping the number in step — 2.13.1
  is not missing a fix.

## 2.13.1

- **Fixed: in 速成, typing on past a two-key code now moves to the next character instead of
  getting stuck.** A 速成 code is two keys — the first and last 倉頡 radical — so once you have
  typed both, the character is as narrowed down as it can get. Type 女木 for 好 and then start the
  next character with 人, and Yahoo KeyKey 2 would add that 人 to the code you had just finished,
  making a three-key code. No such code exists in 速成, so the candidate list emptied out and 好
  could no longer be picked at all; the only way forward was Backspace.

  A third key now finishes the character in progress — taking the candidate the space bar would
  have taken, the first one on the page you are looking at — and begins the next character with
  that key, the way the original Yahoo! KeyKey behaves. Everything else is unchanged: 倉頡 still
  takes up to five keys, and in 速成 the space bar, 1–9, the arrow keys and Backspace all work
  exactly as before. Thanks to the reporter of
  [issue #113](https://github.com/teddychan/yahoo-keykey-2/issues/113).

- **Under the hood: updated to DragonKit 4.1.0** (from 4.0.0), the shared code behind the Settings
  window's About, What's New, Backup & Restore, Updates and Uninstall panes. Nothing was
  redesigned and no feature changed; this release is almost entirely automatic checks that hold
  the five Dragon apps to the same shape — an About Website row now has to address the app's own
  page on the studio site, a language menu can only offer languages the app is actually translated
  into, and a check that finds nothing to look at now fails instead of quietly reporting success.
  Yahoo! KeyKey 2 passes all of them unchanged. The About pane reports the new number; that is the
  whole of what you can see.

## 2.13.0

- **Added: the adaptive candidate order can now be turned off.** A new toggle in **設定… ▸ 一般 ▸
  輸入方式**, **依選字習慣調整候選字順序**, on by default — so nothing changes unless you want it to.
  Turn it off and candidates keep their built-in order and stay there: 五代 and 拼音 use their
  built-in rankings, 三代 the original Yahoo! KeyKey order, and 聯想字詞 the language model's. It
  covers all three input methods and the associated phrases, not just one of them.

  Yahoo! KeyKey 2 has always counted the characters you commit and ranked candidates by that
  count, with no way to stop it. [Issue #85](https://github.com/teddychan/yahoo-keykey-2/issues/85)
  is from a long-time 速成 typist who had memorised the candidate sequence, and for them a list
  that keeps rearranging itself is worse than one that never moves — the position they reach for
  is no longer the position the character is in.

  Turning it off **pauses** learning rather than erasing it. Nothing new is counted, and what has
  already been learned stays on disk, so turning it back on resumes where you left off instead of
  starting from nothing. (Uninstall still removes that data, as it always has.)

- **Fixed: associated phrases with the same score now always appear in the same order.** They were
  sorted on score alone, and Swift's sort makes no promise about equally-scoring items, so their
  order was arbitrary and could differ between launches. Because that same sort decides which 20
  suggestions per character are kept, it also decided which ones you could see at all. Both the
  order and the selection are now reproducible. A few phrases may sit in slightly different
  positions than before, with the new toggle on or off — that is the fix.

  It ships here rather than on its own because making 聯想字詞 respond to what you pick is what
  moved the ordering from load time to typing time: an order can only be promised not to change
  with your selections if it is reproducible to begin with.

- **Known limitation, now written down: a rare character you keep picking may never reach the
  front.** Adaptive ranking lifts a character *within* the dictionary's own ordering, so a
  character the bundled language model does not know cannot overtake one it does, however many
  times you pick it. Under `卜月卜尸心`, 龍 is in the model and the variant 㡣 is not, so 㡣 stays
  second permanently. Roughly four in five characters in the 五代 table are outside the model, and
  about two in five codes with more than one candidate mix the two kinds.

  Nothing here changes — this is how ranking has always worked, and it is now described in the
  README's Troubleshooting section instead of being a surprise. It does not affect 聯想字詞, where
  every phrase is scored and one selection is enough to reach the top. Fixing it means changing
  the ranking for everyone who has learning switched on, not only those using the new toggle, so
  it is deliberately left for a release of its own.

- **Under the hood: `docs/RELEASE.md` no longer describes the retired appcast mirror.** The
  release workflow stopped publishing a second copy of the update feed to the website in 2.12.0,
  but the release instructions still described that mirror as live and said it would be dropped
  "at the next minor release" — which is this one. Anyone cutting a manual release by that
  document would have pushed to an unrelated repository for no reason. Nothing about update
  delivery changes; only the instructions were stale.

## 2.12.1

- **Fixed: Yahoo! KeyKey 2 now carries a copyright notice.** `App/Info.plist` had no
  `NSHumanReadableCopyright`, so Finder's Get Info panel showed no copyright line for the app at
  all. It now reads `© 2026 Teddy Chan` — byte-for-byte the string the About pane's copyright row
  renders. Nothing about typing changes.

  Found by auditing the field across all five Dragon apps, where it sat in four different states:
  a tagline in ClipMenu 2 (`ClipMenu modern rewrite.`), two holders in Ice 2, and absent here, in
  Spectacle 2 and in Dragon Sample App. Yahoo! KeyKey 2 is the app whose *About* copyright slot
  once held `倉頡／簡易 輸入法` — the defect DragonKit still cites in
  `DragonAbout.copyright(years:holder:)` — so the bundle's own notice being missing entirely was
  the same failure one field over.

  The key is an optional Apple one that no licence names, so it is presentation rather than a
  legal notice, and the rule for presentation is the one About already follows: a single holder,
  the app's own. `LICENSE` is where the MIT grant lives and is untouched apart from the name form
  below.

- **Under the hood: `LICENSE` names the holder "Teddy Chan".** It read
  `Copyright (c) 2026 Lung Sang Chan (teddychan)`, the only one of the five apps to use that form —
  the other four say `Teddy Chan`, and so does every About pane. Same person, same grant, same
  year; only the spelling is unified. Not in the release notes, because there is nothing a user
  can observe from inside the app.

## 2.12.0

- **Added: Yahoo! KeyKey 2 now speaks all seven languages the Language menu offers.** Español,
  Français, 日本語, 한국어 and 简体中文 join English and 繁體中文, and every word of Yahoo! KeyKey 2's
  own interface is translated into each — the General pane and its explanations, the uninstall
  checklist, and these release notes. 2.11.5 took those five languages out of the menu because they
  were the shared Dragon App code's languages and not Yahoo! KeyKey 2's, so choosing one translated
  the shared Settings panes and left everything else in English. This release closes that gap from
  the other side, so the menu offers them again and means it. In System Settings ▸ Keyboard ▸ Input
  Sources, a Simplified Chinese system now sees 仓颉 and 速成 written in simplified characters.
- **Under the hood: the update feed no longer publishes a copy to the website.** Yahoo! KeyKey 2 has
  read its updates from this repository since 2.11.4, and the website copy existed only so that
  copies still on 2.11.3 or older — which read the website and nothing else — were not cut off
  while everyone moved across. Since Sparkle checks daily, anyone who has launched the app even
  once since 2.11.4 moved long ago. Nothing changes for them. A copy that has not been launched in
  all that time will report no updates available rather than an error; reinstalling from the
  releases page brings it back. The website's old file is left in place, stale, rather than
  deleted, because a stale file is a quiet no-op where a missing one would be a visible failure.

## 2.11.6

- **Under the hood: updated to DragonKit 4.0.0** (from 3.4.0), the shared code behind the Settings
  window's About, What's New, Backup & Restore, Updates and Uninstall panes. This version fixes the
  About pane's rows in place — the licences page is now required, and the original project's
  repository travels with the credit that names it, so no Dragon app can list an upstream project
  it never links or name bundled data whose licences are published nowhere. Yahoo! KeyKey 2's About
  pane already looked exactly the way the shared code now requires: it had all four link rows and
  the single-holder copyright, and its own reasoning about that copyright — that an independent
  reimplementation using no upstream source cannot assert the upstream author's copyright over this
  binary — is what the shared code adopted for every app. So nothing here moves. The About pane
  reports the new number; that is the whole of what you can see.

## 2.11.5

- **Fixed: the Language menu in Settings offered languages Yahoo! KeyKey 2 does not have.** Beside
  English and 繁體中文 it listed Español, Français, 日本語, 한국어 and 简体中文 — the languages the
  shared Dragon App code is translated into, not the ones Yahoo! KeyKey 2 is. Choosing one of them
  translated the About, What's New, Updates and Uninstall panes and left every other word in
  English, which is not a language setting anyone wanted. The menu now offers the two languages
  Yahoo! KeyKey 2 actually has. A choice already made outside those two stays listed and stays
  selected until you move off it, so nobody is left on a language they can no longer see in the
  menu.
- **Under the hood: updated to DragonKit 3.4.0** (from 3.3.0), the shared code behind the Settings
  window's About, What's New, Backup & Restore, Updates and Uninstall panes — and the version that
  added the setting the fix above needed, so the two arrived together. The About pane reports the
  new number; nothing else it provides changed.

## 2.11.4

- **Yahoo! KeyKey 2 now checks for updates at its own home rather than the website.** Update
  delivery no longer depends on the website being reachable, deployed and up to date. Updates
  keep arriving exactly as before, signed by the same key. This finishes what 2.11.3 started:
  that release began publishing the file to both places, and only once it had actually done so
  was there anything here to point the app at. Doing both at once would have sent every
  installed copy to a file that did not exist.

## 2.11.3

- **The file Yahoo! KeyKey 2 checks for updates is now published to its own home as well as
  the website.** Update delivery no longer depends on the website being reachable and
  up to date. Nothing changes for you yet: the copy you have installed keeps reading the
  website, and a later version moves it across. Doing both at once would have pointed every
  installed copy at a file that did not exist yet.
- **Internal: the engine's learning-store folder must now be named by whoever asks for it.**
  The adaptive candidate-ordering file used to have a default location, and that default was
  the installed copy's — so any build that simply left the argument out would have opened,
  trained and rewritten your real ranking. 2.11.2 fixed the code that actually runs; this
  removes the default so the mistake cannot be made again. Nothing moves: your counts stay
  exactly where they are.

## 2.11.2

- **The About panel now follows the shared Dragon App layout.** Its rows are fixed and identical
  across the Dragon apps — Website, Support on GitHub, Original project and Open-source licenses,
  then Created by, Based on, Built with and the licence — and each piece of bundled data is listed
  under its own name with its licence (McBopomofo — MIT, ibus-table-chinese — freely
  redistributable, OpenCC — Apache-2.0) instead of a description of what it is for. This reached
  you in 2.11.1, which was published as a version-number correction and never described it.
- **Fixed: a local test build no longer reaches into your installed copy.** When Yahoo! KeyKey 2
  is built on a developer's Mac it runs alongside the version you use, and the two shared one file
  of adaptive candidate ordering — so testing changed your real ranking, and running 解除安裝 in
  the test build deleted it. A test build now keeps its own copy, and it can no longer check for
  or install updates. None of this affects the version you type with; it is listed so the record
  is complete.

## 2.11.1

- **Nothing new — this is a version number fix.** A 2.11.0 was tagged but never released: the
  build checks that the version being released matches the version recorded in the app, the two
  did not match, and it stopped. Rather than reuse a version number that already has a failed
  build attached to it, the next release is 2.11.1. There is no change to the app itself.

## 2.10.0

- **New: the selection box can be read by VoiceOver.** The nine candidates are drawn as one
  piece of text, so VoiceOver read the picker as a run of digits and glyphs — or skipped it
  altogether — even though picking a candidate is the whole job. The window now publishes a
  proper list: each row is announced with its selecting digit, the candidate, and its 反查 code
  hint when shown, and the page indicator reads **第 2 頁，共 3 頁** instead of a bare "▼ 1/3".
  Turning the page is announced too. Nothing about how the window looks or behaves changed.
- **Faster.** Builds were never compiled with optimization turned on — including the notarized
  download — so the engine ran unoptimized inside a process attached to every app that takes
  keyboard input. Measured on the bundled 五代 table: loading the 倉頡 table 73 → 34 ms, deriving
  the 速成 table 78 → 8 ms, and 2000 速成 compositions 21 → 2 ms.
- **設定 now has a proper menu bar.** Opening Settings used to put an empty menu bar on screen,
  which meant no ⌘W to close the window and no working Undo/Cut/Copy/Paste in any text field.
  There is now a standard **編輯** menu and **關閉 ⌘W**. There is deliberately no Quit: an input
  method is started and stopped by macOS, not by you — the same reason the 倉頡／速成 input menu
  has never had one.
- **Fixed: restoring a damaged backup erased your settings.** Restoring a backup file that was
  truncated or corrupt wiped the existing settings instead of refusing, so a bad file cost you
  the settings you still had. A backup that cannot be read is now rejected and your current
  settings are left alone.
- **Fixed: a failed uninstall reported success.** If removing Yahoo! KeyKey 2 hit an error part
  way through, the pane still said it had finished. It now reports the failure.
- **Fixed: switching 倉頡版本 could mix the two tables.** Changing between 三代 and 五代 could
  derive the 速成 table from one version while the 倉頡 table came from the other, offering
  candidates under codes that belonged to the other table. Both are now always taken from the
  same load.
- **Fixed: an unreadable learning file silently reset your adaptive ranking.** If the file
  holding your adaptive candidate ordering could not be read, it was quietly replaced with an
  empty one and then overwritten, so the ranking was gone with nothing to explain it. It is now
  set aside as `.corrupt` and the problem is logged, so a fresh file starts without destroying
  the old one.
- **Fixed: a future update could have reset every preference.** A flaw in the shared settings
  code meant that the first release to add a new option would have failed to read your saved
  settings, fallen back to defaults, and then written those defaults over the real ones. It was
  found and fixed before any release shipped a new option, so nothing was lost — but the same
  flaw would have hit on the next one.
- **Under the hood.** Updated to DragonKit 2.4.0 (from 2.1.0), the shared code behind the
  Settings, About, What's New, Backup and Uninstall panes. Compile-time data-race checking is
  now on across the project, compiler warnings fail the build, and the input-routing logic that
  decides paging and candidate selection was extracted into tested pure functions.

## 2.9.1

- **Fixed: the selection box could be left stuck on screen.** If you switched to another app —
  or to another input source — while the candidate window or the **聯想** (associated-phrase)
  window was open, it stayed floating above whatever you switched to, with no way to close it:
  the keys that dismiss it now belonged to the other app, so it was still sitting there even
  after switching back to English. The window now closes as soon as Yahoo! KeyKey 2 loses
  focus. A half-typed code is committed on the way out; **聯想** suggestions are simply dropped,
  since they are offers you never picked.

## 2.9.0

- **A tidier input menu.** The app items at the bottom of the 倉頡／速成 input menu — **關於 Yahoo!
  KeyKey 2**, **檢查更新…** and **設定…** — now each lead with an icon and follow standard macOS
  naming, matching the other Dragon apps. They are built from the shared DragonKit menu, so the
  wording, order, and icons can no longer drift between apps. Nothing you type changes, and the
  **輸出簡體字 / 全形標點 / 聯想字詞 / 反查提示** toggles above them are untouched.
- **解除安裝 (Uninstall) now lives in Settings.** Removing Yahoo! KeyKey 2 used to sit at the
  bottom of the input menu, one slip away from the options you use while typing. It is now at
  **設定… ▸ 解除安裝** instead — the same checklist, just not in the menu you open mid-sentence.
- **Under the hood.** Updated to DragonKit 2.1.0 (from 1.3.0), the shared code behind the
  Settings, About, What's New, and Uninstall panes.

## 2.8.0

- **Press Space to confirm the code (new option).** In **速成**, and in **倉頡** with the `*`
  wildcard, candidates appear before the code is finished — so **Space** flipped to the next
  page instead of confirming what you typed, breaking the 倉頡 habit of "type the radicals,
  press Space". A new **設定… ▸ 一般 ▸ 輸入方式** option, **以空白鍵確認字根**, makes the first
  Space confirm the code and stay on page 1; press Space again to page, or **1–9** to pick.
  Off by default, and plain 倉頡 is unaffected.
- **Fixed: 三代倉頡 offered characters under the wrong code.** Typing `人一弓口` (何's code)
  also offered 含, which decomposes as `人戈弓口` — as the 反查 hint beside it already said.
  The bundled 三代 table came from an upstream merge that never removed duplicates, handing
  800 characters a second, non-standard code. Those extra codes are gone; every character
  keeps its real one, Yahoo's original candidate order is untouched, and **五代倉頡 was never
  affected**.

## 2.7.0

- **Page Up / Page Down now flip candidate pages.** In both the 倉頡／速成 candidate window and
  the 聯想 (associated-phrase) window, you can now page through choices with **Page Up**
  (previous page) and **Page Down** (next page), the way many traditional Chinese IMEs do — in
  addition to the existing arrow keys and Space.
- **Choose how to pick associated phrases.** A new **設定… ▸ 一般** option lets you keep the
  default (**1–9** picks an associated phrase) or switch to **Shift + 1–9** — with that on, a
  plain **1–9** types the digit and dismisses the suggestions, so numbers flow naturally right
  after a character (e.g. `這周有7天。`). Default is unchanged, so existing users see no difference.
- **Fixed: ⌘ and ⌃ shortcuts now pass through to the app.** With Yahoo KeyKey 2 selected,
  combinations like **⌘C / ⌘X / ⌘V** were intercepted by the input method (⌘C could turn into the
  倉頡 radical 金) instead of copying, cutting, or pasting. ⌘/⌃ key combinations now reach the app
  as expected.
- **Corrected the install instructions.** Releases ship a `.zip` (not a `.pkg`), so the
  README and the `Install.txt` inside the download now tell you to unzip and move
  `YahooKeyKey2.app` into `~/Library/Input Methods/` yourself — or just use Homebrew.
  No app behavior changes; documentation only.
- **More automated tests, no behavior change.** Added 32 test cases (bringing the total to 209),
  raising region test coverage of the input engine to **92%** and adding a new **91%**-covered
  test suite for the app's settings and screen-content logic. New coverage includes: candidate
  font-size clamping and preference persistence (`Preferences`), the 速成 (Simplex) quick-code
  table loader, user-frequency file handling and save-failure safety, the 反查／拆碼提示
  reverse-lookup index, best-path walker edge cases, the input-method engine protocol contract,
  and the About / What's New content. Both test suites now run automatically in CI on every
  pull request. Nothing you type changes — this only guards against future regressions.

## 2.6.4

- **Starts up even faster and lighter.** At launch, Yahoo KeyKey 2 now reads its dictionary file
  in a single pass instead of two, and it builds the **速成 (Simplex)** code table and the
  **反查／拆碼提示** reverse-lookup index only when you actually use them. If you type only 倉頡 or
  拼音, that's less work and less memory every time the app starts. Nothing you type changes.
- **拼音 stays responsive on unusual input.** Typing a long run of letters that can't form valid
  syllables no longer makes the pinyin composer do more and more work on every keystroke.
- **Under the hood.** Added test coverage for the 拼音 and 速成 engines to match 倉頡 (user-learning
  reranking, edge-case input handling, and real-dictionary checks), guarding against regressions.

## 2.6.3

- **Faster startup and lower memory use.** At launch, Yahoo KeyKey 2 no longer builds a large
  in-memory copy of its whole dictionary just to work out which characters are most common — it
  now reads only what it needs. The app starts up quicker and uses less memory, and nothing you
  type changes.
- **拼音 typing is a little more efficient.** While you're composing pinyin, the engine skips
  repeated sorting work it used to do on every keystroke. You'll notice it most with long
  phrases. The candidates you see, and their order, are exactly the same as before.

## 2.6.2

- **Removed 候選字大小 from the input menu.** The coarse **小／中／大** shortcuts in the
  input-method menu-bar item are gone — candidate text size is now set with the fine-grained
  slider under **設定… ▸ 一般**, which lets you pick any size in the supported range instead of
  just three fixed steps. Your current size is unchanged.

## 2.6.1

- **拼音: number keys now pick a candidate directly.** While typing Pinyin, pressing **1–9**
  now selects that candidate — for a single syllable it commits right away (just like 倉頡／速成),
  and for a multi-syllable phrase it picks that syllable and moves to the next one. **Space** still
  commits the whole phrase at once, so both ways work.
- **拼音: the 反查／拆碼提示 hint now shows pinyin.** With the code hint turned on, candidates in
  拼音 mode now show their **pinyin reading** (e.g. `wo`, `ni hao`) instead of the 倉頡 code —
  for both the syllables you're typing and the 聯想 suggestions that follow a commit.
- **Fixed: the in-app What's New now shows the current version.** The **設定… ▸ What's New** pane
  was stuck on an older release's notes; it now reflects the version you're running.

## 2.6.0

- **New input method: 拼音 (Pinyin).** Alongside **倉頡** and **速成**, Yahoo KeyKey 2 now
  offers a **拼音** phrase input method. Add it the same way as the others — **System Settings ▸
  Keyboard ▸ Input Sources ▸ + ▸ Chinese, Traditional ▸ Yahoo KeyKey 2** — then pick **拼音**
  from the input menu. Type pinyin (no tone marks needed) and it composes whole phrases, not
  just one character at a time:
    - **Space / Return** commit the whole phrase.
    - **1–9** pick a different candidate for the syllable at the cursor.
    - **← / →** move between syllables to correct them individually.
    - **Backspace** deletes; **Esc** clears the composition.
  Use an apostrophe (`'`) to split syllables when they're ambiguous (e.g. `xi'an` → 西安).

## 2.5.0

- **Fixed: the candidate text size slider now updates as you drag.** In **設定… ▸ 一般**,
  dragging the **候選字大小 (Candidate text size)** slider left the shown value (e.g. `19 pt`)
  and the slider stuck in place, even though the size did change. The slider and its label now
  track your dragging live.

## 2.4.1

- **Changed: clearer "already up to date" message.** When you check for updates and you're
  already on the latest version, the confirmation dialog now reads more naturally.
- **Changed: About now shows the build time.** The version line in **About** now reads like
  `v2.4.1 (24) · 2026-Jul-06 13:34:56 UTC`, adding the exact UTC build time alongside the
  version and build number.

## 2.4.0

- **New: 反查／拆碼提示 (Cangjie code hint).** Turn on **反查提示** — from the input menu or
  **設定… ▸ 一般** — to show each character's 倉頡 code beside it in the candidate list, e.g.
  倉 → 人口竹口. It's a handy way to learn or double-check how a character breaks down,
  especially in **速成** (where you type only the first and last radical) and in **聯想**
  suggestions. Off by default; turn it on when you want it.
- **New: 臨時英數 (quick English).** Hold **Shift** and press a letter to type that English
  letter directly, the classic Yahoo! KeyKey way — no need to switch input source. The case
  follows **Caps Lock** (Shift is only the trigger, so it's lowercase with Caps Lock off,
  uppercase with it on); anything you type without Shift stays Chinese.
- **Fixed: the 倉頡版本 choice now saves.** Switching between **五代** and **三代** in **設定…**
  could revert instead of sticking. Your selection is now kept correctly.

## 2.3.0

- **New: Sync & Backup.** A new screen in **設定…** lets you back up your Yahoo! KeyKey 2 settings to a folder and restore them later — handy when setting up a new Mac.
- **New: switch the app's language live.** Settings, About, and the other app screens can now display in English, 繁體中文, 简体中文, 日本語, 한국어, Español, or Français, switchable on the fly with no restart. (This changes the app's own interface, not what you type.)
- **Changed: refreshed Settings, About, What's New, and Uninstall.** These screens were rebuilt with a cleaner, more native macOS look (now sharing the common Dragon App UI). Your input options — **輸出簡體字**, **全形標點**, **聯想字詞**, candidate text size, and 倉頡版本 — are unchanged and in the same place.

## 2.2.0

- **New: z-code punctuation in 三代倉頡.** In the **三代倉頡（Yahoo KeyKey 相容）** mode you can now type punctuation with the classic Yahoo `z` codes — e.g. `zxcd` → 「, `zxce` → 」, `zxab` → ，, `zxbe` → （. These were part of the original Yahoo table and are available again.
- **New: 聯想只顯示接續字 option.** A new checkbox in **設定… ▸ 一般** makes the associated-phrase (聯想) window show only the continuation after the character you just typed — e.g. after 關 it shows 係／心／於 instead of the full words 關係／關心／關於, like the classic Yahoo! KeyKey. Off by default; what you commit is unchanged either way.

## 2.1.0

- **New: choose your 倉頡版本 (Cangjie generation).** In **設定… ▸ 輸入方式** you can now switch between **五代倉頡** (the standard 5th-generation table, the default) and **三代倉頡（Yahoo KeyKey 相容）**. The 三代 option uses the original Yahoo! KeyKey code table and its candidate order, so characters like 面 (`一田卜中`), 鬼 (`竹戈`), and 樓 (`木中田女`) take the codes long-time Yahoo users remember instead of the 5th-generation forms (`一田尸中`, `竹山戈`, `木中中女`). The choice applies to both 倉頡 and 速成 and takes effect immediately — no need to re-select the input method. The default stays 五代 so existing users are unaffected until they opt in.

## 2.0.2

- **Fixed: the Settings window now matches the quick menu.** Toggling **輸出簡體字**, **全形標點**, **聯想字詞**, or the **候選字大小** from the menu-bar input menu changed the behaviour correctly, but the checkboxes and slider in **設定…** still showed their old values. The Settings window now re-reads the current values each time it opens, so it always reflects what you set in the menu.

## 2.0.1

- **Fixed: Yahoo KeyKey 2 now appears in System Settings → Keyboard → Input Sources again.** Version 2.0.0 could be installed but never showed up as an input method you could add, because the rebrand accidentally changed the app's identifier to a form macOS does not recognise as an input method. The identifier now includes the required `inputmethod` component, so the input method registers correctly. If you had 2.0.0, install 2.0.1 and add **Yahoo KeyKey 2** under **Chinese, Traditional**.

## 2.0.0

- Version numbers now start at **2.x** to match the product name, **Yahoo! KeyKey 2**. No functional change from 1.7.2.

## 1.7.2

- The About window now links to the Yahoo! KeyKey 2 website (dragonapp.com/keykey) and to GitHub Issues for support, alongside the existing homage to the original Yahoo! KeyKey.

## 1.5.0

- **Cangjie wildcard now works from the first key.** Typing **`*`** as the very
  first radical starts a wildcard search instead of inserting a full-width **＊**.
  (Mid-word wildcards already worked; this fixes the start-of-word case.)
- **Lower memory use.** The language-model data is now used to build the ranking
  and then released, so the app keeps less in memory while you type.
- **Now requires macOS 26 Tahoe or later** (Apple Silicon). If you're on an older
  macOS, stay on version 1.4.1.

## 1.4.1

- **Fixed: the candidate text size now sticks.** Picking 小 / 中 / 大 from the
  **「候選字大小」** menu had no effect — your choice was never saved. It now applies
  and is remembered, the way it was meant to.

## 1.4.0

- **Choose your candidate text size.** The input menu now has a new
  **「候選字大小」(Candidate Text Size)** option with **小 / 中 / 大 (Small / Medium /
  Large)**. Pick whichever is easiest on your eyes — the candidate list updates the
  next time you type.
- **Apple Silicon only.** Yahoo KeyKey 2 now runs exclusively on Apple Silicon Macs
  (M1 and newer). Older Intel Macs are no longer supported. If you're on an Intel
  Mac, stay on version 1.3.4. This keeps the app smaller and lets us focus on the
  Macs people use today.

## 1.3.4

- Tidied up the candidate window by removing the fixed "SHIFT + NUM" header line,
  so the list looks cleaner.

## 1.3.3

- Refreshed the candidate window to a classic, more familiar KeyKey style.

## 1.3.0

- Added automatic updates: from this version on, Yahoo KeyKey 2 can check for and
  install new versions on its own (for the direct download — Homebrew users update
  through Homebrew).
