import 'dart:async';

import 'package:flutter/material.dart';

enum AppNoticeTone { info, success, error }

class AppNoticeRequest {
  const AppNoticeRequest({
    required this.message,
    this.tone = AppNoticeTone.info,
    this.duration = const Duration(seconds: 3),
  });

  final String message;
  final AppNoticeTone tone;
  final Duration duration;
}

class AppNoticeController extends ChangeNotifier {
  _AppNoticeEntry? _currentEntry;
  Timer? _dismissTimer;
  int _nextEntryId = 0;

  AppNoticeRequest? get currentRequest => _currentEntry?.request;
  int? get currentEntryId => _currentEntry?.id;

  void show(AppNoticeRequest request) {
    final message = request.message.trim();
    if (message.isEmpty) {
      hide();
      return;
    }

    _dismissTimer?.cancel();
    _currentEntry = _AppNoticeEntry(
      id: _nextEntryId++,
      request: AppNoticeRequest(
        message: message,
        tone: request.tone,
        duration: request.duration,
      ),
    );
    notifyListeners();
    _dismissTimer = Timer(request.duration, hide);
  }

  void hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_currentEntry == null) {
      return;
    }
    _currentEntry = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}

class AppNoticeViewport extends StatelessWidget {
  const AppNoticeViewport({
    super.key,
    required this.controller,
    required this.child,
  });

  final AppNoticeController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;
                  final horizontalPadding = isWide ? 28.0 : 16.0;
                  final topPadding =
                      (constraints.maxHeight * 0.28)
                          .clamp(isWide ? 32.0 : 22.0, isWide ? 164.0 : 120.0)
                          .toDouble();
                  final maxNoticeWidth = isWide ? 520.0 : 440.0;
                  final minNoticeWidth = isWide ? 340.0 : 280.0;

                  return Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: topPadding,
                        left: horizontalPadding,
                        right: horizontalPadding,
                      ),
                      child: ListenableBuilder(
                        listenable: controller,
                        builder: (context, _) {
                          final request = controller.currentRequest;
                          final entryId = controller.currentEntryId;

                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              final curved = CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                                reverseCurve: Curves.easeInCubic,
                              );
                              return FadeTransition(
                                opacity: curved,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.22, 0),
                                    end: Offset.zero,
                                  ).animate(curved),
                                  child: child,
                                ),
                              );
                            },
                            child:
                                request == null || entryId == null
                                    ? const SizedBox(
                                      key: ValueKey('app-notice-empty'),
                                    )
                                    : ConstrainedBox(
                                      key: ValueKey<int>(entryId),
                                      constraints: BoxConstraints(
                                        minWidth: minNoticeWidth,
                                        maxWidth: maxNoticeWidth,
                                      ),
                                      child: _AppNoticeCard(request: request),
                                    ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

extension AppNoticeContextExtension on BuildContext {
  void showAppNotice(
    String message, {
    AppNoticeTone tone = AppNoticeTone.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final controller = AppNoticeScope.maybeOf(this);
    if (controller != null) {
      controller.show(
        AppNoticeRequest(message: message, tone: tone, duration: duration),
      );
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(this);
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: duration),
    );
  }

  void hideAppNotice() {
    final controller = AppNoticeScope.maybeOf(this);
    if (controller != null) {
      controller.hide();
      return;
    }

    ScaffoldMessenger.maybeOf(this)?.hideCurrentSnackBar();
  }
}

extension AppNoticeScaffoldMessengerExtension on ScaffoldMessengerState? {
  void showAppSnackBar(SnackBar snackBar) {
    final messenger = this;
    if (messenger == null) {
      return;
    }

    final message = _extractText(snackBar.content);
    if (snackBar.action != null || message == null || message.trim().isEmpty) {
      messenger.context.hideAppNotice();
      messenger.showSnackBar(snackBar);
      return;
    }

    messenger.hideCurrentSnackBar();
    messenger.context.showAppNotice(
      message,
      tone: inferAppNoticeTone(message),
      duration: snackBar.duration,
    );
  }

  void hideCurrentAppSnackBar({
    SnackBarClosedReason reason = SnackBarClosedReason.hide,
  }) {
    final messenger = this;
    if (messenger == null) {
      return;
    }

    messenger.context.hideAppNotice();
    messenger.hideCurrentSnackBar(reason: reason);
  }

  void clearAppSnackBars() {
    final messenger = this;
    if (messenger == null) {
      return;
    }

    messenger.context.hideAppNotice();
    messenger.clearSnackBars();
  }
}

AppNoticeTone inferAppNoticeTone(String message) {
  final normalized = message.trim().toLowerCase();
  if (normalized.isEmpty) {
    return AppNoticeTone.info;
  }

  const infoMarkers = [
    'in corso',
    'in arrivo',
    'attesa',
    'caricamento',
    'processing',
    'verifica',
  ];
  if (infoMarkers.any(normalized.contains)) {
    return AppNoticeTone.info;
  }

  const errorMarkers = [
    'errore',
    'impossibile',
    'non riuscit',
    'non disponibile',
    'non valido',
    'già ',
    'scadut',
    'seleziona ',
    'aggiungi ',
    'completa ',
    'deve essere',
    'nessun ',
    'nessuna ',
    'mancante',
    'occupato',
    'blocc',
  ];
  if (errorMarkers.any(normalized.contains)) {
    return AppNoticeTone.error;
  }

  const successMarkers = [
    'salvat',
    'inviat',
    'copiat',
    'eliminat',
    'aggiornat',
    'approvat',
    'rifiutat',
    'completat',
    'registrat',
    'prenotat',
    'rimoss',
    'stornat',
    'aggiunt',
    'scollegat',
    'collegat',
    'pagat',
    'saldat',
  ];
  if (successMarkers.any(normalized.contains)) {
    return AppNoticeTone.success;
  }

  return AppNoticeTone.info;
}

class AppNoticeScope extends StatefulWidget {
  const AppNoticeScope({super.key, required this.child});

  final Widget child;

  static AppNoticeController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'AppNoticeScope not found in context.');
    return controller!;
  }

  static AppNoticeController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_AppNoticeScope>()
        ?.notifier;
  }

  @override
  State<AppNoticeScope> createState() => _AppNoticeScopeState();
}

class _AppNoticeScopeState extends State<AppNoticeScope> {
  late final AppNoticeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppNoticeController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AppNoticeScope(controller: _controller, child: widget.child);
  }
}

class _AppNoticeScope extends InheritedNotifier<AppNoticeController> {
  const _AppNoticeScope({
    required AppNoticeController controller,
    required super.child,
  }) : super(notifier: controller);
}

class _AppNoticeEntry {
  const _AppNoticeEntry({required this.id, required this.request});

  final int id;
  final AppNoticeRequest request;
}

class _AppNoticeCard extends StatelessWidget {
  const _AppNoticeCard({required this.request});

  final AppNoticeRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = _AppNoticePalette.resolve(theme, request.tone, isDark);

    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.42 : 0.14),
              blurRadius: 34,
              offset: const Offset(0, 16),
              spreadRadius: -14,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: palette.iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(palette.icon, size: 16, color: palette.foreground),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _labelForTone(request.tone),
                      textAlign: TextAlign.left,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.foreground.withOpacity(
                          isDark ? 0.88 : 0.76,
                        ),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.message,
                      textAlign: TextAlign.left,
                      softWrap: true,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.foreground,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppNoticePalette {
  const _AppNoticePalette({
    required this.background,
    required this.border,
    required this.foreground,
    required this.iconBackground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final Color iconBackground;
  final IconData icon;

  static _AppNoticePalette resolve(
    ThemeData theme,
    AppNoticeTone tone,
    bool isDark,
  ) {
    final scheme = theme.colorScheme;
    switch (tone) {
      case AppNoticeTone.success:
        const accent = Color(0xFF15803D);
        return _AppNoticePalette(
          background: _blendBackground(
            base: scheme.surface,
            accent: const Color(0xFFDCFCE7),
            isDark: isDark,
          ),
          border: accent.withOpacity(isDark ? 0.45 : 0.24),
          foreground: isDark ? const Color(0xFF86EFAC) : accent,
          iconBackground: accent.withOpacity(isDark ? 0.24 : 0.12),
          icon: Icons.check_rounded,
        );
      case AppNoticeTone.error:
        final accent = scheme.error;
        return _AppNoticePalette(
          background: _blendBackground(
            base: scheme.surface,
            accent: scheme.errorContainer,
            isDark: isDark,
          ),
          border: accent.withOpacity(isDark ? 0.52 : 0.24),
          foreground: isDark ? scheme.errorContainer : accent,
          iconBackground: accent.withOpacity(isDark ? 0.24 : 0.12),
          icon: Icons.close_rounded,
        );
      case AppNoticeTone.info:
        const accent = Color(0xFF2563EB);
        return _AppNoticePalette(
          background: _blendBackground(
            base: scheme.surface,
            accent: const Color(0xFFDBEAFE),
            isDark: isDark,
          ),
          border: accent.withOpacity(isDark ? 0.38 : 0.26),
          foreground: isDark ? const Color(0xFFBFDBFE) : accent,
          iconBackground: accent.withOpacity(isDark ? 0.24 : 0.14),
          icon: Icons.info_outline_rounded,
        );
    }
  }

  static Color _blendBackground({
    required Color base,
    required Color accent,
    required bool isDark,
  }) {
    return Color.alphaBlend(accent.withOpacity(isDark ? 0.18 : 0.16), base);
  }
}

String? _extractText(Widget widget) {
  if (widget is Text) {
    if (widget.data != null) {
      return widget.data;
    }
    final textSpan = widget.textSpan;
    if (textSpan != null) {
      return textSpan.toPlainText();
    }
  }
  return null;
}

String _labelForTone(AppNoticeTone tone) {
  switch (tone) {
    case AppNoticeTone.info:
      return 'NOTIFICA';
    case AppNoticeTone.success:
      return 'CONFERMATO';
    case AppNoticeTone.error:
      return 'ATTENZIONE';
  }
}
