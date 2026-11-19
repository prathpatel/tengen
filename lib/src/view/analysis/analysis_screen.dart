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
    final theme = Theme.of(context);
    final game = _line;
    final position = _line.positions[_ply];
    final score = _counting ? scoreGame(truncateGame(_line, _ply), _dead) : null;
    final variation = _isVariation;

    Widget bar(StoneColor color) => PlayerBar(
      color: color,
      name: color == StoneColor.black ? widget.blackName : widget.whiteName,
      captures: position.capturesOf(color),
      komi: color == StoneColor.white ? game.komi : null,
      active: !_counting && position.toMove == color,
    );

    return Scaffold(
      appBar: AppBar(
        title: GameTitle(
          icon: Icons.biotech_outlined,
          title: widget.title,
          subtitle: score != null
              ? 'Count · ${score.resultString} '
                    '(B ${score.black.total} · W ${score.white.total}) · tap dead stones'
              : variation
              ? 'Variation from move ${_branchPly + 1}'
              : '${game.width}×${game.height} · ${game.ruleset.label}',
        ),
      ),
      body: GameLayout(
        moveList: MoveList(
          moves: _line.moves,
          boardHeight: game.height,
          selected: _ply,
          onSelect: _show,
        ),
        topPlayer: bar(StoneColor.white),
        bottomPlayer: bar(StoneColor.black),
        board: Goban(
          board: position.board,
          theme: prefs.boardTheme,
          showCoordinates: prefs.showCoordinates,
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
        actions: [
          GameAction(
            icon: Icons.menu,
            tooltip: 'Menu',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (sheetContext) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (variation)
                      ListTile(
                        leading: const Icon(Icons.undo),
                        title: const Text('Back to the game'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _backToGame();
                        },
                      ),
                    ListTile(
                      leading: const Icon(Icons.front_hand_outlined),
                      title: Text(
                        'Pass (${position.toMove == StoneColor.black ? 'black' : 'white'})',
                      ),
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
                            text: toSgf(
                              _line,
                              blackName: widget.blackName,
                              whiteName: widget.whiteName,
                            ),
                          ),
                        );
                        showSnack(context, 'SGF copied to the clipboard');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (variation)
            GameAction(
              icon: Icons.settings_backup_restore,
              tooltip: 'Back to the game',
              onPressed: _backToGame,
            ),
          GameAction(
            icon: _counting ? Icons.calculate : Icons.calculate_outlined,
            tooltip: _counting ? 'Stop counting' : 'Count territory',
            onPressed: () => setState(() {
              _counting = !_counting;
              _dead = {};
            }),
          ),
          GameAction(
            icon: Icons.first_page,
            tooltip: 'First move',
            onPressed: _ply > 0 ? () => _show(0) : null,
          ),
          GameAction(
            icon: Icons.chevron_left,
            tooltip: 'Previous move',
            large: true,
            onPressed: _ply > 0 ? () => _show(_ply - 1) : null,
          ),
          GameAction(
            icon: Icons.chevron_right,
            tooltip: 'Next move',
            large: true,
            onPressed: _ply < _line.moveCount ? () => _show(_ply + 1) : null,
          ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }
}
