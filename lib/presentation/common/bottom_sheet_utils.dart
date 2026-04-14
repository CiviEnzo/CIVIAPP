import 'package:flutter/material.dart';

const double _kSheetCornerRadius = 24;
const double _kSheetPhoneBreakpoint = 600;
const double _kSheetTabletBreakpoint = 1024;

enum AppModalSheetPreset { adaptive, compact, wide }

enum AppMobileSheetPresentation { auto, page, bottomSheet }

enum AppMobileSheetLeadingMode { auto, close, back, none }

bool isAppSheetPhoneLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < _kSheetPhoneBreakpoint;

Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  bool includeCloseButton = true,
  VoidCallback? onClose,
  double desktopMaxWidth = 920,
  bool compactWrapContent = false,
  Alignment compactAlignment = Alignment.topCenter,
  BorderSide? borderSide,
  AppModalSheetPreset preset = AppModalSheetPreset.adaptive,
  AppMobileSheetPresentation phonePresentation =
      AppMobileSheetPresentation.auto,
}) {
  if (isAppSheetPhoneLayout(context)) {
    final currentDepth = _AppMobileSheetScope.maybeOf(context)?.depth ?? 0;
    final resolvedPhonePresentation = switch (phonePresentation) {
      AppMobileSheetPresentation.auto =>
        compactWrapContent
            ? AppMobileSheetPresentation.bottomSheet
            : AppMobileSheetPresentation.page,
      _ => phonePresentation,
    };

    if (resolvedPhonePresentation == AppMobileSheetPresentation.bottomSheet) {
      final theme = Theme.of(context);
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        barrierColor: theme.colorScheme.scrim.withValues(alpha: 0.42),
        isDismissible: barrierDismissible,
        enableDrag: barrierDismissible,
        builder:
            (sheetContext) => _AppMobileSheetScope(
              depth: currentDepth + 1,
              child: _AppMobileBottomSheetSurface(
                borderSide: borderSide,
                compactWrapContent: compactWrapContent,
                child: builder(sheetContext),
              ),
            ),
      );
    }

    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        fullscreenDialog: true,
        builder: (routeContext) {
          final theme = Theme.of(routeContext);
          return Theme(
            data: theme,
            child: Material(
              color: theme.colorScheme.surface,
              child: _AppMobileSheetScope(
                depth: currentDepth + 1,
                child: builder(routeContext),
              ),
            ),
          );
        },
      ),
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      final mediaQuery = MediaQuery.of(ctx);
      final theme = Theme.of(ctx);
      final screenWidth = mediaQuery.size.width;
      final isTabletWidth =
          screenWidth >= _kSheetPhoneBreakpoint &&
          screenWidth < _kSheetTabletBreakpoint;

      final content = builder(ctx);
      final contentWithoutBottomInsets = MediaQuery.removeViewInsets(
        context: ctx,
        removeBottom: true,
        child: content,
      );
      final wrappedContent =
          includeCloseButton
              ? _SheetCloseOverlay(
                onClose: onClose,
                child: contentWithoutBottomInsets,
              )
              : contentWithoutBottomInsets;
      final dismissableContent = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: wrappedContent,
      );
      final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kSheetCornerRadius),
        side: borderSide ?? BorderSide.none,
      );
      final resolvedMaxWidth = switch (preset) {
        AppModalSheetPreset.adaptive => desktopMaxWidth,
        AppModalSheetPreset.compact =>
          desktopMaxWidth.clamp(0.0, 560.0).toDouble(),
        AppModalSheetPreset.wide =>
          desktopMaxWidth < 920 ? 920.0 : desktopMaxWidth,
      };

      final sheetSurface = Material(
        color: theme.colorScheme.surface,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
          child: dismissableContent,
        ),
      );

      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isTabletWidth ? 24 : 32,
          vertical: isTabletWidth ? 20 : 24,
        ),
        clipBehavior: Clip.none,
        child: sheetSurface,
      );
    },
  );
}

class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onClose,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 16, 12),
    this.showDivider = true,
    this.showCloseButton = true,
    this.stackBreakpoint = 560,
    this.trailingFullWidthOnStack = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onClose;
  final EdgeInsets padding;
  final bool showDivider;
  final bool showCloseButton;
  final double stackBreakpoint;
  final bool trailingFullWidthOnStack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final closeHandler = onClose ?? () => Navigator.of(context).maybePop();
    final titleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shouldStackTrailing =
                  trailing != null && constraints.maxWidth < stackBreakpoint;
              final closeButton =
                  showCloseButton
                      ? IconButton(
                        tooltip: 'Chiudi',
                        visualDensity: VisualDensity.compact,
                        splashRadius: 20,
                        onPressed: closeHandler,
                        icon: const Icon(Icons.close_rounded),
                      )
                      : null;

              Widget buildHeaderRow({required bool includeTrailing}) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: titleWidget),
                    if (includeTrailing && trailing != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: trailing!,
                        ),
                      ),
                    ],
                    if (closeButton != null) ...[
                      const SizedBox(width: 4),
                      closeButton,
                    ],
                  ],
                );
              }

              if (!shouldStackTrailing) {
                return buildHeaderRow(includeTrailing: true);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildHeaderRow(includeTrailing: false),
                  const SizedBox(height: 12),
                  if (trailingFullWidthOnStack)
                    SizedBox(width: double.infinity, child: trailing!)
                  else
                    Align(alignment: Alignment.centerLeft, child: trailing!),
                ],
              );
            },
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _AppMobileSheetScope extends InheritedWidget {
  const _AppMobileSheetScope({required this.depth, required super.child});

  final int depth;

  static _AppMobileSheetScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_AppMobileSheetScope>();
  }

  @override
  bool updateShouldNotify(_AppMobileSheetScope oldWidget) =>
      depth != oldWidget.depth;
}

class AppSheetFooter extends StatelessWidget {
  const AppSheetFooter({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 16),
    this.showDivider = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider) const Divider(height: 1),
        SafeArea(top: false, child: Padding(padding: padding, child: child)),
      ],
    );
  }
}

class AppSheetScaffold extends StatelessWidget {
  const AppSheetScaffold({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onClose,
    this.footer,
    this.bodyPadding = const EdgeInsets.fromLTRB(24, 24, 24, 16),
    this.footerPadding = const EdgeInsets.fromLTRB(24, 16, 24, 16),
    this.scrollBody = true,
    this.backgroundColor,
    this.showCloseButton = true,
  });

  final Widget body;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onClose;
  final Widget? footer;
  final EdgeInsets bodyPadding;
  final EdgeInsets footerPadding;
  final bool scrollBody;
  final Color? backgroundColor;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final hasHeader =
        title != null ||
        subtitle != null ||
        leading != null ||
        trailing != null ||
        onClose != null;
    final bodyContent =
        scrollBody
            ? SingleChildScrollView(padding: bodyPadding, child: body)
            : Padding(padding: bodyPadding, child: body);

    return Material(
      color: backgroundColor ?? Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader)
            AppSheetHeader(
              title: title ?? '',
              subtitle: subtitle,
              leading: leading,
              trailing: trailing,
              onClose: onClose,
              showCloseButton: showCloseButton,
            ),
          Flexible(child: bodyContent),
          if (footer != null)
            AppSheetFooter(padding: footerPadding, child: footer!),
        ],
      ),
    );
  }
}

class AppMobileSheetScaffold extends StatelessWidget {
  const AppMobileSheetScaffold({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onClose,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
    this.scrollController,
    this.backgroundColor,
    this.showCloseButton = true,
    this.scrollBody = true,
  });

  final Widget body;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onClose;
  final EdgeInsets bodyPadding;
  final ScrollController? scrollController;
  final Color? backgroundColor;
  final bool showCloseButton;
  final bool scrollBody;

  @override
  Widget build(BuildContext context) {
    final hasHeader =
        title != null ||
        subtitle != null ||
        leading != null ||
        trailing != null ||
        onClose != null;
    final bodyContent =
        scrollBody
            ? SingleChildScrollView(
              controller: scrollController,
              padding: bodyPadding,
              child: body,
            )
            : Padding(padding: bodyPadding, child: body);

    return Material(
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader)
            AppSheetHeader(
              title: title ?? '',
              subtitle: subtitle,
              leading: leading,
              trailing: trailing,
              onClose: onClose,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              showCloseButton: showCloseButton,
            ),
          Expanded(child: bodyContent),
        ],
      ),
    );
  }
}

class AppMobileSheetPageScaffold extends StatelessWidget {
  const AppMobileSheetPageScaffold({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.onLeadingPressed,
    this.leadingMode = AppMobileSheetLeadingMode.auto,
    this.backgroundColor,
    this.bottom,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onLeadingPressed;
  final AppMobileSheetLeadingMode leadingMode;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scopeDepth = _AppMobileSheetScope.maybeOf(context)?.depth ?? 1;
    final resolvedLeadingMode = switch (leadingMode) {
      AppMobileSheetLeadingMode.auto =>
        scopeDepth > 1
            ? AppMobileSheetLeadingMode.back
            : AppMobileSheetLeadingMode.close,
      _ => leadingMode,
    };
    final color = backgroundColor ?? theme.colorScheme.surface;

    Widget? leading;
    switch (resolvedLeadingMode) {
      case AppMobileSheetLeadingMode.close:
        leading = IconButton(
          tooltip: 'Chiudi',
          onPressed: onLeadingPressed ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
        );
        break;
      case AppMobileSheetLeadingMode.back:
        leading = IconButton(
          tooltip: 'Indietro',
          onPressed: onLeadingPressed ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        );
        break;
      case AppMobileSheetLeadingMode.none:
        leading = null;
        break;
      case AppMobileSheetLeadingMode.auto:
        break;
    }

    final hasAppBar =
        title != null ||
        subtitle != null ||
        actions.isNotEmpty ||
        resolvedLeadingMode != AppMobileSheetLeadingMode.none;

    return Scaffold(
      backgroundColor: color,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar:
          hasAppBar
              ? AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: color,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                titleSpacing: leading == null ? 20 : 0,
                leading: leading,
                title:
                    title == null
                        ? null
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title!,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (subtitle != null &&
                                subtitle!.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                actions: actions,
                shape: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                bottom: bottom,
              )
              : null,
      body: SafeArea(top: false, child: body),
    );
  }
}

class _SheetCloseOverlay extends StatelessWidget {
  const _SheetCloseOverlay({required this.child, this.onClose});

  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final closeHandler = onClose ?? () => Navigator.of(context).maybePop();
    return Stack(
      children: [
        child,
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            bottom: false,
            child: IconButton(
              tooltip: 'Chiudi',
              visualDensity: VisualDensity.compact,
              splashRadius: 20,
              onPressed: closeHandler,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppMobileBottomSheetSurface extends StatelessWidget {
  const _AppMobileBottomSheetSurface({
    required this.child,
    this.borderSide,
    this.compactWrapContent = false,
  });

  final Widget child;
  final BorderSide? borderSide;
  final bool compactWrapContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxHeightFactor = compactWrapContent ? 0.82 : 0.92;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * maxHeightFactor,
            minWidth: double.infinity,
          ),
          child: Material(
            color: theme.colorScheme.surface,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_kSheetCornerRadius),
              ),
              side: borderSide ?? BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(top: false, child: child),
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
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onClose,
    this.footer,
    this.bodyPadding = const EdgeInsets.fromLTRB(24, 24, 24, 16),
    this.footerPadding = const EdgeInsets.fromLTRB(24, 16, 24, 16),
    this.actionsSpacing = 12,
    this.maxHeightFactor = 0.9,
    this.scrollBody = true,
    this.showCloseButton = true,
  });

  final Widget body;
  final List<Widget> actions;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onClose;
  final Widget? footer;
  final EdgeInsets bodyPadding;
  final EdgeInsets footerPadding;
  final double actionsSpacing;
  final double maxHeightFactor;
  final bool scrollBody;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * maxHeightFactor;
    final resolvedFooterPadding = footerPadding.resolve(
      Directionality.of(context),
    );
    final footerChild =
        footer ??
        (actions.isEmpty
            ? null
            : Wrap(
              alignment: WrapAlignment.end,
              spacing: actionsSpacing,
              runSpacing: actionsSpacing,
              children: [for (final action in actions) action],
            ));

    if (isAppSheetPhoneLayout(context)) {
      final bodyContent =
          scrollBody
              ? ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: bodyPadding,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(height: 16),
                  ],
                  if (trailing != null) ...[
                    trailing!,
                    const SizedBox(height: 16),
                  ],
                  body,
                  if (footerChild != null) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    Padding(padding: resolvedFooterPadding, child: footerChild),
                  ],
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (leading != null || trailing != null)
                    Padding(
                      padding: bodyPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (leading != null) leading!,
                          if (leading != null && trailing != null)
                            const SizedBox(height: 12),
                          if (trailing != null) trailing!,
                        ],
                      ),
                    ),
                  Expanded(child: Padding(padding: bodyPadding, child: body)),
                  if (footerChild != null) ...[
                    const Divider(height: 1),
                    Padding(padding: resolvedFooterPadding, child: footerChild),
                  ],
                ],
              );

      return AppMobileSheetPageScaffold(
        title: title,
        subtitle: subtitle,
        leadingMode:
            showCloseButton
                ? AppMobileSheetLeadingMode.auto
                : AppMobileSheetLeadingMode.none,
        onLeadingPressed: onClose,
        body: bodyContent,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: AppSheetScaffold(
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        onClose: onClose,
        body: body,
        bodyPadding: bodyPadding,
        footer: footerChild,
        footerPadding: resolvedFooterPadding,
        scrollBody: scrollBody,
        showCloseButton: showCloseButton,
      ),
    );
  }
}

Future<T?> showAppSelectionSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) labelBuilder,
  String? subtitle,
  String Function(T)? subtitleBuilder,
  double desktopMaxWidth = 720,
  AppModalSheetPreset preset = AppModalSheetPreset.compact,
}) {
  if (isAppSheetPhoneLayout(context)) {
    return showAppModalSheet<T>(
      context: context,
      barrierDismissible: true,
      includeCloseButton: false,
      compactWrapContent: true,
      phonePresentation: AppMobileSheetPresentation.bottomSheet,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                  if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final item = items[index];
                  final itemSubtitle = subtitleBuilder?.call(item);
                  return ListTile(
                    title: Text(labelBuilder(item)),
                    subtitle:
                        itemSubtitle == null || itemSubtitle.isEmpty
                            ? null
                            : Text(itemSubtitle),
                    onTap: () => Navigator.of(ctx).pop(item),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  return showAppModalSheet<T>(
    context: context,
    includeCloseButton: false,
    desktopMaxWidth: desktopMaxWidth,
    preset: preset,
    builder: (ctx) {
      return DialogActionLayout(
        title: title,
        subtitle: subtitle,
        scrollBody: false,
        bodyPadding: EdgeInsets.zero,
        body: SizedBox(
          width: double.infinity,
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, index) {
              final item = items[index];
              final itemSubtitle = subtitleBuilder?.call(item);
              return ListTile(
                title: Text(labelBuilder(item)),
                subtitle:
                    itemSubtitle == null || itemSubtitle.isEmpty
                        ? null
                        : Text(itemSubtitle),
                onTap: () => Navigator.of(ctx).pop(item),
              );
            },
          ),
        ),
        actions: const [],
      );
    },
  );
}
