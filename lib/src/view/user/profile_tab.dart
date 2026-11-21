import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/ogs/ogs_repository.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/auth/sign_in_screen.dart';
import 'package:tengen/src/view/chat/chat_rooms_screen.dart';
import 'package:tengen/src/view/home/home_screen.dart';
import 'package:tengen/src/view/home/my_games_screen.dart';
import 'package:tengen/src/view/settings/settings_screen.dart';
import 'package:tengen/src/view/user/player_screen.dart';
import 'package:tengen/src/widgets/ui.dart';

/// The Profile tab: who you are on online-go.com, your games, the settings and the rest.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;
    final signedIn = auth?.isSignedIn ?? false;
    final user = signedIn ? auth!.user : null;
    final me = user == null ? null : ref.watch(playerProvider(user.id)).value;
    final board = ref.watch(preferencesProvider.select((p) => p.boardTheme));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget icon(IconData i) => Icon(i, size: 21, color: scheme.onSurfaceVariant);

    return ListView(
      padding: tabPagePadding(context, page: true),
      children: [
        const PageHeader('Profile'),
        if (user != null)
          Group(
            children: [
              GroupRow(
                leading: AccountAvatar(user: me ?? user, size: 46, onTap: () {}),
                title: user.username,
                subtitle: [
                  (me ?? user).rankLabel,
                  if (me?.rating case final r?) 'rating ${r.round()}',
                ].where((s) => s.isNotEmpty).join(' · '),
                onTap: () => pushFullScreen<void>(context, PlayerScreen(playerId: user.id)),
              ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Not signed in', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Sign in to online-go.com to play people and the KataGo bots, and to see '
                    'your games and rank.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: () => showSignIn(context), child: const Text('Sign in')),
                ],
              ),
            ),
          ),
        if (user != null) ...[
          const SectionLabel('Games'),
          Group(
            children: [
              GroupRow(
                leading: icon(Icons.layers_outlined),
                title: 'My games',
                subtitle: 'Ongoing and finished',
                onTap: () => pushFullScreen<void>(context, const MyGamesScreen()),
              ),
              GroupRow(
                leading: icon(Icons.person_outline_rounded),
                title: 'Profile on OGS',
                subtitle: 'Stats and recent games',
                onTap: () => pushFullScreen<void>(context, PlayerScreen(playerId: user.id)),
              ),
            ],
          ),
        ],
        const SectionLabel('App'),
        Group(
          children: [
            GroupRow(
              leading: icon(Icons.settings_outlined),
              title: 'Settings',
              subtitle: 'Sound, moves, coordinates, theme',
              onTap: () => pushFullScreen<void>(context, const SettingsScreen()),
            ),
            GroupRow(
              leading: BoardSwatch(board: board, size: 22),
              title: 'Board and stones',
              subtitle: board.label,
              onTap: () => pushFullScreen<void>(context, const SettingsScreen()),
            ),
            GroupRow(
              leading: icon(Icons.forum_outlined),
              title: 'Chat rooms',
              onTap: () => pushFullScreen<void>(context, const ChatRoomsScreen()),
            ),
            GroupRow(
              leading: icon(Icons.info_outline_rounded),
              title: 'About',
              subtitle: 'Version $kAppVersion',
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
                    'play uses the online-go.com APIs; this app is not affiliated with OGS.\n\n'
                    'The Learn course, the board and stone images and the stone sounds come '
                    'from online-go.com, © the OGS contributors, under the GNU AGPL v3.',
              ),
            ),
          ],
        ),
        if (user != null) ...[
          const SizedBox(height: 20),
          Group(
            children: [
              GroupRow(
                leading: Icon(Icons.logout_rounded, size: 21, color: scheme.error),
                title: 'Sign out',
                chevron: false,
                onTap: () async {
                  if (await confirm(context, title: 'Sign out?', confirmLabel: 'Sign out')) {
                    await ref.read(authProvider.notifier).signOut();
                  }
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}
