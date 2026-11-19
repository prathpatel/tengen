import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/puzzle/puzzle.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/puzzle/puzzle_collections_screen.dart';
import 'package:tengen/src/view/puzzle/puzzle_screen.dart';
import 'package:tengen/src/widgets/board_thumbnail.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/list_section.dart';

/// Puzzles from the OGS puzzle collections.
class PuzzleTabScreen extends ConsumerWidget {
  const PuzzleTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastPuzzleProvider);
    final featured = ref.watch(featuredCollectionsProvider);
    void open(int id) => pushFullScreen<void>(context, PuzzleScreen(puzzleId: id));

    return Scaffold(
      appBar: AppBar(title: const Text('Puzzles')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(featuredCollectionsProvider);
          await ref
              .read(featuredCollectionsProvider.future)
              .catchError((_) => <PuzzleCollection>[]);
        },
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            CardSection(
              children: [
                if (last != null)
                  CardRow(
                    icon: Icons.play_circle_outline,
                    title: 'Continue',
                    subtitle: last.title,
                    onTap: () => open(last.id),
                  ),
                CardRow(
                  icon: Icons.school_outlined,
                  title: 'Exercises for beginners',
                  subtitle: 'Life and death basics, each followed by its solution.',
                  onTap: () => open(2625),
                ),
                CardRow(
                  icon: Icons.favorite_border,
                  title: 'Life and death',
                  subtitle: "Problems from Cho Chikun's encyclopedia.",
                  onTap: () => open(2824),
                ),
                CardRow(
                  icon: Icons.bolt_outlined,
                  title: 'Tesuji',
                  subtitle: 'Find the clever move.',
                  onTap: () => open(26872),
                ),
                CardRow(
                  icon: Icons.search,
                  title: 'All collections',
                  subtitle: 'Thousands of collections made by the OGS community.',
                  onTap: () => pushInTab<void>(context, const PuzzleCollectionsScreen()),
                ),
              ],
            ),
            SectionHeader(
              'Top collections',
              onMore: () => pushInTab<void>(context, const PuzzleCollectionsScreen()),
            ),
            switch (featured) {
              AsyncData(:final value) => Column(
                children: [
                  for (final c in value)
                    CollectionTile(collection: c, onTap: () => open(c.startingPuzzleId)),
                ],
              ),
              AsyncError() => ListTile(
                leading: const Icon(Icons.cloud_off),
                title: const Text('Could not load the collections'),
                trailing: TextButton(
                  onPressed: () => ref.invalidate(featuredCollectionsProvider),
                  child: const Text('Retry'),
                ),
              ),
              _ => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
          ],
        ),
      ),
    );
  }
}

/// A puzzle collection with a preview of its first puzzle.
class CollectionTile extends StatelessWidget {
  const CollectionTile({required this.collection, required this.onTap, super.key});

  final PuzzleCollection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final preview = collection.preview;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            if (preview != null)
              BoardThumbnail(
                board: preview,
                size: 76,
                viewport: GobanViewport.around(
                  preview,
                  preview.points.where((p) => preview[p] != null),
                ),
              )
            else
              const SizedBox.square(dimension: 76),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      '${collection.puzzleCount} puzzles',
                      if (collection.rankRange.isNotEmpty) collection.rankRange,
                    ].join(' · '),
                    style: muted,
                  ),
                  if (collection.rating != null)
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
                        const SizedBox(width: 2),
                        Text(
                          '${collection.rating!.toStringAsFixed(1)} (${collection.ratingCount})',
                          style: muted,
                        ),
                      ],
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
