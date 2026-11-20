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
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/ui.dart';

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

  /// The hint shown: the moves to try.
  Set<Point>? _hint;

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
      _hint = null;
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
    setState(() {
      _solver = next;
      _hint = null;
    });
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
      return const Scaffold(
        appBar: TopBar(),
        body: Center(child: CircularProgressIndicator()),
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

    final hint = _hint;
    final nextLabel = !isLastPage ? 'Next page' : (nextTopic == null ? 'Done' : 'Next lesson');

    // The result, or a hint, under the board.
    final Widget? card = switch (_status) {
      PuzzleStatus.correct => _ResultCard(
        icon: Icons.check_rounded,
        title: 'Great job!',
        color: scheme.secondary,
        background: scheme.secondaryContainer,
      ),
      PuzzleStatus.wrong => _ResultCard(
        icon: Icons.close_rounded,
        title: 'Not quite',
        text: 'Start the page again with the retry button.',
        color: scheme.error,
        background: scheme.errorContainer,
      ),
      PuzzleStatus.solving when hint != null => _ResultCard(
        icon: Icons.lightbulb_outline_rounded,
        title: hint.isEmpty
            ? 'No hint here'
            : 'Hint: try ${hint.map((p) => prettyCoordinate(p, page.board.height)).join(' or ')}',
        text: hint
            .map((p) => (_solver?.node ?? page.moveTree)?.branchAt(p)?.text)
            .nonNulls
            .firstOrNull,
        color: scheme.primary,
        background: scheme.surfaceContainer,
        outlined: true,
      ),
      _ => null,
    };

    final pages = topic.pages.length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 20, 0),
              child: Row(
                children: [
                  const CircleBackButton(icon: Icons.close_rounded),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                topic.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            Text(
                              'Page ${_page + 1} of $pages',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // One segment per page: done and current ones in the accent.
                        Row(
                          children: [
                            for (var i = 0; i < pages; i++) ...[
                              if (i > 0) SizedBox(width: pages > 12 ? 3 : 5),
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  label: 'Page ${i + 1}',
                                  child: GestureDetector(
                                    onTap: () => i == _page ? _reset() : _goTo(topic.id, i),
                                    child: Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color:
                                            i == _page ||
                                                done.contains(HubProgressController.key(topic, i))
                                            ? scheme.primary
                                            : scheme.surfaceContainerHighest,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
              child: Text(
                choice?.question ?? page.text ?? '',
                style: theme.textTheme.titleLarge?.copyWith(height: 1.3, fontSize: 22),
              ),
            ),
            if (special case HubButton(:final label) when _status == PuzzleStatus.solving)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () => _finish(topic, PuzzleStatus.correct),
                    child: Text(label),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: Goban(
                  board: board,
                  viewport: vp == null ? null : GobanViewport(vp.left, vp.top, vp.right, vp.bottom),
                  marks: {
                    if ((solver?.game.moveCount ?? 0) == 0)
                      for (final e in page.marks.entries) e.key: _mark(e.value),
                    for (final p in hint ?? const <Point>{}) p: const ShapeMark(ShapeKind.circle),
                  },
                  theme: prefs.boardTheme,
                  blackStones: prefs.blackStones,
                  whiteStones: prefs.whiteStones,
                  showCoordinates: prefs.showCoordinates,
                  sound: prefs.stoneSound,
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    for (final (i, option) in choice.options.indexed) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _chosen == option.value
                                ? (option.value == choice.correct ? scheme.secondary : scheme.error)
                                : scheme.surfaceContainer,
                            foregroundColor: _chosen == option.value
                                ? scheme.onSecondary
                                : scheme.onSurface,
                            disabledBackgroundColor: _chosen == option.value
                                ? (option.value == choice.correct ? scheme.secondary : scheme.error)
                                : scheme.surfaceContainer,
                            disabledForegroundColor: _chosen == option.value
                                ? scheme.onSecondary
                                : scheme.onSurfaceVariant,
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
                    ],
                  ],
                ),
              ),
            ?card,
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Tooltip(
                    message: 'Start the page again',
                    child: Material(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _reset,
                        child: const SizedBox.square(
                          dimension: 56,
                          child: Icon(Icons.refresh_rounded),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _status == PuzzleStatus.correct
                        ? FilledButton(
                            onPressed: next,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(nextLabel),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          )
                        : page.moveTree != null && special is! HubButton
                        ? FilledButton(
                            style: softButtonStyle(context),
                            onPressed: canPlay
                                ? () {
                                    final s =
                                        _solver ??
                                        TreeSolver.start(page.board, page.toPlay, page.moveTree!);
                                    setState(() => _hint = hint == null ? s.hint() : null);
                                  }
                                : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lightbulb_outline_rounded),
                                const SizedBox(width: 8),
                                Text(hint == null ? 'Hint' : 'Hide hint'),
                              ],
                            ),
                          )
                        : FilledButton(
                            style: softButtonStyle(context),
                            onPressed: isLastPage && nextTopic == null ? null : next,
                            child: const Text('Skip page'),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The result of a page, or a hint.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.background,
    this.text,
    this.outlined = false,
  });

  final IconData icon;
  final String title;
  final String? text;
  final Color color;
  final Color background;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: outlined ? color : color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: background, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // Its own height: under the board, the card must not take the board's room.
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(color: color)),
                  if (text != null)
                    Text(
                      text!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
