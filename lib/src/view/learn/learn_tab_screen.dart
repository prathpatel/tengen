import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/learn/learning_hub.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/learn/coordinate_training_screen.dart';
import 'package:tengen/src/view/learn/hub_section_screen.dart';
import 'package:tengen/src/view/learn/hub_topic_screen.dart';
import 'package:tengen/src/view/offline_game/offline_game_screen.dart';
import 'package:tengen/src/widgets/list_section.dart';

/// The OGS Learning Hub course, and practice tools.
class LearnTabScreen extends ConsumerWidget {
  const LearnTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(learningHubProvider);
    final done = ref.watch(hubProgressProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          switch (hub) {
            AsyncData(:final value) => Builder(
              builder: (context) {
                final total = value.pageCount;
                final completed = done.length.clamp(0, total);
                final next = value.topics
                    .where((t) => pagesDone(done, t) < t.pages.length)
                    .firstOrNull;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Material(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: next == null
                              ? null
                              : () => pushFullScreen<void>(
                                  context,
                                  HubTopicScreen(
                                    topicId: next.id,
                                    initialPage: _firstUndone(done, next),
                                  ),
                                ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Learn to play Go',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'The interactive course of online-go.com: '
                                  '${value.topics.length} lessons, $total exercises.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: total == 0 ? 0 : completed / total,
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  next == null
                                      ? 'Course completed!'
                                      : '$completed of $total done · '
                                            '${completed == 0 ? 'Start' : 'Continue'}: '
                                            '${next.number} ${next.title}',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SectionHeader('Sections'),
                    CardSection(
                      children: [
                        for (final section in value.sections)
                          Builder(
                            builder: (context) {
                              final pages = section.topics.fold(0, (n, t) => n + t.pages.length);
                              final sectionDone = section.topics.fold(
                                0,
                                (n, t) => n + pagesDone(done, t),
                              );
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 4,
                                ),
                                leading: _ProgressRing(
                                  label: '${section.index + 1}',
                                  value: pages == 0 ? 0 : sectionDone / pages,
                                ),
                                title: Text(section.title, style: theme.textTheme.titleMedium),
                                subtitle: Text(
                                  '${section.topics.length} lessons · $sectionDone/$pages',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => pushInTab<void>(
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
          const SectionHeader('Practice'),
          CardSection(
            children: [
              CardRow(
                icon: Icons.fitness_center_outlined,
                title: 'Play the computer',
                subtitle: 'A 9×9 game against a simple bot.',
                onTap: () => pushFullScreen<void>(
                  context,
                  const OfflineGameScreen(setup: OfflineGameSetup()),
                ),
              ),
              CardRow(
                icon: Icons.my_location_outlined,
                title: 'Coordinate training',
                subtitle: 'Find points like D4 or Q16 as fast as you can.',
                onTap: () => pushFullScreen<void>(context, const CoordinateTrainingScreen()),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Text(
              'Course content from the online-go.com Learning Hub, © the OGS contributors, '
              'licensed under the GNU AGPL v3.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

int _firstUndone(Set<String> done, HubTopic topic) {
  for (var i = 0; i < topic.pages.length; i++) {
    if (!done.contains(HubProgressController.key(topic, i))) return i;
  }
  return 0;
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 3,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
          if (value >= 1)
            Icon(Icons.check, color: scheme.primary, size: 20)
          else
            Text(label, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
