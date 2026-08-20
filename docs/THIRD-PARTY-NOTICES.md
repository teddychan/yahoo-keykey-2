# Third-Party Notices

The MIT license in `LICENSE` covers the original Yahoo! KeyKey 2 source code (the
Swift engine and the macOS app). Bundled third-party **data** keeps its own
license — all of them permit redistribution, including commercial use:

| Component | License |
|---|---|
| McBopomofo language model | MIT |
| libtabe / TaBE phrase data | BSD-style |
| OpenCC conversion data | Apache-2.0 |
| Cangjie-5 table | "Freely redistributable without restriction" (upstream table header; see `Resources/CANGJIE-DATA-LICENSE.txt`) |
| Yahoo! KeyKey 三代 tables (倉頡第三代 / 速成) | New BSD (BSD-3-Clause) |

Yahoo! KeyKey 2 is an independent reimplementation and is not affiliated with, or
endorsed by, Yahoo. See `CREDITS.md`.

## McBopomofo (language model + algorithm reference)
MIT License. Copyright (c) 2011-2026 Mengjuei Hsieh, Lukhnos Liu, et al.
https://github.com/openvanilla/McBopomofo

The bundled `Resources/data.txt` is built from McBopomofo's data sources.

### libtabe / TaBE
McBopomofo's phrase data (`BPMFMappings.txt`) is derived from libtabe's `tsi.src`
(BSD-style license; TaBE project, Pai-Hsiang Hsiao et al.). This attribution is
preserved per that license.

## OpenCC (Traditional <-> Simplified conversion data)
Apache License 2.0. Copyright (c) 2010-2026 Carbo Kuo (BYVoid) and contributors.
https://github.com/BYVoid/OpenCC

Bundled `Packages/KeyKeyEngine/Resources/opencc-TSCharacters.txt` (and
`opencc-STCharacters.txt`) are derived from OpenCC's character-level dictionaries
(first target retained). Apache-2.0 permits commercial use and redistribution;
this NOTICE is retained accordingly. See `Packages/KeyKeyEngine/Resources/OPENCC-DATA-LICENSE.txt`.

## Cangjie 5 table
The bundled `Resources/cangjie.txt` is derived from the Cangjie-5 table in
`definite/ibus-table-chinese` (`tables/cangjie/cangjie5.txt`). The table file's
own header declares: **"LICENSE = Freely redistributable without restriction"**
(a permissive, non-copyleft term). Upstream data origin: chinesecj.com
(倉頡之友‧馬來西亞). Only the data table is reused (the surrounding
ibus-table-chinese repository packaging is GPLv3; the table carries its own
freely-redistributable declaration). See `Resources/CANGJIE-DATA-LICENSE.txt`.

## Yahoo! KeyKey 三代 tables (倉頡第三代 / 速成)
The bundled `Resources/cangjie-yahoo.txt` and `Resources/simplex-yahoo.txt` are
extracted from the open-sourced Yahoo! KeyKey source release
(`YahooKeyKey-Source-1.1.2528/DataTables/cj-ext.cin` and `simplex-ext.cin`),
which is released under the New BSD (BSD-3-Clause) license.
https://github.com/bency/YahooKeyKey

Both tables are the "large character set" builds based on opendesktop.org.tw's
`cj.cin` / `simplex.cin`, merged and extended by yylin and b6s — as the `cj.cin`
header itself records. The `.cin` files carry no per-file copyright line, so the
notice reproduced below is the project's, from the repository's `LICENSE`. The
release's own `COPYING` says "Refer to individual source code header for copyright
notices", and its `Copyright (c) 2007-2010 Yahoo! Taiwan` line is scoped to
`PreferenceApplications/` and `Utilities/` — not to `DataTables/` — so it is
recorded as provenance rather than presented as these tables' notice.

Only the data tables are reused. Yahoo! KeyKey 2 uses no source code from the
original Yahoo! KeyKey. See `Resources/CANGJIE-DATA-LICENSE.txt` for the exact
extraction and de-duplication steps.

BSD-3-Clause requires binary redistributions to reproduce the copyright notice,
the conditions and the disclaimer, so the license is reproduced here in full:

```
Copyright (c) 2012, Yahoo! Inc.  All rights reserved.

Redistribution and use of this software in source and binary forms,
with or without modification, are permitted provided that the following
conditions are met:

* Redistributions of source code must retain the above
  copyright notice, this list of conditions and the
  following disclaimer.

* Redistributions in binary form must reproduce the above
  copyright notice, this list of conditions and the
  following disclaimer in the documentation and/or other
  materials provided with the distribution.

* Neither the name of Yahoo! Inc. nor the names of its
  contributors may be used to endorse or promote products
  derived from this software without specific prior
  written permission of Yahoo! Inc.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

The third condition is why the summary at the top of this file states that
Yahoo! KeyKey 2 is not affiliated with, or endorsed by, Yahoo.

## Project source code
The original Yahoo! KeyKey 2 source code (Swift engine + macOS app) is released
under the MIT License — see `LICENSE`. It is an independent reimplementation and
uses no source code from the original Yahoo! KeyKey (credited in `CREDITS.md`).
Its bundled **data** is another matter: the 三代 tables above come from that
project's source release, under its New BSD license.
