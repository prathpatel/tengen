import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/learn/learning_hub.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/learn/hub_topic_screen.dart';
import 'package:tengen/src/widgets/ui.dart';

/// The lessons of a Learning Hub section.
class HubSectionScreen extends ConsumerWidget {
  const HubSectionScreen({required this.sectionIndex, super.key});

  final int sectionIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(learningHubProvider).value;
    final done = ref.watch(hubProgressProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final section = hub?.sections[sectionIndex];
    return Scaffold(
      appBar: TopBar(title: section?.title ?? 'Learn'),
      body: section == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: section.topics.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
              itemBuilder: (context, i) {
                final topic = section.topics[i];
                final n = pagesDone(done, topic);
                final complete = n == topic.pages.length;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: complete ? scheme.primary : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: complete
                        ? Icon(Icons.check, color: scheme.onPrimary)
                        : Text(topic.number, style: theme.textTheme.labelLarge),
                  ),
                  title: Text(topic.title, style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    '${topic.subtext} · $n/${topic.pages.length}',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  onTap: () => pushFullScreen<void>(context, HubTopicScreen(topicId: topic.id)),
                );
              },
            ),
    );
  }
}
