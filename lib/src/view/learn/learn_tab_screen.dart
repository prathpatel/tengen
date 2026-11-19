import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/learn/lessons.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/learn/coordinate_training_screen.dart';
import 'package:tengen/src/view/learn/lesson_screen.dart';
import 'package:tengen/src/view/offline_game/offline_game_screen.dart';
import 'package:tengen/src/view/puzzle/puzzle_screen.dart';
import 'package:tengen/src/widgets/list_section.dart';

class LearnTabScreen extends ConsumerWidget {
  const LearnTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(lessonProgressProvider);
    final theme = Theme.of(context);
    final next = goBasics.where((l) => !done.contains(l.id)).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          CardSection(
            children: [
              CardRow(
                icon: Icons.menu_book_outlined,
                title: 'Go basics',
                subtitle: next == null
                    ? 'All ${goBasics.length} lessons done'
                    : '${done.length} of ${goBasics.length} lessons · next: ${next.title}',
                onTap: () =>
                    pushFullScreen<void>(context, LessonScreen(lesson: next ?? goBasics.first)),
              ),
              CardRow(
                icon: Icons.fitness_center_outlined,
                title: 'Practice',
                subtitle: 'Play the computer on a 9×9 board.',
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
              CardRow(
                icon: Icons.extension_outlined,
                title: 'Beginner puzzles',
                subtitle: 'Easy life and death problems from OGS.',
                onTap: () => pushFullScreen<void>(context, const PuzzleScreen(puzzleId: 2625)),
              ),
            ],
          ),
          const SectionHeader('Lessons'),
          CardSection(
            children: [
              for (final (i, lesson) in goBasics.indexed)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: done.contains(lesson.id)
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: done.contains(lesson.id)
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                    child: done.contains(lesson.id)
                        ? const Icon(Icons.check, size: 20)
                        : Text('${i + 1}'),
                  ),
                  title: Text(lesson.title, style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    lesson.summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => pushFullScreen<void>(context, LessonScreen(lesson: lesson)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
