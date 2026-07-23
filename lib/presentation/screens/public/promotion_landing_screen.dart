import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:you_book/domain/entities/public_promotion_landing.dart';
import 'package:you_book/presentation/screens/public/promotion_landing_template_layout.dart';
import 'package:you_book/services/clients/web_client_request_service.dart';

class PromotionLandingScreen extends StatefulWidget {
  const PromotionLandingScreen({
    super.key,
    required this.salonSlug,
    required this.promotionSlug,
    this.embedded = false,
  });

  final String salonSlug;
  final String promotionSlug;
  final bool embedded;

  @override
  State<PromotionLandingScreen> createState() => _PromotionLandingScreenState();
}

class _PromotionLandingScreenState extends State<PromotionLandingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bookingKey = GlobalKey();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _service = WebClientRequestService();
  String? _interest;
  bool _privacyAccepted = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<void> _submit(PublicPromotionLanding promotion) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (promotion.webLanding.interestOptions.isNotEmpty && _interest == null) {
      setState(() => _error = 'Seleziona una delle opzioni disponibili.');
      return;
    }
    if (!_privacyAccepted) {
      setState(() => _error = 'Accetta l’informativa privacy per continuare.');
      return;
    }
    final parts = _fullName.text.trim().split(RegExp(r'\s+'));
    final firstName = parts.isEmpty ? '' : parts.first;
    final lastName = parts.length <= 1 ? '-' : parts.sublist(1).join(' ');
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final uri = Uri.base;
      await _service.submit(
        salonId: promotion.salonId,
        promotionId: promotion.id,
        firstName: firstName,
        lastName: lastName,
        phone: _phone.text,
        email: _email.text,
        privacyAccepted: true,
        marketingAccepted: false,
        extraData: <String, dynamic>{
          if (_interest != null) 'interest': _interest,
        },
        sourceUrl: uri.toString(),
        utmSource: uri.queryParameters['utm_source'],
        utmMedium: uri.queryParameters['utm_medium'],
        utmCampaign: uri.queryParameters['utm_campaign'],
        website: _website.text,
      );
      if (mounted) setState(() => _submitted = true);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            error.code == 'resource-exhausted'
                ? 'Attendi un minuto prima di inviare nuovamente.'
                : 'Non è stato possibile inviare la richiesta. Riprova.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Non è stato possibile inviare la richiesta. Riprova.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _scrollToBooking() {
    final target = _bookingKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      alignment: 0.04,
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('public_promotions')
        .where('salonSlug', isEqualTo: widget.salonSlug)
        .where('promotionSlug', isEqualTo: widget.promotionSlug)
        .limit(1);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _LandingMessage(
            icon: Icons.error_outline_rounded,
            title: 'Promozione non disponibile',
            message: 'Riprova più tardi o contatta direttamente il salone.',
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data!.docs.isEmpty) {
          return const _LandingMessage(
            icon: Icons.link_off_rounded,
            title: 'Promozione non trovata',
            message:
                'Il collegamento non è valido oppure la promozione non è attiva.',
          );
        }
        final promotion = PublicPromotionLanding.fromDoc(
          snapshot.data!.docs.first,
        );
        final templatePalette = PromotionLandingPalette.fromPromotion(
          promotion,
        );
        final palette = _LandingPalette.fromTemplate(templatePalette);
        return Theme(
          data: _themeFor(promotion, palette),
          child: _buildSelectedTemplate(promotion, palette, templatePalette),
        );
      },
    );
  }

  Widget _buildSelectedTemplate(
    PublicPromotionLanding promotion,
    _LandingPalette palette,
    PromotionLandingPalette templatePalette,
  ) {
    switch (PromotionLandingTemplates.normalize(
      promotion.webLanding.templateId,
    )) {
      case PromotionLandingTemplates.editorialBeauty:
        return KeyedSubtree(
          key: const ValueKey<String>('landing-template-editorialBeauty'),
          child:
              widget.embedded
                  ? _buildEmbed(promotion, palette)
                  : _buildFullLanding(promotion, palette),
        );
      case PromotionLandingTemplates.minimalGlow:
      case PromotionLandingTemplates.studioPop:
      case PromotionLandingTemplates.botanicalRitual:
        return PromotionLandingTemplateLayout(
          promotion: promotion,
          palette: templatePalette,
          embedded: widget.embedded,
          bookingKey: _bookingKey,
          onPrimaryAction: _scrollToBooking,
          leadForm: _leadForm(promotion, palette),
        );
      default:
        return KeyedSubtree(
          key: const ValueKey<String>('landing-template-editorialBeauty'),
          child:
              widget.embedded
                  ? _buildEmbed(promotion, palette)
                  : _buildFullLanding(promotion, palette),
        );
    }
  }

  ThemeData _themeFor(
    PublicPromotionLanding promotion,
    _LandingPalette palette,
  ) {
    var textTheme = GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme);
    if (promotion.webLanding.fontFamily == 'playfairDmSans') {
      textTheme = textTheme.copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          textStyle: textTheme.displayLarge,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          textStyle: textTheme.displayMedium,
        ),
        displaySmall: GoogleFonts.playfairDisplay(
          textStyle: textTheme.displaySmall,
        ),
        headlineLarge: GoogleFonts.playfairDisplay(
          textStyle: textTheme.headlineLarge,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          textStyle: textTheme.headlineMedium,
        ),
        headlineSmall: GoogleFonts.playfairDisplay(
          textStyle: textTheme.headlineSmall,
        ),
      );
    } else if (const {
      'DM Sans',
      'Montserrat',
      'Lato',
      'Poppins',
    }.contains(promotion.webLanding.fontFamily)) {
      textTheme = GoogleFonts.getTextTheme(
        promotion.webLanding.fontFamily,
        textTheme,
      );
    }
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.brown,
        brightness: Brightness.light,
      ),
      textTheme: textTheme.apply(
        bodyColor: palette.ink,
        displayColor: palette.ink,
      ),
      scaffoldBackgroundColor: palette.cream,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.terracotta,
        selectionColor: palette.gold.withValues(alpha: 0.35),
      ),
    );
  }

  Widget _buildFullLanding(
    PublicPromotionLanding promotion,
    _LandingPalette palette,
  ) {
    return Scaffold(
      body: SelectionArea(
        child: CustomScrollView(
          slivers: [
            _navigation(promotion, palette),
            SliverToBoxAdapter(child: _hero(promotion, palette)),
            SliverToBoxAdapter(child: _sections(promotion, palette)),
            SliverToBoxAdapter(child: _offer(promotion, palette)),
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: _bookingKey,
                child: _bookingSection(promotion, palette),
              ),
            ),
            SliverToBoxAdapter(child: _footer(promotion, palette)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbed(
    PublicPromotionLanding promotion,
    _LandingPalette palette,
  ) {
    return Scaffold(
      backgroundColor: palette.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final copy = _bookingCopy(
                    promotion,
                    palette,
                    compact: compact,
                  );
                  final form = _leadForm(promotion, palette);
                  if (compact) {
                    return Column(
                      children: [copy, const SizedBox(height: 38), form],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 86, top: 30),
                          child: copy,
                        ),
                      ),
                      Expanded(child: form),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  SliverAppBar _navigation(
    PublicPromotionLanding promotion,
    _LandingPalette palette,
  ) {
    return SliverAppBar(
      pinned: true,
      toolbarHeight: 88,
      backgroundColor: palette.cream.withValues(alpha: 0.97),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: palette.line,
      titleSpacing: 0,
      title: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                if (promotion.salonLogoImageUrl?.isNotEmpty == true) ...[
                  Image.network(
                    promotion.salonLogoImageUrl!,
                    width: 42,
                    height: 42,
                    fit: BoxFit.contain,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promotion.salonName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: palette.brown,
                          fontFamily:
                              promotion.webLanding.fontFamily ==
                                      'playfairDmSans'
                                  ? GoogleFonts.playfairDisplay().fontFamily
                                  : null,
                          letterSpacing: 3.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (promotion.salonCity.isNotEmpty)
                        Text(
                          promotion.salonCity.toUpperCase(),
                          maxLines: 1,
                          style: TextStyle(
                            color: palette.terracotta,
                            fontSize: 8,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: _scrollToBooking,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.brown,
                    side: BorderSide(color: palette.brown),
                    shape: const RoundedRectangleBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 19,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(
                    MediaQuery.sizeOf(context).width < 560
                        ? 'RICHIEDI'
                        : 'RICHIEDI ORA',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(PublicPromotionLanding promotion, _LandingPalette palette) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final titleSize =
            compact ? 58.0 : (constraints.maxWidth < 1100 ? 76.0 : 98.0);
        return Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: compact ? 650 : 720),
          decoration: BoxDecoration(color: palette.brown),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (promotion.coverImageUrl?.isNotEmpty == true) ...[
                Positioned.fill(
                  child: Image.network(
                    promotion.coverImageUrl!,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(
                    color: palette.brown.withValues(alpha: 0.62),
                  ),
                ),
              ],
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.62, -0.15),
                      radius: 0.9,
                      colors: [
                        palette.terracotta.withValues(alpha: 0.58),
                        palette.brown.withValues(alpha: 0.18),
                        palette.ink.withValues(alpha: 0.62),
                      ],
                      stops: const [0, 0.48, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: compact ? -180 : -40,
                top: compact ? 78 : 38,
                child: _HeroHalo(color: palette.gold, compact: compact),
              ),
              Positioned(
                right: compact ? -12 : 22,
                bottom: compact ? 22 : -34,
                child: IgnorePointer(
                  child: Text(
                    'PROMO',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: compact ? 84 : 162,
                      fontWeight: FontWeight.w600,
                      foreground:
                          Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 1
                            ..color = Colors.white.withValues(alpha: 0.11),
                    ),
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 24 : 28,
                      compact ? 88 : 110,
                      compact ? 24 : 28,
                      compact ? 94 : 120,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 840),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Eyebrow(
                              text: promotion.webLanding.eyebrow,
                              color: palette.gold,
                              light: true,
                            ),
                            const SizedBox(height: 28),
                            Text(
                              promotion.title,
                              style: Theme.of(
                                context,
                              ).textTheme.displayLarge?.copyWith(
                                color: Colors.white,
                                fontSize: titleSize,
                                height: 0.98,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -1.5,
                              ),
                            ),
                            if (promotion.subtitle?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 22),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 680,
                                ),
                                child: Text(
                                  promotion.subtitle!,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium?.copyWith(
                                    color: palette.gold,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w400,
                                    height: 1.2,
                                    fontSize: compact ? 27 : 38,
                                  ),
                                ),
                              ),
                            ],
                            if (promotion.tagline?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 24),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 620,
                                ),
                                child: Text(
                                  promotion.tagline!,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    height: 1.65,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 38),
                            OutlinedButton.icon(
                              onPressed: _scrollToBooking,
                              icon: const Icon(
                                Icons.arrow_downward_rounded,
                                size: 17,
                              ),
                              label: Text(
                                promotion.webLanding.submitLabel.toUpperCase(),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: palette.gold),
                                shape: const RoundedRectangleBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                  vertical: 19,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 2.1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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

  Widget _sections(PublicPromotionLanding promotion, _LandingPalette palette) {
    if (promotion.sections.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var index = 0; index < promotion.sections.length; index++)
          _landingSection(promotion.sections[index], index, palette),
      ],
    );
  }

  Widget _landingSection(
    PromotionSection section,
    int index,
    _LandingPalette palette,
  ) {
    if (section.layout == PromotionSectionLayout.quote) {
      return _quoteSection(section, palette);
    }
    final background = index.isEven ? palette.cream : palette.paper;
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 112),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final copy = _sectionCopy(section, palette, compact: compact);
              final hasImage =
                  section.type == PromotionSectionType.image &&
                  section.imageUrl?.isNotEmpty == true;
              if (hasImage) {
                final image = _sectionImage(section, palette);
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [image, const SizedBox(height: 46), copy],
                  );
                }
                final imageFirst = index.isEven;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 11, child: imageFirst ? image : copy),
                    const SizedBox(width: 88),
                    Expanded(flex: 10, child: imageFirst ? copy : image),
                  ],
                );
              }
              if (section.layout == PromotionSectionLayout.split && !compact) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 70),
                        child: _sectionHeading(section, palette),
                      ),
                    ),
                    Expanded(flex: 6, child: _sectionBody(section, palette)),
                  ],
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: copy,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sectionCopy(
    PromotionSection section,
    _LandingPalette palette, {
    required bool compact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(section, palette),
        if (section.title?.trim().isNotEmpty == true &&
            section.text?.trim().isNotEmpty == true)
          SizedBox(height: compact ? 24 : 34),
        _sectionBody(section, palette),
      ],
    );
  }

  Widget _sectionHeading(PromotionSection section, _LandingPalette palette) {
    if (section.title?.trim().isNotEmpty != true) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow(text: 'SCOPRI DI PIÙ', color: palette.terracotta),
        const SizedBox(height: 22),
        Text(
          section.title!,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: palette.brown,
            fontSize: 46,
            height: 1.08,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _sectionBody(PromotionSection section, _LandingPalette palette) {
    if (section.text?.trim().isNotEmpty != true) return const SizedBox.shrink();
    return Text(
      section.text!,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: palette.ink.withValues(alpha: 0.72),
        fontWeight: FontWeight.w400,
        fontSize: 17,
        height: 1.8,
      ),
    );
  }

  Widget _sectionImage(PromotionSection section, _LandingPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.line,
              boxShadow: [
                BoxShadow(
                  color: palette.brown.withValues(alpha: 0.12),
                  blurRadius: 42,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Image.network(
              section.imageUrl!,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder:
                  (_, __, ___) => Icon(
                    Icons.image_not_supported_outlined,
                    color: palette.brown,
                  ),
            ),
          ),
        ),
        if (section.caption?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            section.caption!,
            style: TextStyle(
              color: palette.ink.withValues(alpha: 0.55),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _quoteSection(PromotionSection section, _LandingPalette palette) {
    return Container(
      width: double.infinity,
      color: palette.terracotta,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Text(
                '“',
                style: GoogleFonts.playfairDisplay(
                  color: palette.gold,
                  fontSize: 78,
                  height: 0.7,
                ),
              ),
              if (section.title?.trim().isNotEmpty == true)
                Text(
                  section.title!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 44,
                    height: 1.18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (section.text?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 24),
                Text(
                  section.text!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.75,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _offer(PublicPromotionLanding promotion, _LandingPalette palette) {
    final price = promotion.webLanding.offerPrice;
    final original = promotion.webLanding.originalPrice;
    if ((price == null || price.isEmpty) && promotion.discountPercentage <= 0) {
      return const SizedBox.shrink();
    }
    final displayPrice =
        price?.trim().isNotEmpty == true
            ? price!
            : '-${promotion.discountPercentage.round()}%';
    return Container(
      width: double.infinity,
      color: palette.brown,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 105),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                'OFFERTA',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 128,
                  foreground:
                      Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 1
                        ..color = Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              children: [
                _Eyebrow(
                  text: 'LA TUA OCCASIONE',
                  color: palette.gold,
                  light: true,
                ),
                const SizedBox(height: 24),
                Text(
                  promotion.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 48,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 26),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.center,
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    if (original?.trim().isNotEmpty == true)
                      Text(
                        original!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 24,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.white60,
                        ),
                      ),
                    Text(
                      displayPrice,
                      style: GoogleFonts.playfairDisplay(
                        color: palette.gold,
                        fontSize: 72,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                OutlinedButton(
                  onPressed: _scrollToBooking,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: palette.gold),
                    shape: const RoundedRectangleBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 19,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 2.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(promotion.webLanding.submitLabel.toUpperCase()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingSection(
    PublicPromotionLanding promotion,
    _LandingPalette palette,
  ) {
    return Container(
      color: palette.cream,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 112),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              if (compact) {
                return Column(
                  children: [
                    _bookingCopy(promotion, palette, compact: true),
                    const SizedBox(height: 46),
                    _leadForm(promotion, palette),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 94, top: 34),
                      child: _bookingCopy(promotion, palette, compact: false),
                    ),
                  ),
                  Expanded(child: _leadForm(promotion, palette)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bookingCopy(
    PublicPromotionLanding promotion,
    _LandingPalette palette, {
    required bool compact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow(text: promotion.webLanding.eyebrow, color: palette.terracotta),
        const SizedBox(height: 25),
        Text(
          promotion.webLanding.formTitle,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: palette.brown,
            fontSize: compact ? 48 : 64,
            height: 1.05,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          promotion.webLanding.formDescription,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: palette.ink.withValues(alpha: 0.65),
            fontWeight: FontWeight.w400,
            height: 1.75,
          ),
        ),
        if (promotion.salonPhone.isNotEmpty ||
            promotion.salonEmail.isNotEmpty) ...[
          const SizedBox(height: 36),
          Container(width: 42, height: 1, color: palette.terracotta),
          const SizedBox(height: 24),
          if (promotion.salonPhone.isNotEmpty)
            _ContactLine(
              icon: Icons.phone_outlined,
              text: promotion.salonPhone,
              color: palette.brown,
            ),
          if (promotion.salonEmail.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ContactLine(
              icon: Icons.email_outlined,
              text: promotion.salonEmail,
              color: palette.brown,
            ),
          ],
        ],
      ],
    );
  }

  Widget _leadForm(PublicPromotionLanding promotion, _LandingPalette palette) {
    final templateId = PromotionLandingTemplates.normalize(
      promotion.webLanding.templateId,
    );
    final editorial = templateId == PromotionLandingTemplates.editorialBeauty;
    final formRadius = BorderRadius.zero;
    final formBorder =
        editorial
            ? Border(top: BorderSide(color: palette.gold, width: 3))
            : const Border();
    final formShadows =
        editorial
            ? <BoxShadow>[
              BoxShadow(
                color: palette.brown.withValues(alpha: 0.09),
                blurRadius: 42,
                offset: const Offset(0, 20),
              ),
            ]
            : const <BoxShadow>[];
    final buttonBackground =
        templateId == PromotionLandingTemplates.studioPop
            ? palette.terracotta
            : palette.brown;
    final buttonForeground =
        templateId == PromotionLandingTemplates.studioPop
            ? palette.onTerracotta
            : palette.onBrown;
    final buttonShape = switch (templateId) {
      PromotionLandingTemplates.minimalGlow => const StadiumBorder(),
      PromotionLandingTemplates.studioPop => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: palette.ink, width: 2),
      ),
      PromotionLandingTemplates.botanicalRitual => const StadiumBorder(),
      _ => const RoundedRectangleBorder(),
    };
    final optionRadius = switch (templateId) {
      PromotionLandingTemplates.minimalGlow => 14.0,
      PromotionLandingTemplates.studioPop => 8.0,
      PromotionLandingTemplates.botanicalRitual => 18.0,
      _ => 2.0,
    };
    if (_submitted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 72),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: formRadius,
          border: formBorder,
          boxShadow: formShadows,
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 58,
              color: palette.terracotta,
            ),
            const SizedBox(height: 20),
            Text(
              'Richiesta inviata',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: palette.brown),
            ),
            const SizedBox(height: 12),
            Text(
              'Grazie. Il salone ti ricontatterà al più presto.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.ink.withValues(alpha: 0.62)),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 560 ? 24 : 48,
        vertical: MediaQuery.sizeOf(context).width < 560 ? 34 : 48,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: formRadius,
        border: formBorder,
        boxShadow: formShadows,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LandingTextField(
              controller: _fullName,
              label: 'NOME E COGNOME',
              palette: palette,
              validator:
                  (value) =>
                      value?.trim().isEmpty == true
                          ? 'Campo obbligatorio'
                          : null,
            ),
            const SizedBox(height: 28),
            _LandingTextField(
              controller: _phone,
              label: 'NUMERO DI TELEFONO',
              palette: palette,
              keyboardType: TextInputType.phone,
              validator:
                  (value) =>
                      value?.trim().isEmpty == true
                          ? 'Campo obbligatorio'
                          : null,
            ),
            const SizedBox(height: 28),
            _LandingTextField(
              controller: _email,
              label: 'EMAIL (FACOLTATIVA)',
              palette: palette,
              keyboardType: TextInputType.emailAddress,
            ),
            if (promotion.webLanding.interestOptions.isNotEmpty) ...[
              const SizedBox(height: 36),
              Text(
                'SONO INTERESSATA/O A:',
                style: TextStyle(
                  color: palette.ink.withValues(alpha: 0.52),
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 13),
              for (final option in promotion.webLanding.interestOptions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => setState(() => _interest = option),
                    borderRadius: BorderRadius.circular(optionRadius),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _interest == option
                                ? palette.terracotta.withValues(alpha: 0.09)
                                : Colors.transparent,
                        border: Border.all(
                          color:
                              _interest == option
                                  ? palette.terracotta
                                  : palette.line,
                          width: _interest == option ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(optionRadius),
                      ),
                      child: Row(
                        children: [
                          _LandingRadioIndicator(
                            selected: _interest == option,
                            color: palette.terracotta,
                            inactiveColor: palette.ink.withValues(alpha: 0.62),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: palette.ink.withValues(alpha: 0.82),
                                fontSize: 15,
                                fontWeight:
                                    _interest == option
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            Offstage(offstage: true, child: TextField(controller: _website)),
            const SizedBox(height: 28),
            InkWell(
              onTap: () => setState(() => _privacyAccepted = !_privacyAccepted),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _privacyAccepted,
                      onChanged:
                          (value) =>
                              setState(() => _privacyAccepted = value ?? false),
                      activeColor: palette.brown,
                      side: BorderSide(
                        color: palette.ink.withValues(alpha: 0.65),
                      ),
                      shape: const RoundedRectangleBorder(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Acconsento al trattamento dei dati personali per essere ricontattata/o. *',
                          style: TextStyle(
                            color: palette.ink.withValues(alpha: 0.74),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        if (promotion.privacyPolicyUrl?.isNotEmpty == true)
                          TextButton(
                            onPressed:
                                () => launchUrl(
                                  Uri.parse(promotion.privacyPolicyUrl!),
                                  mode: LaunchMode.platformDefault,
                                ),
                            style: TextButton.styleFrom(
                              foregroundColor: palette.terracotta,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text('Leggi'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 18),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _submitting ? null : () => _submit(promotion),
                icon:
                    _submitting
                        ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: buttonForeground,
                          ),
                        )
                        : const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  _submitting
                      ? 'INVIO IN CORSO…'
                      : promotion.webLanding.submitLabel.toUpperCase(),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: buttonBackground,
                  foregroundColor: buttonForeground,
                  disabledBackgroundColor: buttonBackground.withValues(
                    alpha: 0.55,
                  ),
                  shape: buttonShape,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(PublicPromotionLanding promotion, _LandingPalette palette) {
    return Container(
      color: palette.ink,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 36,
                runSpacing: 20,
                children: [
                  Text(
                    promotion.salonName.toUpperCase(),
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 19,
                      letterSpacing: 3,
                    ),
                  ),
                  Wrap(
                    spacing: 28,
                    runSpacing: 10,
                    children: [
                      if (promotion.salonPhone.isNotEmpty)
                        Text(
                          promotion.salonPhone,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      if (promotion.salonEmail.isNotEmpty)
                        Text(
                          promotion.salonEmail,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      if (promotion.salonCity.isNotEmpty)
                        Text(
                          promotion.salonCity,
                          style: const TextStyle(color: Colors.white70),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Divider(color: Colors.white.withValues(alpha: 0.12)),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '© ${DateTime.now().year} ${promotion.salonName}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.46),
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingTextField extends StatelessWidget {
  const _LandingTextField({
    required this.controller,
    required this.label,
    required this.palette,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final _LandingPalette palette;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.ink.withValues(alpha: 0.48),
            fontSize: 9,
            letterSpacing: 1.7,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(color: palette.ink, fontSize: 16),
          cursorColor: palette.terracotta,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            filled: false,
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: palette.line),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: palette.line),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: palette.terracotta, width: 1.5),
            ),
            errorBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LandingRadioIndicator extends StatelessWidget {
  const _LandingRadioIndicator({
    required this.selected,
    required this.color,
    required this.inactiveColor,
  });

  final bool selected;
  final Color color;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 19,
      height: 19,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? color : inactiveColor,
          width: selected ? 2 : 1.5,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color : Colors.transparent,
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text, required this.color, this.light = false});

  final String text;
  final Color color;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 32, height: 1, color: color),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 2,
            style: TextStyle(
              color: light ? Colors.white.withValues(alpha: 0.82) : color,
              fontSize: 10,
              letterSpacing: 3.2,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroHalo extends StatelessWidget {
  const _HeroHalo({required this.color, required this.compact});

  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 380.0 : 600.0;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(compact ? 42 : 68),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.23)),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.16)),
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.14),
              color.withValues(alpha: 0.01),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(color: color))),
      ],
    );
  }
}

class _LandingPalette {
  const _LandingPalette({
    required this.cream,
    required this.paper,
    required this.ink,
    required this.brown,
    required this.terracotta,
    required this.gold,
    required this.onBrown,
    required this.onTerracotta,
    required this.line,
  });

  final Color cream;
  final Color paper;
  final Color ink;
  final Color brown;
  final Color terracotta;
  final Color gold;
  final Color onBrown;
  final Color onTerracotta;
  final Color line;

  factory _LandingPalette.fromTemplate(PromotionLandingPalette palette) {
    return _LandingPalette(
      cream: palette.cream,
      paper: palette.paper,
      ink: palette.ink,
      brown: palette.brown,
      terracotta: palette.terracotta,
      gold: palette.gold,
      onBrown: palette.onPrimary,
      onTerracotta: palette.onSecondary,
      line: palette.line,
    );
  }
}

class _LandingMessage extends StatelessWidget {
  const _LandingMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
