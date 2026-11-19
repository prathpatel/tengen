import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/network/http.dart';
import 'package:tengen/src/utils/json.dart';

Board _boardFrom(
  int width,
  int height,
  Map<String, dynamic>? initialState,
) => Board.empty(width, height)
    .withStones(decodeOgsMoves(initialState?['black'] as String? ?? '').nonNulls, StoneColor.black)
    .withStones(decodeOgsMoves(initialState?['white'] as String? ?? '').nonNulls, StoneColor.white);

/// An OGS puzzle collection (`/api/v1/puzzles/collections`).
@immutable
class PuzzleCollection {
  const PuzzleCollection({
    required this.id,
    required this.name,
    required this.puzzleCount,
    required this.startingPuzzleId,
    this.minRank,
    this.maxRank,
    this.rating,
    this.ratingCount = 0,
    this.preview,
  });

  factory PuzzleCollection.fromJson(Map<String, dynamic> json) {
    final start = asMap(json['starting_puzzle']) ?? const {};
    final width = asInt(start['width']);
    final height = asInt(start['height']);
    return PuzzleCollection(
      id: asInt(json['id']) ?? 0,
      name: (json['name'] as String? ?? '').trim(),
      puzzleCount: asInt(json['puzzle_count']) ?? 0,
      startingPuzzleId: asInt(start['id']) ?? 0,
      minRank: asInt(json['min_rank']),
      maxRank: asInt(json['max_rank']),
      rating: asDouble(json['rating']),
      ratingCount: asInt(json['rating_count']) ?? 0,
      preview: width != null && height != null && width <= 25 && height <= 25
          ? _boardFrom(width, height, asMap(start['initial_state']))
          : null,
    );
  }

  final int id;
  final String name;
  final int puzzleCount;
  final int startingPuzzleId;
  final int? minRank;
  final int? maxRank;

  /// Average rating by the players, out of 5.
  final double? rating;
  final int ratingCount;

  /// The position of the first puzzle.
  final Board? preview;

  /// `25k – 10k`, or a single rank.
  String get rankRange {
    final lo = minRank;
    final hi = maxRank;
    if (lo == null || hi == null) return '';
    final a = rankLabelFor(lo.toDouble());
    final b = rankLabelFor(hi.toDouble());
    return a == b ? a : '$a – $b';
  }
}

/// A node of a puzzle's move tree.
@immutable
class PuzzleNode {
  const PuzzleNode({
    this.point,
    this.correct = false,
    this.wrong = false,
    this.text,
    this.branches = const [],
  });

  factory PuzzleNode.fromJson(Map<String, dynamic> json) {
    final x = asInt(json['x']) ?? -1;
    final y = asInt(json['y']) ?? -1;
    final text = (json['text'] as String?)?.trim();
    return PuzzleNode(
      point: x < 0 || y < 0 ? null : Point(x, y),
      correct: json['correct_answer'] == true,
      wrong: json['wrong_answer'] == true,
      text: text == null || text.isEmpty ? null : text,
      branches: [
        for (final b in asList(json['branches']))
          if (asMap(b) case final map?) PuzzleNode.fromJson(map),
      ],
    );
  }

  /// The move, null for the root.
  final Point? point;
  final bool correct;
  final bool wrong;
  final String? text;
  final List<PuzzleNode> branches;

  PuzzleNode? branchAt(Point p) => branches.where((b) => b.point == p).firstOrNull;

  /// All the points played somewhere in the tree.
  Iterable<Point> get allPoints sync* {
    if (point case final p?) yield p;
    for (final b in branches) {
      yield* b.allPoints;
    }
  }
}

/// An OGS puzzle (`/api/v1/puzzles/<id>`).
@immutable
class Puzzle {
  const Puzzle({
    required this.id,
    required this.name,
    required this.board,
    required this.toPlay,
    required this.root,
    this.collectionId,
    this.collectionName,
    this.description,
    this.type,
    this.rank,
  });

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    final p = asMap(json['puzzle']) ?? const {};
    final width = asInt(p['width']) ?? asInt(json['width']) ?? 19;
    final height = asInt(p['height']) ?? asInt(json['height']) ?? width;
    final collection = asMap(json['collection']);
    final description = (p['puzzle_description'] as String?)?.trim();
    return Puzzle(
      id: asInt(json['id']) ?? 0,
      name: (json['name'] as String? ?? p['name'] as String? ?? '').trim(),
      board: _boardFrom(width, height, asMap(p['initial_state'])),
      toPlay: p['initial_player'] == 'white' ? StoneColor.white : StoneColor.black,
      root: PuzzleNode.fromJson(asMap(p['move_tree']) ?? const {}),
      collectionId: asInt(collection?['id']) ?? asInt(p['puzzle_collection']),
      collectionName: collection?['name'] as String?,
      description: description == null || description.isEmpty ? null : description,
      type: p['puzzle_type'] as String?,
      rank: asInt(json['rank'] ?? p['puzzle_rank']),
    );
  }

  final int id;
  final String name;
  final Board board;

  /// The color played by the solver.
  final StoneColor toPlay;
  final PuzzleNode root;
  final int? collectionId;
  final String? collectionName;
  final String? description;

  /// e.g. `life_and_death`, `tesuji`, `fuseki`.
  final String? type;
  final int? rank;

  /// Whether the tree has a correct answer at all (some OGS "puzzles" are solution pages).
  bool get hasSolution {
    bool search(PuzzleNode n) => n.correct || n.branches.any(search);
    return search(root);
  }

  /// The area of the board worth showing.
  Iterable<Point> get interestingPoints sync* {
    yield* board.points.where((p) => board[p] != null);
    yield* root.allPoints;
  }

  String get typeLabel => switch (type) {
    'life_and_death' => 'Life and death',
    'tesuji' => 'Tesuji',
    'fuseki' => 'Fuseki',
    'joseki' => 'Joseki',
    'endgame' => 'Endgame',
    'elementary' => 'Elementary',
    _ => 'Puzzle',
  };
}

/// Reads puzzles from the OGS REST API.
class PuzzleRepository {
  const PuzzleRepository(this._http);

  final OgsHttp _http;

  /// Collections, best rated first, as on the OGS puzzle page.
  Future<List<PuzzleCollection>> collections({
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final json =
        asMap(
          await _http.get('/api/v1/puzzles/collections/', {
            'ordering': '-rating,-rating_count',
            'puzzle_count__gt': '0',
            'page': '$page',
            'page_size': '$pageSize',
            if (search != null && search.trim().isNotEmpty) 'name__icontains': search.trim(),
          }),
        ) ??
        const {};
    return [
      for (final c in asList(json['results']))
        if (asMap(c) case final map?) PuzzleCollection.fromJson(map),
    ];
  }

  Future<PuzzleCollection> collection(int id) async =>
      PuzzleCollection.fromJson(asMap(await _http.get('/api/v1/puzzles/collections/$id')) ?? {});

  Future<Puzzle> puzzle(int id) async =>
      Puzzle.fromJson(asMap(await _http.get('/api/v1/puzzles/$id')) ?? const {});

  /// The puzzles of the collection [puzzleId] belongs to, in order: `(id, name)`.
  Future<List<({int id, String name})>> collectionSummary(int puzzleId) async => [
    for (final e in asList(await _http.get('/api/v1/puzzles/$puzzleId/collection_summary')))
      if (asMap(e) case final map?) (id: asInt(map['id']) ?? 0, name: map['name'] as String? ?? ''),
  ];
}

final puzzleRepositoryProvider = Provider<PuzzleRepository>(
  (ref) => PuzzleRepository(ref.watch(ogsHttpProvider)),
);

/// Collections picked for the Puzzles tab, from the best rated ones on OGS.
const featuredCollectionIds = [242, 3601, 279, 73, 6];

final featuredCollectionsProvider = FutureProvider.autoDispose<List<PuzzleCollection>>((ref) {
  final repo = ref.watch(puzzleRepositoryProvider);
  return Future.wait(featuredCollectionIds.map(repo.collection));
});

final collectionSearchProvider = FutureProvider.autoDispose.family<List<PuzzleCollection>, String>(
  (ref, search) => ref.watch(puzzleRepositoryProvider).collections(search: search, pageSize: 40),
);

final collectionSummaryProvider = FutureProvider.autoDispose
    .family<List<({int id, String name})>, int>(
      (ref, puzzleId) => ref.watch(puzzleRepositoryProvider).collectionSummary(puzzleId),
    );

enum PuzzleStatus { solving, correct, wrong }

@immutable
class PuzzleState {
  const PuzzleState({
    required this.puzzle,
    required this.game,
    required this.node,
    this.status = PuzzleStatus.solving,
    this.opponentThinking = false,
  });

  final Puzzle puzzle;
  final GoGame game;

  /// The node of the tree reached by the moves played.
  final PuzzleNode node;
  final PuzzleStatus status;
  final bool opponentThinking;

  bool get canPlay => status == PuzzleStatus.solving && !opponentThinking;

  /// The comment of the current node, or the default instruction.
  String get message =>
      node.text ??
      switch (status) {
        PuzzleStatus.correct => 'Correct!',
        PuzzleStatus.wrong => 'That is not the answer.',
        PuzzleStatus.solving => '${puzzle.toPlay == StoneColor.black ? 'Black' : 'White'} to play',
      };

  PuzzleState copyWith({
    GoGame? game,
    PuzzleNode? node,
    PuzzleStatus? status,
    bool? opponentThinking,
  }) => PuzzleState(
    puzzle: puzzle,
    game: game ?? this.game,
    node: node ?? this.node,
    status: status ?? this.status,
    opponentThinking: opponentThinking ?? this.opponentThinking,
  );
}

/// How long the opponent waits before answering in a puzzle.
final puzzleReplyDelayProvider = Provider<Duration>((ref) => const Duration(milliseconds: 450));

final puzzleProvider = AsyncNotifierProvider.autoDispose.family<PuzzleController, PuzzleState, int>(
  PuzzleController.new,
);

/// Solves an OGS puzzle, following its move tree like the OGS website: a move found in the tree
/// is played and the opponent answers with the first reply of that branch; a move outside the
/// tree, or reaching a branch marked wrong, fails; a branch marked correct solves the puzzle.
class PuzzleController extends AsyncNotifier<PuzzleState> {
  PuzzleController(this.puzzleId);

  final int puzzleId;
  Timer? _replyTimer;

  @override
  Future<PuzzleState> build() async {
    ref.onDispose(() => _replyTimer?.cancel());
    final puzzle = await ref.watch(puzzleRepositoryProvider).puzzle(puzzleId);
    return _initial(puzzle);
  }

  PuzzleState _initial(Puzzle puzzle) => PuzzleState(
    puzzle: puzzle,
    game: GoGame.create(
      width: puzzle.board.width,
      height: puzzle.board.height,
      initialBoard: puzzle.board,
      initialPlayer: puzzle.toPlay,
    ),
    node: puzzle.root,
  );

  /// Plays a move. Returns the reason when the move is illegal.
  IllegalMoveException? play(Point p) {
    final s = state.value;
    if (s == null || !s.canPlay) return const IllegalMoveException(IllegalMoveReason.wrongTurn);
    final GoGame game;
    try {
      game = s.game.play(p);
    } on IllegalMoveException catch (e) {
      return e;
    }
    final branch = s.node.branchAt(p);
    if (branch == null) {
      state = AsyncData(s.copyWith(game: game, status: PuzzleStatus.wrong));
      return null;
    }
    if (branch.correct) {
      state = AsyncData(s.copyWith(game: game, node: branch, status: PuzzleStatus.correct));
      return null;
    }
    if (branch.wrong || branch.branches.isEmpty) {
      state = AsyncData(s.copyWith(game: game, node: branch, status: PuzzleStatus.wrong));
      return null;
    }
    state = AsyncData(s.copyWith(game: game, node: branch, opponentThinking: true));
    _replyTimer?.cancel();
    _replyTimer = Timer(ref.read(puzzleReplyDelayProvider), _reply);
    return null;
  }

  void _reply() {
    final s = state.value;
    if (s == null) return;
    final reply = s.node.branches.first;
    final GoGame game;
    try {
      game = s.game.playMove(GoMove(s.game.toMove, reply.point), validate: false);
    } on Object {
      state = AsyncData(s.copyWith(opponentThinking: false, status: PuzzleStatus.wrong));
      return;
    }
    final status = reply.correct
        ? PuzzleStatus.correct
        : (reply.wrong || reply.branches.isEmpty ? PuzzleStatus.wrong : PuzzleStatus.solving);
    state = AsyncData(s.copyWith(game: game, node: reply, status: status, opponentThinking: false));
  }

  /// Starts the puzzle again.
  void retry() {
    _replyTimer?.cancel();
    final s = state.value;
    if (s != null) state = AsyncData(_initial(s.puzzle));
  }

  /// The correct first moves, used as a hint.
  Set<Point> hint() {
    final s = state.value;
    if (s == null) return const {};
    bool leadsToCorrect(PuzzleNode n) => n.correct || n.branches.any(leadsToCorrect);
    return {
      for (final b in s.node.branches)
        if (b.point != null && leadsToCorrect(b)) b.point!,
    };
  }
}

/// The last puzzle opened, to continue from the Puzzles tab.
final lastPuzzleProvider = NotifierProvider<LastPuzzleController, ({int id, String title})?>(
  LastPuzzleController.new,
);

class LastPuzzleController extends Notifier<({int id, String title})?> {
  static const _key = 'puzzle.last';

  @override
  ({int id, String title})? build() {
    final saved = ref.watch(sharedPreferencesProvider).getStringList(_key);
    final id = saved == null || saved.length != 2 ? null : int.tryParse(saved[0]);
    return id == null ? null : (id: id, title: saved![1]);
  }

  Future<void> set(int id, String title) async {
    state = (id: id, title: title);
    await ref.read(sharedPreferencesProvider).setStringList(_key, ['$id', title]);
  }
}
