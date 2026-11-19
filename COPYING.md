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

The OGS client follows the protocol and conventions of the
[online-go.com web client](https://github.com/online-go/online-go.com) and the
[goban](https://github.com/online-go/goban) library (AGPL-3.0 and Apache-2.0). No code from those
projects is included: the Dart implementation here is original, written against their documented
behavior. The Learning Hub course content is the exception, see below.

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
