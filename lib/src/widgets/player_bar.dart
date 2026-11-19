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
      // The outline keeps black stones visible on dark backgrounds.
      border: Border.all(
        color: color == StoneColor.black
            ? Colors.white.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.2),
        width: 0.8,
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

/// A player above or below the board, as in the lichess app: a stone for the player's color,
/// name and rank, captures below, and the clock (or turn indicator) on the right.
class PlayerBar extends StatelessWidget {
  const PlayerBar({
    required this.color,
    required this.name,
    required this.captures,
    required this.active,
    this.rank,
    this.isBot = false,
    this.komi,
    this.clock,
    this.thinking = false,
    this.note,
    this.onTap,
    super.key,
  });

  final StoneColor color;
  final String name;

  /// A short status shown after the captures, e.g. `Passed`.
  final String? note;

  /// Rank label, e.g. `3k`.
  final String? rank;
  final bool isBot;

  /// Stones of the opponent captured by this player.
  final int captures;

  /// Komi, shown for white.
  final double? komi;

  /// Whether it is this player's turn.
  final bool active;

  /// The clock, for online games. Without a clock, the player to move gets a "To play" tag.
  final Widget? clock;

  /// Shows that the computer is choosing its move.
  final bool thinking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    final Widget? trailing =
        clock ??
        (thinking
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text('Thinking…', style: muted),
                ],
              )
            : active
            ? Text(
                'To play',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      StoneIcon(color, size: 16),
                      const SizedBox(width: 8),
                      if (isBot) ...[
                        Icon(Icons.smart_toy_outlined, size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (rank != null && rank!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(rank!, style: muted),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Tooltip(
                    message: '$captures ${captures == 1 ? 'capture' : 'captures'}',
                    child: Row(
                      children: [
                        const SizedBox(width: 2),
                        StoneIcon(color.opposite, size: 11),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            [
                              if (captures == 0) 'no captures' else '+$captures',
                              if (komi != null) 'komi ${_formatKomi(komi!)}',
                            ].join('  ·  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (note != null) ...[
                          const SizedBox(width: 8),
                          // Same text style as the line, and no vertical padding: the tag
                          // must not change the row height (it would move the board).
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: scheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              note!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onTertiaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  static String _formatKomi(double komi) =>
      komi == komi.roundToDouble() ? '${komi.toInt()}' : '$komi';
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
    final scheme = theme.colorScheme;
    final low = _running && reading.critical < const Duration(seconds: 10);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: low
            ? scheme.errorContainer
            : (_running ? scheme.surfaceContainerHighest : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        reading.label,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: low
              ? scheme.onErrorContainer
              : (_running ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.7)),
          fontFeatures: const [FontFeature.tabularFigures()],
          fontWeight: _running ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
