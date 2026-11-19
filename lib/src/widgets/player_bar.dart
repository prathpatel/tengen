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
      gradient: RadialGradient(
        center: const Alignment(-0.35, -0.4),
        colors: color == StoneColor.black
            ? const [Color(0xFF5A5A5A), Color(0xFF111111)]
            : const [Color(0xFFFFFFFF), Color(0xFFC8C8C8)],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: size * 0.12,
          offset: Offset(0, size * 0.06),
        ),
      ],
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

  /// Stones of the opponent captured by this player.
  final int captures;

  /// Whether it is this player's turn.
  final bool active;

  /// The clock, for online games, or a thinking indicator for the bot.
  final Widget? clock;
  final VoidCallback? onTapName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? scheme.primary : Colors.transparent, width: 1.5),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTapName,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                StoneIcon(color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: active ? scheme.onPrimaryContainer : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Tooltip(
                  message: '$captures ${captures == 1 ? 'capture' : 'captures'}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StoneIcon(color.opposite, size: 12),
                        const SizedBox(width: 5),
                        Text(
                          '$captures',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (clock != null) ...[const SizedBox(width: 8), clock!],
              ],
            ),
          ),
        ),
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
