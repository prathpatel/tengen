import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/ogs/game_data.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/widgets/player_bar.dart';

/// `Black [3d] vs White [1k]` with stone icons.
class PlayersTitle extends StatelessWidget {
  const PlayersTitle({required this.black, required this.white, this.winner, super.key});

  final OgsUser black;
  final OgsUser white;
  final StoneColor? winner;

  @override
  Widget build(BuildContext context) {
    TextStyle? style(StoneColor c) =>
        winner == c ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (color, user) in [(StoneColor.black, black), (StoneColor.white, white)])
          Row(
            children: [
              StoneIcon(color, size: 12),
              const SizedBox(width: 6),
              Flexible(
                child: Text(user.displayName, style: style(color), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
      ],
    );
  }
}

class LiveGameTile extends StatelessWidget {
  const LiveGameTile({required this.entry, required this.onTap, super.key});

  final GameListEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    title: PlayersTitle(black: entry.black, white: entry.white),
    subtitle: Text(
      [
        '${entry.width}×${entry.height}',
        'move ${entry.moveNumber}',
        if (entry.handicap > 1) 'H${entry.handicap}',
        if (entry.ranked) 'ranked',
      ].join(' · '),
    ),
    trailing: const Icon(Icons.chevron_right),
  );
}
