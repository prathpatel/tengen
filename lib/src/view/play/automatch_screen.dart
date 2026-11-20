import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/ui.dart';

/// While the OGS automatch looks for an opponent: the settings, an empty board with a stone
/// waiting at tengen, and the time spent searching. Leaving the screen keeps the search going
/// (a bar on the home screen shows it); the game opens when it is found.
class AutomatchScreen extends ConsumerStatefulWidget {
  const AutomatchScreen({super.key});

  @override
  ConsumerState<AutomatchScreen> createState() => _AutomatchScreenState();
}

class _AutomatchScreenState extends ConsumerState<AutomatchScreen>
    with SingleTickerProviderStateMixin {
  final _started = DateTime.now();
  late final Timer _ticker;
  late final _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(automatchProvider);
    final prefs = ref.watch(preferencesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Found (the shell opens the game) or cancelled elsewhere: nothing to wait for here.
    ref.listen(automatchProvider, (_, next) {
      if (next is! AutomatchSearching && mounted) Navigator.of(context).maybePop();
    });

    final settings = search is AutomatchSearching ? search.settings : null;
    final elapsed = DateTime.now().difference(_started);
    final size = settings?.size ?? 19;
    final center = Point(size ~/ 2, size ~/ 2);

    return Scaffold(
      appBar: const TopBar(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Text(
                    'Looking for an opponent',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  if (settings != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      [
                        '${settings.size}×${settings.size}',
                        settings.speed.label,
                        settings.effectiveSystem.label,
                        settings.timeLabel,
                      ].join(' · '),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Goban(
                      board: Board.empty(size, size),
                      theme: prefs.boardTheme,
                      blackStones: prefs.blackStones,
                      whiteStones: prefs.whiteStones,
                      showCoordinates: false,
                    ),
                    // A stone breathing at tengen while the search goes on.
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final geometry = GobanGeometry(
                            constraints.biggest,
                            size,
                            size,
                            coordinates: false,
                          );
                          final c = geometry.offsetOf(center);
                          return AnimatedBuilder(
                            animation: _pulse,
                            builder: (context, _) => Stack(
                              children: [
                                Positioned(
                                  left: c.dx - geometry.cell * 0.9,
                                  top: c.dy - geometry.cell * 0.9,
                                  width: geometry.cell * 1.8,
                                  height: geometry.cell * 1.8,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: scheme.primary.withValues(
                                        alpha: 0.12 + 0.18 * _pulse.value,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: c.dx - geometry.cell * 0.45,
                                  top: c.dy - geometry.cell * 0.45,
                                  width: geometry.cell * 0.9,
                                  height: geometry.cell * 0.9,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(
                                        alpha: 0.35 + 0.3 * _pulse.value,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
              child: Text(
                '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 12, 32, 16),
              child: Text(
                'You can leave this screen: a bar on the home screen keeps searching, and the '
                'game opens when an opponent is found.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => ref.read(automatchProvider.notifier).cancel(),
                  child: const Text('Cancel search'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
