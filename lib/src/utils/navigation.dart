import 'package:material_ui/material_ui.dart';

/// Pushes a full screen route above the tab bar (on the root navigator), as the lichess app does
/// for game screens.
Future<T?> pushFullScreen<T>(BuildContext context, Widget screen) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<T>(builder: (_) => screen));

/// Pushes a screen in the current tab's navigator.
Future<T?> pushInTab<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<T>(builder: (_) => screen));

Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'OK',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}
