# Third-Party Notices

The MIT license in `LICENSE` covers the original Yahoo KeyKey 2 source code (the
Swift engine and the macOS app). Bundled third-party **data** keeps its own
license — all of them permit redistribution, including commercial use:

| Component | License |
|---|---|
| McBopomofo language model | MIT |
| libtabe / TaBE phrase data | BSD-style |
| OpenCC conversion data | Apache-2.0 |
| Cangjie-5 table | "Freely redistributable without restriction" (upstream table header; see `Resources/CANGJIE-DATA-LICENSE.txt`) |

Yahoo KeyKey 2 is an independent reimplementation and is not affiliated with, or
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

## Project source code
The original Yahoo KeyKey 2 source code (Swift engine + macOS app) is released
under the MIT License — see `LICENSE`. It is an independent reimplementation and
uses no source code from the original Yahoo! KeyKey (credited in `CREDITS.md`).
