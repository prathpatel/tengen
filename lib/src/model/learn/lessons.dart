import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/settings/preferences.dart';

/// A position where the learner must find one of the [answers].
@immutable
class LessonExercise {
  const LessonExercise({
    required this.prompt,
    required this.position,
    required this.answers,
    required this.explanation,
    this.toPlay = StoneColor.black,
  });

  final String prompt;

  /// ASCII board: `X` black, `O` white, `.` empty (see [Board.parse]).
  final String position;
  final List<Point> answers;

  /// Shown once the exercise is solved.
  final String explanation;
  final StoneColor toPlay;

  Board get board => Board.parse(position);
}

@immutable
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.summary,
    required this.text,
    this.exercises = const [],
  });

  final String id;
  final String title;
  final String summary;

  /// The explanation shown before the exercises.
  final String text;
  final List<LessonExercise> exercises;
}

/// The basics of Go, as short interactive lessons.
const goBasics = [
  Lesson(
    id: 'stones',
    title: 'Stones and liberties',
    summary: 'How stones are placed and what keeps them alive.',
    text:
        'Go is played on the intersections of the lines. Black plays first, then the players '
        'take turns placing one stone. Stones never move.\n\n'
        'The empty points next to a stone, along the lines, are its liberties. A stone in the '
        'middle has four.',
    exercises: [
      LessonExercise(
        prompt: 'The white stone has four liberties. Play on one of them.',
        position: '''
          .......
          .......
          .......
          ...O...
          .......
          .......
          .......
        ''',
        answers: [Point(2, 3), Point(4, 3), Point(3, 2), Point(3, 4)],
        explanation: 'Right! Each black stone next to it takes away one of its liberties.',
      ),
    ],
  ),
  Lesson(
    id: 'capture',
    title: 'Capturing',
    summary: 'Take the last liberty to capture stones.',
    text:
        'When a stone or a group of connected stones loses its last liberty, it is captured: '
        'it is removed from the board and becomes a prisoner.',
    exercises: [
      LessonExercise(
        prompt: 'The white stone has one liberty left. Capture it.',
        position: '''
          .......
          .......
          ...X...
          ..XOX..
          .......
          .......
          .......
        ''',
        answers: [Point(3, 4)],
        explanation: 'Captured! The white stone is removed from the board.',
      ),
      LessonExercise(
        prompt: 'Stones on the edge have fewer liberties. Capture the white stone.',
        position: '''
          .......
          .......
          X......
          OX.....
          .......
          .......
          .......
        ''',
        answers: [Point(0, 4)],
        explanation: 'On the edge, a stone has only three liberties: easier to capture.',
      ),
      LessonExercise(
        prompt: 'Connected stones share their liberties. Capture both white stones.',
        position: '''
          .......
          .......
          ...XX..
          ..XOOX.
          ...X...
          .......
          .......
        ''',
        answers: [Point(4, 4)],
        explanation: 'Both stones are captured together: a group lives or dies as one.',
      ),
    ],
  ),
  Lesson(
    id: 'atari',
    title: 'Atari',
    summary: 'Save your stones when they have one liberty left.',
    text:
        'A stone with only one liberty left is in atari: it can be captured on the next move. '
        'To save it, give it more liberties by extending, or capture the stones that threaten '
        'it.',
    exercises: [
      LessonExercise(
        prompt: 'Your stone is in atari. Save it by extending.',
        position: '''
          .......
          .......
          ...O...
          ..OXO..
          .......
          .......
          .......
        ''',
        answers: [Point(3, 4)],
        explanation: 'Your two stones now have three liberties together.',
      ),
      LessonExercise(
        prompt: 'Your stone is in atari, but so is a white stone. Capture it!',
        position: '''
          .......
          .......
          ...OX..
          ..OXOX.
          .......
          .......
          .......
        ''',
        answers: [Point(4, 4)],
        explanation: 'Capturing the stone gives your own stone a new liberty.',
      ),
    ],
  ),
  Lesson(
    id: 'suicide',
    title: 'Forbidden moves',
    summary: 'Points where you may not play, and the exception.',
    text:
        'You may not play a stone where it would have no liberties: that would be suicide. '
        'There is one exception: the move is allowed if it captures, because the captured '
        'stones free liberties for it.',
    exercises: [
      LessonExercise(
        prompt:
            'The corner point has no liberties for black, but playing there captures. Take the '
            'two white stones.',
        position: '''
          .OX....
          OX.....
          X......
          .......
          .......
          .......
          .......
        ''',
        answers: [Point(0, 0)],
        explanation: 'The move is legal because it captures both white stones.',
      ),
    ],
  ),
  Lesson(
    id: 'ko',
    title: 'Ko',
    summary: 'Why you cannot always recapture at once.',
    text:
        'Sometimes a capture could be answered by an immediate recapture, and the position '
        'would repeat forever. This is called ko. The rule: after a stone is captured in a ko, '
        'the other player must play elsewhere first before recapturing.',
    exercises: [
      LessonExercise(
        prompt: 'Capture the white stone in the ko.',
        position: '''
          .OX....
          O.OX...
          .OX....
          .......
          .......
          .......
          .......
        ''',
        answers: [Point(1, 1)],
        explanation:
            'You captured. White may not take back right away: white must play elsewhere '
            'first, for example a threat you have to answer.',
      ),
    ],
  ),
  Lesson(
    id: 'eyes',
    title: 'Life and eyes',
    summary: 'A group with two eyes can never be captured.',
    text:
        'An eye is an empty point surrounded by your stones. The opponent cannot play there '
        'unless it captures. A group with two separate eyes can never be captured: it is '
        'alive. With only one eye, it can be surrounded and captured.',
    exercises: [
      LessonExercise(
        prompt: 'Black has a space of three points. Make two eyes.',
        position: '''
          X...XO.
          XXXXXO.
          OOOOOO.
          .......
          .......
          .......
          .......
        ''',
        answers: [Point(2, 0)],
        explanation: 'Playing in the middle splits the space into two eyes: black is alive.',
      ),
      LessonExercise(
        prompt: 'Now you are white. Stop black from making two eyes.',
        toPlay: StoneColor.white,
        position: '''
          X...XO.
          XXXXXO.
          OOOOOO.
          .......
          .......
          .......
          .......
        ''',
        answers: [Point(2, 0)],
        explanation: 'Black can only make one eye now: the group is dead.',
      ),
    ],
  ),
  Lesson(
    id: 'score',
    title: 'Ending and counting',
    summary: 'How the game ends and who wins.',
    text:
        'When neither player sees a useful move, both pass and the game ends. Groups that '
        'could not avoid capture are removed as dead stones.\n\n'
        'Each player then counts their territory, the empty points they surround. With '
        'Japanese rules you add the prisoners you took; with Chinese rules you add your stones '
        'on the board instead. White gets komi, usually 6.5 or 7.5 points, for playing second.\n\n'
        'The higher score wins. Try it: play the computer on a 9×9 board!',
  ),
];

/// The ids of the lessons completed, saved on the device.
final lessonProgressProvider = NotifierProvider<LessonProgressController, Set<String>>(
  LessonProgressController.new,
);

class LessonProgressController extends Notifier<Set<String>> {
  static const _key = 'learn.completedLessons';

  @override
  Set<String> build() =>
      (ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const []).toSet();

  Future<void> complete(String lessonId) async {
    if (state.contains(lessonId)) return;
    state = {...state, lessonId};
    await ref.read(sharedPreferencesProvider).setStringList(_key, state.toList());
  }
}

/// Best scores of the coordinate training, by board size.
final coordinateBestProvider = NotifierProvider<CoordinateBestController, Map<int, int>>(
  CoordinateBestController.new,
);

class CoordinateBestController extends Notifier<Map<int, int>> {
  static String _key(int size) => 'learn.coordinates.best.$size';

  @override
  Map<int, int> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return {
      for (final size in const [9, 13, 19]) size: ?prefs.getInt(_key(size)),
    };
  }

  /// Records a score; returns true when it is a new best.
  Future<bool> record(int size, int score) async {
    if (score <= (state[size] ?? 0)) return false;
    state = {...state, size: score};
    await ref.read(sharedPreferencesProvider).setInt(_key(size), score);
    return true;
  }
}
