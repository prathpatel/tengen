import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/go/scoring.dart';
import 'package:tengen/src/model/go/sgf.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/widgets/game_layout.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/move_list.dart';
import 'package:tengen/src/widgets/player_bar.dart';
import 'package:tengen/src/widgets/ui.dart';

/// The game without its moves after [ply].
GoGame truncateGame(GoGame game, int ply) {
  var g = game;
  while (g.moveCount > ply) {
    g = g.undo();
  }
  return g;
}

/// Explore a game: step through its moves, try other moves from any position (a variation),
/// and count the territory of a position.
class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({
    required this.game,
    this.title = 'Analysis board',
    this.blackName = 'Black',
    this.whiteName = 'White',
    this.initialPly,
    super.key,
  });

  /// The game as played: the main line.
  final GoGame game;
  final String title;
  final String blackName;
  final String whiteName;

  /// The move shown first; the end of the game when null.
  final int? initialPly;

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  late GoGame _line = widget.game;
  late int _ply = (widget.initialPly ?? widget.game.moveCount).clamp(0, widget.game.moveCount);
  bool _counting = false;
  Set<Point> _dead = {};

  /// The number of moves the current line shares with the game.
  int get _branchPly {
    final n = _line.moveCount < widget.game.moveCount ? _line.moveCount : widget.game.moveCount;
    for (var i = 0; i < n; i++) {
      if (_line.moves[i] != widget.game.moves[i]) return i;
    }
    return n;
  }

  bool get _isVariation => _line.moveCount > widget.game.moveCount || _branchPly < _line.moveCount;

  void _show(int ply) => setState(() {
    _ply = ply.clamp(0, _line.moveCount);
    _dead = {};
  });

  void _play(Point? p) {
    final base = truncateGame(_line, _ply);
    final GoGame next;
    try {
      next = base.play(p);
    } on IllegalMoveException catch (e) {
      showSnack(context, e.message);
      return;
    }
    setState(() {
      // Playing the next move of the line just steps forward; any other move starts a new
      // variation from here.
      final following = _ply < _line.moveCount ? _line.moves[_ply] : null;
      if (following == next.moves.last) {
        _ply++;
      } else {
        _line = next;
        _ply = next.moveCount;
      }
      _dead = {};
    });
  }

  void _backToGame() => setState(() {
    final branch = _branchPly;
    _line = widget.game;
    _ply = branch.clamp(0, widget.game.moveCount);
    _dead = {};
  });

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    final game = _line;
    final position = _line.positions[_ply];
    final score = _counting ? scoreGame(truncateGame(_line, _ply), _dead) : null;
    final variation = _isVariation;

    Widget pill(StoneColor color) {
      final captures = position.capturesOf(color);
      return PlayerPill(
        color: color,
        name: color == StoneColor.black ? widget.blackName : widget.whiteName,
        end: color == StoneColor.black,
        active: !_counting && position.toMove == color,
        detail: [
          '$captures ${captures == 1 ? 'capture' : 'captures'}',
          if (color == StoneColor.white && game.komi != 0) 'komi ${_points(game.komi)}',
        ].join(' · '),
      );
    }

    Future<void> showMenu() => showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (variation)
              ListTile(
                leading: const Icon(Icons.settings_backup_restore_rounded),
                title: const Text('Back to the game'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _backToGame();
                },
              ),
            ListTile(
              leading: const Icon(Icons.first_page_rounded),
              title: const Text('First move'),
              onTap: () {
                Navigator.pop(sheetContext);
                _show(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward_rounded),
              title: Text('Pass (${position.toMove == StoneColor.black ? 'black' : 'white'})'),
              onTap: () {
                Navigator.pop(sheetContext);
                _play(null);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: Text(variation ? 'Copy SGF of this line' : 'Copy SGF'),
              onTap: () {
                Navigator.pop(sheetContext);
                Clipboard.setData(
                  ClipboardData(
                    text: toSgf(_line, blackName: widget.blackName, whiteName: widget.whiteName),
                  ),
                );
                showSnack(context, 'SGF copied to the clipboard');
              },
            ),
          ],
        ),
      ),
    );

    final winner = score?.winner;
    return Scaffold(
      // The warmer, lighter tone of the game screens.
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: TopBar(
        title: widget.title,
        subtitle: score != null
            ? 'Counting · tap the dead stones'
            : variation
            ? 'Variation from move ${_branchPly + 1}'
            : '${game.width}×${game.height} · ${game.ruleset.label}',
        actions: [
          if (variation)
            CircleIconButton(
              icon: Icons.settings_backup_restore_rounded,
              tooltip: 'Back to the game',
              onPressed: _backToGame,
            ),
        ],
      ),
      body: GameLayout(
        above: pill(StoneColor.white),
        below: score != null
            ? ScoreCard(
                lines: [
                  for (final c in StoneColor.values)
                    ScoreLine(
                      color: c,
                      name: c == StoneColor.black ? 'Black' : 'White',
                      detail: scoreDetail(c == StoneColor.black ? score.black : score.white),
                      total: (c == StoneColor.black ? score.black : score.white).total,
                    ),
                ],
                verdict: winner == null
                    ? 'Jigo'
                    : '${winner == StoneColor.black ? 'Black' : 'White'} wins by '
                          '${_points(score.margin)}',
                result: score.resultString,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  pill(StoneColor.black),
                  MoveList(
                    moves: _line.moves,
                    boardHeight: game.height,
                    selected: _ply,
                    onSelect: _show,
                  ),
                ],
              ),
        board: Goban(
          board: position.board,
          theme: prefs.boardTheme,
          blackStones: prefs.blackStones,
          whiteStones: prefs.whiteStones,
          showCoordinates: prefs.showCoordinates,
          sound: prefs.stoneSound,
          lastMove: position.lastMove?.point,
          toPlay: _counting ? null : position.toMove,
          onPlay: _play,
          onTapStone: _counting
              ? (p) => setState(() => _dead = toggleDeadGroup(position.board, _dead, p))
              : null,
          deadStones: _dead,
          territory: score == null
              ? null
              : GobanTerritory(black: score.blackTerritory, white: score.whiteTerritory),
        ),
        actions: RoundActionBar(
          actions: [
            RoundAction(
              icon: Icons.chevron_left_rounded,
              label: 'Previous',
              onPressed: _ply > 0 ? () => _show(_ply - 1) : null,
            ),
            RoundAction(
              icon: Icons.chevron_right_rounded,
              label: 'Next',
              onPressed: _ply < _line.moveCount ? () => _show(_ply + 1) : null,
            ),
            RoundAction(
              icon: Icons.calculate_outlined,
              label: 'Count',
              highlighted: _counting,
              onPressed: () => setState(() {
                _counting = !_counting;
                _dead = {};
              }),
            ),
            RoundAction(icon: Icons.more_horiz_rounded, label: 'More', onPressed: showMenu),
          ],
        ),
      ),
    );
  }
}

String _points(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
