import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/go/rules.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/auth/sign_in_screen.dart';
import 'package:tengen/src/view/offline_game/offline_game_screen.dart';
import 'package:tengen/src/view/play/automatch_screen.dart';
import 'package:tengen/src/view/play/play_bot_tab.dart';
import 'package:tengen/src/widgets/form_layout.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';
import 'package:tengen/src/widgets/ui.dart';

enum PlayTab { online, computer, offline }

/// Opens the New game sheet.
Future<void> showNewGame(BuildContext context, {PlayTab tab = PlayTab.online}) =>
    showTengenSheet<void>(context, PlayScreen(tab: tab), topGap: 56);

/// Starts a game: online with the OGS automatch, against an OGS bot, or offline on the device.
class PlayScreen extends StatelessWidget {
  const PlayScreen({this.tab = PlayTab.online, super.key});

  /// The tab shown first.
  final PlayTab tab;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: PlayTab.values.length,
    initialIndex: tab.index,
    // Its own messenger and scaffold, so that messages show in the sheet.
    child: ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle('New game', close: true),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Online'),
                  Tab(text: 'Computer'),
                  Tab(text: 'Offline'),
                ],
              ),
            ),
            Expanded(child: TabBarView(children: [_OnlinePlay(), PlayBotTab(), _OfflinePlay()])),
          ],
        ),
      ),
    ),
  );
}

/// Two settings side by side (`BOARD` and `CLOCK`).
class SideBySide extends StatelessWidget {
  const SideBySide({required this.left, required this.right, super.key});

  final (String, Widget) left;
  final (String, Widget) right;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (label, child)) in [left, right].indexed) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel(label, padding: const EdgeInsets.fromLTRB(0, 20, 0, 10)),
                child,
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

/// A labelled setting: the small uppercase label, then the control.
Widget setting(String label, Widget child) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    SectionLabel(label),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child),
  ],
);

class _OnlinePlay extends ConsumerWidget {
  const _OnlinePlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;
    final signedIn = auth?.isSignedIn ?? false;
    final settings = ref.watch(automatchSettingsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    void update(AutomatchSettings s) => ref.read(automatchSettingsProvider.notifier).update(s);

    if (!signedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public_rounded, size: 44, color: scheme.primary),
              const SizedBox(height: 14),
              Text(
                'Sign in with your online-go.com account to find opponents online.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  showSignIn(context);
                },
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      );
    }

    final myRank = auth!.user.ranking;
    String rankAt(int diff) => myRank == null ? '' : rankLabelFor(myRank.floorToDouble() + diff);

    return FormWithAction(
      footnote: 'OGS quick match games use Japanese rules.',
      action: FilledButton(
        onPressed: () {
          ref.read(automatchProvider.notifier).find(settings);
          Navigator.of(context).pop();
          pushFullScreen<void>(context, const AutomatchScreen());
        },
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Find opponent · ${settings.size}×${settings.size} ${settings.speed.shortLabel}',
          ),
        ),
      ),
      children: [
        setting(
          'Board size',
          boardSizeSelector(settings.size, (v) => update(settings.copyWith(size: v))),
        ),
        setting(
          'Speed',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final speed in GameSpeed.values)
                    _SpeedChip(
                      speed: speed,
                      selected: settings.speed == speed,
                      onTap: () => update(settings.copyWith(speed: speed)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${settings.timeLabel} · ${settings.speed.estimate(settings.size)}',
                style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (settings.speed != GameSpeed.correspondence) ...[
          setting(
            'Clock',
            SegmentedChoice<ClockSystem>(
              choices: [for (final c in ClockSystem.values) Choice(c, c.label)],
              selected: settings.system,
              onChanged: (v) => update(settings.copyWith(system: v)),
            ),
          ),
          ToggleRow(
            title: 'Flexible clock',
            subtitle:
                'Also accept ${settings.system == ClockSystem.fischer ? 'byo-yomi' : 'Fischer'}',
            value: settings.flexibleClock,
            onChanged: (v) => update(settings.copyWith(flexibleClock: v)),
          ),
        ],
        setting(
          'Handicaps',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedChoice<HandicapMode>(
                choices: [for (final h in HandicapMode.values) Choice(h, h.label)],
                selected: settings.handicap,
                onChanged: (v) => update(settings.copyWith(handicap: v)),
              ),
              const SizedBox(height: 8),
              Text(
                settings.handicap.description,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        SectionLabel(
          'Opponent rank',
          trailing: Text(
            '${settings.lowerRankDiff} below to ${settings.upperRankDiff} above you',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: RangeSlider(
            min: -9,
            max: 9,
            divisions: 18,
            values: RangeValues(
              -settings.lowerRankDiff.toDouble(),
              settings.upperRankDiff.toDouble(),
            ),
            onChanged: (v) => update(
              settings.copyWith(
                lowerRankDiff: (-v.start).round().clamp(0, 9),
                upperRankDiff: v.end.round().clamp(0, 9),
              ),
            ),
          ),
        ),
        if (myRank != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: DefaultTextStyle(
              style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
              child: Row(
                children: [
                  Text(rankAt(-settings.lowerRankDiff)),
                  const Spacer(),
                  Text('you · ${rankLabelFor(myRank)}'),
                  const Spacer(),
                  Text(rankAt(settings.upperRankDiff)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.speed, required this.selected, required this.onTap});

  final GameSpeed speed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainer,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                switch (speed) {
                  GameSpeed.blitz => Icons.bolt_rounded,
                  GameSpeed.rapid => Icons.timer_outlined,
                  GameSpeed.live => Icons.schedule_rounded,
                  GameSpeed.correspondence => Icons.calendar_today_outlined,
                },
                size: 19,
                color: fg,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  speed.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflinePlay extends ConsumerStatefulWidget {
  const _OfflinePlay();

  @override
  ConsumerState<_OfflinePlay> createState() => _OfflinePlayState();
}

class _OfflinePlayState extends ConsumerState<_OfflinePlay> {
  OfflineGameSetup _setup = const OfflineGameSetup();

  void _update(OfflineGameSetup Function(OfflineGameSetup) f) => setState(() => _setup = f(_setup));

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxHandicap = _setup.size == 9 ? 5 : 9;
    final vsBot = _setup.opponent == OfflineOpponent.bot;
    final komi = _setup.effectiveKomi;
    String n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

    // The handicap stones on the preview, as they will be placed.
    final previewGame = OfflineGameSetup(
      size: _setup.size,
      handicap: _setup.handicap,
      ruleset: _setup.ruleset,
    );
    return FormWithAction(
      action: FilledButton.icon(
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start game'),
        onPressed: () {
          Navigator.of(context).pop();
          pushFullScreen<void>(context, OfflineGameScreen(setup: _setup));
        },
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            children: [
              Text(
                'Preview · ${_setup.size}×${_setup.size}'
                '${vsBot ? ' · you play ${_setup.humanColor == StoneColor.black ? 'Black' : 'White'}' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              SizedBox.square(
                dimension: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Goban(
                    board: previewBoard(previewGame),
                    theme: prefs.boardTheme,
                    blackStones: prefs.blackStones,
                    whiteStones: prefs.whiteStones,
                    showCoordinates: false,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: SegmentedChoice<OfflineOpponent>(
            choices: const [
              Choice(OfflineOpponent.bot, 'Simple bot'),
              Choice(OfflineOpponent.human, 'Pass and play'),
            ],
            selected: _setup.opponent,
            onChanged: (v) => _update((x) => x.copyWith(opponent: v)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text(
            vsBot
                ? 'A beginner level bot that runs on your phone, without internet. For a real '
                      'opponent, play the KataGo and other OGS bots in the Computer tab.'
                : 'Two players on this phone, taking turns.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        SideBySide(
          left: (
            'Board',
            SegmentedChoice<int>(
              choices: const [Choice(9, '9'), Choice(13, '13'), Choice(19, '19')],
              selected: _setup.size,
              onChanged: (v) => _update(
                (x) => x.copyWith(size: v, handicap: x.handicap.clamp(0, v == 9 ? 5 : 9)),
              ),
            ),
          ),
          right: (
            vsBot ? 'Your color' : 'First move',
            SegmentedChoice<StoneColor>(
              choices: const [Choice(StoneColor.black, 'Black'), Choice(StoneColor.white, 'White')],
              selected: vsBot ? _setup.humanColor : StoneColor.black,
              onChanged: vsBot ? (v) => _update((x) => x.copyWith(humanColor: v)) : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rules', style: theme.textTheme.titleMedium),
                    Text(
                      _setup.ruleset.areaScoring ? 'Area scoring' : 'Territory scoring',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<Ruleset>(
                initialValue: _setup.ruleset,
                onSelected: (r) => _update((x) => x.copyWith(ruleset: r, komi: () => null)),
                itemBuilder: (_) => [
                  for (final r in Ruleset.values) PopupMenuItem(value: r, child: Text(r.label)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_setup.ruleset.label, style: theme.textTheme.titleMedium),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(indent: 20, endIndent: 20, color: scheme.outlineVariant),
        StepperRow(
          label: 'Handicap',
          value: _setup.handicap < 2 ? 'None' : '${_setup.handicap}',
          onMinus: _setup.handicap == 0
              ? null
              : () => _update((x) => x.copyWith(handicap: x.handicap <= 2 ? 0 : x.handicap - 1)),
          onPlus: _setup.handicap >= maxHandicap
              ? null
              : () => _update((x) => x.copyWith(handicap: x.handicap < 2 ? 2 : x.handicap + 1)),
        ),
        Divider(indent: 20, endIndent: 20, color: scheme.outlineVariant),
        StepperRow(
          label: 'Komi',
          value: n(komi),
          onMinus: komi <= -20 ? null : () => _update((x) => x.copyWith(komi: () => komi - 0.5)),
          onPlus: komi >= 20 ? null : () => _update((x) => x.copyWith(komi: () => komi + 0.5)),
        ),
      ],
    );
  }
}

/// The board of a new offline game, with its handicap stones.
Board previewBoard(OfflineGameSetup setup) {
  var board = Board.empty(setup.size, setup.size);
  if (setup.handicap >= 2) {
    board = board.withStones(fixedHandicapStones(setup.size, setup.handicap), StoneColor.black);
  }
  return board;
}
