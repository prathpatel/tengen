import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/widgets/goban.dart';

/// The main card of a tab: the accent color, white text, and a corner of a board in the user's
/// board and stone themes.
class HeroCard extends ConsumerWidget {
  const HeroCard({
    required this.title,
    required this.body,
    this.footer,
    this.onTap,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 0),
    super.key,
  });

  final String title;
  final String body;

  /// Below the text: buttons or progress.
  final Widget? footer;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Padding(
      padding: margin,
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF245A98), Color(0xFF153659)]
                  : const [Color(0xFF2A7BDB), Color(0xFF1653A0)],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The board shows about two thirds of itself; the text keeps clear of it.
                final art = (constraints.maxWidth * 0.4).clamp(120.0, 180.0);
                final textRoom = art * 0.72 - 20;
                return Stack(
                  children: [
                    Positioned(
                      right: -art * 0.28,
                      top: -art * 0.16,
                      width: art,
                      height: art,
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: Transform.rotate(
                            angle: 0.22,
                            child: Opacity(
                              opacity: 0.9,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x55000000),
                                      blurRadius: 18,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Goban(
                                    board: _art,
                                    theme: prefs.boardTheme,
                                    blackStones: prefs.blackStones,
                                    whiteStones: prefs.whiteStones,
                                    showCoordinates: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(right: textRoom),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  body,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (footer != null) ...[
                            const SizedBox(height: 16),
                            Theme(data: _onAccent(theme), child: footer!),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Buttons and progress bars on the accent background.
ThemeData _onAccent(ThemeData theme) => theme.copyWith(
  filledButtonTheme: FilledButtonThemeData(
    style: theme.filledButtonTheme.style?.copyWith(
      backgroundColor: const WidgetStatePropertyAll(Colors.white),
      foregroundColor: const WidgetStatePropertyAll(Color(0xFF153B6A)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: theme.textButtonTheme.style?.copyWith(
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
    ),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: Colors.white,
    linearTrackColor: Color(0x40FFFFFF),
  ),
  textTheme: theme.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
);

final _art = Board.parse('''
  .........
  .........
  ..XO.....
  ..XOO.X..
  ...XO....
  ..XXOO...
  ....X....
  .........
  .........
''');
