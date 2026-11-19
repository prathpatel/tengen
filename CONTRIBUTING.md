# Contributing

- Read [AGENTS.md](AGENTS.md) for the architecture and the coding rules.
- Run `dart format lib test`, `flutter analyze` and `flutter test` before sending changes.
- Add tests for rules engine changes in `test/model/go/`, and widget tests for UI behavior.
- When changing how the app talks to OGS, check the behavior against the
  [online-go.com](https://github.com/online-go/online-go.com) and
  [goban](https://github.com/online-go/goban) sources, and run the live test
  (`flutter test -t live --run-skipped`).
