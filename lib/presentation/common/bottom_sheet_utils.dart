import 'package:flutter/material.dart';

Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final mediaQuery = MediaQuery.of(ctx);
      final theme = Theme.of(ctx);
      final isCompactWidth = mediaQuery.size.width < 600;

      final content = builder(ctx);

      if (isCompactWidth) {
        return Dialog.fullscreen(
          backgroundColor: theme.colorScheme.surface,
          child: SafeArea(child: content),
        );
      }

      return Dialog(
        backgroundColor: theme.colorScheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: content,
        ),
      );
    },
  );
}

class DialogActionLayout extends StatelessWidget {
  const DialogActionLayout({
    super.key,
    required this.body,
    required this.actions,
    this.bodyPadding = const EdgeInsets.fromLTRB(24, 24, 24, 16),
    this.actionsPadding = const EdgeInsets.fromLTRB(24, 16, 24, 16),
    this.actionsSpacing = 12,
    this.maxHeightFactor = 0.9,
  });

  final Widget body;
  final List<Widget> actions;
  final EdgeInsets bodyPadding;
  final EdgeInsets actionsPadding;
  final double actionsSpacing;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final resolvedActionsPadding =
        actionsPadding.resolve(Directionality.of(context));
    final maxHeight = mediaQuery.size.height * maxHeightFactor;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: bodyPadding,
              child: body,
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: resolvedActionsPadding.copyWith(
                bottom: resolvedActionsPadding.bottom + bottomInset,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (int i = 0; i < actions.length; i++) ...[
                    if (i > 0) SizedBox(width: actionsSpacing),
                    actions[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
