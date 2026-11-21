import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/learn/coordinate_training.dart';
import 'package:tengen/src/model/learn/learning_hub.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/learn/coordinate_training_screen.dart';
import 'package:tengen/src/view/learn/hub_section_screen.dart';
import 'package:tengen/src/view/learn/hub_topic_screen.dart';
import 'package:tengen/src/view/offline_game/offline_game_screen.dart';
import 'package:tengen/src/widgets/ui.dart';

/// The OGS Learning Hub course and practice, in a sheet over the home screen.
class LearnSheet extends ConsumerWidget {
  const LearnSheet({this.page = false, super.key});

  /// Shown as a tab of the app rather than in a sheet: clear of the status bar and of the
  /// floating tab bar.
  final bool page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(learningHubProvider);
    final done = ref.watch(hubProgressProvider);
    final best = ref.watch(coordinateBestProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: tabPagePadding(context, page: page),
      children: [
        const SheetTitle('Learn to play Go'),
        switch (hub) {
          AsyncData(:final value) => Builder(
            builder: (context) {
              final topics = value.topics.toList();
              final topicsDone = topics.where((t) => pagesDone(done, t) == t.pages.length).length;
              final next = topics.where((t) => pagesDone(done, t) < t.pages.length).firstOrNull;
              final nextSection = next == null
                  ? null
                  : value.sections.firstWhere((s) => s.topics.contains(next));
              // The section in progress: the first not completed.
              final current = value.sections
                  .where((s) => s.topics.any((t) => pagesDone(done, t) < t.pages.length))
                  .firstOrNull;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          _Ring(
                            value: topics.isEmpty ? 0 : topicsDone / topics.length,
                            size: 88,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$topicsDone', style: theme.textTheme.titleLarge),
                                Text(
                                  'of ${topics.length}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  next == null
                                      ? 'COURSE COMPLETED'
                                      : 'UP NEXT · ${nextSection!.title.toUpperCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.primary,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  next?.title ?? 'Well done!',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge,
                                ),
                                if (next != null) ...[
                                  const SizedBox(height: 10),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 46),
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                    ),
                                    onPressed: () => pushFullScreen<void>(
                                      context,
                                      HubTopicScreen(
                                        topicId: next.id,
                                        initialPage: firstUndone(done, next),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            topicsDone == 0 ? 'Start' : 'Continue',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.chevron_right_rounded, size: 22),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SectionLabel('Sections', padding: EdgeInsets.fromLTRB(24, 24, 24, 8)),
                  for (final section in value.sections)
                    Builder(
                      builder: (context) {
                        final total = section.topics.length;
                        final complete = section.topics
                            .where((t) => pagesDone(done, t) == t.pages.length)
                            .length;
                        final finished = complete == total;
                        final active = section == current;
                        return InkWell(
                          onTap: () => pushFullScreen<void>(
                            context,
                            HubSectionScreen(sectionIndex: section.index),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: finished
                                        ? scheme.primary
                                        : (active
                                              ? scheme.primaryContainer
                                              : scheme.surfaceContainer),
                                  ),
                                  child: finished
                                      ? Icon(Icons.check_rounded, color: scheme.onPrimary)
                                      : Text(
                                          '${section.index + 1}',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: active
                                                ? scheme.primary
                                                : scheme.onSurfaceVariant,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(section.title, style: theme.textTheme.titleMedium),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(3),
                                              child: LinearProgressIndicator(
                                                value: total == 0 ? 0 : complete / total,
                                                minHeight: 5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          SizedBox(
                                            width: 56,
                                            child: Text(
                                              '$complete / $total',
                                              textAlign: TextAlign.right,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
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
                      },
                    ),
                ],
              );
            },
          ),
          AsyncError(:final error) => ListTile(title: Text('Could not load the course: $error')),
          _ => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: _SmallCard(
                  icon: Icons.my_location_rounded,
                  title: 'Coordinates',
                  subtitle: best.isEmpty
                      ? 'Find D4, Q16…'
                      : 'Best: ${best.values.reduce(math.max)}',
                  onTap: () => pushFullScreen<void>(context, const CoordinateTrainingScreen()),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SmallCard(
                  icon: Icons.smart_toy_outlined,
                  title: 'Practice',
                  subtitle: '9×9 vs bot',
                  onTap: () => pushFullScreen<void>(
                    context,
                    const OfflineGameScreen(setup: OfflineGameSetup()),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Text(
            'Course from the online-go.com Learning Hub, © the OGS contributors, GNU AGPL v3.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// The first page of [topic] not done yet.
int firstUndone(Set<String> done, HubTopic topic) {
  for (var i = 0; i < topic.pages.length; i++) {
    if (!done.contains(HubProgressController.key(topic, i))) return i;
  }
  return 0;
}

class _SmallCard extends StatelessWidget {
  const _SmallCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.value, required this.size, required this.child});

  final double value;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
              value: value == 0 ? 0.02 : value,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
