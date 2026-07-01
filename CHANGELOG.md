# What's New in Yahoo KeyKey 2

A plain-language list of changes in each version, newest first.

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
