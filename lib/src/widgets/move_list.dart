import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/coordinates.dart';
import 'package:tengen/src/model/go/game.dart';
import 'package:tengen/src/widgets/player_bar.dart';

/// The moves of a game in a horizontal strip, in pairs as in the chess.com and lichess apps:
/// `1. ● D4 ○ Q16   2. ● C3 ○ R4 …`, one number for each two moves.
///
/// [selected] is the number of moves shown on the board (0 for the initial position). Tapping a
/// move selects the position after it. The current move is highlighted and kept in view.
class MoveList extends StatefulWidget {
  const MoveList({
    required this.moves,
    required this.boardHeight,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<GoMove> moves;
  final int boardHeight;
  final int selected;
  final ValueChanged<int> onSelect;

  static const height = 44.0;

  @override
  State<MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<MoveList> {
  final _controller = ScrollController();
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow(animate: false));
  }

  @override
  void didUpdateWidget(MoveList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected || oldWidget.moves.length != widget.moves.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow(animate: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _follow({required bool animate}) {
    if (!mounted || !_controller.hasClients) return;
    final live = widget.selected == widget.moves.length;
    final itemContext = _selectedKey.currentContext;
    if (live || itemContext == null) {
      final end = _controller.position.maxScrollExtent;
      if (animate) {
        _controller.animateTo(
          end,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _controller.jumpTo(end);
      }
      return;
    }
    Scrollable.ensureVisible(
      itemContext,
      alignment: 0.5,
      duration: animate ? const Duration(milliseconds: 200) : Duration.zero,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (widget.moves.isEmpty) {
      return SizedBox(
        height: MoveList.height,
        child: Center(
          child: Text(
            'No moves yet',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return SizedBox(
      height: MoveList.height,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (var pair = 0; pair * 2 < widget.moves.length; pair++) ...[
              if (pair > 0) const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 2),
                child: Text(
                  '${pair + 1}.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              for (final i in [pair * 2, pair * 2 + 1])
                if (i < widget.moves.length)
                  _MoveItem(
                    key: widget.selected == i + 1 ? _selectedKey : null,
                    move: widget.moves[i],
                    label: prettyCoordinate(widget.moves[i].point, widget.boardHeight),
                    selected: widget.selected == i + 1,
                    onTap: () => widget.onSelect(i + 1),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One move: its stone and coordinate, on a highlight when it is the move shown.
class _MoveItem extends StatelessWidget {
  const _MoveItem({
    required this.move,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final GoMove move;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StoneIcon(move.color, size: 12),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
