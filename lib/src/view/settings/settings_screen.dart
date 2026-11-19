import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/widgets/board_thumbnail.dart';
import 'package:tengen/src/widgets/list_section.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final controller = ref.read(preferencesProvider.notifier);
    final theme = Theme.of(context);
    final preview = Board.parse('''
      .....
      .XO..
      .XOX.
      ..O..
      .....
    ''');

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SectionHeader('Board'),
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final t in BoardTheme.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => controller.setBoardTheme(t),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: t == prefs.boardTheme
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: ProviderScope(
                              overrides: [
                                preferencesProvider.overrideWithBuild(
                                  (ref, _) => prefs.copyWith(boardTheme: t),
                                ),
                              ],
                              child: BoardThumbnail(board: preview, size: 64),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(t.label, style: theme.textTheme.labelMedium),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CardSection(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.abc),
                title: const Text('Show coordinates'),
                value: prefs.showCoordinates,
                onChanged: controller.setShowCoordinates,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.touch_app_outlined),
                title: const Text('Confirm moves'),
                subtitle: const Text('Tap twice to place a stone'),
                value: prefs.confirmMoves,
                onChanged: controller.setConfirmMoves,
              ),
            ],
          ),
          const SectionHeader('App'),
          CardSection(
            children: [
              const ListTile(
                leading: Icon(Icons.brightness_6_outlined),
                title: Text('Theme'),
                subtitle: Text('Auto follows the phone setting'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedChoice<AppThemeMode>(
                    choices: const [
                      Choice(AppThemeMode.system, 'Auto', icon: Icons.brightness_auto_outlined),
                      Choice(AppThemeMode.light, 'Light', icon: Icons.light_mode_outlined),
                      Choice(AppThemeMode.dark, 'Dark', icon: Icons.dark_mode_outlined),
                    ],
                    selected: prefs.themeMode,
                    onChanged: controller.setThemeMode,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
