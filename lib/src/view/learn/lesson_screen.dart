import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/learn/lessons.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/widgets/goban.dart';

/// An interactive lesson: an explanation, then positions where the learner finds the move.
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({required this.lesson, super.key});

  final Lesson lesson;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  late Lesson _lesson = widget.lesson;
  int _exercise = 0;
  late GoGame _game = _start();
  bool _solved = false;
  bool _wrong = false;

  LessonExercise? get _current =>
      _exercise < _lesson.exercises.length ? _lesson.exercises[_exercise] : null;

  GoGame _start() {
    final e = _current;
    if (e == null) return GoGame.create(width: 7);
    final board = e.board;
    return GoGame.create(
      width: board.width,
      height: board.height,
      initialBoard: board,
      initialPlayer: e.toPlay,
    );
  }

  void _play(LessonExercise exercise, Point p) {
    final GoGame next;
    try {
      next = _game.play(p);
    } on IllegalMoveException catch (e) {
      showSnack(context, e.message);
      return;
    }
    setState(() {
      _game = next;
      _solved = exercise.answers.contains(p);
      _wrong = !_solved;
    });
    if (_solved && _exercise == _lesson.exercises.length - 1) {
      ref.read(lessonProgressProvider.notifier).complete(_lesson.id);
    }
  }

  void _retry() => setState(() {
    _game = _start();
    _solved = false;
    _wrong = false;
  });

  void _nextExercise() => setState(() {
    _exercise++;
    _game = _start();
    _solved = false;
    _wrong = false;
  });

  void _openLesson(Lesson lesson) => setState(() {
    _lesson = lesson;
    _exercise = 0;
    _game = _start();
    _solved = false;
    _wrong = false;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final prefs = ref.watch(preferencesProvider);
    final exercise = _current;
    final lessonIndex = goBasics.indexWhere((l) => l.id == _lesson.id);
    final nextLesson = lessonIndex >= 0 && lessonIndex < goBasics.length - 1
        ? goBasics[lessonIndex + 1]
        : null;
    final lastExercise = _exercise >= _lesson.exercises.length - 1;

    // Lessons without exercises complete when read.
    if (_lesson.exercises.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(lessonProgressProvider.notifier).complete(_lesson.id),
      );
    }

    final Widget? action = exercise == null || _solved
        ? (exercise != null && !lastExercise
              ? FilledButton(onPressed: _nextExercise, child: const Text('Next exercise'))
              : nextLesson != null
              ? FilledButton(
                  onPressed: () => _openLesson(nextLesson),
                  child: Text('Next lesson: ${nextLesson.title}'),
                )
              : FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')))
        : _wrong
        ? OutlinedButton(onPressed: _retry, child: const Text('Try again'))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_lesson.title),
            Text(
              'Lesson ${lessonIndex + 1} of ${goBasics.length}'
              '${_lesson.exercises.isEmpty ? '' : ' · exercise ${_exercise + 1} of ${_lesson.exercises.length}'}',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(_lesson.text, style: theme.textTheme.bodyLarge),
            ),
            if (exercise != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _solved
                      ? Colors.green.shade700
                      : (_wrong ? scheme.errorContainer : scheme.surfaceContainerHigh),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      _solved
                          ? Icons.check_circle
                          : (_wrong ? Icons.cancel : Icons.touch_app_outlined),
                      color: _solved
                          ? Colors.white
                          : (_wrong ? scheme.onErrorContainer : scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _solved
                            ? exercise.explanation
                            : (_wrong ? 'Not quite. Try again!' : exercise.prompt),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: _solved ? Colors.white : (_wrong ? scheme.onErrorContainer : null),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Goban(
                  board: _game.board,
                  theme: prefs.boardTheme,
                  showCoordinates: false,
                  lastMove: _game.position.lastMove?.point,
                  toPlay: _solved || _wrong ? null : _game.toMove,
                  onPlay: (p) => _play(exercise, p),
                ),
              ),
            ],
            if (action != null)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: action),
          ],
        ),
      ),
    );
  }
}
