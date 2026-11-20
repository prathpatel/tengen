import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/constants.dart';
import 'package:tengen/src/model/auth/auth_controller.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/offline_game/offline_game_controller.dart';
import 'package:tengen/src/model/settings/preferences.dart';
import 'package:tengen/src/network/http.dart';
import 'package:tengen/src/view/offline_game/offline_game_screen.dart';
import 'package:tengen/src/widgets/goban.dart';
import 'package:tengen/src/widgets/ui.dart';
import 'package:url_launcher/url_launcher.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  late final _register = TapGestureRecognizer()
    ..onTap = () => launchUrl(Uri.https(kOgsHost, '/register'));

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _register.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).signIn(_username.text, _password.text);
      if (mounted) Navigator.of(context).pop();
    } on OgsHttpException catch (e) {
      setState(
        () => _error = e.statusCode == 401 || e.statusCode == 403
            ? 'Wrong username or password.'
            : e.message,
      );
    } on Object catch (e) {
      setState(() => _error = 'Could not sign in: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 14),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final boardHeight = constraints.maxHeight * 0.36;
          // Fills the screen: every child is positioned.
          return Stack(
            fit: StackFit.expand,
            children: [
              // A corner of a board in the user's theme, behind the form.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Goban(
                      board: _art,
                      theme: prefs.boardTheme,
                      blackStones: prefs.blackStones,
                      whiteStones: prefs.whiteStones,
                      showCoordinates: false,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                top: boardHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                      children: [
                        Text('Play Go online', style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in with your online-go.com account for rated games, your games '
                          'list and chat.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        label('Username'),
                        TextField(
                          controller: _username,
                          autofillHints: const [AutofillHints.username],
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(hintText: 'Username'),
                        ),
                        label('Password'),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(hintText: 'Password'),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_error!, style: TextStyle(color: scheme.error)),
                          ),
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                )
                              : const Text('Sign in'),
                        ),
                        const SizedBox(height: 16),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text:
                                    'Your password goes only to $kOgsHost. If you sign in to OGS '
                                    'with Google or another account, set a password in your OGS '
                                    'settings first. No account yet? ',
                              ),
                              TextSpan(
                                text: 'Create one on $kOgsHost',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: scheme.primary,
                                ),
                                recognizer: _register,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => const OfflineGameScreen(setup: OfflineGameSetup()),
                            ),
                          ),
                          child: const Text('Play offline instead'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: CircleBackButton(icon: Icons.close_rounded),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Opens the sign in screen.
Future<void> showSignIn(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => const SignInScreen()));

final _art = Board.parse('''
  ...................
  ...................
  ...O...........X...
  ...................
  ...................
  ...................
  ...................
  ...................
  ...................
  .........X.........
  ...................
''');
