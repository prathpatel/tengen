import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tabs of the app's bottom bar.
enum ShellTab { home, puzzles, learn, watch, profile }

/// The tab shown, so that a screen (the home avatar) can switch to another.
final shellTabProvider = NotifierProvider<ShellTabController, ShellTab>(ShellTabController.new);

class ShellTabController extends Notifier<ShellTab> {
  @override
  ShellTab build() => ShellTab.home;

  // ignore: use_setters_to_change_properties
  void select(ShellTab tab) => state = tab;
}
