Copying Tengen
==============

Tengen is free software: you can redistribute it and/or modify it under the terms of the GNU
General Public License as published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

See the LICENSE file for a copy of the *GNU General Public License*.

Origin
------

Tengen is derived from [Lichess Mobile](https://github.com/lichess-org/mobile), copyright (c)
Lichess Mobile contributors, licensed under the GNU GPL v3 or later. The first commit of this
repository is a snapshot of that project; see the commit log for what was changed since.

Tengen talks to online-go.com (OGS) through its public REST API and realtime server: sign in,
games, moves, clocks, automatch, chat, game lists, players, puzzles and bots all come from OGS
while the app runs. That client is written for Tengen, following the protocol and behavior of the
[online-go.com web client](https://github.com/online-go/online-go.com) (AGPL-3.0) and the
[goban](https://github.com/online-go/goban) library (Apache-2.0). The rules engine, scoring,
offline games and their bot, SGF export, coordinate training and the puzzle solver (which follows
the puzzle rules of goban, without its code) are also written for Tengen.

Some parts do come from those two projects' code or files. They are listed here, and detailed in
the sections below:

| What | Where in Tengen | From | License |
| --- | --- | --- | --- |
| Learning Hub lessons (converted) | `assets/learning_hub/` | online-go.com | AGPL-3.0 |
| Board textures, BadukTV and Anime stone images | `assets/goban/` | online-go.com | AGPL-3.0 |
| Stone renderer (Phong shading, shell lines) and theme colors, ported to Dart | `lib/src/widgets/goban_art.dart`, `lib/src/model/settings/preferences.dart` | goban | Apache-2.0 |
| Check of the game settings a bot accepts (`getAcceptableTimeSetting`), ported to Dart | `botAccepts` in `lib/src/model/ogs/bots.dart` | online-go.com | AGPL-3.0 |
| Bot rejection messages (reworded) | `rejectionMessage` in `lib/src/model/online_game/bot_challenge_controller.dart` | online-go.com | AGPL-3.0 |
| Quick match clock times (`SPEED_OPTIONS`) | `lib/src/model/online_game/automatch_controller.dart`, `BotClock` in `lib/src/model/ogs/bots.dart` | online-go.com | AGPL-3.0 |
| Rating to rank formula, provisional rating cutoff | `ratingToRank`, `provisionalDeviation` in `lib/src/model/ogs/user.dart` | online-go.com | AGPL-3.0 |

The GNU GPL v3 (Tengen) and the GNU AGPL v3 allow these works to be combined (section 13 of both
licenses); the AGPL terms apply to the parts from online-go.com. The Apache License 2.0 is
compatible with the GNU GPL v3.

The app icon (`assets/icon/`, the launcher icons in `android/` and `ios/`, and `tool/gen_icon.py`)
comes from the author's [GoGame](https://github.com/prathpatel/GoGame) project.

"Lichess" and "OGS"/"online-go.com" are the names of their respective projects; Tengen is not
affiliated with or endorsed by either.

Learning Hub content (AGPL-3.0)
-------------------------------

`assets/learning_hub/learning_hub.json` is converted from the Learning Hub of the
[online-go.com web client](https://github.com/online-go/online-go.com) (its interactive "Learn to
play Go" course), © the online-go.com contributors, licensed under the GNU Affero General Public
License v3. It is distributed under that license: see `assets/learning_hub/LICENSE-AGPL-3.0.txt`
and `assets/learning_hub/README.md`. The GNU GPL v3 (the rest of Tengen) and the GNU AGPL v3 allow
these works to be combined (section 13 of both licenses); the AGPL terms apply to that content.

Board and stone themes
----------------------

The board textures and stone images in `assets/goban/` come from the
[online-go.com web client](https://github.com/online-go/online-go.com) (`assets/img/`), © the
online-go.com contributors, under the GNU AGPL v3 (see `assets/learning_hub/LICENSE-AGPL-3.0.txt`);
the Anime stones were rasterized from its SVG files. The theme colors and the stone renderer of
`lib/src/widgets/goban_art.dart` (Phong shading, clam shell lines) are ported from the
[goban](https://github.com/online-go/goban) library (`src/Goban/themes/`), © Online-Go.com,
licensed under the Apache License 2.0.

Ported code from online-go.com
------------------------------

`botAccepts` (`lib/src/model/ogs/bots.dart`) is a Dart port of `getAcceptableTimeSetting` and the
helpers it uses in `src/lib/bots.ts` of the online-go.com web client, and `rejectionMessage`
(`lib/src/model/online_game/bot_challenge_controller.dart`) rewords the messages of
`rejectionDetailsToMessage` in `src/components/ChallengeModal/ChallengeModal.utils.ts`. The quick
match clock times come from `src/views/Play/SPEED_OPTIONS.ts`, and `ratingToRank` and
`provisionalDeviation` (`lib/src/model/ogs/user.dart`) use the formula and cutoff of
`src/lib/rank_utils.ts`. © the online-go.com
contributors, GNU AGPL v3 (see `assets/learning_hub/LICENSE-AGPL-3.0.txt`).
