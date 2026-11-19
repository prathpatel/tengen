import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/go/scoring.dart';
import 'package:tengen/src/model/learn/learning_hub.dart';
import 'package:tengen/src/model/puzzle/puzzle.dart';
import 'package:tengen/src/model/puzzle/tree_solver.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/widgets/game_layout.dart';
import 'package:tengen/src/widgets/goban.dart';

/// How long the opponent waits before answering on a Learning Hub page.
final hubReplyDelayProvider = Provider<Duration>((ref) => const Duration(milliseconds: 500));

GobanMark _mark(HubMark m) => switch (m.shape) {
  'triangle' => const ShapeMark(ShapeKind.triangle),
  'square' => const ShapeMark(ShapeKind.square),
  'circle' => const ShapeMark(ShapeKind.circle),
  'cross' => const ShapeMark(ShapeKind.cross),
  _ => LabelMark(m.label ?? ''),
};

/// Plays the pages of a Learning Hub lesson, like the OGS website: an instruction and a
/// position; a move, an answer or a button completes the page ("Great job!"), a wrong one fails
/// it ("Puzzle failed!", retry).
class HubTopicScreen extends ConsumerStatefulWidget {
  const HubTopicScreen({required this.topicId, this.initialPage = 0, super.key});

  final String topicId;
  final int initialPage;

  @override
  ConsumerState<HubTopicScreen> createState() => _HubTopicScreenState();
}

class _HubTopicScreenState extends ConsumerState<HubTopicScreen> {
  late String _topicId = widget.topicId;
  late int _page = widget.initialPage;

  TreeSolver? _solver;
  PuzzleStatus _status = PuzzleStatus.solving;
  String? _chosen;
  Set<Point> _removed = {};
  bool _replying = false;
  Timer? _replyTimer;

  @override
  void dispose() {
    _replyTimer?.cancel();
    super.dispose();
  }

  void _reset() {
    _replyTimer?.cancel();
    setState(() {
      _solver = null;
      _status = PuzzleStatus.solving;
      _chosen = null;
      _removed = {};
      _replying = false;
    });
  }

  void _goTo(String topicId, int page) {
    _reset();
    setState(() {
      _topicId = topicId;
      _page = page;
    });
  }

  void _finish(HubTopic topic, PuzzleStatus status) {
    setState(() => _status = status);
    if (status == PuzzleStatus.correct) {
      HapticFeedback.lightImpact();
      ref.read(hubProgressProvider.notifier).complete(topic, _page);
    } else if (status == PuzzleStatus.wrong) {
      HapticFeedback.heavyImpact();
    }
  }

  void _play(HubTopic topic, HubPage page, Point p) {
    final tree = page.moveTree;
    if (tree == null || _status != PuzzleStatus.solving || _replying) return;
    final solver = _solver ?? TreeSolver.start(page.board, page.toPlay, tree);
    final TreeSolver next;
    try {
      next = solver.play(p);
    } on IllegalMoveException catch (e) {
      showSnack(context, e.message);
      return;
    }
    setState(() => _solver = next);
    if (next.status != PuzzleStatus.solving) {
      _finish(topic, next.status);
      return;
    }
    setState(() => _replying = true);
    _replyTimer = Timer(ref.read(hubReplyDelayProvider), () {
      if (!mounted) return;
      final answered = next.reply();
      setState(() {
        _solver = answered;
        _replying = false;
      });
      if (answered.status != PuzzleStatus.solving) _finish(topic, answered.status);
    });
  }

  void _choose(HubTopic topic, HubChoice choice, String value) {
    if (_status != PuzzleStatus.solving) return;
    setState(() => _chosen = value);
    _finish(topic, value == choice.correct ? PuzzleStatus.correct : PuzzleStatus.wrong);
  }

  void _toggleRemoved(HubTopic topic, HubPage page, HubRemoval removal, Point p) {
    if (_status != PuzzleStatus.solving) return;
    final removed = toggleDeadGroup(page.board, _removed, p);
    setState(() => _removed = removed);
    if (removed.length == removal.stones.length && removed.containsAll(removal.stones)) {
      _finish(topic, PuzzleStatus.correct);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hub = ref.watch(learningHubProvider).value;
    final done = ref.watch(hubProgressProvider);
    final prefs = ref.watch(preferencesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topic = hub?.topics.where((t) => t.id == _topicId).firstOrNull;
    if (hub == null || topic == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final page = topic.pages[_page.clamp(0, topic.pages.length - 1)];
    final nextTopic = hub.topicAfter(topic);
    final isLastPage = _page >= topic.pages.length - 1;
    void next() {
      if (!isLastPage) {
        _goTo(topic.id, _page + 1);
      } else if (nextTopic != null) {
        _goTo(nextTopic.id, 0);
      } else {
        Navigator.pop(context);
      }
    }

    final solver = _solver;
    final board = solver?.game.board ?? page.board;
    final vp = page.viewport;
    final special = page.special;
    final choice = page.choice;
    final canPlay =
        page.moveTree != null &&
        special is! HubButton &&
        _status == PuzzleStatus.solving &&
        !_replying;

    final (Color bg, Color fg) = switch (_status) {
      PuzzleStatus.correct => (Colors.green.shade700, Colors.white),
      PuzzleStatus.wrong => (scheme.errorContainer, scheme.onErrorContainer),
      PuzzleStatus.solving => (scheme.surfaceContainerHigh, scheme.onSurface),
    };

    final instruction = Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_status == PuzzleStatus.correct)
            Row(
              children: [
                Icon(Icons.check_circle, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Great job!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green.shade800,
                  ),
                  onPressed: next,
                  child: Text(isLastPage && nextTopic == null ? 'Done' : 'Next'),
                ),
              ],
            )
          else if (_status == PuzzleStatus.wrong)
            Row(
              children: [
                Icon(Icons.cancel, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Puzzle failed!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton(onPressed: _reset, child: const Text('Retry')),
              ],
            )
          else ...[
            Text(
              choice?.question ?? page.text ?? '',
              style: theme.textTheme.bodyLarge?.copyWith(color: fg),
            ),
            if (special case HubButton(:final label))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: FilledButton(
                  onPressed: () => _finish(topic, PuzzleStatus.correct),
                  child: Text(label),
                ),
              ),
          ],
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: GameTitle(
          icon: Icons.school_outlined,
          title: '${topic.number} ${topic.title}',
          subtitle: 'Page ${_page + 1} of ${topic.pages.length}',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: topic.pages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final isDone = done.contains(HubProgressController.key(topic, i));
                  final current = i == _page;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => current ? _reset() : _goTo(topic.id, i),
                    child: Container(
                      width: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: current
                            ? scheme.primary
                            : (isDone ? scheme.primaryContainer : scheme.surfaceContainerHigh),
                      ),
                      child: isDone && !current
                          ? Icon(Icons.star_rounded, size: 18, color: scheme.onPrimaryContainer)
                          : Text(
                              '${i + 1}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: current ? scheme.onPrimary : null,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
            instruction,
            Expanded(
              child: Center(
                child: Goban(
                  board: board,
                  viewport: vp == null ? null : GobanViewport(vp.left, vp.top, vp.right, vp.bottom),
                  marks: (solver?.game.moveCount ?? 0) == 0
                      ? {for (final e in page.marks.entries) e.key: _mark(e.value)}
                      : const {},
                  theme: prefs.boardTheme,
                  showCoordinates: prefs.showCoordinates,
                  lastMove: solver?.game.position.lastMove?.point,
                  toPlay: canPlay ? (solver?.game.toMove ?? page.toPlay) : null,
                  onPlay: (p) => _play(topic, page, p),
                  onTapStone: special is HubRemoval && _status == PuzzleStatus.solving
                      ? (p) => _toggleRemoved(topic, page, special, p)
                      : null,
                  deadStones: _removed,
                ),
              ),
            ),
            if (choice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    for (final (i, option) in choice.options.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: _chosen == option.value
                                  ? (option.value == choice.correct
                                        ? Colors.green.shade700
                                        : scheme.error)
                                  : null,
                              foregroundColor: _chosen == option.value ? Colors.white : null,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            onPressed: _status == PuzzleStatus.solving
                                ? () => _choose(topic, choice, option.value)
                                : null,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(option.label, maxLines: 1),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GameAction(
                      icon: Icons.refresh,
                      tooltip: 'Start the page again',
                      onPressed: _reset,
                    ),
                    GameAction(
                      icon: Icons.lightbulb_outline,
                      tooltip: 'Hint',
                      onPressed: page.moveTree != null && canPlay
                          ? () {
                              final s =
                                  _solver ??
                                  TreeSolver.start(page.board, page.toPlay, page.moveTree!);
                              final hint = s.hint();
                              showSnack(
                                context,
                                hint.isEmpty
                                    ? 'No hint here'
                                    : 'Try ${hint.map((p) => prettyCoordinate(p, page.board.height)).join(' or ')}',
                              );
                            }
                          : null,
                    ),
                    GameAction(
                      icon: Icons.chevron_left,
                      tooltip: 'Previous page',
                      large: true,
                      onPressed: _page > 0 ? () => _goTo(topic.id, _page - 1) : null,
                    ),
                    GameAction(
                      icon: Icons.chevron_right,
                      tooltip: 'Next page',
                      large: true,
                      onPressed: isLastPage && nextTopic == null ? null : next,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
