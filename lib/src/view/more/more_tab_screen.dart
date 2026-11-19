import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/auth/sign_in_screen.dart';
import 'package:tengen/src/view/chat/chat_rooms_screen.dart';
import 'package:tengen/src/view/offline_game/offline_game_screen.dart';
import 'package:tengen/src/view/play/play_screen.dart';
import 'package:tengen/src/view/settings/settings_screen.dart';
import 'package:tengen/src/view/user/player_screen.dart';
import 'package:tengen/src/widgets/list_section.dart';

/// Grouped links, as in the More tab of the lichess app.
class MoreTabScreen extends ConsumerWidget {
  const MoreTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;
    final signedIn = auth?.isSignedIn ?? false;
    final theme = Theme.of(context);

    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text(kAppName)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          label('Play'),
          CardSection(
            children: [
              CardRow(
                icon: Icons.public,
                title: 'Play online',
                onTap: () => pushFullScreen<void>(context, const PlayScreen()),
              ),
              CardRow(
                icon: Icons.smart_toy_outlined,
                title: 'Play the computer',
                onTap: () => pushFullScreen<void>(context, const PlayScreen(offline: true)),
              ),
              CardRow(
                icon: Icons.people_outline,
                title: 'Pass and play',
                onTap: () => pushFullScreen<void>(
                  context,
                  const OfflineGameScreen(
                    setup: OfflineGameSetup(opponent: OfflineOpponent.human, size: 13),
                  ),
                ),
              ),
            ],
          ),
          label('Community'),
          CardSection(
            children: [
              CardRow(
                icon: Icons.forum_outlined,
                title: 'Chat rooms',
                onTap: () => pushInTab<void>(context, const ChatRoomsScreen()),
              ),
            ],
          ),
          label(signedIn ? auth!.user.username : 'Account'),
          CardSection(
            children: [
              if (signedIn) ...[
                CardRow(
                  icon: Icons.person_outline,
                  title: 'Profile',
                  onTap: () => pushInTab<void>(context, PlayerScreen(playerId: auth!.user.id)),
                ),
                CardRow(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => pushInTab<void>(context, const SettingsScreen()),
                ),
                CardRow(
                  icon: Icons.logout,
                  title: 'Sign out',
                  onTap: () async {
                    if (await confirm(context, title: 'Sign out?', confirmLabel: 'Sign out')) {
                      await ref.read(authProvider.notifier).signOut();
                    }
                  },
                ),
              ] else ...[
                CardRow(
                  icon: Icons.login,
                  title: 'Sign in to online-go.com',
                  onTap: () => pushFullScreen<void>(context, const SignInScreen()),
                ),
                CardRow(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => pushInTab<void>(context, const SettingsScreen()),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          CardSection(
            children: [
              CardRow(
                icon: Icons.info_outline,
                title: 'About',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: kAppName,
                  applicationVersion: kAppVersion,
                  applicationIcon: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/icon/icon.png', width: 56, height: 56),
                  ),
                  applicationLegalese:
                      'Free software under the GNU GPL v3 or later.\n\n'
                      'Based on the Lichess mobile app (github.com/lichess-org/mobile). Online '
                      'play uses the online-go.com APIs; this app is not affiliated with OGS.',
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Text(
              '$kAppName is a free, open source app to play Go, on online-go.com or on your '
              'device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
