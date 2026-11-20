import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/list_section.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final controller = ref.read(preferencesProvider.notifier);
    final sample = Board.parse('''
      .....
      .XO..
      .XOX.
      ..O..
      .....
    ''');
    Widget sampleBoard({BoardTheme? board, StoneTheme? black, StoneTheme? white}) => Goban(
      board: sample,
      theme: board ?? prefs.boardTheme,
      blackStones: black ?? prefs.blackStones,
      whiteStones: white ?? prefs.whiteStones,
      showCoordinates: false,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Goban(
                    board: _preview,
                    theme: prefs.boardTheme,
                    blackStones: prefs.blackStones,
                    whiteStones: prefs.whiteStones,
                    showCoordinates: prefs.showCoordinates,
                    lastMove: const Point(4, 2),
                  ),
                ),
              ),
            ),
          ),
          const SectionHeader('Board'),
          _ThemeRow(
            children: [
              for (final t in BoardTheme.values)
                _ThemeTile(
                  label: t.label,
                  selected: t == prefs.boardTheme,
                  onTap: () => controller.setBoardTheme(t),
                  child: sampleBoard(board: t),
                ),
            ],
          ),
          const SectionHeader('Black stones'),
          _ThemeRow(
            children: [
              for (final t in StoneTheme.forBlack)
                _ThemeTile(
                  label: t.label,
                  selected: t == prefs.blackStones,
                  onTap: () => controller.setBlackStones(t),
                  child: sampleBoard(black: t),
                ),
            ],
          ),
          const SectionHeader('White stones'),
          _ThemeRow(
            children: [
              for (final t in StoneTheme.forWhite)
                _ThemeTile(
                  label: t.label,
                  selected: t == prefs.whiteStones,
                  onTap: () => controller.setWhiteStones(t),
                  child: sampleBoard(white: t),
                ),
            ],
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

/// A position for the preview of the board and stones.
final _preview = Board.parse('''
  .........
  .........
  ..XO..X..
  ..XOOX...
  ..XXO.O..
  ...XO....
  ...XO....
  .........
  .........
''');

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 108,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: children,
    ),
  );
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? theme.colorScheme.primary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: SizedBox.square(dimension: 60, child: IgnorePointer(child: child)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? theme.colorScheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
