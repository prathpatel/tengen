import 'package:flutter_test/flutter_test.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/learn/lessons.dart';

GoGame start(LessonExercise e) {
  final board = e.board;
  return GoGame.create(
    width: board.width,
    height: board.height,
    initialBoard: board,
    initialPlayer: e.toPlay,
  );
}

void main() {
  test('lesson ids are unique', () {
    expect(goBasics.map((l) => l.id).toSet(), hasLength(goBasics.length));
  });

  for (final lesson in goBasics) {
    for (final (i, exercise) in lesson.exercises.indexed) {
      test('${lesson.id} #${i + 1}: every answer is a legal move', () {
        final game = start(exercise);
        expect(exercise.answers, isNotEmpty);
        for (final p in exercise.answers) {
          expect(game.isLegal(p), isTrue, reason: '$p in\n${game.board}');
        }
      });
    }
  }

  test('capture exercises capture the stones they describe', () {
    final capture = goBasics.firstWhere((l) => l.id == 'capture');
    final expected = [1, 1, 2];
    for (final (i, e) in capture.exercises.indexed) {
      final after = start(e).play(e.answers.single);
      expect(after.position.blackCaptures, expected[i], reason: 'exercise ${i + 1}');
    }
    final suicide = goBasics.firstWhere((l) => l.id == 'suicide').exercises.single;
    expect(start(suicide).play(suicide.answers.single).position.blackCaptures, 2);
  });

  test('atari: extending gives three liberties, capturing saves the stone', () {
    final atari = goBasics.firstWhere((l) => l.id == 'atari').exercises;
    final extended = start(atari[0]).play(atari[0].answers.single);
    expect(extended.board.groupAt(const Point(3, 3))!.liberties, hasLength(3));
    final captured = start(atari[1]).play(atari[1].answers.single);
    expect(captured.position.blackCaptures, 1);
    expect(captured.board.groupAt(const Point(3, 3))!.liberties.length, greaterThan(1));
  });

  test('ko: white cannot recapture at once', () {
    final ko = goBasics.firstWhere((l) => l.id == 'ko').exercises.single;
    final after = start(ko).play(ko.answers.single);
    expect(after.position.blackCaptures, 1);
    expect(after.isLegal(const Point(2, 1)), isFalse);
  });

  test('eyes: the middle point makes two eyes, or kills', () {
    final eyes = goBasics.firstWhere((l) => l.id == 'eyes').exercises;
    final alive = start(eyes[0]).play(eyes[0].answers.single);
    // White can play in neither eye.
    expect(alive.toMove, StoneColor.white);
    expect(alive.isLegal(const Point(1, 0)), isFalse);
    expect(alive.isLegal(const Point(3, 0)), isFalse);
    expect(eyes[1].toPlay, StoneColor.white);
  });
}
