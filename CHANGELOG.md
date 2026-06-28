# What's New in Yahoo KeyKey 2

A plain-language list of changes in each version, newest first.

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
