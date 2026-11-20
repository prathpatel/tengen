import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/learn/coordinate_training.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';
import 'package:tengen/src/widgets/ui.dart';

/// Find as many coordinates as possible in 30 seconds, like the lichess coordinate trainer.
class CoordinateTrainingScreen extends ConsumerStatefulWidget {
  const CoordinateTrainingScreen({super.key});

  static const duration = Duration(seconds: 30);

  @override
  ConsumerState<CoordinateTrainingScreen> createState() => _CoordinateTrainingScreenState();
}

class _CoordinateTrainingScreenState extends ConsumerState<CoordinateTrainingScreen> {
  final _random = math.Random();
  int _size = 9;
  Point? _target;
  int _score = 0;
  bool? _lastCorrect;

  /// The point asked before the current one, for the feedback.
  Point? _lastTarget;
  DateTime? _endsAt;
  Timer? _timer;

  bool get _running => _endsAt != null;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Point _randomPoint() => Point(_random.nextInt(_size), _random.nextInt(_size));

  void _start() {
    _timer?.cancel();
    setState(() {
      _score = 0;
      _lastCorrect = null;
      _lastTarget = null;
      _target = _randomPoint();
      _endsAt = DateTime.now().add(CoordinateTrainingScreen.duration);
    });
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (DateTime.now().isAfter(_endsAt!)) {
        _finish();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final score = _score;
    setState(() {
      _endsAt = null;
      _target = null;
    });
    final best = await ref.read(coordinateBestProvider.notifier).record(_size, score);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(best ? 'New best: $score!' : 'Score: $score')));
  }

  void _tap(Point p) {
    final target = _target;
    if (!_running || target == null) return;
    final correct = p == target;
    if (correct) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _lastCorrect = correct;
      _lastTarget = target;
      if (correct) _score++;
      var next = _randomPoint();
      while (next == target) {
        next = _randomPoint();
      }
      _target = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final prefs = ref.watch(preferencesProvider);
    final best = ref.watch(coordinateBestProvider)[_size];
    final remaining = _running
        ? _endsAt!.difference(DateTime.now())
        : CoordinateTrainingScreen.duration;
    final target = _target;

    final total = CoordinateTrainingScreen.duration.inMilliseconds;
    final left = math.max(0, remaining.inMilliseconds);
    final label = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: 1,
      fontWeight: FontWeight.w600,
    );
    final lastTarget = _lastTarget;

    return Scaffold(
      appBar: const TopBar(title: 'Coordinate training'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: SegmentedChoice<int>(
                choices: const [Choice(9, '9×9'), Choice(13, '13×13'), Choice(19, '19×19')],
                selected: _size,
                onChanged: _running ? null : (v) => setState(() => _size = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SCORE', style: label),
                      Text('$_score', style: theme.textTheme.headlineMedium),
                    ],
                  ),
                  Expanded(
                    child: Text(
                      target == null ? '–' : prettyCoordinate(target, _size),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                        height: 1,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('BEST', style: label),
                      Text(
                        '${best ?? 0}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: left / total, minHeight: 7),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(left / 1000).ceil()} s left',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Goban(
                  board: Board.empty(_size, _size),
                  theme: prefs.boardTheme,
                  blackStones: prefs.blackStones,
                  whiteStones: prefs.whiteStones,
                  showCoordinates: false,
                  toPlay: _running ? StoneColor.black : null,
                  onPlay: _tap,
                  marks: {
                    if (lastTarget != null && _lastCorrect != null)
                      lastTarget: const ShapeMark(ShapeKind.circle),
                  },
                ),
              ),
            ),
            SizedBox(
              height: 56,
              child: Center(
                child: lastTarget == null || _lastCorrect == null
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: _lastCorrect! ? scheme.secondaryContainer : scheme.errorContainer,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          _lastCorrect!
                              ? '${prettyCoordinate(lastTarget, _size)} — correct, +1'
                              : '${prettyCoordinate(lastTarget, _size)} was the circled point',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: _lastCorrect!
                                ? scheme.onSecondaryContainer
                                : scheme.onErrorContainer,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: _running
                  ? Text(
                      'Tap the point shown above. No coordinates on the board — that is the game.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(_lastCorrect == null ? 'Start' : 'Play again'),
                        onPressed: _start,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
