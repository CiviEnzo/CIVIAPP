import 'package:flutter/material.dart';

class Trend {
  const Trend({required this.value, required this.isPositive, bool? isUp})
    : isUp = isUp ?? value >= 0;

  final int value;
  final bool isPositive;
  final bool isUp;
}

class KPICard extends StatefulWidget {
  const KPICard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.trend,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final Trend? trend;
  final VoidCallback? onTap;

  @override
  State<KPICard> createState() => _KPICardState();
}

class _KPICardState extends State<KPICard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      constraints: const BoxConstraints(minHeight: 168),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              _isHovered
                  ? theme.colorScheme.primary.withValues(alpha: 0.55)
                  : theme.colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isHovered ? 0.16 : 0.08),
            blurRadius: _isHovered ? 18 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const Spacer(),
              if (widget.trend != null) _TrendChip(trend: widget.trend!),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child:
          widget.onTap == null
              ? card
              : InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.onTap,
                child: card,
              ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.trend});

  final Trend trend;

  @override
  Widget build(BuildContext context) {
    final isPositive = trend.isPositive;
    final color =
        isPositive ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    final bg = isPositive ? const Color(0x1A22C55E) : const Color(0x1AEF4444);
    final icon =
        trend.isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final sign = trend.value >= 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$sign${trend.value}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
