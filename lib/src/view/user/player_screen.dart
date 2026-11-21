import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/ogs/bots.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_repository.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/model/online_game/bot_challenge_controller.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/view/play/play_screen.dart';
import 'package:tengen/src/widgets/board_thumbnail.dart';
import 'package:tengen/src/widgets/game_result_tag.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';
import 'package:tengen/src/widgets/ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// `4 kyu`, `3 dan`, `2 pro`, from `4k`, `3d`, `2p`.
String _longRank(String rank) => switch (rank.characters.lastOrNull) {
  'k' => '${rank.substring(0, rank.length - 1)} kyu',
  'd' => '${rank.substring(0, rank.length - 1)} dan',
  'p' => '${rank.substring(0, rank.length - 1)} pro',
  _ => rank,
};

/// A player's profile: rank, record, record against you, recent games, and a challenge.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({required this.playerId, super.key});

  final int playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider(playerId));
    final games = ref.watch(playerGamesProvider(playerId));
    final me = ref.watch(authProvider).value;
    final signedIn = me?.isSignedIn ?? false;
    final isMe = signedIn && me!.user.id == playerId;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final link = Uri.https(kOgsHost, '/player/$playerId');

    return Scaffold(
      appBar: TopBar(
        actions: [
          CircleIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: 'Menu',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (sheetContext) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.link_rounded),
                      title: const Text('Copy profile link'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Clipboard.setData(ClipboardData(text: '$link'));
                        showSnack(context, 'Link copied to the clipboard');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          switch (player) {
            AsyncData(:final value) => _Header(
              player: value,
              canChallenge: signedIn && !isMe,
              onOpen: () => launchUrl(link, mode: LaunchMode.externalApplication),
            ),
            AsyncError(:final error) => ListTile(title: Text('Could not load the player: $error')),
            _ => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(label: 'Games', value: _games(ref)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stat(label: 'Won', value: _wonPercent(ref)),
                ),
                if (signedIn && !isMe) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stat(label: 'Vs you', value: _versusMe(ref, me!.user.id)),
                  ),
                ],
              ],
            ),
          ),
          const SectionLabel('Recent games', padding: EdgeInsets.fromLTRB(24, 26, 24, 6)),
          switch (games) {
            AsyncData(:final value) when value.isEmpty => const ListTile(title: Text('No games')),
            AsyncData() => const SizedBox.shrink(),
            AsyncError(:final error) => ListTile(title: Text('Could not load the games: $error')),
            _ => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
          // One child of the list per game: only the games in view are built, and only theirs
          // are downloaded.
          if (games case AsyncData(:final value))
            for (final g in value.take(15)) _RecentGame(game: g, playerId: playerId),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text(
              'Counts of finished games on online-go.com, annulled ones left out.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  String? _games(WidgetRef ref) => switch (ref.watch(playerStatsProvider(playerId))) {
    AsyncData(:final value) => _thousands(value.games),
    AsyncError() => '–',
    _ => null,
  };

  String? _wonPercent(WidgetRef ref) => switch (ref.watch(playerStatsProvider(playerId))) {
    AsyncData(:final value) when value.games == 0 => '–',
    AsyncData(:final value) => '${(value.wins * 100 / value.games).round()}%',
    AsyncError() => '–',
    _ => null,
  };

  String? _versusMe(WidgetRef ref, int me) =>
      switch (ref.watch(headToHeadProvider((me: me, them: playerId)))) {
        AsyncData(:final value) => '${value.wins}–${value.losses}',
        AsyncError() => '–',
        _ => null,
      };
}

String _thousands(int n) {
  final s = '$n';
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return '$buffer';
}

class _Header extends StatelessWidget {
  const _Header({required this.player, required this.canChallenge, required this.onOpen});

  final OgsUser player;
  final bool canChallenge;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = player.iconUrl;
    final initial = Center(
      child: Text(
        player.username.isEmpty ? '?' : player.username.characters.first.toUpperCase(),
        style: theme.textTheme.displaySmall?.copyWith(
          color: const Color(0xFF1A1A1A),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(color: Color(0xFFF2F0EC), shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: icon == null
                ? initial
                : Image.network(icon, fit: BoxFit.cover, errorBuilder: (_, _, _) => initial),
          ),
          const SizedBox(height: 14),
          Text(player.username, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            [
              if (player.rankLabel.isNotEmpty) _longRank(player.rankLabel),
              if (player.rating != null) 'Rating ${player.rating!.round()}',
              if (player.isBot) 'Bot',
            ].join(' · '),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (canChallenge) ...[
                Expanded(
                  child: FilledButton(
                    onPressed: () => showTengenSheet<void>(
                      context,
                      _ChallengeSheet(player: player),
                      topGap: 120,
                    ),
                    child: const Text('Challenge'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  style: softButtonStyle(context),
                  onPressed: onOpen,
                  child: const Text('Open on OGS'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;

  /// Null while loading.
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: value == null
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value!, style: theme.textTheme.headlineSmall),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecentGame extends ConsumerWidget {
  const _RecentGame({required this.game, required this.playerId});

  final PlayerGame game;
  final int playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(gameDataProvider(game.id)).value;
    final board = data?.buildGameCached();
    final opponent = game.black.id == playerId ? game.white : game.black;
    final speed = data?.timeControl?.speed;
    return InkWell(
      onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: game.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            BoardThumbnail(
              board: board?.board ?? Board.empty(game.width, game.height),
              size: 60,
              lastMove: board?.position.lastMove?.point,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vs ${opponent.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    [
                      '${game.width}×${game.height}',
                      if (speed != null && speed.isNotEmpty)
                        speed[0].toUpperCase() + speed.substring(1),
                      if (game.ended != null)
                        MaterialLocalizations.of(context).formatShortDate(game.ended!.toLocal()),
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GameResultTag(game: game, playerId: playerId),
          ],
        ),
      ),
    );
  }
}

/// The settings of a challenge to [player], sent like the challenge of the OGS player page.
class _ChallengeSheet extends ConsumerStatefulWidget {
  const _ChallengeSheet({required this.player});

  final OgsUser player;

  @override
  ConsumerState<_ChallengeSheet> createState() => _ChallengeSheetState();
}

class _ChallengeSheetState extends ConsumerState<_ChallengeSheet> {
  int _size = 19;
  GameSpeed _speed = GameSpeed.rapid;
  ClockSystem _system = ClockSystem.byoyomi;
  bool _ranked = true;
  bool _handicap = false;
  String _color = 'automatic';

  @override
  Widget build(BuildContext context) {
    final challenge = ref.watch(botChallengeProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final system = _speed == GameSpeed.correspondence ? ClockSystem.fischer : _system;
    final clock = BotClock(_size, _speed, system);
    final options = BotGameOptions(size: _size, clock: clock, ranked: _ranked, handicap: _handicap);

    ref.listen(botChallengeProvider, (_, next) {
      switch (next) {
        case BotChallengeAccepted(:final gameId):
          ref.read(botChallengeProvider.notifier).reset();
          Navigator.of(context).pop();
          pushFullScreen<void>(context, OnlineGameScreen(gameId: gameId));
        case BotChallengeSent(:final opponent):
          ref.read(botChallengeProvider.notifier).reset();
          Navigator.of(context).pop();
          showSnack(context, 'Challenge sent. The game starts when $opponent accepts it.');
        case BotChallengeFailed(:final message):
          ref.read(botChallengeProvider.notifier).reset();
          showSnack(context, message);
        case _:
          break;
      }
    });

    final waiting = challenge is BotChallengeWaiting;
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLow,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle('Challenge ${widget.player.username}', close: true),
            Expanded(
              child: ListView(
                children: [
                  setting(
                    'Board size',
                    SegmentedChoice<int>(
                      choices: const [Choice(9, '9×9'), Choice(13, '13×13'), Choice(19, '19×19')],
                      selected: _size,
                      onChanged: (v) => setState(() => _size = v),
                    ),
                  ),
                  setting(
                    'Speed',
                    SegmentedChoice<GameSpeed>(
                      choices: [for (final s in GameSpeed.values) Choice(s, s.shortLabel)],
                      selected: _speed,
                      onChanged: (v) => setState(() => _speed = v),
                    ),
                  ),
                  if (_speed != GameSpeed.correspondence)
                    setting(
                      'Clock',
                      SegmentedChoice<ClockSystem>(
                        choices: [for (final c in ClockSystem.values) Choice(c, c.label)],
                        selected: _system,
                        onChanged: (v) => setState(() => _system = v),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Text(
                      quickMatchTime(_size, _speed, system),
                      style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  setting(
                    'Your color',
                    SegmentedChoice<String>(
                      choices: const [
                        Choice('automatic', 'Automatic'),
                        Choice('black', 'Black'),
                        Choice('white', 'White'),
                      ],
                      selected: _color,
                      onChanged: (v) => setState(() => _color = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ToggleRow(
                    title: 'Rated',
                    subtitle: 'Counts for both ranks',
                    value: _ranked,
                    onChanged: (v) => setState(() => _ranked = v),
                  ),
                  ToggleRow(
                    title: 'Handicap',
                    subtitle: 'From the ranks',
                    value: _handicap,
                    onChanged: (v) => setState(() => _handicap = v),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: waiting
                    ? OutlinedButton.icon(
                        onPressed: ref.read(botChallengeProvider.notifier).cancel,
                        icon: const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        label: Text('Waiting for ${widget.player.username}… Cancel', maxLines: 1),
                      )
                    : FilledButton(
                        onPressed: () => ref
                            .read(botChallengeProvider.notifier)
                            .challengePlayer(
                              playerId: widget.player.id,
                              name: widget.player.username,
                              options: options,
                              color: _color,
                            ),
                        child: const Text('Send challenge'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
