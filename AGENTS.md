# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project Overview

Tengen is a Flutter (3.50, Dart 3.14) app to play Go on online-go.com (OGS) and offline. It is a
fork of the Lichess mobile app and keeps its architecture: Riverpod 3 for state, a model layer
independent of the UI, one navigator per bottom tab, and game screens pushed on the root
navigator.

## Commands

```bash
flutter pub get
flutter test                                   # all tests (the live OGS test is skipped)
flutter test test/model/go/game_test.dart      # a single file
flutter test -t live --run-skipped             # replays real OGS games, needs network
flutter analyze                                # must report no issues
dart format lib test                           # page width 100
```

## Rules

- **Analysis**: strict casts/inference/raw types, single quotes, package imports only. Keep
  `flutter analyze` clean, including tests. Conventional constructors are used (the primary
  constructor lints are disabled in `analysis_options.yaml`).
- **Layering**: `lib/src/model/` never imports `view/` or `widgets/`
  (`test/model/model_layer_test.dart` enforces it).
- **Immutability**: state classes are `@immutable` with `final` fields and `copyWith`.
- **Riverpod 3**: family notifiers take their argument in the constructor
  (`NotifierProvider.family(Controller.new)`); pattern match `AsyncValue`
  (`AsyncData(:final value)`) rather than using `when`. Never write `state` inside `build()`.
- **UI**: Material via `package:material_ui/material_ui.dart` (the `flutter/material.dart` import is
  deprecated in this Flutter version).
- **Tests**: fake the network at the edges, never the providers: `test/fakes.dart` has
  `makeContainer()` with a fake OGS HTTP server (`MockClient`) and an in-memory WebSocket
  (`FakeWebSocketChannel`) where the test plays the server.

## OGS protocol notes

- Moves are two letters, `a` = 0, from the top left (`dd` is D16 on 19×19); `..` is a pass. The
  `moves` array of the game data holds `[x, y, timedelta, ...]` with `x == -1` for a pass.
- With free handicap placement black plays its handicap stones as its first moves; with fixed
  placement the stones are on the board and white plays first.
- Server moves are replayed with `validate: false`; the server is authoritative.
- Reference sources: `online-go/goban` (`src/engine/GobanSocket.ts`, `src/engine/protocol/`,
  `src/engine/GobanEngine.ts`) and `online-go/online-go.com` (`src/lib/requests.ts`,
  `src/views/SignIn/`, `src/views/Play/QuickMatch.tsx`).
