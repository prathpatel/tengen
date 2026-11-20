import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/view/home/home_screen.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/goban_art.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';
import 'package:tengen/src/widgets/ui.dart';

/// Stone sets: OGS stone themes that go together, black and white.
const _stoneSets = <(String, StoneTheme, StoneTheme)>[
  ('Classic', StoneTheme.slate, StoneTheme.shell),
  ('Glass', StoneTheme.glass, StoneTheme.glass),
  ('Worn Glass', StoneTheme.wornGlass, StoneTheme.wornGlass),
  ('Night', StoneTheme.night, StoneTheme.night),
  ('Plain', StoneTheme.plain, StoneTheme.plain),
  ('Anime', StoneTheme.anime, StoneTheme.anime),
  ('BadukTV', StoneTheme.badukTV, StoneTheme.badukTV),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final controller = ref.read(preferencesProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: const TopBar(title: 'Settings'),
      body: ListView(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox.square(
                dimension: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Goban(
                    board: _preview,
                    theme: prefs.boardTheme,
                    blackStones: prefs.blackStones,
                    whiteStones: prefs.whiteStones,
                    showCoordinates: false,
                    lastMove: const Point(4, 4),
                  ),
                ),
              ),
            ),
          ),
          Text(
            "Live preview · the app's colours follow the board",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionLabel('Theme', padding: EdgeInsets.fromLTRB(20, 24, 20, 10)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SegmentedChoice<AppThemeMode>(
                    choices: const [
                      Choice(AppThemeMode.system, 'Auto'),
                      Choice(AppThemeMode.light, 'Light'),
                      Choice(AppThemeMode.dark, 'Dark'),
                    ],
                    selected: prefs.themeMode,
                    onChanged: controller.setThemeMode,
                  ),
                ),
                const SectionLabel('Board'),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      for (final b in BoardTheme.values)
                        _Choice(
                          label: b.label,
                          selected: b == prefs.boardTheme,
                          onTap: () => controller.setBoardTheme(b),
                          child: BoardSwatch(board: b, size: 60),
                        ),
                    ],
                  ),
                ),
                const SectionLabel('Stones'),
                SizedBox(
                  height: 112,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (final (name, black, white) in _stoneSets)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 112,
                            child: Semantics(
                              button: true,
                              selected: prefs.blackStones == black && prefs.whiteStones == white,
                              label: name,
                              excludeSemantics: true,
                              child: SoftCard(
                                selected: prefs.blackStones == black && prefs.whiteStones == white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                onTap: () {
                                  controller
                                    ..setBlackStones(black)
                                    ..setWhiteStones(white);
                                },
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: 66,
                                      height: 32,
                                      child: CustomPaint(
                                        painter: _StonePairPainter(
                                          black: black,
                                          white: white,
                                          lines: prefs.boardTheme.lines,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ToggleRow(
                  title: 'Show coordinates',
                  subtitle: 'A–T and 1–19 around the board',
                  value: prefs.showCoordinates,
                  onChanged: controller.setShowCoordinates,
                ),
                Divider(indent: 20, endIndent: 20, color: scheme.outlineVariant),
                ToggleRow(
                  title: 'Confirm moves',
                  subtitle: 'Tap twice to place a stone',
                  value: prefs.confirmMoves,
                  onChanged: controller.setConfirmMoves,
                ),
                Divider(indent: 20, endIndent: 20, color: scheme.outlineVariant),
                ToggleRow(
                  title: 'Stone sound',
                  subtitle: 'The OGS wooden click with each move',
                  value: prefs.stoneSound,
                  onChanged: controller.setStoneSound,
                ),
              ],
            ),
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
  ..X...O..
  .........
  ....X....
  ....O....
  ..O...X..
  .........
  .........
''');

class _Choice extends StatelessWidget {
  const _Choice({
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
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 80,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: selected ? scheme.primary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: child,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A black and a white stone of a set, drawn as on the board.
class _StonePairPainter extends CustomPainter {
  _StonePairPainter({required this.black, required this.white, required this.lines})
    : super(repaint: GobanArt.instance);

  final StoneTheme black;
  final StoneTheme white;
  final Color lines;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    paintStone(
      canvas,
      center: Offset(r, r),
      radius: r,
      color: StoneColor.black,
      theme: black,
      lineColor: lines,
    );
    paintStone(
      canvas,
      center: Offset(size.width - r, r),
      radius: r,
      color: StoneColor.white,
      theme: white,
      lineColor: lines,
      variant: 3,
    );
  }

  @override
  bool shouldRepaint(_StonePairPainter old) =>
      old.black != black || old.white != white || old.lines != lines;
}
