# What's New in Yahoo KeyKey 2

A plain-language list of changes in each version, newest first.

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
