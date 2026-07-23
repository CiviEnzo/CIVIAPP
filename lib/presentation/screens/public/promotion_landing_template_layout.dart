import 'package:flutter/material.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:you_book/domain/entities/public_promotion_landing.dart';

/// Semantic colors shared by the public promotion landing templates.
///
/// [fromPromotion] always uses the configured promotion color as the primary
/// color. Text colors placed on chromatic surfaces are chosen by comparing the
/// WCAG contrast ratio of a light and a dark candidate.
@immutable
class PromotionLandingPalette {
  const PromotionLandingPalette({
    required this.templateId,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.line,
    required this.onPrimary,
    required this.onSecondary,
    required this.onAccent,
    required this.footer,
    required this.onFooter,
  });

  final String templateId;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color textMuted;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color line;
  final Color onPrimary;
  final Color onSecondary;
  final Color onAccent;
  final Color footer;
  final Color onFooter;

  // Compatibility aliases for the original Editorial Beauty renderer.
  Color get cream => background;
  Color get paper => surfaceAlt;
  Color get ink => text;
  Color get brown => primary;
  Color get terracotta => secondary;
  Color get gold => accent;

  factory PromotionLandingPalette.fromPromotion(
    PublicPromotionLanding promotion, {
    String? templateId,
  }) {
    final normalized = PromotionLandingTemplates.normalize(
      templateId ?? promotion.webLanding.templateId,
    );
    final configured = promotion.themeColor;

    switch (normalized) {
      case PromotionLandingTemplates.minimalGlow:
        final primary = _opaqueColor(configured, const Color(0xFF48675D));
        final background = const Color(0xFFF5F8F3);
        final text = Color.lerp(const Color(0xFF1E2922), primary, 0.08)!;
        final secondary = Color.lerp(primary, const Color(0xFFBFD0BC), 0.72)!;
        final accent = Color.lerp(primary, const Color(0xFFD6A88E), 0.82)!;
        final footer = Color.lerp(const Color(0xFF17231B), primary, 0.18)!;
        return PromotionLandingPalette(
          templateId: normalized,
          background: background,
          surface: Colors.white,
          surfaceAlt: const Color(0xFFEAF0E8),
          text: text,
          textMuted: Color.lerp(text, background, 0.34)!,
          primary: primary,
          secondary: secondary,
          accent: accent,
          line: const Color(0xFFD9E2D6),
          onPrimary: _contrastingColor(primary),
          onSecondary: _contrastingColor(secondary),
          onAccent: _contrastingColor(accent),
          footer: footer,
          onFooter: _contrastingColor(footer),
        );
      case PromotionLandingTemplates.studioPop:
        final primary = _opaqueColor(configured, const Color(0xFFE8513D));
        final background = const Color(0xFFFFF2D8);
        const text = Color(0xFF14213D);
        const secondary = Color(0xFFFFD447);
        final accent = Color.lerp(const Color(0xFF14213D), primary, 0.06)!;
        return PromotionLandingPalette(
          templateId: normalized,
          background: background,
          surface: const Color(0xFFFFFBF1),
          surfaceAlt: secondary,
          text: text,
          textMuted: Color.lerp(text, background, 0.27)!,
          primary: primary,
          secondary: secondary,
          accent: accent,
          line: text,
          onPrimary: _contrastingColor(primary),
          onSecondary: _contrastingColor(secondary),
          onAccent: _contrastingColor(accent),
          footer: accent,
          onFooter: _contrastingColor(accent),
        );
      case PromotionLandingTemplates.botanicalRitual:
        final primary = _opaqueColor(configured, const Color(0xFF315B4A));
        const background = Color(0xFFF1E6D2);
        final text = Color.lerp(const Color(0xFF172D24), primary, 0.12)!;
        final secondary = Color.lerp(primary, const Color(0xFFB6C3A5), 0.7)!;
        final accent = Color.lerp(primary, const Color(0xFFB96F4A), 0.78)!;
        final footer = Color.lerp(const Color(0xFF13291F), primary, 0.2)!;
        return PromotionLandingPalette(
          templateId: normalized,
          background: background,
          surface: const Color(0xFFFBF7ED),
          surfaceAlt: secondary,
          text: text,
          textMuted: Color.lerp(text, background, 0.32)!,
          primary: primary,
          secondary: secondary,
          accent: accent,
          line: const Color(0xFFD6C9B2),
          onPrimary: _contrastingColor(primary),
          onSecondary: _contrastingColor(secondary),
          onAccent: _contrastingColor(accent),
          footer: footer,
          onFooter: _contrastingColor(footer),
        );
      case PromotionLandingTemplates.editorialBeauty:
      default:
        final brown = _opaqueColor(configured, const Color(0xFF6D3D32));
        const background = Color(0xFFFAF6F3);
        final ink = Color.lerp(const Color(0xFF281D19), brown, 0.08)!;
        final terracotta = Color.lerp(brown, const Color(0xFFA75F4A), 0.64)!;
        final gold = Color.lerp(brown, const Color(0xFFEFAE73), 0.78)!;
        return PromotionLandingPalette(
          templateId: normalized,
          background: background,
          surface: Colors.white,
          surfaceAlt: const Color(0xFFF7F3EF),
          text: ink,
          textMuted: Color.lerp(ink, background, 0.34)!,
          primary: brown,
          secondary: terracotta,
          accent: gold,
          line: const Color(0xFFDDD0C8),
          onPrimary: _contrastingColor(brown),
          onSecondary: _contrastingColor(terracotta),
          onAccent: _contrastingColor(gold),
          footer: ink,
          onFooter: _contrastingColor(ink),
        );
    }
  }

  static Color _opaqueColor(int? value, Color fallback) {
    if (value == null) return fallback;
    return Color(0xFF000000 | (value & 0x00FFFFFF));
  }

  static Color _contrastingColor(Color background) {
    const light = Color(0xFFFFFFFF);
    const dark = Color(0xFF111713);
    final lightRatio = _contrastRatio(background, light);
    final darkRatio = _contrastRatio(background, dark);
    return lightRatio >= darkRatio ? light : dark;
  }

  static double _contrastRatio(Color first, Color second) {
    final firstLuminance = first.computeLuminance();
    final secondLuminance = second.computeLuminance();
    final brightest =
        firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
    final darkest =
        firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
    return (brightest + 0.05) / (darkest + 0.05);
  }
}

/// Renders the three alternative public promotion landing templates.
class PromotionLandingTemplateLayout extends StatelessWidget {
  const PromotionLandingTemplateLayout({
    super.key,
    required this.promotion,
    required this.palette,
    required this.embedded,
    required this.bookingKey,
    required this.onPrimaryAction,
    required this.leadForm,
  });

  final PublicPromotionLanding promotion;
  final PromotionLandingPalette palette;
  final bool embedded;
  final GlobalKey bookingKey;
  final VoidCallback onPrimaryAction;
  final Widget leadForm;

  @override
  Widget build(BuildContext context) {
    final templateId = PromotionLandingTemplates.normalize(
      promotion.webLanding.templateId,
    );
    final child = switch (templateId) {
      PromotionLandingTemplates.studioPop => _StudioPopLayout(
        promotion: promotion,
        palette: palette,
        embedded: embedded,
        bookingKey: bookingKey,
        onPrimaryAction: onPrimaryAction,
        leadForm: leadForm,
      ),
      PromotionLandingTemplates.botanicalRitual => _BotanicalRitualLayout(
        promotion: promotion,
        palette: palette,
        embedded: embedded,
        bookingKey: bookingKey,
        onPrimaryAction: onPrimaryAction,
        leadForm: leadForm,
      ),
      _ => _MinimalGlowLayout(
        promotion: promotion,
        palette: palette,
        embedded: embedded,
        bookingKey: bookingKey,
        onPrimaryAction: onPrimaryAction,
        leadForm: leadForm,
      ),
    };
    return KeyedSubtree(
      key: ValueKey<String>('landing-template-$templateId'),
      child: child,
    );
  }
}

class _MinimalGlowLayout extends StatelessWidget {
  const _MinimalGlowLayout({
    required this.promotion,
    required this.palette,
    required this.embedded,
    required this.bookingKey,
    required this.onPrimaryAction,
    required this.leadForm,
  });

  final PublicPromotionLanding promotion;
  final PromotionLandingPalette palette;
  final bool embedded;
  final GlobalKey bookingKey;
  final VoidCallback onPrimaryAction;
  final Widget leadForm;

  @override
  Widget build(BuildContext context) {
    if (embedded) return _embed(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SelectionArea(
        child: CustomScrollView(
          slivers: [
            _navigation(context),
            SliverToBoxAdapter(child: _hero(context)),
            SliverToBoxAdapter(child: _sections(context)),
            SliverToBoxAdapter(child: _offer(context)),
            SliverToBoxAdapter(
              child: KeyedSubtree(key: bookingKey, child: _booking(context)),
            ),
            SliverToBoxAdapter(child: _footer(context)),
          ],
        ),
      ),
    );
  }

  Widget _embed(BuildContext context) {
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _LandingFrame(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final copy = Container(
                  padding: EdgeInsets.all(compact ? 28 : 48),
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: _BookingCopy(
                    promotion: promotion,
                    palette: palette,
                    titleSize: compact ? 40 : 54,
                    eyebrow: promotion.webLanding.eyebrow,
                  ),
                );
                final form = _SoftFormFrame(palette: palette, child: leadForm);
                if (compact) {
                  return Column(
                    key: bookingKey,
                    children: [copy, const SizedBox(height: 24), form],
                  );
                }
                return Row(
                  key: bookingKey,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 34),
                    Expanded(child: form),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  SliverAppBar _navigation(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      toolbarHeight: 78,
      backgroundColor: palette.background.withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      shadowColor: palette.line,
      titleSpacing: 0,
      title: _LandingFrame(
        child: Row(
          children: [
            Flexible(
              child: _Brand(
                promotion: promotion,
                color: palette.text,
                compact: MediaQuery.sizeOf(context).width < 560,
              ),
            ),
            const Spacer(),
            _MinimalButton(
              label: _shortActionLabel(context, promotion),
              palette: palette,
              onPressed: onPrimaryAction,
              filled: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      color: palette.background,
      padding: const EdgeInsets.symmetric(vertical: 46),
      child: _LandingFrame(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 780;
            final copy = Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 4 : 10,
                compact ? 28 : 54,
                compact ? 4 : 60,
                compact ? 42 : 54,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PillEyebrow(
                    text: promotion.webLanding.eyebrow,
                    background: palette.surfaceAlt,
                    foreground: palette.primary,
                  ),
                  const SizedBox(height: 26),
                  Text(
                    promotion.title,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: palette.text,
                      fontSize: compact ? 54 : 76,
                      height: 1.02,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1.5,
                    ),
                  ),
                  if (_hasText(promotion.subtitle)) ...[
                    const SizedBox(height: 20),
                    Text(
                      promotion.subtitle!,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        color: palette.primary,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (_hasText(promotion.tagline)) ...[
                    const SizedBox(height: 22),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        promotion.tagline!,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: palette.textMuted,
                          height: 1.65,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 34),
                  _MinimalButton(
                    label: promotion.webLanding.submitLabel,
                    palette: palette,
                    onPressed: onPrimaryAction,
                    filled: true,
                  ),
                ],
              ),
            );
            final visual = _MinimalHeroVisual(
              promotion: promotion,
              palette: palette,
            );
            if (compact) {
              return Column(children: [copy, visual]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 11, child: copy),
                Expanded(flex: 10, child: visual),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sections(BuildContext context) {
    final sections = _orderedSections(promotion);
    if (sections.isEmpty) return const SizedBox.shrink();
    return Container(
      color: palette.surface,
      padding: const EdgeInsets.symmetric(vertical: 86),
      child: _LandingFrame(
        child: Column(
          children: [
            for (var index = 0; index < sections.length; index++) ...[
              _minimalSection(context, sections[index], index),
              if (index != sections.length - 1) const SizedBox(height: 28),
            ],
          ],
        ),
      ),
    );
  }

  Widget _minimalSection(
    BuildContext context,
    PromotionSection section,
    int index,
  ) {
    if (section.layout == PromotionSectionLayout.quote) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 68),
        decoration: BoxDecoration(
          color: palette.primary,
          borderRadius: BorderRadius.circular(38),
        ),
        child: Column(
          children: [
            Icon(Icons.format_quote_rounded, color: palette.accent, size: 42),
            if (_hasText(section.title)) ...[
              const SizedBox(height: 14),
              Text(
                section.title!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: palette.onPrimary,
                  height: 1.18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (_hasText(section.text)) ...[
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  section.text!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.onPrimary.withValues(alpha: 0.82),
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final hasImage = _hasText(section.imageUrl);
    final copy = _MinimalSectionCopy(
      section: section,
      palette: palette,
      index: index,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: palette.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          if (!hasImage) {
            return Padding(
              padding: EdgeInsets.all(compact ? 18 : 42),
              child: copy,
            );
          }
          final image = _CaptionedImage(
            url: section.imageUrl,
            semanticLabel: section.altText,
            caption: section.caption,
            borderRadius: BorderRadius.circular(26),
            background: palette.surfaceAlt,
            iconColor: palette.primary,
            aspectRatio: compact ? 4 / 3 : 1.05,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                image,
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 34, 18, 20),
                  child: copy,
                ),
              ],
            );
          }
          final children = <Widget>[
            Expanded(child: image),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: copy,
              ),
            ),
          ];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: index.isEven ? children : children.reversed.toList(),
          );
        },
      ),
    );
  }

  Widget _offer(BuildContext context) {
    return Container(
      color: palette.surface,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
      child: _LandingFrame(
        horizontalPadding: 0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 68),
          decoration: BoxDecoration(
            color: palette.surfaceAlt,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 58,
            runSpacing: 28,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PillEyebrow(
                      text: 'La tua occasione',
                      background: palette.surface,
                      foreground: palette.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      promotion.title,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: palette.text,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              _OfferPrice(
                promotion: promotion,
                color: palette.primary,
                mutedColor: palette.textMuted,
                align: TextAlign.center,
              ),
              _MinimalButton(
                label: promotion.webLanding.submitLabel,
                palette: palette,
                onPressed: onPrimaryAction,
                filled: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _booking(BuildContext context) {
    return Container(
      color: palette.background,
      padding: const EdgeInsets.symmetric(vertical: 104),
      child: _LandingFrame(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final copy = _BookingCopy(
              promotion: promotion,
              palette: palette,
              titleSize: compact ? 46 : 60,
              eyebrow: promotion.webLanding.eyebrow,
            );
            final form = _SoftFormFrame(palette: palette, child: leadForm);
            if (compact) {
              return Column(children: [copy, const SizedBox(height: 42), form]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 78),
                    child: copy,
                  ),
                ),
                Expanded(child: form),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return _CommonFooter(
      promotion: promotion,
      background: palette.footer,
      foreground: palette.onFooter,
      accent: palette.secondary,
      roundedTop: true,
    );
  }
}

class _StudioPopLayout extends StatelessWidget {
  const _StudioPopLayout({
    required this.promotion,
    required this.palette,
    required this.embedded,
    required this.bookingKey,
    required this.onPrimaryAction,
    required this.leadForm,
  });

  final PublicPromotionLanding promotion;
  final PromotionLandingPalette palette;
  final bool embedded;
  final GlobalKey bookingKey;
  final VoidCallback onPrimaryAction;
  final Widget leadForm;

  @override
  Widget build(BuildContext context) {
    if (embedded) return _embed(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SelectionArea(
        child: CustomScrollView(
          slivers: [
            _navigation(context),
            SliverToBoxAdapter(child: _hero(context)),
            SliverToBoxAdapter(child: _sections(context)),
            SliverToBoxAdapter(child: _offer(context)),
            SliverToBoxAdapter(
              child: KeyedSubtree(key: bookingKey, child: _booking(context)),
            ),
            SliverToBoxAdapter(child: _footer(context)),
          ],
        ),
      ),
    );
  }

  Widget _embed(BuildContext context) {
    return Scaffold(
      backgroundColor: palette.secondary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Positioned(
                top: -70,
                right: -45,
                child: _PopCircle(
                  size: 210,
                  color: palette.primary,
                  borderColor: palette.text,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: _LandingFrame(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 780;
                      final copy = Container(
                        padding: EdgeInsets.all(compact ? 28 : 48),
                        decoration: BoxDecoration(
                          color: palette.primary,
                          border: Border.all(color: palette.line, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: palette.line,
                              offset: const Offset(9, 9),
                            ),
                          ],
                        ),
                        child: _StudioBookingCopy(
                          promotion: promotion,
                          palette: palette,
                          compact: compact,
                          dark: true,
                        ),
                      );
                      final form = _PopFormFrame(
                        palette: palette,
                        child: leadForm,
                      );
                      if (compact) {
                        return Column(
                          key: bookingKey,
                          children: [copy, const SizedBox(height: 34), form],
                        );
                      }
                      return Row(
                        key: bookingKey,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: copy),
                          const SizedBox(width: 54),
                          Expanded(child: form),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _navigation(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      toolbarHeight: 76,
      titleSpacing: 0,
      backgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: palette.line, width: 3)),
      title: _LandingFrame(
        child: Row(
          children: [
            Flexible(
              child: _Brand(
                promotion: promotion,
                color: palette.text,
                compact: MediaQuery.sizeOf(context).width < 560,
                bold: true,
              ),
            ),
            const Spacer(),
            _PopButton(
              label: _shortActionLabel(context, promotion),
              background: palette.primary,
              foreground: palette.onPrimary,
              border: palette.line,
              onPressed: onPrimaryAction,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      color: palette.primary,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: -105,
            right: -72,
            child: _PopCircle(
              size: 330,
              color: palette.secondary,
              borderColor: palette.line,
            ),
          ),
          Positioned(
            left: -80,
            bottom: -120,
            child: Transform.rotate(
              angle: -0.18,
              child: Container(width: 260, height: 190, color: palette.accent),
            ),
          ),
          _LandingFrame(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 800;
                final copy = Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 0 : 6,
                    compact ? 76 : 112,
                    compact ? 0 : 64,
                    compact ? 54 : 112,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PopLabel(
                        text: promotion.webLanding.eyebrow,
                        background: palette.secondary,
                        foreground: palette.onSecondary,
                        border: palette.line,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        promotion.title.toUpperCase(),
                        style: Theme.of(
                          context,
                        ).textTheme.displayLarge?.copyWith(
                          color: palette.onPrimary,
                          fontSize: compact ? 54 : 82,
                          height: 0.94,
                          letterSpacing: -2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (_hasText(promotion.subtitle)) ...[
                        const SizedBox(height: 24),
                        Text(
                          promotion.subtitle!,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(
                            color: palette.onPrimary,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (_hasText(promotion.tagline)) ...[
                        const SizedBox(height: 20),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 570),
                          child: Text(
                            promotion.tagline!,
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              color: palette.onPrimary.withValues(alpha: 0.88),
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 36),
                      _PopButton(
                        label: promotion.webLanding.submitLabel.toUpperCase(),
                        background: palette.secondary,
                        foreground: palette.onSecondary,
                        border: palette.line,
                        onPressed: onPrimaryAction,
                      ),
                    ],
                  ),
                );
                final visual = _StudioHeroVisual(
                  promotion: promotion,
                  palette: palette,
                  compact: compact,
                );
                if (compact) {
                  return Column(children: [copy, visual]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 11, child: copy),
                    Expanded(flex: 9, child: visual),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sections(BuildContext context) {
    final sections = _orderedSections(promotion);
    if (sections.isEmpty) return const SizedBox.shrink();
    return Container(
      color: palette.background,
      padding: const EdgeInsets.symmetric(vertical: 94),
      child: _LandingFrame(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _PopLabel(
                text: 'Dentro la promozione',
                background: palette.accent,
                foreground: palette.onAccent,
                border: palette.line,
              ),
            ),
            const SizedBox(height: 44),
            for (var index = 0; index < sections.length; index++) ...[
              _studioSection(context, sections[index], index),
              if (index != sections.length - 1) const SizedBox(height: 42),
            ],
          ],
        ),
      ),
    );
  }

  Widget _studioSection(
    BuildContext context,
    PromotionSection section,
    int index,
  ) {
    if (section.layout == PromotionSectionLayout.quote) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 66),
        decoration: BoxDecoration(
          color: index.isEven ? palette.secondary : palette.accent,
          border: Border.all(color: palette.line, width: 3),
          boxShadow: [
            BoxShadow(color: palette.line, offset: const Offset(10, 10)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              left: -6,
              child: Text(
                '“',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color:
                      index.isEven
                          ? palette.onSecondary.withValues(alpha: 0.18)
                          : palette.onAccent.withValues(alpha: 0.18),
                  fontSize: 140,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Column(
                  children: [
                    if (_hasText(section.title))
                      Text(
                        section.title!.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineLarge?.copyWith(
                          color:
                              index.isEven
                                  ? palette.onSecondary
                                  : palette.onAccent,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                    if (_hasText(section.text)) ...[
                      const SizedBox(height: 22),
                      Text(
                        section.text!,
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: (index.isEven
                                  ? palette.onSecondary
                                  : palette.onAccent)
                              .withValues(alpha: 0.86),
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasImage = _hasText(section.imageUrl);
    final copy = _StudioSectionCopy(
      section: section,
      palette: palette,
      index: index,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (!hasImage) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 28 : 52),
            decoration: BoxDecoration(
              color: index.isEven ? palette.surface : palette.surfaceAlt,
              border: Border.all(color: palette.line, width: 3),
              boxShadow: [
                BoxShadow(color: palette.line, offset: const Offset(9, 9)),
              ],
            ),
            child: copy,
          );
        }
        final image = _CaptionedImage(
          url: section.imageUrl,
          semanticLabel: section.altText,
          caption: section.caption,
          borderRadius: BorderRadius.zero,
          background: palette.secondary,
          iconColor: palette.text,
          aspectRatio: compact ? 4 / 3 : 1.04,
          border: Border.all(color: palette.line, width: 3),
          hardShadowColor: palette.line,
        );
        final copyCard = Container(
          padding: EdgeInsets.all(compact ? 28 : 48),
          decoration: BoxDecoration(
            color: index.isEven ? palette.secondary : palette.surface,
            border: Border.all(color: palette.line, width: 3),
          ),
          child: copy,
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [image, const SizedBox(height: 30), copyCard],
          );
        }
        final children = <Widget>[
          Expanded(child: image),
          const SizedBox(width: 44),
          Expanded(child: copyCard),
        ];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: index.isEven ? children : children.reversed.toList(),
        );
      },
    );
  }

  Widget _offer(BuildContext context) {
    return Container(
      color: palette.accent,
      padding: const EdgeInsets.symmetric(vertical: 92),
      child: _LandingFrame(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PopLabel(
                  text: 'Offerta in evidenza',
                  background: palette.primary,
                  foreground: palette.onPrimary,
                  border: palette.onAccent,
                ),
                const SizedBox(height: 24),
                Text(
                  promotion.title.toUpperCase(),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: palette.onAccent,
                    fontWeight: FontWeight.w900,
                    height: 0.98,
                  ),
                ),
              ],
            );
            final details = Column(
              crossAxisAlignment:
                  compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                _OfferPrice(
                  promotion: promotion,
                  color: palette.secondary,
                  mutedColor: palette.onAccent.withValues(alpha: 0.62),
                  align: compact ? TextAlign.left : TextAlign.right,
                  bold: true,
                ),
                const SizedBox(height: 28),
                _PopButton(
                  label: promotion.webLanding.submitLabel.toUpperCase(),
                  background: palette.secondary,
                  foreground: palette.onSecondary,
                  border: palette.onAccent,
                  onPressed: onPrimaryAction,
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [copy, const SizedBox(height: 42), details],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: copy),
                const SizedBox(width: 70),
                Expanded(flex: 2, child: details),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _booking(BuildContext context) {
    return Container(
      color: palette.background,
      padding: const EdgeInsets.symmetric(vertical: 106),
      child: _LandingFrame(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 780;
            final copy = _StudioBookingCopy(
              promotion: promotion,
              palette: palette,
              compact: compact,
            );
            final form = _PopFormFrame(palette: palette, child: leadForm);
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 46), form],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 74),
                    child: copy,
                  ),
                ),
                Expanded(child: form),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return _CommonFooter(
      promotion: promotion,
      background: palette.footer,
      foreground: palette.onFooter,
      accent: palette.primary,
      topBorder: BorderSide(color: palette.secondary, width: 12),
    );
  }
}

class _BotanicalRitualLayout extends StatelessWidget {
  const _BotanicalRitualLayout({
    required this.promotion,
    required this.palette,
    required this.embedded,
    required this.bookingKey,
    required this.onPrimaryAction,
    required this.leadForm,
  });

  final PublicPromotionLanding promotion;
  final PromotionLandingPalette palette;
  final bool embedded;
  final GlobalKey bookingKey;
  final VoidCallback onPrimaryAction;
  final Widget leadForm;

  @override
  Widget build(BuildContext context) {
    if (embedded) return _embed(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SelectionArea(
        child: CustomScrollView(
          slivers: [
            _navigation(context),
            SliverToBoxAdapter(child: _hero(context)),
            SliverToBoxAdapter(child: _sections(context)),
            SliverToBoxAdapter(child: _offer(context)),
            SliverToBoxAdapter(
              child: KeyedSubtree(key: bookingKey, child: _booking(context)),
            ),
            SliverToBoxAdapter(child: _footer(context)),
          ],
        ),
      ),
    );
  }

  Widget _embed(BuildContext context) {
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Positioned(
                top: -130,
                right: -100,
                child: _BotanicalLeaf(
                  width: 290,
                  height: 430,
                  color: palette.secondary.withValues(alpha: 0.52),
                  angle: 0.5,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 46),
                child: _LandingFrame(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 780;
                      final copy = Container(
                        padding: EdgeInsets.all(compact ? 30 : 48),
                        decoration: BoxDecoration(
                          color: palette.primary,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(86),
                            topRight: Radius.circular(24),
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(86),
                          ),
                        ),
                        child: _BotanicalBookingCopy(
                          promotion: promotion,
                          palette: palette,
                          compact: compact,
                        ),
                      );
                      final form = _BotanicalFormFrame(
                        palette: palette,
                        child: leadForm,
                      );
                      if (compact) {
                        return Column(
                          key: bookingKey,
                          children: [copy, const SizedBox(height: 32), form],
                        );
                      }
                      return Row(
                        key: bookingKey,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: copy),
                          const SizedBox(width: 54),
                          Expanded(child: form),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _navigation(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      toolbarHeight: 82,
      backgroundColor: palette.primary.withValues(alpha: 0.97),
      foregroundColor: palette.onPrimary,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: _LandingFrame(
        child: Row(
          children: [
            Flexible(
              child: _Brand(
                promotion: promotion,
                color: palette.onPrimary,
                compact: MediaQuery.sizeOf(context).width < 560,
              ),
            ),
            const Spacer(),
            _BotanicalButton(
              label: _shortActionLabel(context, promotion),
              background: palette.accent,
              foreground: palette.onAccent,
              onPressed: onPrimaryAction,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SizedBox(
          height: compact ? 710 : 790,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _NetworkVisual(
                url: promotion.coverImageUrl,
                semanticLabel: promotion.title,
                fit: BoxFit.cover,
                fallback: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [palette.primary, palette.secondary],
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.footer.withValues(alpha: 0.2),
                      palette.footer.withValues(alpha: compact ? 0.9 : 0.78),
                    ],
                    stops: const [0.12, 1],
                  ),
                ),
              ),
              Positioned(
                right: compact ? -130 : -60,
                top: compact ? 50 : 80,
                child: _BotanicalLeaf(
                  width: compact ? 250 : 370,
                  height: compact ? 390 : 560,
                  color: palette.secondary.withValues(alpha: 0.23),
                  angle: 0.44,
                  borderColor: palette.onPrimary.withValues(alpha: 0.24),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _LandingFrame(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: compact ? 68 : 92),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 850),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BotanicalEyebrow(
                              text: promotion.webLanding.eyebrow,
                              color: palette.accent,
                              textColor: palette.onPrimary,
                            ),
                            const SizedBox(height: 28),
                            Text(
                              promotion.title,
                              style: Theme.of(
                                context,
                              ).textTheme.displayLarge?.copyWith(
                                color: palette.onPrimary,
                                fontSize: compact ? 58 : 92,
                                height: 0.98,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -1.8,
                              ),
                            ),
                            if (_hasText(promotion.subtitle)) ...[
                              const SizedBox(height: 20),
                              Text(
                                promotion.subtitle!,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium?.copyWith(
                                  color: palette.secondary,
                                  height: 1.15,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            if (_hasText(promotion.tagline)) ...[
                              const SizedBox(height: 20),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 650,
                                ),
                                child: Text(
                                  promotion.tagline!,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(
                                    color: palette.onPrimary.withValues(
                                      alpha: 0.84,
                                    ),
                                    height: 1.58,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 34),
                            _BotanicalButton(
                              label: promotion.webLanding.submitLabel,
                              background: palette.accent,
                              foreground: palette.onAccent,
                              onPressed: onPrimaryAction,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sections(BuildContext context) {
    final sections = _orderedSections(promotion);
    if (sections.isEmpty) return const SizedBox.shrink();
    return Container(
      color: palette.background,
      padding: const EdgeInsets.symmetric(vertical: 108),
      child: _LandingFrame(
        child: Column(
          children: [
            for (var index = 0; index < sections.length; index++) ...[
              _botanicalSection(context, sections[index], index),
              if (index != sections.length - 1) const SizedBox(height: 74),
            ],
          ],
        ),
      ),
    );
  }

  Widget _botanicalSection(
    BuildContext context,
    PromotionSection section,
    int index,
  ) {
    if (section.layout == PromotionSectionLayout.quote) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 84),
        decoration: BoxDecoration(
          color: palette.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(120),
            bottomRight: Radius.circular(120),
            topRight: Radius.circular(28),
            bottomLeft: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.eco_outlined, color: palette.accent, size: 36),
            if (_hasText(section.title)) ...[
              const SizedBox(height: 22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Text(
                  section.title!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: palette.onPrimary,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            if (_hasText(section.text)) ...[
              const SizedBox(height: 22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  section.text!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.onPrimary.withValues(alpha: 0.82),
                    height: 1.72,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final copy = _BotanicalSectionCopy(
      section: section,
      palette: palette,
      index: index,
    );
    final hasImage = _hasText(section.imageUrl);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (!hasImage) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 30 : 72,
              vertical: compact ? 46 : 66,
            ),
            decoration: BoxDecoration(
              color: index.isEven ? palette.surface : palette.surfaceAlt,
              borderRadius: BorderRadius.circular(48),
            ),
            child: copy,
          );
        }
        final image = _CaptionedImage(
          url: section.imageUrl,
          semanticLabel: section.altText,
          caption: section.caption,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(index.isEven ? 160 : 34),
            topRight: Radius.circular(index.isEven ? 34 : 160),
            bottomLeft: const Radius.circular(34),
            bottomRight: const Radius.circular(34),
          ),
          background: palette.secondary,
          iconColor: palette.primary,
          aspectRatio: compact ? 4 / 3 : 0.92,
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              image,
              const SizedBox(height: 42),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: copy,
              ),
            ],
          );
        }
        final children = <Widget>[
          Expanded(flex: 10, child: image),
          const SizedBox(width: 88),
          Expanded(flex: 9, child: copy),
        ];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: index.isEven ? children : children.reversed.toList(),
        );
      },
    );
  }

  Widget _offer(BuildContext context) {
    return Container(
      color: palette.accent,
      padding: const EdgeInsets.symmetric(vertical: 100),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -90,
            top: -130,
            child: _BotanicalLeaf(
              width: 300,
              height: 440,
              color: palette.onAccent.withValues(alpha: 0.09),
              angle: 0.55,
              borderColor: palette.onAccent.withValues(alpha: 0.18),
            ),
          ),
          _LandingFrame(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BotanicalEyebrow(
                      text: 'La tua occasione',
                      color: palette.onAccent,
                      textColor: palette.onAccent,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      promotion.title,
                      style: Theme.of(
                        context,
                      ).textTheme.displayMedium?.copyWith(
                        color: palette.onAccent,
                        height: 1.05,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
                final detail = Column(
                  crossAxisAlignment:
                      compact
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                  children: [
                    _OfferPrice(
                      promotion: promotion,
                      color: palette.onAccent,
                      mutedColor: palette.onAccent.withValues(alpha: 0.62),
                      align: compact ? TextAlign.left : TextAlign.right,
                    ),
                    const SizedBox(height: 28),
                    _BotanicalButton(
                      label: promotion.webLanding.submitLabel,
                      background: palette.primary,
                      foreground: palette.onPrimary,
                      onPressed: onPrimaryAction,
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [copy, const SizedBox(height: 42), detail],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 3, child: copy),
                    const SizedBox(width: 70),
                    Expanded(flex: 2, child: detail),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _booking(BuildContext context) {
    return Container(
      color: palette.surface,
      padding: const EdgeInsets.symmetric(vertical: 110),
      child: _LandingFrame(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 780;
            final copy = _BotanicalBookingCopy(
              promotion: promotion,
              palette: palette,
              compact: compact,
              dark: false,
            );
            final form = _BotanicalFormFrame(palette: palette, child: leadForm);
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 48), form],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 86),
                    child: copy,
                  ),
                ),
                Expanded(child: form),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return _CommonFooter(
      promotion: promotion,
      background: palette.footer,
      foreground: palette.onFooter,
      accent: palette.accent,
      roundedTop: true,
    );
  }
}

class _LandingFrame extends StatelessWidget {
  const _LandingFrame({required this.child, this.horizontalPadding = 24});

  final Widget child;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({
    required this.promotion,
    required this.color,
    required this.compact,
    this.bold = false,
  });

  final PublicPromotionLanding promotion;
  final Color color;
  final bool compact;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasText(promotion.salonLogoImageUrl)) ...[
          SizedBox(
            width: 40,
            height: 40,
            child: _NetworkVisual(
              url: promotion.salonLogoImageUrl,
              semanticLabel: promotion.salonName,
              fit: BoxFit.contain,
              fallback: const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                promotion.salonName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: bold ? 1.3 : 2.3,
                ),
              ),
              if (!compact && _hasText(promotion.salonCity))
                Text(
                  promotion.salonCity.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color.withValues(alpha: 0.66),
                    fontSize: 9,
                    letterSpacing: 2,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NetworkVisual extends StatelessWidget {
  const _NetworkVisual({
    required this.url,
    required this.semanticLabel,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final String? semanticLabel;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (!_hasText(url)) return fallback;
    return Image.network(
      url!,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      semanticLabel: semanticLabel,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _CaptionedImage extends StatelessWidget {
  const _CaptionedImage({
    required this.url,
    required this.semanticLabel,
    required this.caption,
    required this.borderRadius,
    required this.background,
    required this.iconColor,
    required this.aspectRatio,
    this.border,
    this.hardShadowColor,
  });

  final String? url;
  final String? semanticLabel;
  final String? caption;
  final BorderRadius borderRadius;
  final Color background;
  final Color iconColor;
  final double aspectRatio;
  final Border? border;
  final Color? hardShadowColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow:
                hardShadowColor == null
                    ? null
                    : [
                      BoxShadow(
                        color: hardShadowColor!,
                        offset: const Offset(9, 9),
                      ),
                    ],
          ),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: background,
                borderRadius: borderRadius,
                border: border,
              ),
              child: _NetworkVisual(
                url: url,
                semanticLabel: semanticLabel,
                fallback: Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: iconColor,
                    size: 42,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_hasText(caption)) ...[
          const SizedBox(height: 13),
          Text(
            caption!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withValues(alpha: 0.62),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _MinimalHeroVisual extends StatelessWidget {
  const _MinimalHeroVisual({required this.promotion, required this.palette});

  final PublicPromotionLanding promotion;
  final PromotionLandingPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: AspectRatio(
        aspectRatio: 0.92,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 12,
              left: 12,
              right: 36,
              bottom: 36,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(180),
                ),
              ),
            ),
            Positioned(
              left: 36,
              top: 36,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(180),
                  topRight: Radius.circular(36),
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(180),
                ),
                child: _NetworkVisual(
                  url: promotion.coverImageUrl,
                  semanticLabel: promotion.title,
                  fallback: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [palette.secondary, palette.surfaceAlt],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.auto_awesome_outlined,
                        color: palette.primary,
                        size: 72,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -12,
              bottom: 44,
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.surface, width: 8),
                ),
                child: Icon(
                  Icons.spa_outlined,
                  color: palette.onAccent,
                  size: 34,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimalSectionCopy extends StatelessWidget {
  const _MinimalSectionCopy({
    required this.section,
    required this.palette,
    required this.index,
  });

  final PromotionSection section;
  final PromotionLandingPalette palette;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${index + 1}'.padLeft(2, '0'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: palette.primary,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (_hasText(section.title)) ...[
          const SizedBox(height: 16),
          Text(
            section.title!,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: palette.text,
              height: 1.1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (_hasText(section.text)) ...[
          const SizedBox(height: 22),
          Text(
            section.text!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: palette.textMuted,
              fontWeight: FontWeight.w400,
              height: 1.7,
            ),
          ),
        ],
      ],
    );
  }
}

class _PillEyebrow extends StatelessWidget {
  const _PillEyebrow({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}

class _MinimalButton extends StatelessWidget {
  const _MinimalButton({
    required this.label,
    required this.palette,
    required this.onPressed,
    required this.filled,
  });

  final String label;
  final PromotionLandingPalette palette;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_forward_rounded, size: 17),
      label: Text(label),
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: filled ? palette.primary : Colors.transparent,
        foregroundColor: filled ? palette.onPrimary : palette.primary,
        side: BorderSide(color: palette.primary),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SoftFormFrame extends StatelessWidget {
  const _SoftFormFrame({required this.palette, required this.child});

  final PromotionLandingPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.1),
            blurRadius: 38,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BookingCopy extends StatelessWidget {
  const _BookingCopy({
    required this.promotion,
    required this.palette,
    required this.titleSize,
    required this.eyebrow,
  });

  final PublicPromotionLanding promotion;
  final PromotionLandingPalette palette;
  final double titleSize;
  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PillEyebrow(
          text: eyebrow,
          background: palette.secondary.withValues(alpha: 0.32),
          foreground: palette.primary,
        ),
        const SizedBox(height: 24),
        Text(
          promotion.webLanding.formTitle,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: palette.text,
            fontSize: titleSize,
            height: 1.06,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          promotion.webLanding.formDescription,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: palette.textMuted,
            height: 1.65,
            fontWeight: FontWeight.w400,
          ),
        ),
        _ContactBlock(
          promotion: promotion,
          foreground: palette.text,
          accent: palette.primary,
        ),
      ],
    );
  }
}

class _OfferPrice extends StatelessWidget {
  const _OfferPrice({
    required this.promotion,
    required this.color,
    required this.mutedColor,
    required this.align,
    this.bold = false,
  });

  final PublicPromotionLanding promotion;
  final Color color;
  final Color mutedColor;
  final TextAlign align;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final price = promotion.webLanding.offerPrice?.trim();
    final original = promotion.webLanding.originalPrice?.trim();
    final discount = promotion.discountPercentage;
    final hasNumericOffer = _hasText(price) || discount > 0;
    final display =
        _hasText(price)
            ? price!
            : discount > 0
            ? '-${discount.round()}%'
            : 'SCOPRI';
    return Column(
      crossAxisAlignment:
          align == TextAlign.right
              ? CrossAxisAlignment.end
              : align == TextAlign.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
      children: [
        if (_hasText(original))
          Text(
            original!,
            textAlign: align,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: mutedColor,
              decoration: TextDecoration.lineThrough,
              decorationColor: mutedColor,
            ),
          ),
        Text(
          display,
          textAlign: align,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: color,
            fontSize: hasNumericOffer ? 66 : 32,
            height: 1,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            letterSpacing: hasNumericOffer ? -1 : 2,
          ),
        ),
      ],
    );
  }
}

class _PopCircle extends StatelessWidget {
  const _PopCircle({
    required this.size,
    required this.color,
    required this.borderColor,
  });

  final double size;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 3),
      ),
    );
  }
}

class _PopLabel extends StatelessWidget {
  const _PopLabel({
    required this.text,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String text;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border, width: 2),
      ),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _PopButton extends StatelessWidget {
  const _PopButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(
        compact ? Icons.arrow_forward_rounded : Icons.north_east_rounded,
        size: 18,
      ),
      label: Text(label),
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: background,
        foregroundColor: foreground,
        side: BorderSide(color: border, width: 2.5),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 24,
          vertical: compact ? 14 : 18,
        ),
        shape: const RoundedRectangleBorder(),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _StudioHeroVisual extends StatelessWidget {
  const _StudioHeroVisual({
    required this.promotion,
    required this.palette,
    required this.compact,
  });

  final PublicPromotionLanding promotion;
  final PromotionLandingPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 26,
        compact ? 0 : 82,
        compact ? 20 : 8,
        compact ? 72 : 82,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 12, bottom: 12),
            decoration: BoxDecoration(
              color: palette.secondary,
              border: Border.all(color: palette.line, width: 3),
              boxShadow: [
                BoxShadow(color: palette.line, offset: const Offset(12, 12)),
              ],
            ),
            child: AspectRatio(
              aspectRatio: compact ? 4 / 3 : 0.9,
              child: _NetworkVisual(
                url: promotion.coverImageUrl,
                semanticLabel: promotion.title,
                fallback: Center(
                  child: Text(
                    promotion.discountPercentage > 0
                        ? '-${promotion.discountPercentage.round()}%'
                        : 'WOW!',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: palette.onSecondary,
                      fontSize: compact ? 68 : 86,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -3,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -24,
            right: -10,
            child: Transform.rotate(
              angle: 0.1,
              child: _PopLabel(
                text: 'Solo per te',
                background: palette.secondary,
                foreground: palette.onSecondary,
                border: palette.line,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioSectionCopy extends StatelessWidget {
  const _StudioSectionCopy({
    required this.section,
    required this.palette,
    required this.index,
  });

  final PromotionSection section;
  final PromotionLandingPalette palette;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.primary,
                border: Border.all(color: palette.line, width: 2),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: palette.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Container(height: 3, color: palette.line)),
          ],
        ),
        if (_hasText(section.title)) ...[
          const SizedBox(height: 26),
          Text(
            section.title!.toUpperCase(),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: palette.text,
              height: 0.98,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
        ],
        if (_hasText(section.text)) ...[
          const SizedBox(height: 24),
          Text(
            section.text!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: palette.text.withValues(alpha: 0.78),
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _StudioBookingCopy extends StatelessWidget {
  const _StudioBookingCopy({
    required this.promotion,
    required this.palette,
    required this.compact,
    this.dark = false,
  });

  final PublicPromotionLanding promotion;
  final PromotionLandingPalette palette;
  final bool compact;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? palette.onPrimary : palette.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PopLabel(
          text: promotion.webLanding.eyebrow,
          background: palette.secondary,
          foreground: palette.onSecondary,
          border: foreground,
        ),
        const SizedBox(height: 25),
        Text(
          promotion.webLanding.formTitle.toUpperCase(),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: foreground,
            fontSize: compact ? 45 : 60,
            fontWeight: FontWeight.w900,
            height: 0.98,
            letterSpacing: -1.4,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          promotion.webLanding.formDescription,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: foreground.withValues(alpha: 0.78),
            height: 1.55,
            fontWeight: FontWeight.w600,
          ),
        ),
        _ContactBlock(
          promotion: promotion,
          foreground: foreground,
          accent: dark ? palette.secondary : palette.primary,
          bold: true,
        ),
      ],
    );
  }
}

class _PopFormFrame extends StatelessWidget {
  const _PopFormFrame({required this.palette, required this.child});

  final PromotionLandingPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10, bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.line, width: 3),
        boxShadow: [
          BoxShadow(color: palette.line, offset: const Offset(10, 10)),
        ],
      ),
      child: child,
    );
  }
}

class _BotanicalLeaf extends StatelessWidget {
  const _BotanicalLeaf({
    required this.width,
    required this.height,
    required this.color,
    required this.angle,
    this.borderColor,
  });

  final double width;
  final double height;
  final Color color;
  final double angle;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          border: borderColor == null ? null : Border.all(color: borderColor!),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(width),
            bottomRight: Radius.circular(width),
            topRight: Radius.circular(width * 0.18),
            bottomLeft: Radius.circular(width * 0.18),
          ),
        ),
      ),
    );
  }
}

class _BotanicalEyebrow extends StatelessWidget {
  const _BotanicalEyebrow({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.eco_outlined, size: 17, color: color),
        const SizedBox(width: 11),
        Flexible(
          child: Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _BotanicalButton extends StatelessWidget {
  const _BotanicalButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: background,
        foregroundColor: foreground,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 25,
          vertical: compact ? 14 : 18,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(compact ? 22 : 30),
            topRight: const Radius.circular(8),
            bottomLeft: const Radius.circular(8),
            bottomRight: Radius.circular(compact ? 22 : 30),
          ),
        ),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _BotanicalSectionCopy extends StatelessWidget {
  const _BotanicalSectionCopy({
    required this.section,
    required this.palette,
    required this.index,
  });

  final PromotionSection section;
  final PromotionLandingPalette palette;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _BotanicalEyebrow(
          text: 'Rituale ${index + 1}',
          color: palette.accent,
          textColor: palette.primary,
        ),
        if (_hasText(section.title)) ...[
          const SizedBox(height: 22),
          Text(
            section.title!,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: palette.text,
              height: 1.1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (_hasText(section.text)) ...[
          const SizedBox(height: 24),
          Text(
            section.text!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: palette.textMuted,
              height: 1.75,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

class _BotanicalBookingCopy extends StatelessWidget {
  const _BotanicalBookingCopy({
    required this.promotion,
    required this.palette,
    required this.compact,
    this.dark = true,
  });

  final PublicPromotionLanding promotion;
  final PromotionLandingPalette palette;
  final bool compact;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? palette.onPrimary : palette.text;
    final muted = foreground.withValues(alpha: 0.74);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BotanicalEyebrow(
          text: promotion.webLanding.eyebrow,
          color: palette.accent,
          textColor: foreground,
        ),
        const SizedBox(height: 25),
        Text(
          promotion.webLanding.formTitle,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: foreground,
            fontSize: compact ? 46 : 61,
            fontWeight: FontWeight.w500,
            height: 1.04,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          promotion.webLanding.formDescription,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: muted, height: 1.7),
        ),
        _ContactBlock(
          promotion: promotion,
          foreground: foreground,
          accent: palette.accent,
        ),
      ],
    );
  }
}

class _BotanicalFormFrame extends StatelessWidget {
  const _BotanicalFormFrame({required this.palette, required this.child});

  final PromotionLandingPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(76),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(76),
        ),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.13),
            blurRadius: 42,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ContactBlock extends StatelessWidget {
  const _ContactBlock({
    required this.promotion,
    required this.foreground,
    required this.accent,
    this.bold = false,
  });

  final PublicPromotionLanding promotion;
  final Color foreground;
  final Color accent;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    if (!_hasText(promotion.salonPhone) &&
        !_hasText(promotion.salonEmail) &&
        !_hasText(promotion.salonCity)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 44, height: bold ? 3 : 1.5, color: accent),
          const SizedBox(height: 22),
          if (_hasText(promotion.salonPhone))
            _ContactLine(
              icon: Icons.phone_outlined,
              value: promotion.salonPhone,
              color: foreground,
              bold: bold,
            ),
          if (_hasText(promotion.salonEmail)) ...[
            const SizedBox(height: 11),
            _ContactLine(
              icon: Icons.email_outlined,
              value: promotion.salonEmail,
              color: foreground,
              bold: bold,
            ),
          ],
          if (_hasText(promotion.salonCity)) ...[
            const SizedBox(height: 11),
            _ContactLine(
              icon: Icons.location_on_outlined,
              value: promotion.salonCity,
              color: foreground,
              bold: bold,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({
    required this.icon,
    required this.value,
    required this.color,
    required this.bold,
  });

  final IconData icon;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color.withValues(alpha: 0.86),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _CommonFooter extends StatelessWidget {
  const _CommonFooter({
    required this.promotion,
    required this.background,
    required this.foreground,
    required this.accent,
    this.roundedTop = false,
    this.topBorder,
  });

  final PublicPromotionLanding promotion;
  final Color background;
  final Color foreground;
  final Color accent;
  final bool roundedTop;
  final BorderSide? topBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: topBorder == null ? null : Border(top: topBorder!),
        borderRadius:
            roundedTop
                ? const BorderRadius.only(
                  topLeft: Radius.circular(54),
                  topRight: Radius.circular(54),
                )
                : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 58),
      child: _LandingFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 44,
              runSpacing: 28,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 220),
                  child: _Brand(
                    promotion: promotion,
                    color: foreground,
                    compact: false,
                  ),
                ),
                if (_hasText(promotion.salonPhone))
                  _FooterDetail(
                    label: 'Telefono',
                    value: promotion.salonPhone,
                    foreground: foreground,
                    accent: accent,
                  ),
                if (_hasText(promotion.salonEmail))
                  _FooterDetail(
                    label: 'Email',
                    value: promotion.salonEmail,
                    foreground: foreground,
                    accent: accent,
                  ),
                if (_hasText(promotion.salonCity))
                  _FooterDetail(
                    label: 'Dove siamo',
                    value: promotion.salonCity,
                    foreground: foreground,
                    accent: accent,
                  ),
              ],
            ),
            const SizedBox(height: 38),
            Divider(color: foreground.withValues(alpha: 0.18)),
            const SizedBox(height: 18),
            Text(
              '© ${DateTime.now().year} ${promotion.salonName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foreground.withValues(alpha: 0.55),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterDetail extends StatelessWidget {
  const _FooterDetail({
    required this.label,
    required this.value,
    required this.foreground,
    required this.accent,
  });

  final String label;
  final String value;
  final Color foreground;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foreground.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

bool _hasText(String? value) => value?.trim().isNotEmpty == true;

String _shortActionLabel(
  BuildContext context,
  PublicPromotionLanding promotion,
) {
  if (MediaQuery.sizeOf(context).width < 520) return 'Richiedi';
  return promotion.webLanding.submitLabel;
}

List<PromotionSection> _orderedSections(PublicPromotionLanding promotion) {
  final sections =
      promotion.sections.where((section) => section.visible).toList()
        ..sort((first, second) => first.order.compareTo(second.order));
  return sections;
}
