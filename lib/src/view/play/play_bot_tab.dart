import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';
import 'package:tengen/src/model/ogs/bots.dart';
import 'package:tengen/src/model/online_game/automatch_controller.dart';
import 'package:tengen/src/model/online_game/bot_challenge_controller.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/auth/sign_in_screen.dart';
import 'package:tengen/src/view/offline_game/offline_game_screen.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/widgets/form_layout.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';

/// A game against one of the bots of OGS (KataGo, GnuGo, Fuego…), as the "Play computer" dialog
/// of the OGS website: the settings, then the bots that accept them, by strength.
class PlayBotTab extends ConsumerStatefulWidget {
  const PlayBotTab({super.key});

  @override
  ConsumerState<PlayBotTab> createState() => _PlayBotTabState();
}

class _PlayBotTabState extends ConsumerState<PlayBotTab> {
  /// The strength group shown; at first the one of the chosen bot, or of the player.
  BotCategory? _category;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).value;
    if (!(auth?.isSignedIn ?? false)) return const _SignedOut();

    final settings = ref.watch(botGameSettingsProvider);
    final bots = ref.watch(activeBotsProvider);
    final challenge = ref.watch(botChallengeProvider);
    final theme = Theme.of(context);
    void update(BotGameSettings s) => ref.read(botGameSettingsProvider.notifier).update(s);
    final options = settings.options(playerRanking: auth!.user.ranking);

    ref.listen(botChallengeProvider, (_, next) {
      switch (next) {
        case BotChallengeAccepted(:final gameId):
          ref.read(botChallengeProvider.notifier).reset();
          pushFullScreen<void>(context, OnlineGameScreen(gameId: gameId));
        case BotChallengeFailed(:final message):
          ref.read(botChallengeProvider.notifier).reset();
          showSnack(context, message);
        case _:
          break;
      }
    });

    final list = bots.value ?? const <OgsBot>[];
    final verdicts = {for (final b in list) b.id: botAccepts(b, options)};
    final selected = list
        .where((b) => b.id == settings.botId && verdicts[b.id]!.clock != null)
        .firstOrNull;
    final waiting = challenge is BotChallengeWaiting;
    final category =
        _category ??
        list.where((b) => b.id == settings.botId).firstOrNull?.category ??
        BotCategory.of(auth.user.ranking);

    return FormWithAction(
      action: waiting
          ? OutlinedButton.icon(
              onPressed: ref.read(botChallengeProvider.notifier).cancel,
              icon: const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: Text('Waiting for ${challenge.bot.username}… Cancel', maxLines: 1),
            )
          : FilledButton.icon(
              onPressed: selected == null
                  ? null
                  : () => ref.read(botChallengeProvider.notifier).challenge(selected, options),
              icon: const Icon(Icons.smart_toy_outlined),
              label: Text(
                selected == null ? 'Choose a computer opponent' : 'Play ${selected.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      children: [
        LabeledField(
          'Board size',
          boardSizeSelector(settings.size, (v) => update(settings.copyWith(size: v))),
        ),
        LabeledField(
          'Time',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedChoice<GameSpeed>(
                choices: [for (final s in botSpeeds) Choice(s, s.label)],
                selected: settings.speed,
                onChanged: (v) => update(settings.copyWith(speed: v)),
              ),
              const SizedBox(height: 8),
              SegmentedChoice<ClockSystem>(
                choices: [for (final s in ClockSystem.values) Choice(s, s.label)],
                selected: settings.system,
                onChanged: (v) => update(settings.copyWith(system: v)),
              ),
              const SizedBox(height: 6),
              Text(
                '${quickMatchTime(settings.size, settings.speed, settings.system)}  ·  '
                '${settings.speed.estimate(settings.size)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('Rated'),
          subtitle: const Text('Counts for your OGS rank'),
          value: settings.ranked,
          onChanged: (v) => update(settings.copyWith(ranked: v)),
        ),
        SwitchListTile(
          title: const Text('Handicap'),
          subtitle: const Text('Stones for the weaker player, from the ranks'),
          value: settings.handicap,
          onChanged: (v) => update(settings.copyWith(handicap: v)),
        ),
        switch (bots) {
          AsyncData() when list.isEmpty => const _Message(
            icon: Icons.smart_toy_outlined,
            text: 'No computer opponents are online right now.',
          ),
          AsyncData() => _BotList(
            category: category,
            onCategory: (c) => setState(() => _category = c),
            bots: list,
            verdicts: verdicts,
            selected: selected,
            enabled: !waiting,
            onSelect: (b) => update(settings.copyWith(botId: b.id)),
          ),
          AsyncError() => const _Message(
            icon: Icons.cloud_off,
            text: 'Could not load the computer opponents.',
          ),
          _ => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}

class _BotList extends StatelessWidget {
  const _BotList({
    required this.category,
    required this.onCategory,
    required this.bots,
    required this.verdicts,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final BotCategory category;
  final ValueChanged<BotCategory> onCategory;
  final List<OgsBot> bots;
  final Map<int, ({BotClock? clock, String? problem})> verdicts;
  final OgsBot? selected;
  final bool enabled;
  final ValueChanged<OgsBot> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final group = bots.where((b) => b.category == category).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          'Opponent',
          SegmentedChoice<BotCategory>(
            choices: [for (final c in BotCategory.values) Choice(c, c.label)],
            selected: category,
            onChanged: onCategory,
          ),
        ),
        if (group.isEmpty)
          const _Message(icon: Icons.smart_toy_outlined, text: 'No bots of this strength online.')
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Material(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Bots that can play these settings first, weakest first.
                  for (final bot in [
                    ...group.where((b) => verdicts[b.id]!.clock != null),
                    ...group.where((b) => verdicts[b.id]!.clock == null),
                  ])
                    _BotRow(
                      bot: bot,
                      problem: verdicts[bot.id]!.problem,
                      selected: bot == selected,
                      onTap: enabled && verdicts[bot.id]!.clock != null
                          ? () => onSelect(bot)
                          : null,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BotRow extends StatelessWidget {
  const _BotRow({
    required this.bot,
    required this.problem,
    required this.selected,
    required this.onTap,
  });

  final OgsBot bot;
  final String? problem;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final available = problem == null;
    return Opacity(
      opacity: available ? 1 : 0.5,
      child: ListTile(
        onTap: onTap,
        selected: selected,
        selectedTileColor: scheme.primaryContainer,
        selectedColor: scheme.onPrimaryContainer,
        leading: CircleAvatar(
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundImage: bot.iconUrl == null ? null : NetworkImage(bot.iconUrl!),
          // The robot icon stays when the picture cannot load.
          onForegroundImageError: bot.iconUrl == null ? null : (_, _) {},
          child: const Icon(Icons.smart_toy_outlined, size: 20),
        ),
        title: Row(
          children: [
            Flexible(child: Text(bot.username, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(
              bot.rankLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
            ),
            if (bot.isKataGo) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'KataGo',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: available ? null : Text(problem!),
        trailing: selected ? const Icon(Icons.check_circle) : null,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        Icon(icon, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smart_toy_outlined, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Sign in with your online-go.com account to play the OGS computer opponents: '
            'KataGo, GnuGo and others, from beginner to professional strength.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => pushFullScreen<void>(context, const SignInScreen()),
            child: const Text('Sign in'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () =>
                pushFullScreen<void>(context, const OfflineGameScreen(setup: OfflineGameSetup())),
            child: const Text('Play the simple offline bot'),
          ),
        ],
      ),
    ),
  );
}
