import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/ogs/chat_rooms.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/chat/chat_room_screen.dart';

/// The public chat rooms of online-go.com.
class ChatTabScreen extends StatelessWidget {
  const ChatTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Chat rooms')),
      body: ListView.separated(
        itemCount: globalChatRooms.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, i) {
          final room = globalChatRooms[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              child: Text(room.flag, style: const TextStyle(fontSize: 20)),
            ),
            title: Text(room.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushInTab<void>(context, ChatRoomScreen(room: room)),
          );
        },
      ),
    );
  }
}
