import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:flutter/material.dart';
import 'package:you_book/presentation/common/app_notice.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class PackageFormSheet extends StatefulWidget {
  const PackageFormSheet({
    super.key,
    required this.salons,
    required this.services,
    this.initial,
    this.defaultSalonId,
    this.defaultShowOnClientDashboard,
  });

  final List<Salon> salons;
  final List<Service> services;
  final ServicePackage? initial;
  final String? defaultSalonId;
  final bool? defaultShowOnClientDashboard;

  @override
  State<PackageFormSheet> createState() => _PackageFormSheetState();
}

class _PackageFormSheetState extends State<PackageFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _name;
  late TextEditingController _description;
  late TextEditingController _price;
  late TextEditingController _discountPercentage;
  late TextEditingController _sessionCount;
  late TextEditingController _validDays;
  late TextEditingController _serviceSearch;
  String? _salonId;
  final Set<String> _selectedServices = {};
  final Map<String, TextEditingController> _serviceControllers = {};
  final Map<String, FocusNode> _serviceFocusNodes = {};
  final Map<String, int> _serviceSessions = {};
  bool _isUpdatingSessionCount = false;
  bool _sessionCountEdited = false;
  double _fullPrice = 0;
  bool _finalPriceEdited = false;
  bool _isUpdatingFinalPrice = false;
  bool _isUpdatingDiscount = false;
  late bool _showOnClientDashboard;
  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency(
    locale: 'it_IT',
  );

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _price = TextEditingController(
      text: initial != null ? initial.price.toStringAsFixed(2) : '',
    );
    _discountPercentage = TextEditingController(
      text:
          initial?.discountPercentage != null
              ? initial!.discountPercentage!.toStringAsFixed(2)
              : '',
    );
    final initialSessions =
        initial?.totalConfiguredSessions ?? initial?.sessionCount;
    _sessionCount = TextEditingController(
      text: initialSessions?.toString() ?? '',
    );
    _validDays = TextEditingController(
      text: initial?.validDays?.toString() ?? '',
    );
    _fullPrice = initial?.fullPrice ?? initial?.price ?? 0;
    _finalPriceEdited = initial != null && initial.discountPercentage == null;
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _showOnClientDashboard =
        initial?.showOnClientDashboard ??
        widget.defaultShowOnClientDashboard ??
        true;
    _selectedServices.addAll(initial?.serviceIds ?? []);
    if (initial?.serviceSessionCounts.isNotEmpty ?? false) {
      _serviceSessions.addAll(initial!.serviceSessionCounts);
      _selectedServices.addAll(initial.serviceSessionCounts.keys);
    }
    _sessionCount.addListener(_handleSessionCountChanged);
    _price.addListener(_handlePriceChanged);
    _discountPercentage.addListener(_handleDiscountChanged);
    _serviceSearch =
        TextEditingController()..addListener(() {
          if (!mounted) return;
          setState(() {});
        });
    _syncSalonDependencies();
    _recalculateFullPrice(notify: false);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.removeListener(_handlePriceChanged);
    _price.dispose();
    _discountPercentage.removeListener(_handleDiscountChanged);
    _discountPercentage.dispose();
    _sessionCount.removeListener(_handleSessionCountChanged);
    _sessionCount.dispose();
    _validDays.dispose();
    _serviceSearch.dispose();
    for (final controller in _serviceControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _serviceFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final salonServices =
        widget.services.where((service) => service.salonId == _salonId).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final selectedSalon = _selectedSalon;
    final totalSessions = _currentSessionTotal();
    final discountValue = _currentDiscount();
    final finalPriceValue = _currentFinalPrice();
    final savings = _fullPrice > 0 ? _fullPrice - finalPriceValue : 0;

    return DialogActionLayout(
      title: widget.initial == null ? 'Nuovo pacchetto' : 'Modifica pacchetto',
      subtitle:
          'Configura contenuti, pricing e visibilita con il layout a due colonne del nuovo editor.',
      bodyPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      footerPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth.clamp(0.0, 1120.0);
            final isWide = contentWidth >= 920;
            final leftColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPanel(
                  theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dettagli del pacchetto',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Definisci identita, validita e visibilita commerciale del pacchetto.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (widget.salons.length > 1) ...[
                        _buildFieldGroup(
                          theme,
                          label: 'SALONE',
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _salonId,
                            decoration: _fieldDecoration(theme),
                            items:
                                widget.salons
                                    .map(
                                      (salon) => DropdownMenuItem<String>(
                                        value: salon.id,
                                        child: Text(salon.name),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) => _handleSalonChanged(value),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else if (selectedSalon != null) ...[
                        _buildFieldGroup(
                          theme,
                          label: 'SALONE',
                          child: _buildMetricTile(
                            theme,
                            label: 'Salon attivo',
                            value: selectedSalon.name,
                            icon: Icons.storefront_rounded,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildFieldGroup(
                        theme,
                        label: 'NOME PACCHETTO *',
                        child: TextFormField(
                          controller: _name,
                          decoration: _fieldDecoration(
                            theme,
                            hintText: 'Inserisci il nome del pacchetto',
                          ),
                          validator:
                              (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Inserisci il nome del pacchetto'
                                      : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFieldGroup(
                        theme,
                        label: 'DESCRIZIONE',
                        child: TextFormField(
                          controller: _description,
                          decoration: _fieldDecoration(
                            theme,
                            hintText:
                                'Descrivi obiettivo, inclusioni o limitazioni',
                          ),
                          minLines: 3,
                          maxLines: 5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, innerConstraints) {
                          final useColumns = innerConstraints.maxWidth >= 430;
                          final sessionField = _buildFieldGroup(
                            theme,
                            label: 'SESSIONI TOTALI',
                            helper:
                                'Se lasci il conteggio automatico, il totale viene ricavato dai servizi selezionati.',
                            child: TextFormField(
                              controller: _sessionCount,
                              decoration: _fieldDecoration(
                                theme,
                                hintText: '0',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          );
                          final validityField = _buildFieldGroup(
                            theme,
                            label: 'VALIDITA',
                            helper: 'Numero di giorni prima della scadenza.',
                            child: TextFormField(
                              controller: _validDays,
                              decoration: _fieldDecoration(
                                theme,
                                hintText: 'Es. 90',
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Icon(
                                    Icons.event_available_rounded,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          );
                          if (!useColumns) {
                            return Column(
                              children: [
                                sessionField,
                                const SizedBox(height: 16),
                                validityField,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: sessionField),
                              const SizedBox(width: 16),
                              Expanded(child: validityField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildVisibilityPanel(theme),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildPanel(
                  theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pricing',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Il prezzo pieno viene calcolato dai servizi inclusi; puoi poi rifinire sconto e prezzo finale.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildMetricTile(
                            theme,
                            label: 'Prezzo pieno',
                            value: _currencyFormat.format(_fullPrice),
                            icon: Icons.price_change_rounded,
                          ),
                          _buildMetricTile(
                            theme,
                            label: 'Prezzo finale',
                            value: _currencyFormat.format(finalPriceValue),
                            icon: Icons.local_offer_rounded,
                          ),
                          _buildMetricTile(
                            theme,
                            label: 'Risparmio',
                            value: _currencyFormat.format(
                              savings > 0 ? savings : 0,
                            ),
                            icon: Icons.savings_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, innerConstraints) {
                          final useColumns = innerConstraints.maxWidth >= 430;
                          final discountField = _buildFieldGroup(
                            theme,
                            label: 'SCONTO (%)',
                            helper:
                                'Aggiorna automaticamente il prezzo finale.',
                            child: TextFormField(
                              controller: _discountPercentage,
                              decoration: _fieldDecoration(
                                theme,
                                hintText: '0',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          );
                          final priceField = _buildFieldGroup(
                            theme,
                            label: 'PREZZO FINALE (€)',
                            helper:
                                'Puoi impostarlo manualmente: lo sconto si ricalcola.',
                            child: TextFormField(
                              controller: _price,
                              decoration: _fieldDecoration(
                                theme,
                                hintText: '0.00',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          );
                          if (!useColumns) {
                            return Column(
                              children: [
                                discountField,
                                const SizedBox(height: 16),
                                priceField,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: discountField),
                              const SizedBox(width: 16),
                              Expanded(child: priceField),
                            ],
                          );
                        },
                      ),
                      if (discountValue != null &&
                          discountValue > 0 &&
                          savings > 0) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.22,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Risparmio ${_currencyFormat.format(savings)} con sconto ${discountValue.toStringAsFixed(2)}%.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
            final rightColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryPanel(
                  theme,
                  salonName: selectedSalon?.name,
                  totalSessions: totalSessions,
                  finalPriceValue: finalPriceValue,
                  discountValue: discountValue,
                  selectedServices: _selectedServices.length,
                ),
                const SizedBox(height: 18),
                _buildPanel(
                  theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              totalSessions > 0
                                  ? 'Servizi inclusi ($totalSessions sessioni)'
                                  : 'Servizi inclusi',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${_selectedServices.length} selezionati',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Seleziona i servizi e assegna il numero di sessioni per ciascuno.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ..._buildServiceInputs(context, salonServices),
                    ],
                  ),
                ),
              ],
            );
            if (!isWide) {
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leftColumn,
                      const SizedBox(height: 18),
                      rightColumn,
                    ],
                  ),
                ),
              );
            }

            final leftWidth = (contentWidth * 0.46).clamp(390.0, 520.0);
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: leftWidth.toDouble(), child: leftColumn),
                    const SizedBox(width: 18),
                    Expanded(child: rightColumn),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(136, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Salva'),
        ),
      ],
    );
  }

  Salon? get _selectedSalon {
    final salonId = _salonId;
    if (salonId == null) {
      return null;
    }
    for (final salon in widget.salons) {
      if (salon.id == salonId) {
        return salon;
      }
    }
    return null;
  }

  InputDecoration _fieldDecoration(
    ThemeData theme, {
    String? hintText,
    String? helperText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final scheme = theme.colorScheme;
    return InputDecoration(
      hintText: hintText,
      helperText: helperText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor:
          theme.brightness == Brightness.dark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.96),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 1.4),
      ),
    );
  }

  Widget _buildFieldGroup(
    ThemeData theme, {
    required String label,
    required Widget child,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        child,
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPanel(
    ThemeData theme, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            theme.brightness == Brightness.dark
                ? scheme.surface.withValues(alpha: 0.98)
                : const Color(0xFFF8F8F6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _buildMetricTile(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color:
            theme.brightness == Brightness.dark
                ? scheme.surfaceContainerHighest.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.64),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityPanel(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color:
            _showOnClientDashboard
                ? scheme.tertiaryContainer.withValues(alpha: 0.48)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              _showOnClientDashboard
                  ? scheme.tertiary.withValues(alpha: 0.32)
                  : scheme.outlineVariant,
        ),
      ),
      child: SwitchListTile.adaptive(
        value: _showOnClientDashboard,
        onChanged: (value) {
          setState(() {
            _showOnClientDashboard = value;
          });
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text('Mostra nel dashboard cliente'),
        subtitle: const Text(
          'Quando disattivato il pacchetto resta disponibile solo per preventivi e vendite interne.',
        ),
      ),
    );
  }

  Widget _buildSummaryPanel(
    ThemeData theme, {
    required String? salonName,
    required int totalSessions,
    required double finalPriceValue,
    required double? discountValue,
    required int selectedServices,
  }) {
    final scheme = theme.colorScheme;
    return _buildPanel(
      theme,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Snapshot commerciale',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Riepilogo immediato dei dati che finiranno nel catalogo interno e nel dashboard cliente.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricTile(
                theme,
                label: 'Servizi',
                value: '$selectedServices',
                icon: Icons.spa_rounded,
              ),
              _buildMetricTile(
                theme,
                label: 'Sessioni',
                value: '$totalSessions',
                icon: Icons.repeat_rounded,
              ),
              _buildMetricTile(
                theme,
                label: 'Prezzo',
                value: _currencyFormat.format(finalPriceValue),
                icon: Icons.payments_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.86),
                  scheme.secondaryContainer.withValues(alpha: 0.72),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name.text.trim().isEmpty
                      ? 'Nome pacchetto'
                      : _name.text.trim(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  salonName ?? 'Salone non selezionato',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSummaryChip(
                      theme,
                      label:
                          discountValue != null && discountValue > 0
                              ? 'Sconto ${discountValue.toStringAsFixed(2)}%'
                              : 'Prezzo pieno',
                    ),
                    _buildSummaryChip(
                      theme,
                      label:
                          _showOnClientDashboard
                              ? 'Visibile ai clienti'
                              : 'Solo uso interno',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(ThemeData theme, {required String label}) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _handleSalonChanged(String? value) {
    if (value == null || value == _salonId) {
      return;
    }
    setState(() {
      _salonId = value;
      _serviceSearch.clear();
      _syncSalonDependencies();
    });
    _recalculateFullPrice();
  }

  void _syncSalonDependencies() {
    final salonId = _salonId;
    final allowedIds =
        salonId == null
            ? <String>{}
            : widget.services
                .where((service) => service.salonId == salonId)
                .map((service) => service.id)
                .toSet();
    _selectedServices.removeWhere((id) => !allowedIds.contains(id));
    _serviceSessions.removeWhere((id, _) => !allowedIds.contains(id));
    for (final entry in _serviceControllers.entries) {
      if (!allowedIds.contains(entry.key)) {
        entry.value.clear();
      }
    }
    _recalculateSessionCountFromServices();
  }

  List<Widget> _buildServiceInputs(
    BuildContext context,
    List<Service> services,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_salonId == null) {
      return [
        Text(
          'Nessun salone associato. Impossibile mostrare i servizi disponibili.',
          style: theme.textTheme.bodyMedium,
        ),
      ];
    }
    if (services.isEmpty) {
      return [
        Text(
          'Nessun servizio associato al salone selezionato.',
          style: theme.textTheme.bodyMedium,
        ),
      ];
    }

    final query = _serviceSearch.text.trim().toLowerCase();
    final filtered =
        query.isEmpty
              ? services
              : services.where((service) {
                final name = service.name.toLowerCase();
                final desc = (service.description ?? '').toLowerCase();
                final cat = (service.category).toLowerCase();
                return name.contains(query) ||
                    desc.contains(query) ||
                    cat.contains(query);
              }).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final Map<String, List<Service>> byCategory = {};
    for (final service in filtered) {
      final label =
          service.category.trim().isEmpty ? 'Altro' : service.category.trim();
      byCategory.putIfAbsent(label, () => <Service>[]).add(service);
    }
    final sortedCategoryLabels =
        byCategory.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final widgets = <Widget>[];
    widgets.add(
      TextField(
        controller: _serviceSearch,
        decoration: _fieldDecoration(
          theme,
          hintText: 'Cerca servizi...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon:
              _serviceSearch.text.isEmpty
                  ? null
                  : IconButton(
                    tooltip: 'Pulisci',
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _serviceSearch.clear();
                    },
                  ),
        ),
        textInputAction: TextInputAction.search,
      ),
    );
    widgets.add(const SizedBox(height: 12));

    if (sortedCategoryLabels.isEmpty) {
      widgets.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Nessun servizio corrisponde alla ricerca.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
      return widgets;
    }

    for (final label in sortedCategoryLabels) {
      final items = byCategory[label]!;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${items.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      for (final service in items) {
        final selected = _selectedServices.contains(service.id);
        final controller = _controllerForService(service.id);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color:
                    selected
                        ? scheme.primaryContainer.withValues(alpha: 0.36)
                        : (theme.brightness == Brightness.dark
                            ? scheme.surfaceContainerHighest.withValues(
                              alpha: 0.14,
                            )
                            : Colors.white.withValues(alpha: 0.82)),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color:
                      selected
                          ? scheme.primary.withValues(alpha: 0.28)
                          : scheme.outlineVariant,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: selected,
                    onChanged:
                        (value) => _toggleService(service, value ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                service.name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _currencyFormat.format(service.price),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (service.description != null &&
                            service.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              service.description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 124,
                    child: TextFormField(
                      focusNode: _focusNodeForService(service.id),
                      controller: controller,
                      enabled: selected,
                      decoration: _fieldDecoration(
                        theme,
                        hintText: '0',
                        helperText: selected ? 'Sessioni' : null,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (!selected) {
                          return null;
                        }
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Obbligatorio';
                        }
                        final numeric = int.tryParse(trimmed);
                        if (numeric == null || numeric <= 0) {
                          return 'Valore non valido';
                        }
                        return null;
                      },
                      onChanged:
                          (value) =>
                              _onServiceSessionsChanged(service.id, value),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  TextEditingController _controllerForService(String serviceId) {
    return _serviceControllers.putIfAbsent(
      serviceId,
      () => TextEditingController(
        text: _serviceSessions[serviceId]?.toString() ?? '',
      ),
    );
  }

  FocusNode _focusNodeForService(String serviceId) {
    return _serviceFocusNodes.putIfAbsent(serviceId, () => FocusNode());
  }

  void _toggleService(Service service, bool isSelected) {
    final focusNode = _focusNodeForService(service.id);
    setState(() {
      if (isSelected) {
        _selectedServices.add(service.id);
        final current = _serviceSessions[service.id];
        final controller = _controllerForService(service.id);
        if (current != null && current > 0) {
          controller.text = current.toString();
        } else {
          controller.text = '1';
          _serviceSessions[service.id] = 1;
        }
      } else {
        _selectedServices.remove(service.id);
        _serviceSessions.remove(service.id);
        _serviceControllers[service.id]?.clear();
        focusNode.unfocus();
      }
    });
    if (isSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(focusNode);
      });
    }
    _recalculateSessionCountFromServices();
    _recalculateFullPrice();
  }

  void _onServiceSessionsChanged(String serviceId, String value) {
    if (!_selectedServices.contains(serviceId)) {
      return;
    }
    final numeric = int.tryParse(value.trim());
    setState(() {
      if (numeric == null || numeric <= 0) {
        _serviceSessions.remove(serviceId);
      } else {
        _serviceSessions[serviceId] = numeric;
      }
    });
    _recalculateSessionCountFromServices();
    _recalculateFullPrice();
  }

  void _handleSessionCountChanged() {
    if (_isUpdatingSessionCount) {
      return;
    }
    _sessionCountEdited = _sessionCount.text.trim().isNotEmpty;
  }

  void _handlePriceChanged() {
    if (_isUpdatingFinalPrice) {
      return;
    }
    _finalPriceEdited = true;
    _updateDiscountFromFinalPrice();
    setState(() {});
  }

  void _handleDiscountChanged() {
    if (_isUpdatingDiscount) {
      return;
    }
    final discount = _parseDouble(_discountPercentage.text);
    if (discount == null || discount < 0) {
      _finalPriceEdited = false;
      _isUpdatingDiscount = true;
      if (_discountPercentage.text.isNotEmpty) {
        _discountPercentage.clear();
      }
      _isUpdatingDiscount = false;
      _applyDiscountToPrice();
      setState(() {});
      return;
    }

    final normalized = discount.clamp(0, 100).toDouble();
    if ((normalized - discount).abs() > 0.001) {
      _isUpdatingDiscount = true;
      _discountPercentage.text = normalized.toStringAsFixed(2);
      _discountPercentage.selection = TextSelection.fromPosition(
        TextPosition(offset: _discountPercentage.text.length),
      );
      _isUpdatingDiscount = false;
    }

    _finalPriceEdited = false;
    _applyDiscountToPrice();
    setState(() {});
  }

  void _recalculateSessionCountFromServices() {
    if (_sessionCountEdited) {
      return;
    }
    if (_serviceSessions.isEmpty && _selectedServices.isNotEmpty) {
      return;
    }
    final total = _serviceSessions.entries
        .where((entry) => _selectedServices.contains(entry.key))
        .fold<int>(0, (sum, entry) => sum + entry.value);
    _isUpdatingSessionCount = true;
    if (total > 0) {
      _sessionCount.text = total.toString();
    } else if (_serviceSessions.isEmpty) {
      _sessionCount.clear();
    }
    _isUpdatingSessionCount = false;
  }

  void _recalculateFullPrice({bool notify = true}) {
    if (_serviceSessions.isEmpty && _selectedServices.isNotEmpty) {
      if (!notify) {
        _syncPricingWithFullPrice();
      } else {
        setState(_syncPricingWithFullPrice);
      }
      return;
    }
    final total = _calculateFullPriceValue();
    if (!notify) {
      _fullPrice = total;
      _syncPricingWithFullPrice();
      return;
    }
    setState(() {
      _fullPrice = total;
      _syncPricingWithFullPrice();
    });
  }

  void _syncPricingWithFullPrice() {
    if (_finalPriceEdited) {
      _updateDiscountFromFinalPrice();
    } else {
      _applyDiscountToPrice();
    }
  }

  double _calculateFullPriceValue() {
    var total = 0.0;
    for (final serviceId in _selectedServices) {
      final sessions = _serviceSessions[serviceId] ?? 1;
      if (sessions <= 0) {
        continue;
      }
      final service = _findServiceById(serviceId);
      if (service == null) {
        continue;
      }
      total += service.price * sessions;
    }
    return total;
  }

  void _applyDiscountToPrice() {
    final discount = _parseDouble(_discountPercentage.text);
    double? finalPrice;

    if (_fullPrice <= 0) {
      if (discount == null || discount <= 0) {
        finalPrice = null;
      } else {
        finalPrice = 0;
      }
    } else if (discount == null || discount <= 0) {
      finalPrice = _fullPrice;
    } else {
      final normalized = discount.clamp(0, 100).toDouble();
      finalPrice = _fullPrice * (1 - normalized / 100);
      if (finalPrice < 0) {
        finalPrice = 0;
      }
    }

    _isUpdatingFinalPrice = true;
    if (finalPrice == null) {
      _price.clear();
    } else {
      _price.text = finalPrice.toStringAsFixed(2);
    }
    _price.selection = TextSelection.fromPosition(
      TextPosition(offset: _price.text.length),
    );
    _isUpdatingFinalPrice = false;
  }

  void _updateDiscountFromFinalPrice() {
    final finalPrice = _parseDouble(_price.text);
    double? discount;

    if (_fullPrice <= 0 || finalPrice == null || finalPrice <= 0) {
      discount = null;
    } else if (finalPrice >= _fullPrice) {
      discount = null;
    } else {
      discount = ((_fullPrice - finalPrice) / _fullPrice) * 100;
    }

    _isUpdatingDiscount = true;
    if (discount == null || discount <= 0) {
      _discountPercentage.clear();
    } else {
      _discountPercentage.text = discount.toStringAsFixed(2);
    }
    _discountPercentage.selection = TextSelection.fromPosition(
      TextPosition(offset: _discountPercentage.text.length),
    );
    _isUpdatingDiscount = false;
  }

  double? _parseDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final normalized = trimmed.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  double _currentFinalPrice() {
    return _parseDouble(_price.text) ?? 0;
  }

  double? _currentDiscount() {
    final discount = _parseDouble(_discountPercentage.text);
    if (discount == null) {
      return null;
    }
    if (discount <= 0) {
      return null;
    }
    return discount.clamp(0, 100).toDouble();
  }

  int _currentSessionTotal() {
    final manual = int.tryParse(_sessionCount.text.trim());
    if (manual != null && manual > 0) {
      return manual;
    }
    return _serviceSessions.entries
        .where((entry) => _selectedServices.contains(entry.key))
        .fold<int>(0, (sum, entry) => sum + entry.value);
  }

  Service? _findServiceById(String serviceId) {
    for (final service in widget.services) {
      if (service.id == serviceId) {
        return service;
      }
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_salonId == null) {
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(const SnackBar(content: Text('Seleziona un salone')));
      return;
    }

    final selectedServiceIds = _selectedServices.toList();
    final serviceSessions = <String, int>{};
    for (final serviceId in selectedServiceIds) {
      final text = _serviceControllers[serviceId]?.text.trim() ?? '';
      final sessions = int.tryParse(text);
      if (sessions != null && sessions > 0) {
        serviceSessions[serviceId] = sessions;
      }
    }

    final totalFromServices =
        serviceSessions.isEmpty
            ? null
            : serviceSessions.values.fold<int>(0, (sum, value) => sum + value);
    final manualSessionsText = _sessionCount.text.trim();
    final parsedSessionCount =
        manualSessionsText.isEmpty ? null : int.tryParse(manualSessionsText);
    final resolvedFinalPrice = _parseDouble(_price.text) ?? 0;
    final resolvedDiscount = _parseDouble(_discountPercentage.text);
    final discountPercentage =
        (resolvedDiscount == null || resolvedDiscount <= 0 || _fullPrice <= 0)
            ? null
            : resolvedDiscount.clamp(0, 100).toDouble();

    final pkg = ServicePackage(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      name: _name.text.trim(),
      price: resolvedFinalPrice,
      fullPrice: _fullPrice,
      discountPercentage: discountPercentage,
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      serviceIds: selectedServiceIds,
      sessionCount: totalFromServices ?? parsedSessionCount,
      validDays:
          _validDays.text.trim().isEmpty
              ? null
              : int.tryParse(_validDays.text.trim()),
      serviceSessionCounts: serviceSessions,
      showOnClientDashboard: _showOnClientDashboard,
      isGeneratedFromServiceBuilder:
          widget.initial?.isGeneratedFromServiceBuilder ?? false,
    );

    Navigator.of(context).pop(pkg);
  }
}
