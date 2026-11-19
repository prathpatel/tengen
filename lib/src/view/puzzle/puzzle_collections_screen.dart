import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/puzzle/puzzle.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/puzzle/puzzle_screen.dart';
import 'package:tengen/src/view/puzzle/puzzle_tab_screen.dart';

/// Browse and search the OGS puzzle collections.
class PuzzleCollectionsScreen extends ConsumerStatefulWidget {
  const PuzzleCollectionsScreen({super.key});

  @override
  ConsumerState<PuzzleCollectionsScreen> createState() => _PuzzleCollectionsScreenState();
}

class _PuzzleCollectionsScreenState extends ConsumerState<PuzzleCollectionsScreen> {
  String _search = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(collectionSearchProvider(_search));
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle collections')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              hintText: 'Search collections',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 400),
                  () => setState(() => _search = value.trim()),
                );
              },
            ),
          ),
          Expanded(
            child: switch (results) {
              AsyncData(:final value) when value.isEmpty => const Center(
                child: Text('No collection found'),
              ),
              AsyncData(:final value) => ListView.builder(
                itemCount: value.length,
                itemBuilder: (context, i) => CollectionTile(
                  collection: value[i],
                  onTap: () => pushFullScreen<void>(
                    context,
                    PuzzleScreen(puzzleId: value[i].startingPuzzleId),
                  ),
                ),
              ),
              AsyncError(:final error) => Center(child: Text('Could not load: $error')),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}
