import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/puzzle/puzzle.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/json.dart';

/// The OGS Learning Hub: the interactive course of online-go.com, converted from its source by
/// `tool/learning_hub/convert.mjs` (content under the GNU AGPL v3, see COPYING.md).
@immutable
class LearningHub {
  const LearningHub(this.sections);

  factory LearningHub.fromJson(Map<String, dynamic> json) => LearningHub([
    for (final (i, s) in asList(json['sections']).indexed)
      HubSection.fromJson(i, asMap(s) ?? const {}),
  ]);

  final List<HubSection> sections;

  Iterable<HubTopic> get topics => sections.expand((s) => s.topics);

  int get pageCount => topics.fold(0, (n, t) => n + t.pages.length);

  /// The topic after [topic], across sections; null after the last one.
  HubTopic? topicAfter(HubTopic topic) {
    final all = topics.toList();
    final i = all.indexWhere((t) => t.id == topic.id);
    return i >= 0 && i < all.length - 1 ? all[i + 1] : null;
  }
}

@immutable
class HubSection {
  const HubSection({required this.index, required this.title, required this.topics});

  factory HubSection.fromJson(int index, Map<String, dynamic> json) => HubSection(
    index: index,
    title: json['title'] as String? ?? '',
    topics: [
      for (final (i, t) in asList(json['topics']).indexed)
        HubTopic.fromJson(index, i, asMap(t) ?? const {}),
    ],
  );

  final int index;
  final String title;
  final List<HubTopic> topics;
}

@immutable
class HubTopic {
  const HubTopic({
    required this.id,
    required this.number,
    required this.title,
    required this.subtext,
    required this.pages,
  });

  factory HubTopic.fromJson(int section, int index, Map<String, dynamic> json) => HubTopic(
    id: json['id'] as String? ?? '$section-$index',
    number: '${section + 1}.${index + 1}',
    title: json['title'] as String? ?? '',
    subtext: json['subtext'] as String? ?? '',
    pages: [for (final p in asList(json['pages'])) HubPage.fromJson(asMap(p) ?? const {})],
  );

  /// Stable id, e.g. `capture-stone`.
  final String id;

  /// Numbering as on OGS, e.g. `2.5`.
  final String number;
  final String title;
  final String subtext;
  final List<HubPage> pages;
}

/// A multiple choice question.
@immutable
class HubChoice {
  const HubChoice({required this.question, required this.options, required this.correct});

  final String question;
  final List<({String value, String label})> options;
  final String correct;
}

/// A page completed by something else than a move: pressing a button, or removing dead stones.
sealed class HubSpecial {
  const HubSpecial();
}

class HubButton extends HubSpecial {
  const HubButton(this.label);

  final String label;
}

class HubRemoval extends HubSpecial {
  const HubRemoval(this.stones);

  /// The dead stones to mark.
  final Set<Point> stones;
}

@immutable
class HubPage {
  const HubPage({
    required this.board,
    required this.toPlay,
    this.text,
    this.choice,
    this.moveTree,
    this.viewport,
    this.marks = const {},
    this.special,
  });

  factory HubPage.fromJson(Map<String, dynamic> json) {
    final config = asMap(json['config']) ?? const {};
    final width = asInt(config['width']) ?? 9;
    final height = asInt(config['height']) ?? 9;
    final state = asMap(config['initial_state']) ?? const {};
    final board = Board.empty(width, height)
        .withStones(decodeOgsMoves(state['black'] as String? ?? '').nonNulls, StoneColor.black)
        .withStones(decodeOgsMoves(state['white'] as String? ?? '').nonNulls, StoneColor.white);
    final bounds = asMap(config['bounds']);
    final choice = asMap(json['choice']);
    final special = asMap(json['special']);
    final tree = asMap(config['move_tree']);
    return HubPage(
      board: board,
      toPlay: config['initial_player'] == 'white' ? StoneColor.white : StoneColor.black,
      text: json['text'] as String?,
      choice: choice == null
          ? null
          : HubChoice(
              question: choice['question'] as String? ?? '',
              options: [
                for (final o in asList(choice['options']))
                  if (asMap(o) case final m?)
                    (value: m['value'].toString(), label: m['label'].toString()),
              ],
              correct: choice['correct'].toString(),
            ),
      moveTree: tree == null ? null : PuzzleNode.fromJson(tree),
      viewport: bounds == null
          ? null
          : (
              left: asInt(bounds['left']) ?? 0,
              top: asInt(bounds['top']) ?? 0,
              right: asInt(bounds['right']) ?? width - 1,
              bottom: asInt(bounds['bottom']) ?? height - 1,
            ),
      marks: _parseMarks(asMap(config['marks'])),
      special: switch (special?['type']) {
        'button' => HubButton(special!['label'] as String? ?? 'OK'),
        'remove' => HubRemoval(
          decodeOgsMoves(special!['stones'] as String? ?? '').nonNulls.toSet(),
        ),
        _ => null,
      },
    );
  }

  /// OGS marks: `{"A": "aq", "1": "ep", "triangle": "efdf", "cross": ..., "square": ...}`.
  static Map<Point, HubMark> _parseMarks(Map<String, dynamic>? json) => {
    for (final MapEntry(:key, :value) in (json ?? const <String, dynamic>{}).entries)
      if (value is String)
        for (final p in decodeOgsMoves(value).nonNulls)
          p: switch (key) {
            'triangle' => HubMark.triangle,
            'square' => HubMark.square,
            'circle' => HubMark.circle,
            'cross' => HubMark.cross,
            _ => HubMark.label(key),
          },
  };

  final Board board;
  final StoneColor toPlay;

  /// The instruction, for move and special pages.
  final String? text;
  final HubChoice? choice;
  final PuzzleNode? moveTree;
  final ({int left, int top, int right, int bottom})? viewport;
  final Map<Point, HubMark> marks;
  final HubSpecial? special;
}

/// A mark of a Learning Hub position (the model layer does not depend on the board widget).
@immutable
class HubMark {
  const HubMark._(this.shape, this.label);

  const HubMark.label(String text) : this._(null, text);

  static const triangle = HubMark._('triangle', null);
  static const square = HubMark._('square', null);
  static const circle = HubMark._('circle', null);
  static const cross = HubMark._('cross', null);

  final String? shape;
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is HubMark && other.shape == shape && other.label == label;

  @override
  int get hashCode => Object.hash(shape, label);
}

LearningHub _parse(String source) =>
    LearningHub.fromJson(jsonDecode(source) as Map<String, dynamic>);

/// The Learning Hub, read from the app assets (about 2 MB, parsed off the UI thread).
final learningHubProvider = FutureProvider<LearningHub>((ref) async {
  final source = await rootBundle.loadString('assets/learning_hub/learning_hub.json');
  return await compute(_parse, source);
});

/// The Learning Hub pages completed, as `topicId/pageIndex`, saved on the device.
final hubProgressProvider = NotifierProvider<HubProgressController, Set<String>>(
  HubProgressController.new,
);

class HubProgressController extends Notifier<Set<String>> {
  static const _key = 'learn.hub.completed';

  @override
  Set<String> build() =>
      (ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const []).toSet();

  static String key(HubTopic topic, int page) => '${topic.id}/$page';

  Future<void> complete(HubTopic topic, int page) async {
    final k = key(topic, page);
    if (state.contains(k)) return;
    state = {...state, k};
    await ref.read(sharedPreferencesProvider).setStringList(_key, state.toList());
  }
}

/// The number of pages of [topic] in [done].
int pagesDone(Set<String> done, HubTopic topic) =>
    [for (var i = 0; i < topic.pages.length; i++) i]
        .where((i) => done.contains(HubProgressController.key(topic, i)))
        .length;
