import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/ogs/chat_rooms.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/auth/sign_in_screen.dart';
import 'package:tengen/src/view/user/player_screen.dart';
import 'package:tengen/src/widgets/ui.dart';

/// An OGS chat room: messages, the people in the room and a field to write.
class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({required this.room, super.key});

  final ChatRoomInfo room;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    if (ref.read(chatRoomProvider(widget.room.channel).notifier).send(_input.text)) {
      _input.clear();
    }
  }

  void _showUsers(List<OgsUser> users) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: Column(
        children: [
          Text('${users.length} in the room', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (_, i) {
                final user = users[i];
                return ListTile(
                  dense: true,
                  leading: Icon(user.isBot ? Icons.smart_toy_outlined : Icons.person_outline),
                  title: Text(user.username),
                  trailing: Text(user.rankLabel),
                  onTap: user.id > 0
                      ? () {
                          Navigator.pop(sheetContext);
                          pushInTab<void>(context, PlayerScreen(playerId: user.id));
                        }
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final state = ref.watch(chatRoomProvider(room.channel));
    final auth = ref.watch(authProvider).value;
    final me = auth?.user;
    final signedIn = auth?.isSignedIn ?? false;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final users = state.users.values.toList()
      ..sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    final topic = state.topic?.trim() ?? '';

    return Scaffold(
      appBar: TopBar(
        title: '${room.flag}  ${room.name}',
        subtitle: state.joined ? '${users.length} in the room' : 'Joining…',
        actions: [
          CircleIconButton(
            tooltip: 'People in the room',
            icon: Icons.people_outline_rounded,
            onPressed: users.isEmpty ? null : () => _showUsers(users),
          ),
        ],
      ),
      body: Column(
        children: [
          if (topic.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: scheme.surfaceContainerHigh,
              child: Text(
                topic,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          Expanded(
            child: state.messages.isEmpty
                ? Center(
                    child: state.joined
                        ? Text(
                            'No messages yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        : const CircularProgressIndicator(),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: state.messages.length,
                    itemBuilder: (context, i) {
                      final message = state.messages[state.messages.length - 1 - i];
                      final mine = me != null && message.user.id == me.id;
                      final rank = message.user.rankLabel;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: message.user.username,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: mine ? scheme.primary : scheme.tertiary,
                                ),
                              ),
                              if (rank.isNotEmpty)
                                TextSpan(
                                  text: ' $rank',
                                  style: TextStyle(color: scheme.onSurfaceVariant),
                                ),
                              TextSpan(
                                text:
                                    '  ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(message.date))}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                              TextSpan(
                                text: '\n${message.text}',
                                style: message.system
                                    ? const TextStyle(fontStyle: FontStyle.italic)
                                    : null,
                              ),
                            ],
                          ),
                          style: theme.textTheme.bodyMedium,
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
                            decoration: InputDecoration(
                              hintText: 'Message ${room.name}',
                              counterText: '',
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(tooltip: 'Send', icon: const Icon(Icons.send), onPressed: _send),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sign in to write in this room.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => pushFullScreen<void>(context, const SignInScreen()),
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
