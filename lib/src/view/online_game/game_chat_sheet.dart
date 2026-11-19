import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/ogs/chat.dart';
import 'package:tengen/src/model/online_game/online_game_controller.dart';
import 'package:tengen/src/widgets/player_bar.dart';

/// Opens the chat of an OGS game in a bottom sheet.
Future<void> showGameChat(BuildContext context, int gameId) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
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
    final signedIn = ref.watch(authProvider).value?.isSignedIn ?? false;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chat = state?.chat ?? const <GameChatLine>[];
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    StoneColor? colorOf(GameChatLine line) => state?.data.colorOf(line.playerId);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.65,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text('Chat', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    state?.isPlayer ?? false ? 'Seen by your opponent' : 'Seen by spectators',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: chat.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet',
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: chat.length,
                      itemBuilder: (context, i) {
                        final line = chat[chat.length - 1 - i];
                        final color = colorOf(line);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 3, right: 8),
                                child: color != null
                                    ? StoneIcon(color, size: 14)
                                    : Icon(
                                        Icons.visibility_outlined,
                                        size: 16,
                                        color: scheme.onSurfaceVariant,
                                      ),
                              ),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: line.username,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: color != null ? scheme.primary : null,
                                        ),
                                      ),
                                      if (line.isBot)
                                        TextSpan(
                                          text: ' (bot)',
                                          style: TextStyle(color: scheme.onSurfaceVariant),
                                        ),
                                      if (line.moveNumber != null)
                                        TextSpan(
                                          text: '  move ${line.moveNumber}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      TextSpan(text: '\n${line.text}'),
                                    ],
                                  ),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: signedIn
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              maxLength: 500,
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                counterText: '',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Send',
                            icon: const Icon(Icons.send),
                            onPressed: _send,
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'Sign in to chat.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
