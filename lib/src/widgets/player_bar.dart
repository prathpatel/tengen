import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:tengen/src/model/go/board.dart';
import 'package:tengen/src/model/ogs/clock.dart';
import 'package:tengen/src/widgets/ui.dart';

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

/// A player above or below the board: a full-width rounded card with the stone, the name and
/// rank, a line of detail and the clock in large thin figures. The player to move is on the
/// accent color, the other on soft glass.
class PlayerPill extends StatelessWidget {
  const PlayerPill({
    required this.color,
    required this.name,
    required this.active,
    this.rank,
    this.detail,
    this.note,
    this.clock,
    this.isBot = false,
    this.thinking = false,
    this.end = false,
    this.onTap,
    super.key,
  });

  final StoneColor color;
  final String name;
  final String? rank;

  /// The line below the name: `3 captures`, `Your move · 2 captures`.
  final String? detail;

  /// A short status in bold, e.g. `Passed`.
  final String? note;

  /// The clock, for online games.
  final Widget? clock;
  final bool active;
  final bool isBot;

  /// Shows that the computer is choosing its move.
  final bool thinking;

  /// You, below the board. The card is laid out the same; kept for the callers.
  final bool end;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final fg = active ? scheme.onPrimary : scheme.onSurface;
    final muted = active ? scheme.onPrimary.withValues(alpha: 0.68) : scheme.onSurfaceVariant;
    final line = [if (thinking) 'Thinking…', ?detail].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Pressable(
        scale: 0.98,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
          decoration: BoxDecoration(
            color: active
                ? scheme.primary
                : scheme.surfaceContainerHigh.withValues(alpha: dark ? 0.7 : 0.9),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: active
                  ? Colors.transparent
                  : (dark ? Colors.white : Colors.black).withValues(alpha: 0.06),
            ),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: fg),
            child: Row(
              children: [
                StoneIcon(color, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (isBot) ...[
                            Icon(Icons.smart_toy_outlined, size: 17, color: muted),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(color: fg),
                            ),
                          ),
                          if (rank != null && rank!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              rank!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: muted,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (line.isNotEmpty || note != null)
                        Row(
                          children: [
                            if (thinking) ...[
                              SizedBox.square(
                                dimension: 11,
                                child: CircularProgressIndicator(strokeWidth: 1.6, color: muted),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                line,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                              ),
                            ),
                            if (note != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                note!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: fg,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
                if (clock != null) ...[const SizedBox(width: 12), clock!],
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
    final scheme = theme.colorScheme;
    final low = _running && reading.critical < const Duration(seconds: 10);
    // The color of the card it is on (dark on the accent), dimmed while it is not running.
    final base = DefaultTextStyle.of(context).style.color ?? scheme.onSurface;
    return Text(
      reading.label,
      style: theme.textTheme.headlineMedium?.copyWith(
        fontSize: 30,
        height: 1.1,
        color: low ? scheme.error : (_running ? base : base.withValues(alpha: 0.6)),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
