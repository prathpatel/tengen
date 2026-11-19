import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/auth/sign_in_screen.dart';
import 'package:tengen/src/view/user/player_screen.dart';

class MoreTabScreen extends ConsumerWidget {
  const MoreTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;
    final prefs = ref.watch(preferencesProvider);
    final controller = ref.read(preferencesProvider.notifier);
    final theme = Theme.of(context);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          section('Account'),
          if (auth != null && auth.isSignedIn) ...[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(auth.user.displayName),
              subtitle: const Text('Profile and recent games'),
              onTap: () => pushInTab<void>(context, PlayerScreen(playerId: auth.user.id)),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                if (await confirm(context, title: 'Sign out?', confirmLabel: 'Sign out')) {
                  await ref.read(authProvider.notifier).signOut();
                }
              },
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign in to online-go.com'),
              onTap: () => pushFullScreen<void>(context, const SignInScreen()),
            ),
          section('Board'),
          ListTile(
            leading: const Icon(Icons.grid_on),
            title: const Text('Board theme'),
            trailing: DropdownButton<BoardTheme>(
              value: prefs.boardTheme,
              items: [
                for (final t in BoardTheme.values)
                  DropdownMenuItem(
                    value: t,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: t.wood,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: t.lines, width: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(t.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (t) => t == null ? null : controller.setBoardTheme(t),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.abc),
            title: const Text('Show coordinates'),
            value: prefs.showCoordinates,
            onChanged: controller.setShowCoordinates,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.touch_app_outlined),
            title: const Text('Confirm moves'),
            subtitle: const Text('Tap twice to place a stone'),
            value: prefs.confirmMoves,
            onChanged: controller.setConfirmMoves,
          ),
          section('App'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            trailing: DropdownButton<AppThemeMode>(
              value: prefs.themeMode,
              items: const [
                DropdownMenuItem(value: AppThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: AppThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: AppThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (m) => m == null ? null : controller.setThemeMode(m),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: kAppName,
              applicationVersion: kAppVersion,
              applicationLegalese:
                  'Free software under the GNU GPL v3 or later.\n\n'
                  'Based on the Lichess mobile app (github.com/lichess-org/mobile). Online play '
                  'uses the online-go.com APIs; this app is not affiliated with OGS.',
            ),
          ),
        ],
      ),
    );
  }
}
