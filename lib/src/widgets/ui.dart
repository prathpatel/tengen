import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

/// The building blocks of the Tengen design: round icon buttons, labelled round actions, small
/// uppercase section labels, cards, toggles, steppers and sheets.

/// A secondary button: the size of the main one, on the card color instead of the accent.
ButtonStyle softButtonStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: scheme.surfaceContainerHigh,
    foregroundColor: scheme.onSurface,
  );
}

/// A round icon button on a card colored disc, for the top of screens (back, chat, menu).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.badge,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  /// A count shown on the button (unread messages).
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = badge;
    final iconWidget = Icon(icon, size: size * 0.46);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainer,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: count != null && count > 0
                  ? Badge(label: Text(count > 99 ? '99+' : '$count'), child: iconWidget)
                  : iconWidget,
            ),
          ),
        ),
      ),
    );
  }
}

/// The back button of the design: a round button with a chevron.
class CircleBackButton extends StatelessWidget {
  const CircleBackButton({this.icon = Icons.chevron_left_rounded, this.onPressed, super.key});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => CircleIconButton(
    icon: icon,
    tooltip: icon == Icons.close_rounded ? 'Close' : 'Back',
    onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
  );
}

/// The top bar of a screen: a round back button, a centered title (and subtitle) and round
/// actions on the right.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({
    this.title,
    this.subtitle,
    this.titleWidget,
    this.leading,
    this.actions = const [],
    this.muted = false,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final Widget? titleWidget;

  /// Replaces the back button.
  final Widget? leading;
  final List<Widget> actions;

  /// The title in the muted color, for information rather than a heading (`Move 28 · 19×19`).
  final bool muted;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canPop = Navigator.of(context).canPop();
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              SizedBox(width: 44, child: leading ?? (canPop ? const CircleBackButton() : null)),
              Expanded(
                child:
                    titleWidget ??
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: muted
                                ? theme.textTheme.bodyLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  )
                                : theme.textTheme.titleMedium?.copyWith(fontSize: 18),
                          ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, a) in actions.indexed) ...[if (i > 0) const SizedBox(width: 8), a],
                  if (actions.isEmpty) const SizedBox(width: 44),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round action with its label below, for the bottom of the game and puzzle screens.
class RoundAction extends StatelessWidget {
  const RoundAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;

  /// Said by the tooltip and to screen readers; the button itself shows only the icon.
  final String label;
  final VoidCallback? onPressed;

  /// In the accent color (the hint shown, the move to make).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final fg = highlighted
        ? scheme.onPrimary
        : (enabled ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.4));
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Pressable(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 56,
            height: 52,
            decoration: BoxDecoration(
              color: highlighted ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(icon, color: fg, size: 24),
          ),
        ),
      ),
    );
  }
}

/// The actions of a game or a puzzle: icons in a floating glass pill.
class RoundActionBar extends StatelessWidget {
  const RoundActionBar({required this.actions, super.key});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GlassPanel(
        radius: 32,
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, a) in actions.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Flexible(child: a),
            ],
          ],
        ),
      ),
    ),
  );
}

/// The height of the floating tab bar with its margin, kept clear at the bottom of tab pages.
const kFloatingBarClearance = 96.0;

/// The padding of a list that is either a tab page (below the status bar, above the floating
/// tab bar) or the content of a sheet.
EdgeInsets tabPagePadding(BuildContext context, {required bool page}) {
  if (!page) return const EdgeInsets.only(bottom: 24);
  final insets = MediaQuery.paddingOf(context);
  return EdgeInsets.only(top: insets.top + 16, bottom: insets.bottom + kFloatingBarClearance + 8);
}

/// Frosted glass: what is behind shows through, blurred, under a tint of the surface.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.opacity = 0.72,
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// The tint, the high surface by default.
  final Color? tint;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (tint ?? scheme.surfaceContainerHigh).withValues(alpha: opacity),
              borderRadius: shape,
              border: Border.all(
                color: (dark ? Colors.white : Colors.black).withValues(alpha: dark ? 0.07 : 0.05),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Shrinks a little while pressed and springs back: the soft touch of the design's buttons and
/// cards.
class Pressable extends StatefulWidget {
  const Pressable({required this.child, this.onTap, this.scale = 0.95, super.key});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onTap != null && down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.onTap,
    onTapDown: (_) => _set(true),
    onTapUp: (_) => _set(false),
    onTapCancel: () => _set(false),
    child: AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: Duration(milliseconds: _down ? 90 : 260),
      curve: _down ? Curves.easeOut : Curves.easeOutBack,
      child: widget.child,
    ),
  );
}

/// A small uppercase label above a group of settings (`BOARD SIZE`, `SECTIONS`).
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 10),
    this.trailing,
    super.key,
  });

  final String text;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
          // Shrinks on narrow screens or with large text rather than overflowing.
          if (trailing != null) Flexible(child: trailing!),
        ],
      ),
    );
  }
}

/// A rounded card of the design, optionally tappable and outlined in the accent.
class SoftCard extends StatelessWidget {
  const SoftCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.selected = false,
    this.color,
    this.radius = 20,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: selected ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
    );
    return Material(
      color: color ?? (selected ? scheme.primaryContainer : scheme.surfaceContainer),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A card with an accent icon, a title and a subtitle, for the home hub and the course.
class NavCard extends StatelessWidget {
  const NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SoftCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: scheme.primary, size: 26),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A title, a subtitle and a switch.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// A label, a value and − / + buttons (handicap, komi).
class StepperRow extends StatelessWidget {
  const StepperRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.subtitle,
    super.key,
  });

  final String label;
  final String? subtitle;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget button(IconData icon, String tooltip, VoidCallback? onPressed) => Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox.square(
            dimension: 44,
            child: Icon(
              icon,
              size: 22,
              color: onPressed == null ? scheme.outline : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleMedium),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          button(Icons.remove_rounded, 'Less $label'.toLowerCase(), onMinus),
          SizedBox(
            width: 76,
            child: Text(value, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          ),
          button(Icons.add_rounded, 'More $label'.toLowerCase(), onPlus),
        ],
      ),
    );
  }
}

/// A small rounded tag (a rank, a result).
class Tag extends StatelessWidget {
  const Tag(this.text, {this.background, this.foreground, super.key});

  final String text;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: foreground ?? scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The title of a sheet: large and bold, with an optional trailing widget (a close button,
/// `Updated live`).
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {this.trailing, this.close = false, super.key});

  final String title;
  final Widget? trailing;

  /// A round close button on the right.
  final bool close;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 20, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30),
          ),
        ),
        ?trailing,
        if (close) const CircleBackButton(icon: Icons.close_rounded),
      ],
    ),
  );
}

/// Opens [child] in a tall rounded sheet over the current screen, the top of which stays in
/// view (the board of the home screen, in the design).
Future<T?> showTengenSheet<T>(BuildContext context, Widget child, {double topGap = 72}) =>
    showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height - topGap),
          child: SizedBox(height: height - topGap, child: child),
        );
      },
    );

/// What a [FeedbackCard] says: a success, a mistake, a hint or a comment.
enum FeedbackKind { success, failure, hint, comment }

/// The result of a move in a puzzle or a lesson, a hint, or the author's comment: a softly
/// tinted card with a round badge, a title and an explanation.
class FeedbackCard extends StatelessWidget {
  const FeedbackCard({
    required this.kind,
    required this.title,
    this.body,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 4),
    super.key,
  });

  final FeedbackKind kind;
  final String title;
  final String? body;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color color, IconData icon) = switch (kind) {
      FeedbackKind.success => (scheme.secondary, Icons.check_rounded),
      FeedbackKind.failure => (scheme.error, Icons.close_rounded),
      FeedbackKind.hint => (scheme.primary, Icons.lightbulb_rounded),
      FeedbackKind.comment => (scheme.onSurfaceVariant, Icons.chat_bubble_rounded),
    };
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: 0.12), scheme.surfaceContainer),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: body == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: scheme.surfaceContainerLowest),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // Its own height: under a board, the card must not take the board's room.
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: kind == FeedbackKind.comment ? FontWeight.w500 : FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      body!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades and slides its child up into place once, [delay] after it first appears: lists and
/// sections come in one after another.
class Entrance extends StatefulWidget {
  const Entrance({
    required this.child,
    this.delay = Duration.zero,
    this.offset = 24,
    this.duration = const Duration(milliseconds: 520),
    super.key,
  });

  final Widget child;
  final Duration delay;

  /// How far below its place it starts, in pixels.
  final double offset;
  final Duration duration;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds / (widget.delay + widget.duration).inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isDismissed) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (context, child) => Opacity(
      opacity: _t.value,
      child: Transform.translate(offset: Offset(0, widget.offset * (1 - _t.value)), child: child),
    ),
    child: widget.child,
  );
}

/// A number that counts up to [value] when it appears and moves to a new value smoothly.
class CountUp extends StatelessWidget {
  const CountUp({required this.value, required this.builder, super.key});

  final num value;
  final Widget Function(BuildContext context, int value) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 1100),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => builder(context, v.round()),
  );
}
