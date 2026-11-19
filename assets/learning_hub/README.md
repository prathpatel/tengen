# OGS Learning Hub content

`learning_hub.json` is the interactive course of online-go.com (the "Learning Hub": 7 sections,
248 lessons, 3,551 pages), converted from
[online-go/online-go.com](https://github.com/online-go/online-go.com/tree/main/src/views/LearningHub)
at commit `f0a08bfaf068f93494229dbaf894aced5a750692` by `tool/learning_hub/convert.mjs`.

That content is © the online-go.com contributors and licensed under the GNU Affero General
Public License v3 (see `LICENSE-AGPL-3.0.txt`). It is distributed here under that license.

To update it, with checkouts of online-go.com and goban next to each other:

```bash
cd tool/learning_hub && npm install
node convert.mjs ../../../online-go.com ../../../goban ../../assets/learning_hub/learning_hub.json
```
