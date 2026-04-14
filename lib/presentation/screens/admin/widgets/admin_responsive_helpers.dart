import 'package:flutter/material.dart';

const double kAdminPhoneBreakpoint = 600;
const double kAdminStackBreakpoint = 720;
const double kAdminTwoColumnBreakpoint = 920;

bool isAdminPhoneWidth(double width) => width < kAdminPhoneBreakpoint;

bool isAdminStackWidth(double width) => width < kAdminStackBreakpoint;

bool isAdminTwoColumnWidth(double width) => width >= kAdminTwoColumnBreakpoint;

class AdminResponsiveHeader extends StatelessWidget {
  const AdminResponsiveHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.stackBreakpoint = kAdminStackBreakpoint,
    this.spacing = 16,
    this.trailingFullWidthOnStack = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final double stackBreakpoint;
  final double spacing;
  final bool trailingFullWidthOnStack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleText = subtitle?.trim();
    final hasSubtitle = subtitleText != null && subtitleText.isNotEmpty;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (hasSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            subtitleText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    Widget buildHeadingBlock() {
      if (leading == null) {
        return heading;
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading!,
          SizedBox(width: spacing - 2),
          Expanded(child: heading),
        ],
      );
    }

    if (trailing == null) {
      return buildHeadingBlock();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < stackBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildHeadingBlock(),
              SizedBox(height: spacing - 2),
              if (trailingFullWidthOnStack)
                SizedBox(width: double.infinity, child: trailing!)
              else
                trailing!,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: buildHeadingBlock()),
            SizedBox(width: spacing),
            trailing!,
          ],
        );
      },
    );
  }
}

class AdminResponsiveToolbar extends StatelessWidget {
  const AdminResponsiveToolbar({
    super.key,
    required this.primary,
    this.secondary,
    this.stackBreakpoint = kAdminStackBreakpoint,
    this.spacing = 12,
    this.expandPrimary = true,
    this.secondaryFullWidthOnStack = false,
  });

  final Widget primary;
  final Widget? secondary;
  final double stackBreakpoint;
  final double spacing;
  final bool expandPrimary;
  final bool secondaryFullWidthOnStack;

  @override
  Widget build(BuildContext context) {
    if (secondary == null) {
      return primary;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < stackBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              SizedBox(height: spacing),
              if (secondaryFullWidthOnStack)
                SizedBox(width: double.infinity, child: secondary!)
              else
                secondary!,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expandPrimary) Expanded(child: primary) else primary,
            SizedBox(width: spacing),
            secondary!,
          ],
        );
      },
    );
  }
}

class AdminResponsiveDataRow extends StatelessWidget {
  const AdminResponsiveDataRow({
    super.key,
    required this.label,
    this.value,
    this.subtitle,
    this.child,
    this.valueColor,
    this.stackBreakpoint = 420,
    this.bottomPadding = 10,
  }) : assert(value != null || child != null);

  final String label;
  final String? value;
  final String? subtitle;
  final Widget? child;
  final Color? valueColor;
  final double stackBreakpoint;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelWidget = Text(
      label,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );

    Widget buildValueText({required bool stacked}) {
      return Column(
        crossAxisAlignment:
            stacked ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            value!,
            textAlign: stacked ? TextAlign.start : TextAlign.end,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              textAlign: stacked ? TextAlign.start : TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final valueWidget = child ?? buildValueText(stacked: false);
          if (constraints.maxWidth < stackBreakpoint) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 6),
                child ?? buildValueText(stacked: true),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: labelWidget),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: valueWidget,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
