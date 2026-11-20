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

/// A player above or below the board, in a rounded pill: the opponent on the left above the
/// board, you on the right below it. The player to move is outlined in the accent color.
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

  /// A short status in the accent, e.g. `Passed`.
  final String? note;

  /// The clock, for online games.
  final Widget? clock;
  final bool active;
  final bool isBot;

  /// Shows that the computer is choosing its move.
  final bool thinking;

  /// Aligned to the right, with the stone last (you, below the board).
  final bool end;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final text = Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBot) ...[
              Icon(Icons.smart_toy_outlined, size: 17, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (rank != null && rank!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                rank!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (thinking) ...[
              const SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                [if (thinking) 'Thinking…', ?detail].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            ),
            if (note != null) ...[
              const SizedBox(width: 8),
              Text(
                note!,
                style: muted?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ],
    );
    final children = <Widget>[
      StoneIcon(color, size: 34),
      const SizedBox(width: 12),
      Flexible(child: text),
      if (clock != null) ...[const SizedBox(width: 16), clock!],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      // A row rather than an Align: the pill must keep its own height (the board takes the rest).
      child: Row(
        mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Material(
              color: scheme.surfaceContainer,
              shape: StadiumBorder(
                side: active
                    ? BorderSide(color: scheme.primary, width: 2)
                    : const BorderSide(color: Colors.transparent, width: 2),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(end ? 18 : 8, 8, end ? 8 : 18, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: end ? children.reversed.toList() : children,
                  ),
                ),
              ),
            ),
          ),
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
    final scheme = theme.colorScheme;
    final low = _running && reading.critical < const Duration(seconds: 10);
    return Text(
      reading.label,
      style: theme.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        color: low ? scheme.error : (_running ? scheme.onSurface : scheme.onSurfaceVariant),
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
