import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/bot.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/go/rules.dart';
import 'package:tengen/src/model/go/scoring.dart';

enum OfflineOpponent { human, bot }

/// The settings of an offline game.
@immutable
class OfflineGameSetup {
  const OfflineGameSetup({
    this.size = 9,
    this.ruleset = Ruleset.japanese,
    this.handicap = 0,
    this.komi,
    this.opponent = OfflineOpponent.bot,
    this.humanColor = StoneColor.black,
  });

  final int size;
  final Ruleset ruleset;
  final int handicap;

  /// Null for the rule set default.
  final double? komi;
  final OfflineOpponent opponent;

  /// The color played by the user against the bot.
  final StoneColor humanColor;

  double get effectiveKomi => komi ?? ruleset.defaultKomi(handicap);

  StoneColor? get botColor => opponent == OfflineOpponent.bot ? humanColor.opposite : null;

  OfflineGameSetup copyWith({
    int? size,
    Ruleset? ruleset,
    int? handicap,
    double? Function()? komi,
    OfflineOpponent? opponent,
    StoneColor? humanColor,
  }) => OfflineGameSetup(
    size: size ?? this.size,
    ruleset: ruleset ?? this.ruleset,
    handicap: handicap ?? this.handicap,
    komi: komi != null ? komi() : this.komi,
    opponent: opponent ?? this.opponent,
    humanColor: humanColor ?? this.humanColor,
  );

  @override
  bool operator ==(Object other) =>
      other is OfflineGameSetup &&
      other.size == size &&
      other.ruleset == ruleset &&
      other.handicap == handicap &&
      other.komi == komi &&
      other.opponent == opponent &&
      other.humanColor == humanColor;

  @override
  int get hashCode => Object.hash(size, ruleset, handicap, komi, opponent, humanColor);
}

enum OfflinePhase { playing, scoring, finished }

@immutable
class OfflineGameState {
  const OfflineGameState({
    required this.setup,
    required this.game,
    this.phase = OfflinePhase.playing,
    this.deadStones = const {},
    this.result,
    this.botThinking = false,
  });

  final OfflineGameSetup setup;
  final GoGame game;
  final OfflinePhase phase;
  final Set<Point> deadStones;

  /// The final result, e.g. `B+3.5` or `W+R`.
  final String? result;
  final bool botThinking;

  GameScore get score => scoreGame(game, deadStones);

  bool get isBotTurn => phase == OfflinePhase.playing && game.toMove == setup.botColor;

  bool get canPlay => phase == OfflinePhase.playing && !isBotTurn && !botThinking;

  OfflineGameState copyWith({
    GoGame? game,
    OfflinePhase? phase,
    Set<Point>? deadStones,
    String? Function()? result,
    bool? botThinking,
  }) => OfflineGameState(
    setup: setup,
    game: game ?? this.game,
    phase: phase ?? this.phase,
    deadStones: deadStones ?? this.deadStones,
    result: result != null ? result() : this.result,
    botThinking: botThinking ?? this.botThinking,
  );
}

/// Overridable so that tests can use a seeded bot.
final simpleBotProvider = Provider<SimpleBot>((ref) => SimpleBot());

/// How long the bot waits before playing, so that its move does not appear instantly.
final botDelayProvider = Provider<Duration>((ref) => const Duration(milliseconds: 350));

final offlineGameProvider = NotifierProvider.autoDispose
    .family<OfflineGameController, OfflineGameState, OfflineGameSetup>(OfflineGameController.new);

/// A game played on the device: pass and play, or against [SimpleBot].
class OfflineGameController extends Notifier<OfflineGameState> {
  OfflineGameController(this.setup);

  final OfflineGameSetup setup;
  Timer? _botTimer;

  @override
  OfflineGameState build() {
    ref.onDispose(() => _botTimer?.cancel());
    return _withBot(OfflineGameState(setup: setup, game: _newGame()));
  }

  GoGame _newGame() => GoGame.create(
    width: setup.size,
    ruleset: setup.ruleset,
    komi: setup.effectiveKomi,
    handicap: setup.handicap,
  );

  /// Plays a stone for the player to move. Returns the reason when the move is illegal.
  IllegalMoveException? play(Point p) {
    if (!state.canPlay) return const IllegalMoveException(IllegalMoveReason.wrongTurn);
    try {
      _apply(state.game.play(p));
      return null;
    } on IllegalMoveException catch (e) {
      return e;
    }
  }

  void pass() {
    if (!state.canPlay) return;
    _apply(state.game.play(null));
  }

  void _apply(GoGame game) {
    final next = state.copyWith(
      game: game,
      phase: game.bothPassed ? OfflinePhase.scoring : OfflinePhase.playing,
      deadStones: const {},
    );
    state = _withBot(next);
  }

  /// Schedules the bot's move if it is its turn, and returns [s] marked accordingly.
  OfflineGameState _withBot(OfflineGameState s) {
    if (!s.isBotTurn) return s;
    _botTimer?.cancel();
    _botTimer = Timer(ref.read(botDelayProvider), () {
      final current = state;
      if (!current.isBotTurn) {
        state = current.copyWith(botThinking: false);
        return;
      }
      final move = ref.read(simpleBotProvider).chooseMove(current.game);
      state = current.copyWith(botThinking: false);
      _apply(current.game.play(move));
    });
    return s.copyWith(botThinking: true);
  }

  /// Takes back the last move, or against the bot the last move of the user.
  void undo() {
    _botTimer?.cancel();
    var game = state.game;
    if (game.moveCount == 0) return;
    game = game.undo();
    final bot = setup.botColor;
    // Against the bot, also take back its reply so that it is the user's turn again.
    while (bot != null && game.moveCount > 0 && game.toMove == bot) {
      game = game.undo();
    }
    state = _withBot(
      state.copyWith(
        game: game,
        phase: OfflinePhase.playing,
        deadStones: const {},
        result: () => null,
        botThinking: false,
      ),
    );
  }

  void resign() {
    _botTimer?.cancel();
    final loser = setup.botColor == null ? state.game.toMove : setup.humanColor;
    state = state.copyWith(
      phase: OfflinePhase.finished,
      result: () => '${loser.opposite.code}+R',
      botThinking: false,
    );
  }

  /// In the scoring phase, marks or unmarks the chain at [p] as dead.
  void toggleDead(Point p) {
    if (state.phase != OfflinePhase.scoring) return;
    state = state.copyWith(deadStones: toggleDeadGroup(state.game.board, state.deadStones, p));
  }

  /// Leaves the scoring phase to keep playing (e.g. to settle a dispute).
  void resumePlay() {
    if (state.phase != OfflinePhase.scoring) return;
    state = _withBot(state.copyWith(phase: OfflinePhase.playing, deadStones: const {}));
  }

  void acceptScore() {
    if (state.phase != OfflinePhase.scoring) return;
    state = state.copyWith(phase: OfflinePhase.finished, result: () => state.score.resultString);
  }

  void restart() {
    _botTimer?.cancel();
    state = _withBot(OfflineGameState(setup: setup, game: _newGame()));
  }
}
