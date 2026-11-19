import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/ogs_repository.dart';
import 'package:tengen/src/utils/navigation.dart';
import 'package:tengen/src/view/online_game/online_game_screen.dart';
import 'package:tengen/src/widgets/game_tiles.dart';

/// Ongoing public games on online-go.com, strongest players first.
class WatchTabScreen extends StatelessWidget {
  const WatchTabScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: GameListKind.values.length,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Watch'),
        bottom: TabBar(tabs: [for (final kind in GameListKind.values) Tab(text: kind.label)]),
      ),
      body: TabBarView(children: [for (final kind in GameListKind.values) _GameList(kind: kind)]),
    ),
  );
}

class _GameList extends ConsumerWidget {
  const _GameList({required this.kind});

  final GameListKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(liveGamesProvider(kind));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(liveGamesProvider(kind));
        await ref.read(liveGamesProvider(kind).future).catchError((_) => <GameListEntry>[]);
      },
      child: switch (games) {
        AsyncData(:final value) when value.isEmpty => ListView(
          children: const [ListTile(title: Text('No games right now'))],
        ),
        AsyncData(:final value) => ListView.separated(
          itemCount: value.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => LiveGameTile(
            entry: value[i],
            onTap: () => pushFullScreen<void>(context, OnlineGameScreen(gameId: value[i].id)),
          ),
        ),
        AsyncError(:final error) => ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_off),
              title: const Text('Could not load the games'),
              subtitle: Text('$error'),
              trailing: TextButton(
                onPressed: () => ref.invalidate(liveGamesProvider(kind)),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
