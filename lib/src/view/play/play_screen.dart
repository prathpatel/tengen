import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/rules.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/auth/sign_in_screen.dart';
import 'package:tengen/src/view/offline_game/offline_game_screen.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';

/// Starts a game: online with the OGS automatch, or offline on the device.
class PlayScreen extends StatelessWidget {
  const PlayScreen({this.offline = false, super.key});

  /// Opens on the offline tab.
  final bool offline;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: offline ? 1 : 0,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('New game'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Online'),
            Tab(text: 'Offline'),
          ],
        ),
      ),
      body: const TabBarView(children: [_OnlinePlay(), _OfflinePlay()]),
    ),
  );
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

/// A scrolling form with its main button pinned at the bottom, above the system navigation bar.
/// The content is capped in width on tablets.
class _FormWithAction extends StatelessWidget {
  const _FormWithAction({required this.children, required this.action});

  final List<Widget> children;
  final Widget action;

  static const maxWidth = 560.0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ],
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SizedBox(width: double.infinity, height: 52, child: action),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _sizeSelector(int size, ValueChanged<int> onChanged) => SegmentedChoice<int>(
  choices: const [Choice(9, '9×9'), Choice(13, '13×13'), Choice(19, '19×19')],
  selected: size,
  onChanged: onChanged,
);

class _OnlinePlay extends ConsumerStatefulWidget {
  const _OnlinePlay();

  @override
  ConsumerState<_OnlinePlay> createState() => _OnlinePlayState();
}

class _OnlinePlayState extends ConsumerState<_OnlinePlay> {
  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authProvider).value?.isSignedIn ?? false;
    final automatch = ref.watch(automatchProvider);
    final settings = ref.watch(automatchSettingsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    void update(AutomatchSettings s) => ref.read(automatchSettingsProvider.notifier).update(s);

    if (!signedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Sign in with your online-go.com account to find opponents online.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => pushFullScreen<void>(context, const SignInScreen()),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      );
    }

    if (automatch is AutomatchSearching) {
      final s = automatch.settings;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Looking for an opponent', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${s.size}×${s.size} · ${s.speed.label} · ${s.timeLabel}'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.read(automatchProvider.notifier).cancel(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    return _FormWithAction(
      action: FilledButton.icon(
        icon: const Icon(Icons.search),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Play ${settings.size}×${settings.size} '
            '${settings.speed.shortLabel.toLowerCase()} · ${settings.timeLabel}',
          ),
        ),
        onPressed: () => ref.read(automatchProvider.notifier).find(settings),
      ),
      children: [
        _Labeled(
          'Board size',
          _sizeSelector(settings.size, (v) => update(settings.copyWith(size: v))),
        ),
        _Labeled(
          'Speed',
          Column(
            children: [
              for (final speed in GameSpeed.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: settings.speed == speed
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => update(settings.copyWith(speed: speed)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    speed.label,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: settings.speed == speed
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    speed.estimate(settings.size),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              quickMatchTime(
                                settings.size,
                                speed,
                                speed == GameSpeed.correspondence
                                    ? ClockSystem.fischer
                                    : settings.system,
                              ),
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
        if (settings.speed != GameSpeed.correspondence) ...[
          _Labeled(
            'Clock',
            SegmentedChoice<ClockSystem>(
              choices: [for (final c in ClockSystem.values) Choice(c, c.label)],
              selected: settings.system,
              onChanged: (v) => update(settings.copyWith(system: v)),
            ),
          ),
          SwitchListTile(
            title: const Text('Flexible clock'),
            subtitle: Text(
              settings.flexibleClock
                  ? 'Also accept ${settings.system == ClockSystem.fischer ? 'byo-yomi' : 'Fischer'} '
                        'to find a game faster'
                  : 'Only ${settings.system.label}',
            ),
            value: settings.flexibleClock,
            onChanged: (v) => update(settings.copyWith(flexibleClock: v)),
          ),
        ],
        _Labeled(
          'Handicaps',
          SegmentedChoice<HandicapMode>(
            choices: [for (final h in HandicapMode.values) Choice(h, h.label)],
            selected: settings.handicap,
            onChanged: (v) => update(settings.copyWith(handicap: v)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            settings.handicap.description,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        _Labeled(
          'Opponent rank: ${settings.lowerRankDiff} below to ${settings.upperRankDiff} above you',
          RangeSlider(
            min: -9,
            max: 9,
            divisions: 18,
            values: RangeValues(
              -settings.lowerRankDiff.toDouble(),
              settings.upperRankDiff.toDouble(),
            ),
            labels: RangeLabels('−${settings.lowerRankDiff}', '+${settings.upperRankDiff}'),
            onChanged: (v) => update(
              settings.copyWith(
                lowerRankDiff: (-v.start).round().clamp(0, 9),
                upperRankDiff: v.end.round().clamp(0, 9),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'OGS quick match games use Japanese rules.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _OfflinePlay extends StatefulWidget {
  const _OfflinePlay();

  @override
  State<_OfflinePlay> createState() => _OfflinePlayState();
}

class _OfflinePlayState extends State<_OfflinePlay> {
  OfflineGameSetup _setup = const OfflineGameSetup();

  void _update(OfflineGameSetup Function(OfflineGameSetup) f) => setState(() => _setup = f(_setup));

  @override
  Widget build(BuildContext context) {
    final maxHandicap = _setup.size == 9 ? 5 : 9;
    return _FormWithAction(
      action: FilledButton.icon(
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start game'),
        onPressed: () => pushFullScreen<void>(context, OfflineGameScreen(setup: _setup)),
      ),
      children: [
        _Labeled(
          'Opponent',
          SegmentedChoice<OfflineOpponent>(
            choices: const [
              Choice(OfflineOpponent.bot, 'Computer', icon: Icons.smart_toy_outlined),
              Choice(OfflineOpponent.human, 'Pass and play', icon: Icons.people_outline),
            ],
            selected: _setup.opponent,
            onChanged: (v) => _update((x) => x.copyWith(opponent: v)),
          ),
        ),
        _Labeled(
          'Board size',
          _sizeSelector(
            _setup.size,
            (v) =>
                _update((x) => x.copyWith(size: v, handicap: x.handicap.clamp(0, v == 9 ? 5 : 9))),
          ),
        ),
        if (_setup.opponent == OfflineOpponent.bot)
          _Labeled(
            'Your color',
            SegmentedChoice<StoneColor>(
              choices: const [Choice(StoneColor.black, 'Black'), Choice(StoneColor.white, 'White')],
              selected: _setup.humanColor,
              onChanged: (v) => _update((x) => x.copyWith(humanColor: v)),
            ),
          ),
        ListTile(
          title: const Text('Rules'),
          trailing: DropdownButton<Ruleset>(
            value: _setup.ruleset,
            items: [
              for (final r in Ruleset.values) DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: (r) => _update((x) => x.copyWith(ruleset: r)),
          ),
        ),
        ListTile(
          title: const Text('Handicap'),
          trailing: DropdownButton<int>(
            value: _setup.handicap,
            items: [
              const DropdownMenuItem(value: 0, child: Text('None')),
              for (var h = 2; h <= maxHandicap; h++)
                DropdownMenuItem(value: h, child: Text('$h stones')),
            ],
            onChanged: (h) => _update((x) => x.copyWith(handicap: h)),
          ),
        ),
        ListTile(
          title: const Text('Komi'),
          trailing: Text('${_setup.effectiveKomi}', style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(_setup.ruleset.areaScoring ? 'Area scoring' : 'Territory scoring'),
        ),
      ],
    );
  }
}
