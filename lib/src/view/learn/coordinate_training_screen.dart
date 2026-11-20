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
  int _mistakes = 0;
  bool? _lastCorrect;
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
      _mistakes = 0;
      _lastCorrect = null;
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
      if (correct) {
        _score++;
      } else {
        _mistakes++;
      }
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

    return Scaffold(
      appBar: AppBar(title: const Text('Coordinate training')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedChoice<int>(
                choices: const [Choice(9, '9×9'), Choice(13, '13×13'), Choice(19, '19×19')],
                selected: _size,
                onChanged: _running ? null : (v) => setState(() => _size = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text('Score $_score', style: theme.textTheme.titleMedium),
                  if (_mistakes > 0)
                    Text(
                      '  ·  $_mistakes missed',
                      style: theme.textTheme.titleMedium?.copyWith(color: scheme.error),
                    ),
                  const Spacer(),
                  Text(
                    '0:${math.max(0, remaining.inSeconds).toString().padLeft(2, '0')}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Goban(
                    board: Board.empty(_size, _size),
                    theme: prefs.boardTheme,
                    blackStones: prefs.blackStones,
                    whiteStones: prefs.whiteStones,
                    showCoordinates: false,
                    toPlay: _running ? StoneColor.black : null,
                    onPlay: _tap,
                  ),
                  if (target != null)
                    IgnorePointer(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: theme.textTheme.displayLarge!.copyWith(
                          fontWeight: FontWeight.w800,
                          color: (_lastCorrect == false ? Colors.red : Colors.white).withValues(
                            alpha: 0.9,
                          ),
                          shadows: const [Shadow(blurRadius: 8)],
                        ),
                        child: Text(prettyCoordinate(target, _size)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _running
                  ? Text(
                      'Tap the point shown on the board.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    )
                  : Column(
                      children: [
                        if (best != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('Best on $_size×$_size: $best'),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start'),
                            onPressed: _start,
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
