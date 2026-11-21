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

    Widget accentIcon(IconData i) => Icon(i, size: 22, color: scheme.primary);
    return ListView(
      padding: tabPagePadding(context, page: page),
      children: [
        if (page) const PageHeader('Learn') else const SheetTitle('Learn'),
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
              final share = topics.isEmpty ? 0.0 : topicsDone / topics.length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              _Ring(
                                value: share,
                                size: 58,
                                child: Text(
                                  '${(share * 100).round()}%',
                                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      next == null ? 'Course completed' : 'Up next',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      next?.title ?? 'Well done!',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (next != null)
                                      Text(
                                        '${nextSection!.title} · page '
                                        '${firstUndone(done, next) + 1} of ${next.pages.length}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (next != null) ...[
                            const SizedBox(height: 14),
                            FilledButton(
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                              onPressed: () => pushFullScreen<void>(
                                context,
                                HubTopicScreen(
                                  topicId: next.id,
                                  initialPage: firstUndone(done, next),
                                ),
                              ),
                              child: Text(topicsDone == 0 ? 'Start' : 'Continue'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SectionLabel('Course'),
                  Group(
                    children: [
                      for (final section in value.sections)
                        Builder(
                          builder: (context) {
                            final total = section.topics.length;
                            final complete = section.topics
                                .where((t) => pagesDone(done, t) == t.pages.length)
                                .length;
                            final finished = complete == total;
                            final active = section == current;
                            return GroupRow(
                              leading: Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: finished ? scheme.primary : null,
                                  border: finished
                                      ? null
                                      : Border.all(
                                          color: active ? scheme.primary : scheme.outlineVariant,
                                          width: 2,
                                        ),
                                ),
                                child: finished
                                    ? Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary)
                                    : null,
                              ),
                              title: section.title,
                              subtitle: '$complete of $total',
                              onTap: () => pushFullScreen<void>(
                                context,
                                HubSectionScreen(sectionIndex: section.index),
                              ),
                            );
                          },
                        ),
                    ],
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
        const SectionLabel('Practice'),
        Group(
          children: [
            GroupRow(
              leading: accentIcon(Icons.my_location_rounded),
              title: 'Coordinates',
              subtitle: best.isEmpty
                  ? 'Find D4, Q16… against the clock'
                  : 'Best ${best.values.reduce(math.max)} in 30 s',
              onTap: () => pushFullScreen<void>(context, const CoordinateTrainingScreen()),
            ),
            GroupRow(
              leading: accentIcon(Icons.smart_toy_outlined),
              title: 'Play a beginner bot',
              subtitle: '9×9, on this phone',
              onTap: () =>
                  pushFullScreen<void>(context, const OfflineGameScreen(setup: OfflineGameSetup())),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 24, 0),
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
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              backgroundColor: scheme.outlineVariant,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
