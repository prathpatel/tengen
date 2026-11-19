import 'package:material_ui/material_ui.dart';

/// A section title with an optional "More ›" link, as in the lichess app.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.onMore, super.key});

  final String title;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('More'), Icon(Icons.chevron_right, size: 20)],
              ),
            ),
        ],
      ),
    );
  }
}

/// Rows grouped in a rounded card, as in the lichess app.
class CardSection extends StatelessWidget {
  const CardSection({required this.children, this.margin, super.key});

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin ?? const EdgeInsets.symmetric(horizontal: 16),
    // A Material, so that the rows' ink ripples show on the card.
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    ),
  );
}

/// A row of a [CardSection]: an accent icon, a title and an optional subtitle.
class CardRow extends StatelessWidget {
  const CardRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Icon(icon, color: theme.colorScheme.primary, size: 28),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: trailing,
    );
  }
}
