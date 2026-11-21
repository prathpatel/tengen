import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/puzzle/puzzle.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/puzzle/puzzle_collections_screen.dart';
import 'package:tengen/src/view/puzzle/puzzle_screen.dart';
import 'package:tengen/src/widgets/board_thumbnail.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/ui.dart';

/// Puzzles from the OGS puzzle collections, in a sheet over the home screen.
class PuzzlesSheet extends ConsumerWidget {
  const PuzzlesSheet({this.page = false, super.key});

  /// Shown as a tab of the app rather than in a sheet: clear of the status bar and of the
  /// floating tab bar.
  final bool page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastPuzzleProvider);
    final featured = ref.watch(featuredCollectionsProvider);
    void open(int id) => pushFullScreen<void>(context, PuzzleScreen(puzzleId: id));

    return ListView(
      padding: tabPagePadding(context, page: page),
      children: [
        if (page) const PageHeader('Puzzles') else const SheetTitle('Puzzles'),
        if (last != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _ContinueCard(id: last.id, title: last.title, onTap: () => open(last.id)),
          ),
        const SectionLabel('Start here'),
        Group(
          children: [
            for (final (icon, title, subtitle, onTap) in [
              (Icons.school_outlined, 'Beginners', 'Basics with solutions', () => open(2625)),
              (Icons.favorite_border_rounded, 'Life and death', 'Cho Chikun', () => open(2824)),
              (Icons.bolt_rounded, 'Tesuji', 'Find the clever move', () => open(26872)),
              (
                Icons.search_rounded,
                'All collections',
                'By the OGS community',
                () => pushFullScreen<void>(context, const PuzzleCollectionsScreen()),
              ),
            ])
              GroupRow(
                leading: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
                title: title,
                subtitle: subtitle,
                onTap: onTap,
              ),
          ],
        ),
        SectionLabel(
          'Top collections',
          padding: const EdgeInsets.fromLTRB(16, 24, 12, 4),
          trailing: TextButton(
            onPressed: () => pushFullScreen<void>(context, const PuzzleCollectionsScreen()),
            child: const Text('See all'),
          ),
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
    );
  }
}

/// The puzzle last opened: where it is in its collection.
class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.id, required this.title, required this.onTap});

  final int id;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = ref.watch(collectionSummaryProvider(id)).value;
    final puzzle = ref.watch(puzzleProvider(id)).value?.puzzle;
    final index = summary?.indexWhere((e) => e.id == id) ?? -1;
    return SoftCard(
      onTap: onTap,
      color: scheme.primaryContainer,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          if (puzzle != null)
            BoardThumbnail(
              board: puzzle.board,
              size: 84,
              viewport: GobanViewport.around(puzzle.board, puzzle.interestingPoints),
            )
          else
            const SizedBox.square(dimension: 84),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONTINUE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (index >= 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (index + 1) / summary!.length,
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${index + 1} / ${summary.length}',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final preview = collection.preview;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (preview != null)
              BoardThumbnail(
                board: preview,
                size: 72,
                viewport: GobanViewport.around(
                  preview,
                  preview.points.where((p) => preview[p] != null),
                ),
              )
            else
              const SizedBox.square(dimension: 72),
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
                ],
              ),
            ),
            if (collection.rating != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.star_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 2),
              Text(
                collection.rating!.toStringAsFixed(1),
                style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
