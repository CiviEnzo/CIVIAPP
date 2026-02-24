import 'package:flutter/material.dart';

Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  bool includeCloseButton = true,
  VoidCallback? onClose,
  double desktopMaxWidth = 720,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      final mediaQuery = MediaQuery.of(ctx);
      final theme = Theme.of(ctx);
      final isCompactWidth = mediaQuery.size.width < 600;

      final content = builder(ctx);
      final wrappedContent =
          includeCloseButton
              ? _ModalSheetCloseWrapper(child: content, onClose: onClose)
              : content;
      final dismissableContent = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: wrappedContent,
      );
      final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      );
      const compactPadding = EdgeInsets.fromLTRB(16, 16, 16, 16);

      if (isCompactWidth) {
        final shouldExpandToInsets = mediaQuery.viewInsets.bottom > 0;
        final sheetBody = Material(
          color: theme.colorScheme.surface,
          elevation: 6,
          shadowColor: Colors.black.withOpacity(0.25),
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: dismissableContent,
        );

        return Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: Padding(
            padding: compactPadding,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = constraints.maxHeight;
                final minHeight = shouldExpandToInsets ? maxHeight : 0.0;
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: minHeight,
                    maxHeight: maxHeight,
                  ),
                  child: sheetBody,
                );
              },
            ),
          ),
        );
      }

      return Dialog(
        backgroundColor: theme.colorScheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desktopMaxWidth),
          child: dismissableContent,
        ),
      );
    },
  );
}

class _ModalSheetCloseWrapper extends StatelessWidget {
  const _ModalSheetCloseWrapper({required this.child, this.onClose});

  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + 16;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: topPadding + 12,
          right: 12,
          child: Transform.translate(
            offset: const Offset(12, -12),
            child: _SheetCloseButton(
              onPressed:
                  onClose ??
                  () {
                    Navigator.of(context).maybePop();
                  },
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetCloseButton extends StatelessWidget {
  const _SheetCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = scheme.primary;
    final foreground = scheme.onPrimary;

    return Tooltip(
      message: 'Chiudi',
      child: Material(
        color: background,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.25),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            height: 44,
            width: 44,
            child: Center(
              child: Icon(Icons.close_rounded, size: 20, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
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
    final resolvedActionsPadding = actionsPadding.resolve(
      Directionality.of(context),
    );
    final maxHeight = mediaQuery.size.height * maxHeightFactor;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(padding: bodyPadding, child: body),
          ),
          if (actions.isNotEmpty) ...[
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
        ],
      ),
    );
  }
}
