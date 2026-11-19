import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/ogs/clock.dart';

/// A small stone icon.
class StoneIcon extends StatelessWidget {
  const StoneIcon(this.color, {this.size = 16, super.key});

  final StoneColor color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color == StoneColor.black ? Colors.black : Colors.white,
      border: Border.all(color: Colors.grey.shade600, width: 0.8),
    ),
  );
}

/// Name, captures, turn indicator and clock of one player, shown above or below the board.
class PlayerBar extends StatelessWidget {
  const PlayerBar({
    required this.color,
    required this.name,
    required this.captures,
    required this.active,
    this.subtitle,
    this.clock,
    this.onTapName,
    super.key,
  });

  final StoneColor color;
  final String name;
  final String? subtitle;
  final int captures;

  /// Whether it is this player's turn.
  final bool active;

  /// The clock, for online games.
  final Widget? clock;
  final VoidCallback? onTapName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? theme.colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: StoneIcon(color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onTapName,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [?subtitle, '$captures ${captures == 1 ? 'capture' : 'captures'}'].join(' · '),
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          ?clock,
        ],
      ),
    );
  }
}

/// Displays an OGS game clock, ticking for the player to move.
class OgsClockDisplay extends StatefulWidget {
  const OgsClockDisplay({
    required this.clock,
    required this.color,
    required this.serverNow,
    super.key,
  });

  final OgsClock clock;
  final StoneColor color;
  final DateTime Function() serverNow;

  @override
  State<OgsClockDisplay> createState() => _OgsClockDisplayState();
}

class _OgsClockDisplayState extends State<OgsClockDisplay> {
  Timer? _timer;

  bool get _running =>
      widget.clock.currentColor == widget.color && widget.clock.pausedSince == null;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(OgsClockDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_running) {
      _timer ??= Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() {}));
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.clock.read(widget.color, widget.serverNow());
    final theme = Theme.of(context);
    final low = _running && reading.critical < const Duration(seconds: 10);
    final background = _running
        ? (low ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer)
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = _running
        ? (low ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer)
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(
        reading.label,
        style: theme.textTheme.titleMedium?.copyWith(
          color: foreground,
          fontFeatures: const [FontFeature.tabularFigures()],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
