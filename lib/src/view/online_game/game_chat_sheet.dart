import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/ogs/chat.dart';
import 'package:tengen/src/model/online_game/online_game_controller.dart';
import 'package:tengen/src/widgets/player_bar.dart';
import 'package:tengen/src/widgets/segmented_choice.dart';
import 'package:tengen/src/widgets/ui.dart';

/// Opens the chat of an OGS game in a bottom sheet.
Future<void> showGameChat(BuildContext context, int gameId) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => GameChatSheet(gameId: gameId),
);

/// The chat of an OGS game: the players' messages and the spectators' ones, and a field to write.
class GameChatSheet extends ConsumerStatefulWidget {
  const GameChatSheet({required this.gameId, super.key});

  final int gameId;

  @override
  ConsumerState<GameChatSheet> createState() => _GameChatSheetState();
}

class _GameChatSheetState extends ConsumerState<GameChatSheet> {
  final _input = TextEditingController();

  /// The spectators' channel rather than the game's.
  bool _spectators = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    ref.read(onlineGameProvider(widget.gameId).notifier).sendChat(text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onlineGameProvider(widget.gameId)).value;
    final me = ref.watch(authProvider).value;
    final signedIn = me?.isSignedIn ?? false;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = state?.chat ?? const <GameChatLine>[];
    // OGS puts the spectators' messages in their own channel during a game.
    final spectatorLines = all.where((l) => l.channel == 'spectator').toList();
    final chat = _spectators && spectatorLines.isNotEmpty
        ? spectatorLines
        : all.where((l) => l.channel != 'spectator').toList();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isPlayer = state?.isPlayer ?? false;

    // Items, newest first (the list is reversed): messages, with the move they were written at
    // when it changes.
    final items = <Widget>[];
    for (var i = chat.length - 1; i >= 0; i--) {
      final line = chat[i];
      final mine = signedIn && line.playerId == me!.user.id;
      final color = state?.data.colorOf(line.playerId);
      items.add(
        Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: mine ? scheme.primary : scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!mine)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (color != null) ...[
                          StoneIcon(color, size: 12),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            line.isBot ? '${line.username} (bot)' : line.username,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  Text(
                    line.text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: mine ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final move = line.moveNumber;
      final previousMove = i > 0 ? chat[i - 1].moveNumber : null;
      if (move != null && (i == 0 || previousMove != move)) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Text(
                'Move $move',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        );
      }
    }

    // The chat keeps its height above the keyboard, as far as the screen allows.
    final screen = MediaQuery.sizeOf(context).height;
    final room = screen - bottomInset - MediaQuery.paddingOf(context).top - 48;
    final content = math.min(screen * 0.62, math.max(220.0, room));
    return SizedBox(
      height: content + bottomInset,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('Chat', close: true),
            if (spectatorLines.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: SegmentedChoice<bool>(
                  choices: [
                    Choice(false, isPlayer ? 'With opponent' : 'Players'),
                    Choice(true, 'Spectators · ${spectatorLines.length}'),
                  ],
                  selected: _spectators,
                  onChanged: (v) => setState(() => _spectators = v),
                ),
              ),
            Expanded(
              child: chat.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 32,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No messages yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (signedIn)
                            Text(
                              isPlayer ? 'Say hello to your opponent' : 'Be the first to write',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    )
                  : ListView(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      children: items,
                    ),
            ),
            if (signedIn && chat.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Text(
                  isPlayer ? 'Seen by your opponent' : 'Seen by the players and spectators',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                child: signedIn
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              maxLength: 500,
                              decoration: InputDecoration(
                                hintText: 'Message',
                                counterText: '',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Tooltip(
                            message: 'Send',
                            child: Material(
                              color: scheme.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _send,
                                child: SizedBox.square(
                                  dimension: 56,
                                  child: Icon(Icons.send_rounded, color: scheme.onPrimary),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Sign in to chat.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
