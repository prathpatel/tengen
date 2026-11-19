import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/learn/learning_hub.dart';
import 'package:tengen/src/model/puzzle/puzzle.dart';

void main() {
  final hub = LearningHub.fromJson(
    jsonDecode(File('assets/learning_hub/learning_hub.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('has the whole OGS Learning Hub', () {
    expect(hub.sections.map((s) => s.title), [
      'Fundamentals',
      'Basic Principles',
      'Basic Skills',
      'Beginner Level 1',
      'Beginner Level 2',
      'Beginner Level 3',
      'Beginner Level 4',
    ]);
    expect(hub.topics, hasLength(248));
    expect(hub.pageCount, 3551);
    expect(hub.topics.map((t) => t.id).toSet(), hasLength(248));
    expect(hub.topics.first.number, '1.1');
  });

  test('every page can be completed', () {
    var puzzles = 0;
    var choices = 0;
    var special = 0;
    for (final topic in hub.topics) {
      for (final (i, page) in topic.pages.indexed) {
        final where = '${topic.id}/${i + 1}';
        expect(page.text ?? page.choice?.question, isNotEmpty, reason: where);
        final vp = page.viewport;
        if (vp != null) {
          expect(vp.left >= 0 && vp.top >= 0, isTrue, reason: where);
          expect(
            vp.right < page.board.width && vp.bottom < page.board.height,
            isTrue,
            reason: where,
          );
        }
        if (page.special != null) {
          special++;
        } else if (page.choice case final choice?) {
          choices++;
          expect(choice.options.map((o) => o.value), contains(choice.correct), reason: where);
        } else {
          puzzles++;
          expect(page.moveTree, isNotNull, reason: where);
        }
      }
    }
    expect((puzzles, choices, special), (3028, 520, 3));
  });

  test("every correct answer is legal for the app's rules engine", () {
    final illegal = <String>[];
    var lines = 0;
    for (final topic in hub.topics) {
      for (final (i, page) in topic.pages.indexed) {
        final tree = page.moveTree;
        if (tree == null || page.special != null) continue;
        final start = GoGame.create(
          width: page.board.width,
          height: page.board.height,
          initialBoard: page.board,
          initialPlayer: page.toPlay,
        );
        // Walk every line that ends on a correct answer.
        void walk(GoGame game, PuzzleNode node, String path) {
          for (final b in node.branches) {
            final GoGame next;
            try {
              next = game.play(b.point);
            } on IllegalMoveException catch (e) {
              if (b.correct || _leadsToCorrect(b)) {
                illegal.add('${topic.id}/${i + 1} $path ${b.point}: ${e.reason}');
              }
              continue;
            }
            if (b.correct) lines++;
            walk(next, b, '$path ${b.point}');
          }
        }

        walk(start, tree, '');
      }
    }
    expect(illegal, isEmpty);
    expect(lines, greaterThan(3028));
  });

  test('special pages', () {
    final ending = hub.topics.firstWhere((t) => t.id == 'ending-the-game');
    expect((ending.pages[0].special! as HubButton).label, 'Pass');
    expect((ending.pages[2].special! as HubButton).label, 'Finish');
    final removal = ending.pages[1].special! as HubRemoval;
    expect(removal.stones, hasLength(4));
    expect(removal.stones.every((p) => ending.pages[1].board[p] == StoneColor.black), isTrue);
  });
}

bool _leadsToCorrect(PuzzleNode n) => n.correct || n.branches.any(_leadsToCorrect);
