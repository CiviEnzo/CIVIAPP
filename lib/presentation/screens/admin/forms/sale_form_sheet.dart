import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/loyalty/loyalty_calculator.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/client_search_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/client_search_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/package_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/modules/client_detail_page.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

@visibleForTesting
const saleFormLoyaltyRedeemFieldKey = Key('saleForm.loyaltyRedeemField');

enum _AdditionalSaleItemAction { manualItem, customPackage }

enum _ClientSearchMode { general, number }

Color _blendSaleSurface(Color surface, Color tint, double alpha) {
  return Color.alphaBlend(tint.withValues(alpha: alpha), surface);
}

class _SaleFormPalette {
  const _SaleFormPalette({
    required this.panelBg,
    required this.elevatedPanelBg,
    required this.inputBg,
    required this.denseInputBg,
    required this.reviewCardBg,
    required this.border,
    required this.success,
    required this.successBg,
    required this.danger,
  });

  factory _SaleFormPalette.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return _SaleFormPalette(
      panelBg: isDark ? scheme.surfaceContainerLow : const Color(0xFFF6F5F2),
      elevatedPanelBg:
          isDark
              ? scheme.surfaceContainer
              : Colors.white.withValues(alpha: 0.9),
      inputBg:
          isDark
              ? scheme.surfaceContainerHigh
              : Colors.white.withValues(alpha: 0.92),
      denseInputBg:
          isDark
              ? scheme.surfaceContainerHighest
              : Colors.white.withValues(alpha: 0.86),
      reviewCardBg: isDark ? scheme.surfaceContainerLow : Colors.white,
      border:
          isDark
              ? scheme.outlineVariant.withValues(alpha: 0.88)
              : scheme.outlineVariant,
      success: isDark ? scheme.tertiary : const Color(0xFF22C55E),
      successBg:
          isDark
              ? scheme.tertiaryContainer.withValues(alpha: 0.28)
              : const Color(0x1A22C55E),
      danger: scheme.error,
    );
  }

  final Color panelBg;
  final Color elevatedPanelBg;
  final Color inputBg;
  final Color denseInputBg;
  final Color reviewCardBg;
  final Color border;
  final Color success;
  final Color successBg;
  final Color danger;
}

class SaleFormSheet extends StatefulWidget {
  const SaleFormSheet({
    super.key,
    required this.salons,
    required this.clients,
    required this.staff,
    required this.services,
    required this.packages,
    required this.inventoryItems,
    required this.sales,
    this.defaultSalonId,
    this.initialClientId,
    this.initialItems,
    this.initialPaymentMethod,
    this.initialPaymentStatus,
    this.initialPaidAmount,
    this.initialDiscountAmount,
    this.initialInvoiceNumber,
    this.initialNotes,
    this.initialDate,
    this.initialStaffId,
    this.initialSaleId,
    this.lockServiceOperator = false,
    this.lockInitialServiceSessionToggle = false,
    this.showSheetHeader = true,
    this.serviceLinesCreateSessionsByDefault = false,
    this.onSaved,
    this.onSkipTicket,
  });

  final List<Salon> salons;
  final List<Client> clients;
  final List<StaffMember> staff;
  final List<Service> services;
  final List<ServicePackage> packages;
  final List<InventoryItem> inventoryItems;
  final List<Sale> sales;
  final String? defaultSalonId;
  final String? initialClientId;
  final List<SaleItem>? initialItems;
  final PaymentMethod? initialPaymentMethod;
  final SalePaymentStatus? initialPaymentStatus;
  final double? initialPaidAmount;
  final double? initialDiscountAmount;
  final String? initialInvoiceNumber;
  final String? initialNotes;
  final DateTime? initialDate;
  final String? initialStaffId;
  final String? initialSaleId;
  final bool lockServiceOperator;
  final bool lockInitialServiceSessionToggle;
  final bool showSheetHeader;
  final bool serviceLinesCreateSessionsByDefault;
  final void Function(Sale sale)? onSaved;
  final VoidCallback? onSkipTicket;

  @override
  State<SaleFormSheet> createState() => _SaleFormSheetState();
}

class _SaleFormSheetState extends State<SaleFormSheet> {
  static const _associateSalonHint =
      'Collega la vendita a un salone selezionando un cliente o un membro dello staff.';
  static const _reviewAccentColor = Color(0xFFD4AF37);
  final _formKey = GlobalKey<FormState>();
  final _clientFieldKey = GlobalKey<FormFieldState<String>>();
  final _uuid = const Uuid();
  final List<_SaleLineDraft> _lines = [];
  final ScrollController _sheetScrollController = ScrollController();
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _clientNumberSearchController =
      TextEditingController();
  final FocusNode _clientSearchFocusNode = FocusNode();
  final FocusNode _clientNumberSearchFocusNode = FocusNode();
  _ClientSearchMode _clientSearchMode = _ClientSearchMode.general;
  List<Client> _clientSuggestions = const <Client>[];

  late final TextEditingController _invoiceController;
  late final TextEditingController _notesController;
  late final TextEditingController _manualTotalController;
  late final TextEditingController _paidAmountController;
  late final TextEditingController _loyaltyRedeemController;
  final Map<String, int> _coveredServices = {};
  final Map<String, int> _coveredLineQuantities = {};
  final Map<String, String> _lineCachedPrices = {};
  final Map<String, _ServiceCoverageDetail> _serviceCoverageDetails = {};
  PaymentMethod? _payment;
  SalePaymentStatus? _paymentStatus;
  String? _salonId;
  String? _clientId;
  String? _staffId;
  String? _recorderStaffId;
  DateTime _date = DateTime.now();
  bool _manualTotalOverridden = false;
  bool _programmaticManualUpdate = false;
  bool _isPaymentStep = false;
  bool _programmaticPaidUpdate = false;
  bool _isLoyaltyExpanded = false;

  SaleLoyaltySummary _loyaltySummary = SaleLoyaltySummary();
  int _selectedRedeemPoints = 0;
  int _maxRedeemablePoints = 0;
  double _maxRedeemableValue = 0;
  double _loyaltyEligibleAmount = 0;
  bool _updatingRedeemController = false;

  Iterable<StaffMember> get _serviceProviders => widget.staff;

  Iterable<StaffMember> get _recorderStaff =>
      widget.staff.where((member) => !member.isEquipment);

  StaffMember? get _selectedServiceProvider =>
      _staffId == null
          ? null
          : widget.staff.firstWhereOrNull((member) => member.id == _staffId);

  bool _matchesSalon(StaffMember member, {String? salonId}) {
    final targetSalonId = salonId ?? _salonId;
    if (targetSalonId == null || targetSalonId.isEmpty) {
      return true;
    }
    return member.salonId == targetSalonId;
  }

  bool _isSelectableServiceProviderId(String? staffId, {String? salonId}) {
    if (staffId == null || staffId.isEmpty) {
      return false;
    }
    return _serviceProviders.any(
      (member) =>
          member.id == staffId && _matchesSalon(member, salonId: salonId),
    );
  }

  bool _isSelectableRecorderId(String? staffId, {String? salonId}) {
    if (staffId == null || staffId.isEmpty) {
      return false;
    }
    return _recorderStaff.any(
      (member) =>
          member.id == staffId && _matchesSalon(member, salonId: salonId),
    );
  }

  String? _resolvedRecorderStaffId({String? salonId}) {
    if (_isSelectableRecorderId(_recorderStaffId, salonId: salonId)) {
      return _recorderStaffId;
    }
    if (_isSelectableRecorderId(_staffId, salonId: salonId)) {
      return _staffId;
    }
    return null;
  }

  String _staffOptionLabel(StaffMember member) {
    if (member.isEquipment) {
      return '${member.fullName} (Macchinario)';
    }
    return member.fullName;
  }

  @override
  void initState() {
    super.initState();
    _invoiceController = TextEditingController(
      text: widget.initialInvoiceNumber ?? '',
    );
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
    _manualTotalController = TextEditingController();
    _paidAmountController = TextEditingController();
    _loyaltyRedeemController = TextEditingController(text: '0');
    _payment = widget.initialPaymentMethod;
    _paymentStatus = widget.initialPaymentStatus;
    if (_paymentStatus == SalePaymentStatus.posticipated) {
      _payment = PaymentMethod.posticipated;
    }
    _date = widget.initialDate ?? DateTime.now();
    _salonId =
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _staffId = widget.initialStaffId;

    if (widget.initialClientId != null) {
      final initialClient = widget.clients.firstWhereOrNull(
        (client) => client.id == widget.initialClientId,
      );
      if (initialClient != null) {
        _clientId = initialClient.id;
        _salonId ??= initialClient.salonId;
        _clientSearchController.text = initialClient.fullName;
        _clientNumberSearchController.text = initialClient.clientNumber ?? '';
      }
    }

    if (!_isSelectableServiceProviderId(_staffId, salonId: _salonId)) {
      _staffId = null;
    }

    final existingSale =
        widget.initialSaleId != null
            ? widget.sales.firstWhereOrNull(
              (sale) => sale.id == widget.initialSaleId,
            )
            : null;
    final existingRecorderId = existingSale?.metadata['recordedByStaffId'];
    if (existingRecorderId is String && existingRecorderId.isNotEmpty) {
      _recorderStaffId =
          _isSelectableRecorderId(existingRecorderId, salonId: _salonId)
              ? existingRecorderId
              : null;
    } else {
      _recorderStaffId = null;
    }

    _manualTotalController.addListener(_handleManualTotalChanged);
    _paidAmountController.addListener(_handlePaidAmountChanged);

    final initialItems = widget.initialItems;
    if (initialItems != null && initialItems.isNotEmpty) {
      for (final item in initialItems) {
        final draft = _lineFromSaleItem(item);
        _attachLineListeners(draft);
        _lines.add(draft);
      }
    }

    _updatePackageCoveragePreview();

    final initialPaid = widget.initialPaidAmount;
    if (initialPaid != null && initialPaid > 0) {
      _paidAmountController.text = initialPaid.toStringAsFixed(2);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final subtotal = _computeSubtotal();
      final initialDiscount = widget.initialDiscountAmount ?? 0;
      final base =
          subtotal <= 0 ? 0 : (subtotal - initialDiscount).clamp(0, subtotal);
      _syncManualTotalWithSubtotal(force: true, base: base.toDouble());
      _recalculateLoyalty(autoSuggest: true);
    });
  }

  Widget _buildBottomSummaryBar(
    BuildContext context,
    NumberFormat currency,
    double total,
  ) {
    final theme = Theme.of(context);
    final palette = _SaleFormPalette.fromTheme(theme);
    final colorScheme = theme.colorScheme;
    final canProceed = _lines.isNotEmpty;
    final onCancel =
        _isPaymentStep
            ? _exitPaymentStep
            : (widget.onSkipTicket ?? () => Navigator.of(context).maybePop());
    final cancelLabel = _isPaymentStep ? 'Indietro' : 'Annulla';
    final buttonLabel = _isPaymentStep ? 'Salva vendita' : 'Conferma vendita';
    final VoidCallback? onPressed =
        canProceed
            ? () {
              if (_isPaymentStep) {
                _submit();
                return;
              }
              _continueToPaymentStep();
            }
            : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final totalBlock = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTALE DA PAGARE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              currency.format(total),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color:
                    _isPaymentStep ? _reviewAccentColor : colorScheme.primary,
              ),
            ),
          ],
        );
        final cancelButton = OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            backgroundColor: palette.inputBg,
            side: BorderSide(color: colorScheme.outline),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          ),
          onPressed: onCancel,
          child: Text(cancelLabel),
        );
        final confirmButton = FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
                _isPaymentStep ? _reviewAccentColor : colorScheme.primary,
            foregroundColor:
                _isPaymentStep
                    ? theme.colorScheme.onPrimary
                    : colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          ),
          onPressed: onPressed,
          child: Text(buttonLabel),
        );
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              totalBlock,
              const SizedBox(height: 14),
              cancelButton,
              const SizedBox(height: 8),
              confirmButton,
            ],
          );
        }
        return Row(
          children: [
            totalBlock,
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [cancelButton, confirmButton],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildEditingContent({
    required ThemeData theme,
    required NumberFormat currency,
    required List<Client> filteredClients,
    required List<StaffMember> serviceProviders,
    required double subtotal,
    required double manualDiscount,
    required double loyaltyDiscount,
    required double total,
    required Salon? salon,
    required Client? client,
  }) {
    final saleLabel =
        widget.initialSaleId == null ? 'Nuova vendita' : 'Modifica vendita';
    return [
      _buildEditingHeroBanner(
        theme: theme,
        saleLabel: saleLabel,
        serviceProviders: serviceProviders,
      ),
      const SizedBox(height: 18),
      _buildEditingMainLayout(
        theme: theme,
        currency: currency,
        filteredClients: filteredClients,
        subtotal: subtotal,
        manualDiscount: manualDiscount,
        loyaltyDiscount: loyaltyDiscount,
        total: total,
        salon: salon,
        client: client,
      ),
    ];
  }

  Widget _buildEditingHeroBanner({
    required ThemeData theme,
    required String saleLabel,
    required List<StaffMember> serviceProviders,
  }) {
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.65)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            theme.brightness == Brightness.dark
                ? _blendSaleSurface(
                  colorScheme.surfaceContainerHigh,
                  colorScheme.primary,
                  0.18,
                )
                : colorScheme.primaryContainer.withValues(alpha: 0.8),
            colorScheme.surface,
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 780;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                saleLabel,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
          final operatorField = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EROGATO DA',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: isCompact ? double.infinity : 300,
                child: _buildServiceProviderPicker(
                  serviceProviders,
                  dense: true,
                ),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 16), operatorField],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 20),
              operatorField,
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileTotalSummaryCard(
    BuildContext context,
    NumberFormat currency,
    double total,
  ) {
    final theme = Theme.of(context);
    final highlightColor =
        _isPaymentStep ? _reviewAccentColor : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Totale da pagare',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            currency.format(total),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: highlightColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!_isPaymentStep) ...[
            const SizedBox(height: 8),
            Text(
              'Verifica cliente, righe e sconti prima di passare alla conferma.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditingMainLayout({
    required ThemeData theme,
    required NumberFormat currency,
    required List<Client> filteredClients,
    required double subtotal,
    required double manualDiscount,
    required double loyaltyDiscount,
    required double total,
    required Salon? salon,
    required Client? client,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final showLoyaltyContent = _isLoyaltyExpanded;
        final leftColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormSectionCard(
              theme: theme,
              icon: Icons.people_alt_outlined,
              title: 'Cliente',
              child: _buildClientSelector(filteredClients),
            ),
            const SizedBox(height: 16),
            _buildFormSectionCard(
              theme: theme,
              icon: Icons.loyalty_rounded,
              title: 'Programma fedeltà',
              trailing: Icon(
                showLoyaltyContent
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onTap: () {
                setState(() {
                  _isLoyaltyExpanded = !_isLoyaltyExpanded;
                });
              },
              child:
                  showLoyaltyContent
                      ? _buildLoyaltySection(currency, salon, client)
                      : const SizedBox.shrink(),
            ),
          ],
        );
        final rightColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormSectionCard(
              theme: theme,
              icon: Icons.shopping_cart_checkout_rounded,
              title: 'Elementi vendita',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_lines.isEmpty)
                    _buildMutedInfoContainer(
                      theme,
                      'Aggiungi un pacchetto, un servizio, un prodotto o una voce manuale.',
                    )
                  else
                    _buildSaleLinesSection(theme, currency),
                  if (_serviceCoverageDetails.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildPackageCoverageSummary(theme),
                  ],
                  const SizedBox(height: 16),
                  _buildAddLineActions(theme),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCheckoutSummaryCard(
              theme: theme,
              currency: currency,
              subtotal: subtotal,
              manualDiscount: manualDiscount,
              loyaltyDiscount: loyaltyDiscount,
              total: total,
            ),
          ],
        );

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [leftColumn, const SizedBox(height: 16), rightColumn],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 11, child: leftColumn),
            const SizedBox(width: 16),
            Expanded(flex: 10, child: rightColumn),
          ],
        );
      },
    );
  }

  Widget _buildFormSectionCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final palette = _SaleFormPalette.fromTheme(theme);
    final colorScheme = theme.colorScheme;
    final header = Row(
      children: [
        _buildSectionIconBadge(theme, icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
    final headerWidget =
        onTap == null
            ? header
            : InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: header,
              ),
            );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panelBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerWidget,
          if (child is! SizedBox) ...[const SizedBox(height: 16), child],
        ],
      ),
    );
  }

  Widget _buildSectionIconBadge(ThemeData theme, IconData icon) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: theme.colorScheme.onPrimary),
    );
  }

  Widget _buildAddLineActions(ThemeData theme) {
    final actions = [
      (
        icon: Icons.inventory_2_outlined,
        label: 'Pacchetto',
        onPressed: _onAddPackage,
      ),
      (icon: Icons.build_outlined, label: 'Servizio', onPressed: _onAddService),
      (
        icon: Icons.shopping_bag_outlined,
        label: 'Prodotto',
        onPressed: _onAddInventoryItem,
      ),
      (
        icon: Icons.add_rounded,
        label: 'Altro',
        onPressed: _showAdditionalItemOptions,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 10.0;
        final columns = constraints.maxWidth < 260 ? 1 : 2;
        final buttonWidth =
            columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions)
              SizedBox(
                width: buttonWidth,
                child: _buildAddLineActionButton(
                  theme: theme,
                  icon: action.icon,
                  label: action.label,
                  onPressed: action.onPressed,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAddLineActionButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 46,
      child: FilledButton(
        style: FilledButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutSummaryCard({
    required ThemeData theme,
    required NumberFormat currency,
    required double subtotal,
    required double manualDiscount,
    required double loyaltyDiscount,
    required double total,
    String title = 'Riepilogo',
  }) {
    final colorScheme = theme.colorScheme;
    final manualBase = subtotal - manualDiscount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.8)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.46),
            colorScheme.surface.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionIconBadge(theme, Icons.euro_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSummaryAmountRow(
            theme: theme,
            label: 'Subtotale',
            value: currency.format(subtotal),
          ),
          if (manualDiscount > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryAmountRow(
              theme: theme,
              label: 'Adeguamento manuale',
              value: '-${currency.format(manualDiscount)}',
            ),
            const SizedBox(height: 8),
            _buildSummaryAmountRow(
              theme: theme,
              label: 'Totale dopo adeguamento',
              value: currency.format(manualBase),
            ),
          ],
          if (loyaltyDiscount > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryAmountRow(
              theme: theme,
              label: 'Sconto fedeltà',
              value: '-${currency.format(loyaltyDiscount)}',
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: colorScheme.primary.withValues(alpha: 0.55)),
          const SizedBox(height: 14),
          _buildSummaryAmountRow(
            theme: theme,
            label: 'TOTALE DA PAGARE',
            value: currency.format(total),
            highlighted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAmountRow({
    required ThemeData theme,
    required String label,
    required String value,
    bool highlighted = false,
  }) {
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style:
                highlighted
                    ? theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )
                    : theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          textAlign: TextAlign.end,
          style:
              highlighted
                  ? theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  )
                  : theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
        ),
      ],
    );
  }

  List<Widget> _buildReviewContent({
    required ThemeData theme,
    required NumberFormat currency,
    required double total,
    required List<StaffMember> recorderStaff,
  }) {
    return [
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _buildPaymentSection(
            theme: theme,
            currency: currency,
            total: total,
            recorderStaff: recorderStaff,
          ),
        ),
      ),
    ];
  }

  Widget _buildReviewCard({required ThemeData theme, required Widget child}) {
    final palette = _SaleFormPalette.fromTheme(theme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.reviewCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }

  InputDecoration _reviewFieldDecoration({
    required ThemeData theme,
    required String label,
    bool accent = false,
  }) {
    final palette = _SaleFormPalette.fromTheme(theme);
    final borderColor = accent ? _reviewAccentColor : palette.border;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: borderColor),
    );
    return InputDecoration(
      labelText: label.toUpperCase(),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: _reviewAccentColor,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
      floatingLabelStyle: theme.textTheme.labelMedium?.copyWith(
        color: _reviewAccentColor,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
      filled: true,
      fillColor: palette.inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: border,
      border: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(
          color: accent ? _reviewAccentColor : theme.colorScheme.primary,
          width: 1.2,
        ),
      ),
    );
  }

  Widget _buildPaymentSection({
    required ThemeData theme,
    required NumberFormat currency,
    required double total,
    required List<StaffMember> recorderStaff,
  }) {
    final resolvedRecorderId = _resolvedRecorderStaffId();
    final requiresPayment = total > 0.009;
    final recorderValue =
        resolvedRecorderId != null &&
                recorderStaff.any((member) => member.id == resolvedRecorderId)
            ? resolvedRecorderId
            : null;
    return _buildReviewCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: _reviewAccentColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.credit_card_rounded,
                  size: 16,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Pagamenti',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!requiresPayment) ...[
            Text(
              'Il totale è pari a 0 €. La vendita sarà registrata come saldata senza movimenti di cassa.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            DropdownButtonFormField<SalePaymentStatus>(
              isExpanded: true,
              initialValue: _paymentStatus,
              decoration: _reviewFieldDecoration(
                theme: theme,
                label: 'Stato pagamento',
              ),
              items:
                  SalePaymentStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
              validator:
                  (value) =>
                      value == null ? 'Seleziona lo stato del pagamento' : null,
              onChanged: (value) {
                setState(() {
                  _paymentStatus = value;
                  if (value == SalePaymentStatus.posticipated) {
                    _payment = PaymentMethod.posticipated;
                  } else if (_payment == PaymentMethod.posticipated) {
                    _payment = null;
                  }
                });
                if (value != SalePaymentStatus.deposit) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) {
                      return;
                    }
                    _setPaidAmountText('');
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              isExpanded: true,
              initialValue:
                  _paymentStatus == SalePaymentStatus.posticipated
                      ? PaymentMethod.posticipated
                      : _payment,
              decoration: _reviewFieldDecoration(
                theme: theme,
                label: 'Metodo di pagamento',
              ),
              items:
                  (_paymentStatus == SalePaymentStatus.posticipated
                          ? const [PaymentMethod.posticipated]
                          : PaymentMethod.values.where(
                            (method) =>
                                method != PaymentMethod.posticipated &&
                                method.isManualSelectable,
                          ))
                      .map(
                        (method) => DropdownMenuItem(
                          value: method,
                          child: Text(_paymentLabel(method)),
                        ),
                      )
                      .toList(),
              validator: (value) {
                if (_paymentStatus == SalePaymentStatus.posticipated) {
                  return null;
                }
                return value == null
                    ? 'Seleziona il metodo di pagamento'
                    : null;
              },
              onChanged:
                  _paymentStatus == SalePaymentStatus.posticipated
                      ? null
                      : (value) => setState(() => _payment = value),
            ),
            if (_paymentStatus == SalePaymentStatus.posticipated) ...[
              const SizedBox(height: 8),
              Text(
                'Pagamento posticipato: registriamo un acconto di 0 € e potrai incassare in seguito.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_paymentStatus == SalePaymentStatus.deposit) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _paidAmountController,
                decoration: _reviewFieldDecoration(
                  theme: theme,
                  label: 'Importo incassato (€)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (_paymentStatus != SalePaymentStatus.deposit) {
                    return null;
                  }
                  final amount = _parseAmount(value);
                  if (amount == null || amount <= 0) {
                    return 'Inserisci un importo valido';
                  }
                  if (amount > total + 0.01) {
                    return 'L\'acconto supera il totale';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Residuo da incassare: ${currency.format(_remainingBalance(total))}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
          const SizedBox(height: 12),
          if (recorderStaff.isEmpty) ...[
            Text(
              'Nessun operatore disponibile per registrare la vendita in questo salone.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: recorderValue,
              decoration: _reviewFieldDecoration(
                theme: theme,
                label: 'Registrato da',
                accent: true,
              ),
              items:
                  recorderStaff
                      .map(
                        (member) => DropdownMenuItem(
                          value: member.id,
                          child: Text(member.fullName),
                        ),
                      )
                      .toList(),
              validator:
                  (value) =>
                      value == null
                          ? 'Seleziona l\'operatore che registra la vendita'
                          : null,
              onChanged: (value) => setState(() => _recorderStaffId = value),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _manualTotalController.removeListener(_handleManualTotalChanged);
    _paidAmountController.removeListener(_handlePaidAmountChanged);
    _manualTotalController.dispose();
    _paidAmountController.dispose();
    _loyaltyRedeemController.dispose();
    _invoiceController.dispose();
    _notesController.dispose();
    _sheetScrollController.dispose();
    _clientSearchController.dispose();
    _clientNumberSearchController.dispose();
    _clientSearchFocusNode.dispose();
    _clientNumberSearchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPhoneLayout = isAppSheetPhoneLayout(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final subtotal = _computeSubtotal();
    final manualDiscount = _currentManualDiscount(subtotal);
    final baseTotal = _currentTotal(subtotal, manualDiscount);
    final loyaltyDiscount = _normalizeCurrency(_loyaltySummary.redeemedValue);
    final total = _normalizeCurrency(baseTotal - loyaltyDiscount);
    _syncPaidAmountWithTotal(total);

    final salon = _currentSalon;
    final currentClient = _currentClient;

    final filteredClients =
        widget.clients.toList()..sort((a, b) {
          final aMatches = a.salonId == _salonId;
          final bMatches = b.salonId == _salonId;
          if (aMatches != bMatches) {
            return aMatches ? -1 : 1;
          }
          return a.fullName.compareTo(b.fullName);
        });
    final serviceProviders =
        _serviceProviders.toList()..sort((a, b) {
          final aMatches = a.salonId == _salonId;
          final bMatches = b.salonId == _salonId;
          if (aMatches != bMatches) {
            return aMatches ? -1 : 1;
          }
          return a.fullName.compareTo(b.fullName);
        });
    final recorderStaff =
        _recorderStaff.toList()..sort((a, b) {
          final aMatches = a.salonId == _salonId;
          final bMatches = b.salonId == _salonId;
          if (aMatches != bMatches) {
            return aMatches ? -1 : 1;
          }
          return a.fullName.compareTo(b.fullName);
        });
    final isReviewStep = _isPaymentStep;
    final sheetContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            isReviewStep
                ? _buildReviewContent(
                  theme: theme,
                  currency: currency,
                  total: total,
                  recorderStaff: recorderStaff,
                )
                : _buildEditingContent(
                  theme: theme,
                  currency: currency,
                  filteredClients: filteredClients,
                  serviceProviders: serviceProviders,
                  subtotal: subtotal,
                  manualDiscount: manualDiscount,
                  loyaltyDiscount: loyaltyDiscount,
                  total: total,
                  salon: salon,
                  client: currentClient,
                ),
      ),
    );

    if (isPhoneLayout && widget.showSheetHeader) {
      final leadingMode =
          _isPaymentStep
              ? AppMobileSheetLeadingMode.back
              : AppMobileSheetLeadingMode.close;
      final primaryActionLabel = _isPaymentStep ? 'Salva' : 'Avanti';
      final canProceed = _lines.isNotEmpty;
      final bodyContent =
          isReviewStep
              ? Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: sheetContent,
                ),
              )
              : sheetContent;

      return AppMobileSheetPageScaffold(
        title: _isPaymentStep ? 'Conferma vendita' : 'Registra una vendita',
        subtitle: _salonId == null ? null : _currentSalon?.name,
        leadingMode: leadingMode,
        onLeadingPressed:
            _isPaymentStep
                ? _exitPaymentStep
                : (widget.onSkipTicket ??
                    () => Navigator.of(context).maybePop()),
        actions: [
          TextButton(
            onPressed:
                canProceed
                    ? () {
                      if (_isPaymentStep) {
                        _submit();
                        return;
                      }
                      _continueToPaymentStep();
                    }
                    : null,
            child: Text(primaryActionLabel),
          ),
        ],
        body: ListView(
          controller: _sheetScrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding:
              isReviewStep
                  ? const EdgeInsets.fromLTRB(16, 20, 16, 24)
                  : const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            bodyContent,
            if (!isReviewStep) ...[
              const SizedBox(height: 20),
              _buildMobileTotalSummaryCard(context, currency, total),
            ],
          ],
        ),
      );
    }

    if (isPhoneLayout) {
      final inlineSummary = Container(
        padding: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: _buildBottomSummaryBar(context, currency, total),
      );

      return ColoredBox(
        color: theme.colorScheme.surface,
        child: ListView(
          controller: _sheetScrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding:
              isReviewStep
                  ? const EdgeInsets.fromLTRB(16, 20, 16, 24)
                  : const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            if (isReviewStep)
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      sheetContent,
                      const SizedBox(height: 20),
                      inlineSummary,
                    ],
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sheetContent,
                  const SizedBox(height: 20),
                  inlineSummary,
                ],
              ),
          ],
        ),
      );
    }

    return AppSheetScaffold(
      title:
          widget.showSheetHeader
              ? (_isPaymentStep ? 'Conferma vendita' : 'Registra una vendita')
              : null,
      onClose: widget.showSheetHeader ? widget.onSkipTicket : null,
      bodyPadding: EdgeInsets.zero,
      footerPadding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      scrollBody: false,
      body: SingleChildScrollView(
        controller: _sheetScrollController,
        padding:
            isReviewStep
                ? const EdgeInsets.fromLTRB(24, 20, 24, 20)
                : const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child:
            isReviewStep
                ? Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: sheetContent,
                  ),
                )
                : sheetContent,
      ),
      footer: _buildBottomSummaryBar(context, currency, total),
    );
  }

  Widget _buildClientSelector(List<Client> clients) {
    return FormField<String>(
      key: _clientFieldKey,
      validator: (_) => _clientId == null ? 'Seleziona un cliente' : null,
      builder: (state) {
        final selectedClient = _currentClient;
        final theme = Theme.of(context);
        if (_usesDesktopInlineClientSearch(context)) {
          return _buildDesktopClientSelector(
            theme,
            clients: clients,
            selectedClient: selectedClient,
            errorText: state.errorText,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedClient == null)
              _buildEmptyClientSelectionCard(
                theme,
                clients: clients,
                errorText: state.errorText,
              )
            else
              _buildSelectedClientCard(
                theme,
                selectedClient,
                errorText: state.errorText,
                clients: clients,
              ),
          ],
        );
      },
    );
  }

  Widget _buildSaleLinesSection(ThemeData theme, NumberFormat currency) {
    return Column(
      children: [
        for (var i = 0; i < _lines.length; i++) ...[
          _buildLineCard(_lines[i], i, currency),
          if (i < _lines.length - 1) const SizedBox(height: 2),
        ],
      ],
    );
  }

  Widget _buildLineCard(_SaleLineDraft line, int index, NumberFormat currency) {
    final theme = Theme.of(context);
    final palette = _SaleFormPalette.fromTheme(theme);
    final lineTotal = _lineTotal(line);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.elevatedPanelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _lineTypeIcon(line.referenceType),
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lineDisplayLabel(line, index),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Rimuovi voce',
                onPressed: () => _removeLine(line.id),
                icon: Icon(Icons.delete_outline_rounded, color: palette.danger),
              ),
            ],
          ),
          if (line.catalogLabel != null && line.catalogLabel!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                line.catalogLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (line.referenceType == SaleReferenceType.service &&
              line.referenceId != null &&
              line.referenceId!.isNotEmpty) ...[
            _buildServiceSessionToggle(theme, line),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldCaption(
                      theme,
                      'Quantità',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: line.quantityController,
                      decoration: _buildModalFieldDecoration(theme),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final quantity = _parseAmount(value);
                        if (quantity == null || quantity <= 0) {
                          return 'Quantità non valida';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldCaption(
                      theme,
                      'Prezzo unitario (€)',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: line.priceController,
                      decoration: _buildModalFieldDecoration(theme),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final price = _parseAmount(value);
                        if (price == null || price < 0) {
                          return 'Prezzo non valido';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldCaption(
                theme,
                'Totale riga',
                color: theme.colorScheme.onSurfaceVariant,
              ),
              Text(
                currency.format(lineTotal),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSessionToggle(ThemeData theme, _SaleLineDraft line) {
    final palette = _SaleFormPalette.fromTheme(theme);
    return Container(
      decoration: BoxDecoration(
        color: palette.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sessione utilizzabile',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (line.serviceSessionToggleLocked &&
                    line.serviceSessionToggleLockMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      line.serviceSessionToggleLockMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: line.serviceCreatesSession,
            onChanged:
                line.serviceSessionToggleLocked
                    ? null
                    : (value) {
                      line.serviceCreatesSession = value;
                      _handleLineChanged();
                    },
          ),
        ],
      ),
    );
  }

  Salon? get _currentSalon =>
      widget.salons.firstWhereOrNull((salon) => salon.id == _salonId);

  Client? get _currentClient =>
      widget.clients.firstWhereOrNull((client) => client.id == _clientId);

  Future<void> _pickClient(List<Client> clients) async {
    FocusScope.of(context).unfocus();
    final selectedClient = await showClientSearchSheet(
      context: context,
      clients: clients,
      activeSalonId: _salonId,
      selectedClientId: _clientId,
    );
    if (!mounted || selectedClient == null) {
      return;
    }
    _applyClientSelection(selectedClient);
  }

  bool _usesDesktopInlineClientSearch(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 1024;
  }

  Widget _buildDesktopClientSelector(
    ThemeData theme, {
    required List<Client> clients,
    required Client? selectedClient,
    String? errorText,
  }) {
    final hasSelection = selectedClient != null;
    final suggestions = _clientSuggestions;
    final clientNumberText = selectedClient?.clientNumber?.trim() ?? '';
    final clientField =
        hasSelection
            ? InputDecorator(
              decoration: InputDecoration(
                labelText: 'Cliente',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                errorText: errorText,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              isEmpty: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedClient.fullName,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Vai al cliente',
                        icon: const Icon(Icons.open_in_new_rounded),
                        onPressed: _openSelectedClient,
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Rimuovi cliente',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _clearClientSelection,
                      ),
                    ],
                  ),
                  if (selectedClient.phone.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              selectedClient.phone.trim(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            )
            : TextField(
              controller: _clientSearchController,
              focusNode: _clientSearchFocusNode,
              decoration: InputDecoration(
                labelText: 'Cliente',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: 'Nome, cognome, telefono o email',
                errorText: errorText,
                suffixIcon:
                    _clientSearchController.text.isEmpty
                        ? const Icon(Icons.search_rounded, size: 20)
                        : IconButton(
                          tooltip: 'Pulisci ricerca',
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: _clearClientSearch,
                        ),
              ),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              onChanged:
                  (value) => _onClientSearchChanged(
                    value,
                    clients,
                    _ClientSearchMode.general,
                  ),
            );

    final clientNumberField =
        hasSelection
            ? InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Numero cliente',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              child: SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    clientNumberText.isNotEmpty
                        ? clientNumberText
                        : 'Numero non disponibile',
                    style:
                        theme.textTheme.bodyLarge ?? theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            )
            : TextField(
              controller: _clientNumberSearchController,
              focusNode: _clientNumberSearchFocusNode,
              decoration: InputDecoration(
                labelText: 'Numero cliente',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: 'Numero cliente',
                suffixIcon:
                    _clientNumberSearchController.text.isEmpty
                        ? const Icon(Icons.search_rounded, size: 20)
                        : IconButton(
                          tooltip: 'Pulisci ricerca',
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: _clearClientNumberSearch,
                        ),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged:
                  (value) => _onClientSearchChanged(
                    value,
                    clients,
                    _ClientSearchMode.number,
                  ),
            );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;
        final clientFields =
            isNarrow
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    clientField,
                    const SizedBox(height: 12),
                    clientNumberField,
                  ],
                )
                : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: clientField),
                    const SizedBox(width: 12),
                    SizedBox(width: 220, child: clientNumberField),
                  ],
                );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            clientFields,
            if (!hasSelection) ...[
              const SizedBox(height: 8),
              _buildDesktopClientSuggestions(suggestions),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDesktopClientSuggestions(List<Client> suggestions) {
    final theme = Theme.of(context);
    final isClientNumberMode = _clientSearchMode == _ClientSearchMode.number;
    final query =
        isClientNumberMode
            ? _clientNumberSearchController.text.trim()
            : _clientSearchController.text.trim();
    if (query.isEmpty) {
      return const SizedBox.shrink();
    }
    if (ClientSearchUtils.hasShortQueryForMode(
      query: query,
      isClientNumber: isClientNumberMode,
    )) {
      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(
            ClientSearchUtils.minSearchCriteriaMessage,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    if (suggestions.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(
            'Nessun cliente trovato. Prova a modificare la ricerca.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < suggestions.length; i++) ...[
            _buildDesktopClientSuggestionTile(suggestions[i]),
            if (i != suggestions.length - 1)
              const Divider(height: 1, thickness: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopClientSuggestionTile(Client client) {
    final subtitle = _buildDesktopClientSubtitle(client);
    return ListTile(
      onTap: () => _handleClientSuggestionTap(client),
      leading: CircleAvatar(child: Text(_initialForClient(client))),
      title: Text(client.fullName),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  String _buildDesktopClientSubtitle(Client client) {
    final parts = <String>[];
    if (client.clientNumber != null && client.clientNumber!.isNotEmpty) {
      parts.add('N° ${client.clientNumber}');
    }
    if (client.phone.trim().isNotEmpty) {
      parts.add(client.phone.trim());
    }
    if (client.email != null && client.email!.trim().isNotEmpty) {
      parts.add(client.email!.trim());
    }
    return parts.join(' · ');
  }

  Widget _buildEmptyClientSelectionCard(
    ThemeData theme, {
    required List<Client> clients,
    String? errorText,
  }) {
    final palette = _SaleFormPalette.fromTheme(theme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: palette.elevatedPanelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: errorText != null ? palette.danger : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nessun cliente selezionato',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Apri la ricerca dedicata per trovare rapidamente il cliente giusto per nome, telefono, email o numero cliente.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _pickClient(clients),
            icon: const Icon(Icons.person_search_rounded),
            label: const Text('Seleziona cliente'),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 10),
            Text(
              errorText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedClientCard(
    ThemeData theme,
    Client selectedClient, {
    required List<Client> clients,
    String? errorText,
  }) {
    final palette = _SaleFormPalette.fromTheme(theme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: palette.elevatedPanelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: errorText != null ? palette.danger : palette.success,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: palette.successBg,
                foregroundColor: palette.success,
                child: Text(_initialForClient(selectedClient)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          selectedClient.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (selectedClient.clientNumber != null &&
                            selectedClient.clientNumber!.isNotEmpty)
                          _buildClientPill(
                            theme,
                            'N° ${selectedClient.clientNumber}',
                          ),
                      ],
                    ),
                    if (selectedClient.phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              selectedClient.phone.trim(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (selectedClient.email != null &&
                        selectedClient.email!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          selectedClient.email!.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickClient(clients),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Cambia'),
              ),
              OutlinedButton.icon(
                onPressed: _openSelectedClient,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Apri cliente'),
              ),
              TextButton.icon(
                onPressed: _clearClientSelection,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Rimuovi'),
                style: TextButton.styleFrom(foregroundColor: palette.danger),
              ),
            ],
          ),
          if (errorText != null) ...[
            const SizedBox(height: 10),
            Text(
              errorText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClientPill(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initialForClient(Client client) {
    final trimmed = client.fullName.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  void _clearClientSearch() {
    if (_clientSearchController.text.isEmpty) {
      return;
    }
    _clientSearchController.clear();
    setState(() {
      _clientSearchMode = _ClientSearchMode.general;
      _clientSuggestions = const <Client>[];
    });
    FocusScope.of(context).requestFocus(_clientSearchFocusNode);
  }

  void _clearClientNumberSearch() {
    if (_clientNumberSearchController.text.isEmpty) {
      return;
    }
    _clientNumberSearchController.clear();
    setState(() {
      _clientSearchMode = _ClientSearchMode.general;
      _clientSuggestions = const <Client>[];
    });
    FocusScope.of(context).requestFocus(_clientNumberSearchFocusNode);
  }

  void _onClientSearchChanged(
    String value,
    List<Client> clients,
    _ClientSearchMode mode,
  ) {
    final query = value.trim();
    final isClientNumberMode = mode == _ClientSearchMode.number;
    if (!ClientSearchUtils.hasSearchableQueryForMode(
      query: query,
      isClientNumber: isClientNumberMode,
    )) {
      setState(() {
        _clientSearchMode = mode;
        _clientSuggestions = const <Client>[];
      });
      return;
    }

    final filtered = ClientSearchUtils.rankedClients(
      clients: clients,
      generalQuery: mode == _ClientSearchMode.general ? query : '',
      clientNumberQuery: mode == _ClientSearchMode.number ? query : '',
      activeSalonId: _salonId,
      exactNumberMatch: mode == _ClientSearchMode.number,
      limit: 8,
    );

    setState(() {
      _clientSearchMode = mode;
      _clientSuggestions = filtered;
    });
  }

  void _handleClientSuggestionTap(Client client) {
    FocusScope.of(context).unfocus();
    _applyClientSelection(client);
  }

  Widget _buildServiceProviderPicker(
    List<StaffMember> serviceProviders, {
    bool dense = false,
  }) {
    final theme = Theme.of(context);
    final palette = _SaleFormPalette.fromTheme(theme);
    final decoration =
        dense
            ? _buildModalFieldDecoration(
              theme,
              hintText: 'Seleziona operatore',
              fillColor: palette.denseInputBg,
            )
            : const InputDecoration(
              labelText: 'Erogato da',
              floatingLabelBehavior: FloatingLabelBehavior.always,
            );
    if (widget.lockServiceOperator) {
      return _buildReadOnlyServiceOperatorField(dense: dense);
    }
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _staffId,
      decoration: decoration,
      items:
          serviceProviders
              .map(
                (member) => DropdownMenuItem(
                  value: member.id,
                  child: Text(_staffOptionLabel(member)),
                ),
              )
              .toList(),
      onChanged: _onServiceProviderChanged,
    );
  }

  Widget _buildReadOnlyServiceOperatorField({bool dense = false}) {
    final theme = Theme.of(context);
    final palette = _SaleFormPalette.fromTheme(theme);
    final operator = _selectedServiceProvider;
    final label =
        operator == null ? 'Non assegnato' : _staffOptionLabel(operator);
    return InputDecorator(
      decoration:
          dense
              ? _buildModalFieldDecoration(
                theme,
                fillColor: palette.denseInputBg,
              )
              : const InputDecoration(
                labelText: 'Erogato da',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
      child: Text(label),
    );
  }

  Widget _buildMutedInfoContainer(ThemeData theme, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.75,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required ThemeData theme,
    required String label,
    required String value,
    Color? borderColor,
    Color? backgroundColor,
    Color? labelColor,
    Color? valueColor,
  }) {
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: labelColor ?? colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldCaption(ThemeData theme, String label, {Color? color}) {
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
        color: color ?? theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    );
  }

  InputDecoration _buildModalFieldDecoration(
    ThemeData theme, {
    String? hintText,
    String? errorText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? prefixText,
    Color? borderColor,
    Color? fillColor,
  }) {
    final palette = _SaleFormPalette.fromTheme(theme);
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor ?? palette.border),
    );
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      isDense: true,
      filled: true,
      fillColor: fillColor ?? palette.inputBg,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixText: prefixText,
      prefixStyle: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: BorderSide(
          color: borderColor ?? theme.colorScheme.primary,
          width: 1.2,
        ),
      ),
      errorBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: theme.colorScheme.error),
      ),
      focusedErrorBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1.2),
      ),
    );
  }

  Widget _buildLoyaltySection(
    NumberFormat currency,
    Salon? salon,
    Client? client,
  ) {
    final theme = Theme.of(context);
    final palette = _SaleFormPalette.fromTheme(theme);

    Widget buildInfo(String message) {
      return _buildMutedInfoContainer(theme, message);
    }

    if (salon == null) {
      return buildInfo(_associateSalonHint);
    }
    if (client == null) {
      return buildInfo('Seleziona un cliente per utilizzare i punti fedeltà.');
    }

    final settings = salon.loyaltySettings;
    if (!settings.enabled) {
      return buildInfo(
        'Il programma fedeltà non è attivo per il salone associato.',
      );
    }

    final availablePoints = _computeClientSpendable(client);
    final canRedeem = _maxRedeemablePoints > 0;
    final pointValueEuro =
        settings.redemption.pointValueEuro <= 0
            ? 1.0
            : settings.redemption.pointValueEuro;
    final maxValueFromPoints = _maxRedeemablePoints * pointValueEuro;
    final displayableRedeemValue = math.min(
      _maxRedeemableValue,
      maxValueFromPoints,
    );
    final helperText =
        canRedeem
            ? 'Puoi usare al massimo $_maxRedeemablePoints punti (${currency.format(displayableRedeemValue)}).'
            : availablePoints <= 0
            ? 'Saldo punti insufficiente.'
            : _loyaltyEligibleAmount <= 0
            ? 'Aggiungi righe valide o riduci gli sconti manuali per abilitare il riscatto.'
            : 'Nessun punto utilizzabile per questa vendita.';

    final accentGreen = palette.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 420;
            final tiles = [
              Expanded(
                child: _buildMetricTile(
                  theme: theme,
                  label: 'Saldo cliente',
                  value: '$availablePoints pt',
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  theme: theme,
                  label: 'Utilizzabili ora',
                  value: '$_maxRedeemablePoints pt',
                ),
              ),
            ];
            if (isCompact) {
              return Column(
                children: [tiles[0], const SizedBox(height: 12), tiles[1]],
              );
            }
            return Row(
              children: [tiles[0], const SizedBox(width: 12), tiles[1]],
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMetricTile(
          theme: theme,
          label: 'Importo eleggibile',
          value: currency.format(_loyaltyEligibleAmount),
          borderColor: theme.colorScheme.primary.withValues(alpha: 0.8),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        _buildFieldCaption(theme, 'Punti da utilizzare'),
        const SizedBox(height: 8),
        TextFormField(
          key: saleFormLoyaltyRedeemFieldKey,
          controller: _loyaltyRedeemController,
          enabled: canRedeem,
          decoration: _buildModalFieldDecoration(theme, hintText: '0'),
          keyboardType: const TextInputType.numberWithOptions(
            signed: false,
            decimal: false,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _onRedeemPointsChanged,
        ),
        const SizedBox(height: 6),
        Text(
          helperText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 420;
            final discountTile = Expanded(
              child: _buildMetricTile(
                theme: theme,
                label: 'Sconto fedeltà',
                value: '-${currency.format(_loyaltySummary.redeemedValue)}',
                borderColor: accentGreen.withValues(alpha: 0.85),
                backgroundColor: accentGreen.withValues(alpha: 0.12),
                labelColor: accentGreen,
                valueColor: accentGreen,
              ),
            );
            final earnTile = Expanded(
              child: _buildMetricTile(
                theme: theme,
                label: 'Punti in accredito',
                value: '+${_loyaltySummary.requestedEarnPoints} pt',
                borderColor: theme.colorScheme.primary.withValues(alpha: 0.85),
                backgroundColor: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                valueColor: theme.colorScheme.onSurface,
              ),
            );
            if (isCompact) {
              return Column(
                children: [discountTile, const SizedBox(height: 12), earnTile],
              );
            }
            return Row(
              children: [discountTile, const SizedBox(width: 12), earnTile],
            );
          },
        ),
      ],
    );
  }

  void _onRedeemPointsChanged(String value) {
    if (_updatingRedeemController) {
      return;
    }
    final sanitized = value.trim().isEmpty ? '0' : value.trim();
    final parsed = int.tryParse(sanitized) ?? 0;
    final clamped = parsed.clamp(0, _maxRedeemablePoints);
    if (parsed != clamped) {
      _updateRedeemController(clamped);
    }
    if (clamped == _selectedRedeemPoints) {
      _recalculateLoyalty();
      return;
    }
    setState(() {
      _selectedRedeemPoints = clamped;
    });
    _recalculateLoyalty();
  }

  void _updateRedeemController(int value) {
    final text = value <= 0 ? '0' : value.toString();
    if (_loyaltyRedeemController.text == text) {
      return;
    }
    _updatingRedeemController = true;
    _loyaltyRedeemController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _updatingRedeemController = false;
  }

  void _resetLoyaltyState() {
    final hasData =
        _selectedRedeemPoints != 0 ||
        _maxRedeemablePoints != 0 ||
        _maxRedeemableValue != 0 ||
        _loyaltyEligibleAmount != 0 ||
        _loyaltySummary.hasRedemption ||
        _loyaltySummary.requestedEarnPoints != 0;
    if (!hasData) {
      _updateRedeemController(0);
      return;
    }
    setState(() {
      _selectedRedeemPoints = 0;
      _maxRedeemablePoints = 0;
      _maxRedeemableValue = 0;
      _loyaltyEligibleAmount = 0;
      _loyaltySummary = SaleLoyaltySummary();
    });
    _updateRedeemController(0);
  }

  void _recalculateLoyalty({bool autoSuggest = false}) {
    final salon = _currentSalon;
    final client = _currentClient;
    final subtotal = _computeSubtotal();
    final manualDiscount = _currentManualDiscount(subtotal);

    if (salon == null || client == null || !salon.loyaltySettings.enabled) {
      _resetLoyaltyState();
      return;
    }

    if (subtotal <= 0) {
      _resetLoyaltyState();
      return;
    }

    final settings = salon.loyaltySettings;
    final availablePoints = _computeClientSpendable(client);
    var desired = _selectedRedeemPoints.clamp(0, availablePoints);
    if (autoSuggest && settings.redemption.autoSuggest) {
      desired = availablePoints;
    }

    final quote = LoyaltyCalculator.compute(
      settings: settings,
      subtotal: subtotal,
      manualDiscount: manualDiscount,
      availablePoints: availablePoints,
      selectedRedeemPoints: desired,
    );

    setState(() {
      _selectedRedeemPoints = quote.summary.redeemedPoints;
      _loyaltySummary = quote.summary;
      _maxRedeemablePoints = quote.maxRedeemablePoints;
      _maxRedeemableValue = quote.maxRedeemableValue;
      _loyaltyEligibleAmount = quote.eligibleAmount;
    });
    _updateRedeemController(quote.summary.redeemedPoints);
  }

  int _resolveLoyaltyValue(int? stored, int aggregated) {
    if (stored == null) {
      return aggregated;
    }
    if (stored == 0 && aggregated != 0) {
      return aggregated;
    }
    return stored;
  }

  int _resolveSpendableBalance({required int stored, required int computed}) {
    final normalizedStored = stored < 0 ? 0 : stored;
    final normalizedComputed = computed < 0 ? 0 : computed;
    if (normalizedStored == normalizedComputed) {
      return normalizedStored;
    }
    if (normalizedComputed == 0 && normalizedStored != 0) {
      return normalizedStored;
    }
    return normalizedComputed;
  }

  int _computeClientSpendable(Client client) {
    final clientSales =
        widget.sales.where((sale) => sale.clientId == client.id).toList();
    final aggregatedEarned = clientSales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.resolvedEarnedPoints,
    );
    final aggregatedRedeemed = clientSales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.redeemedPoints,
    );
    final totalEarned = _resolveLoyaltyValue(
      client.loyaltyTotalEarned,
      aggregatedEarned,
    );
    final totalRedeemed = _resolveLoyaltyValue(
      client.loyaltyTotalRedeemed,
      aggregatedRedeemed,
    );
    final computed = client.loyaltyInitialPoints + totalEarned - totalRedeemed;
    return _resolveSpendableBalance(
      stored: client.loyaltyPoints,
      computed: computed,
    );
  }

  void _attachLineListeners(_SaleLineDraft line) {
    line.quantityController.addListener(_handleLineChanged);
    line.priceController.addListener(_handleLineChanged);
  }

  void _registerLine(_SaleLineDraft line) {
    _attachLineListeners(line);
    setState(() {
      _lines.add(line);
      _updatePackageCoveragePreview();
    });
    _syncManualTotalWithSubtotal();
    _recalculateLoyalty();
  }

  void _removeLine(String id) {
    final index = _lines.indexWhere((line) => line.id == id);
    if (index == -1) {
      return;
    }
    final line = _lines[index];
    setState(() {
      _lines.removeAt(index);
      _updatePackageCoveragePreview();
    });
    _lineCachedPrices.remove(line.id);
    line.dispose();
    _syncManualTotalWithSubtotal(force: true);
    _recalculateLoyalty();
  }

  void _resetLines() {
    for (final line in _lines) {
      line.dispose();
    }
    _lines.clear();
    _manualTotalController.clear();
    _manualTotalOverridden = false;
    _isPaymentStep = false;
    _updatePackageCoveragePreview();
    _lineCachedPrices.clear();
  }

  void _applyClientSelection(Client client) {
    final newSalonId = client.salonId;
    final salonChanged = newSalonId.isNotEmpty && newSalonId != _salonId;
    setState(() {
      _clientId = client.id;
      _clientSearchController.text = client.fullName;
      _clientNumberSearchController.text = client.clientNumber ?? '';
      _clientSearchMode = _ClientSearchMode.general;
      _clientSuggestions = const <Client>[];
      if (salonChanged) {
        _salonId = newSalonId;
        _staffId = null;
        if (!_isSelectableRecorderId(_recorderStaffId, salonId: newSalonId)) {
          _recorderStaffId = null;
        }
        _resetLines();
      }
    });
    _clientFieldKey.currentState?.didChange(client.id);
    if (salonChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _syncManualTotalWithSubtotal(force: true);
        _recalculateLoyalty(autoSuggest: true);
      });
    } else {
      _recalculateLoyalty(autoSuggest: true);
    }
  }

  void _clearClientSelection() {
    if (_clientId == null) {
      return;
    }
    setState(() {
      _clientId = null;
      _clientSearchController.clear();
      _clientNumberSearchController.clear();
      _clientSearchMode = _ClientSearchMode.general;
      _clientSuggestions = const <Client>[];
      _isPaymentStep = false;
    });
    _clientFieldKey.currentState?.didChange(null);
    _recalculateLoyalty(autoSuggest: true);
    if (_usesDesktopInlineClientSearch(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        FocusScope.of(context).requestFocus(_clientSearchFocusNode);
      });
    }
  }

  Future<void> _openSelectedClient() async {
    final clientId = _clientId;
    if (clientId == null) {
      return;
    }
    final isCompact = isCompactClientLayout(context);
    final container = ProviderScope.containerOf(context, listen: false);
    if (!isCompact) {
      container
          .read(adminDashboardIntentProvider.notifier)
          .state = AdminDashboardIntent(
        moduleId: 'clients',
        payload: {'clientId': clientId, 'detailTabIndex': 0},
      );
    }
    await openClientDetailPage(
      context,
      clientId: clientId,
      initialTabIndex: 0,
      compactOnly: true,
    );
  }

  void _onServiceProviderChanged(String? staffId) {
    if (staffId == _staffId) {
      return;
    }
    final selectedStaff =
        staffId == null
            ? null
            : _serviceProviders.firstWhereOrNull(
              (member) => member.id == staffId,
            );
    final newSalonId = selectedStaff?.salonId;
    final salonChanged =
        newSalonId != null && newSalonId.isNotEmpty && newSalonId != _salonId;
    setState(() {
      _staffId = staffId;
      if (salonChanged) {
        _salonId = newSalonId;
        if (!_isSelectableRecorderId(_recorderStaffId, salonId: newSalonId)) {
          _recorderStaffId = null;
        }
        if (_clientId != null) {
          final currentClient = widget.clients.firstWhereOrNull(
            (client) => client.id == _clientId,
          );
          if (currentClient?.salonId != newSalonId) {
            _clientId = null;
            _clientSearchController.clear();
            _clientNumberSearchController.clear();
            _clientSearchMode = _ClientSearchMode.general;
            _clientSuggestions = const <Client>[];
            _clientFieldKey.currentState?.didChange(null);
          }
        }
        _resetLines();
      }
    });
    if (salonChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncManualTotalWithSubtotal(force: true);
        _recalculateLoyalty(autoSuggest: true);
      });
    } else {
      _recalculateLoyalty();
    }
  }

  Future<void> _onAddService() async {
    final salonId = _salonId;
    if (salonId == null) {
      _showSnackBar(_associateSalonHint);
      return;
    }
    final services = _servicesForSalon(salonId);
    if (services.isEmpty) {
      _showSnackBar('Nessun servizio disponibile per il salone associato.');
      return;
    }
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final selected = await _pickFromCatalog<Service>(
      title: 'Scegli un servizio',
      items: services,
      labelBuilder: (service) => service.name,
      subtitleBuilder:
          (service) =>
              '${service.category} • ${currency.format(service.price)}',
    );
    if (selected == null) {
      return;
    }
    final line = _createLineDraft(
      referenceType: SaleReferenceType.service,
      referenceId: selected.id,
      description: selected.name,
      quantity: 1,
      unitPrice: selected.price,
      catalogLabel: selected.category,
      serviceCreatesSession: widget.serviceLinesCreateSessionsByDefault,
    );
    _registerLine(line);
  }

  Future<void> _onAddPackage() async {
    final salonId = _salonId;
    if (salonId == null) {
      _showSnackBar(_associateSalonHint);
      return;
    }
    final packages = _packagesForSalon(salonId);
    if (packages.isEmpty) {
      _showSnackBar('Nessun pacchetto disponibile per il salone associato.');
      return;
    }
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final selected = await _pickFromCatalog<ServicePackage>(
      title: 'Scegli un pacchetto',
      items: packages,
      labelBuilder: (pkg) => pkg.name,
      subtitleBuilder:
          (pkg) =>
              'Catalogo ${currency.format(pkg.fullPrice)} • Prezzo ${currency.format(pkg.price)}',
    );
    if (selected == null) {
      return;
    }
    _registerPackageLine(selected);
  }

  Future<void> _onAddInventoryItem() async {
    final salonId = _salonId;
    if (salonId == null) {
      _showSnackBar(_associateSalonHint);
      return;
    }
    final items = _inventoryForSalon(salonId);
    if (items.isEmpty) {
      _showSnackBar('Nessun prodotto disponibile per il salone associato.');
      return;
    }
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final selected = await _pickFromCatalog<InventoryItem>(
      title: 'Scegli un prodotto',
      items: items,
      labelBuilder: (item) => item.name,
      subtitleBuilder:
          (item) => '${item.category} • ${currency.format(item.sellingPrice)}',
    );
    if (selected == null) {
      return;
    }
    if (selected.quantity <= 0) {
      _showSnackBar('Prodotto esaurito in magazzino: ${selected.name}.');
      return;
    }
    final line = _createLineDraft(
      referenceType: SaleReferenceType.product,
      referenceId: selected.id,
      description: selected.name,
      quantity: 1,
      unitPrice:
          selected.sellingPrice > 0 ? selected.sellingPrice : selected.cost,
      catalogLabel: selected.category,
    );
    _registerLine(line);
  }

  void _onAddManualItem() {
    final line = _createLineDraft(
      referenceType: SaleReferenceType.product,
      description: 'Voce manuale',
      quantity: 1,
      unitPrice: 0,
    );
    _registerLine(line);
  }

  Future<void> _showAdditionalItemOptions() async {
    final action = await showAppModalSheet<_AdditionalSaleItemAction>(
      context: context,
      includeCloseButton: false,
      desktopMaxWidth: 420,
      builder: (ctx) {
        return DialogActionLayout(
          title: 'Aggiungi elemento',
          scrollBody: false,
          bodyPadding: EdgeInsets.zero,
          body: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text('Voce manuale'),
                  subtitle: const Text(
                    'Inserisci quantita e prezzo liberamente',
                  ),
                  onTap:
                      () => Navigator.of(
                        ctx,
                      ).pop(_AdditionalSaleItemAction.manualItem),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.auto_fix_high_rounded),
                  title: const Text('Pacchetto personalizzato'),
                  subtitle: const Text(
                    'Crea un pacchetto partendo dai servizi',
                  ),
                  onTap:
                      () => Navigator.of(
                        ctx,
                      ).pop(_AdditionalSaleItemAction.customPackage),
                ),
              ],
            ),
          ),
          actions: const [],
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _AdditionalSaleItemAction.manualItem:
        _onAddManualItem();
        break;
      case _AdditionalSaleItemAction.customPackage:
        await _onAddCustomPackage();
        break;
    }
  }

  Future<void> _onAddCustomPackage() async {
    final salonId = _salonId;
    if (salonId == null) {
      _showSnackBar(_associateSalonHint);
      return;
    }

    var salons = widget.salons.where((salon) => salon.id == salonId).toList();
    if (salons.isEmpty) {
      salons = widget.salons;
    }

    var services =
        widget.services.where((service) => service.salonId == salonId).toList();
    if (services.isEmpty) {
      services = widget.services;
    }

    if (salons.isEmpty || services.isEmpty) {
      _showSnackBar(
        'Nessun salone o servizio disponibile per creare un pacchetto personalizzato.',
      );
      return;
    }

    final customPackage = await showAppModalSheet<ServicePackage>(
      context: context,
      includeCloseButton: false,
      desktopMaxWidth: 1180,
      builder:
          (ctx) => PackageFormSheet(
            salons: salons,
            services: services,
            defaultSalonId: salonId,
          ),
    );

    if (!mounted || customPackage == null) {
      return;
    }

    _registerPackageLine(customPackage, isCustom: true);
  }

  void _registerPackageLine(ServicePackage pkg, {bool isCustom = false}) {
    final metadata = _PackageMetadata(
      isCustom: isCustom,
      sessionCount: pkg.totalConfiguredSessions,
      serviceSessions: Map<String, int>.from(pkg.serviceSessionCounts),
      validDays: pkg.validDays,
      status: PackagePurchaseStatus.active,
    );
    final description = pkg.name;
    final catalogLabel =
        pkg.description != null && pkg.description!.isNotEmpty
            ? pkg.description
            : null;
    final line = _createLineDraft(
      referenceType: SaleReferenceType.package,
      referenceId: pkg.id,
      description: description,
      quantity: 1,
      unitPrice: pkg.price,
      catalogLabel: catalogLabel,
      packageMetadata: metadata,
    );
    _registerLine(line);
  }

  Future<T?> _pickFromCatalog<T>({
    required String title,
    required List<T> items,
    required String Function(T) labelBuilder,
    String Function(T)? subtitleBuilder,
  }) {
    return showAppSelectionSheet<T>(
      context: context,
      title: title,
      items: items,
      labelBuilder: labelBuilder,
      subtitleBuilder: subtitleBuilder,
    );
  }

  List<Service> _servicesForSalon(String salonId) {
    return widget.services
        .where((service) => service.salonId == salonId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<ServicePackage> _packagesForSalon(String salonId) {
    return widget.packages.where((pkg) => pkg.salonId == salonId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<InventoryItem> _inventoryForSalon(String salonId) {
    return widget.inventoryItems
        .where((item) => item.salonId == salonId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  InventoryItem? _inventoryItemById(String? itemId) {
    if (itemId == null) {
      return null;
    }
    return widget.inventoryItems.firstWhereOrNull((item) => item.id == itemId);
  }

  _SaleLineDraft _createLineDraft({
    required SaleReferenceType referenceType,
    String? referenceId,
    required String description,
    double quantity = 1,
    double unitPrice = 0,
    String? catalogLabel,
    _PackageMetadata? packageMetadata,
    bool serviceCreatesSession = false,
    int? serviceRemainingSessions,
    bool serviceSessionToggleLocked = false,
    String? serviceSessionToggleLockMessage,
  }) {
    String formatQuantity(double value) {
      if (value % 1 == 0) {
        return value.toStringAsFixed(0);
      }
      return value.toStringAsFixed(2);
    }

    return _SaleLineDraft(
      id: _uuid.v4(),
      referenceType: referenceType,
      referenceId: referenceId,
      catalogLabel: catalogLabel,
      descriptionController: TextEditingController(text: description),
      quantityController: TextEditingController(text: formatQuantity(quantity)),
      priceController: TextEditingController(
        text: unitPrice.toStringAsFixed(2),
      ),
      packageMetadata: packageMetadata,
      serviceCreatesSession: serviceCreatesSession,
      serviceRemainingSessions: serviceRemainingSessions,
      serviceSessionToggleLocked: serviceSessionToggleLocked,
      serviceSessionToggleLockMessage: serviceSessionToggleLockMessage,
    );
  }

  _SaleLineDraft _lineFromSaleItem(SaleItem item) {
    _PackageMetadata? metadata;
    if (item.referenceType == SaleReferenceType.package) {
      final package = widget.packages.firstWhereOrNull(
        (pkg) => pkg.id == item.referenceId,
      );
      final packageSessions =
          item.packageServiceSessions.isNotEmpty
              ? Map<String, int>.from(item.packageServiceSessions)
              : package != null
              ? Map<String, int>.from(package.serviceSessionCounts)
              : <String, int>{};
      int? sessionCount;
      if (packageSessions.isEmpty) {
        if (package?.totalConfiguredSessions != null) {
          sessionCount = package!.totalConfiguredSessions;
        } else if (item.totalSessions != null && item.quantity > 0) {
          sessionCount = (item.totalSessions! / item.quantity).round();
        }
      } else {
        sessionCount = packageSessions.values.fold<int>(
          0,
          (sum, value) => sum + value,
        );
      }
      metadata = _PackageMetadata(
        isCustom: package == null,
        sessionCount: sessionCount,
        serviceSessions: packageSessions,
        validDays: package?.validDays,
        status: item.packageStatus ?? PackagePurchaseStatus.active,
        remainingSessions: item.remainingSessions,
        expirationDate: item.expirationDate,
      );
    }

    return _createLineDraft(
      referenceType: item.referenceType,
      referenceId: item.referenceId,
      description: item.description,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      packageMetadata: metadata,
      serviceCreatesSession: item.isServiceSessionCredit,
      serviceRemainingSessions:
          item.isServiceSessionCredit ? item.remainingSessions : null,
      serviceSessionToggleLocked:
          widget.lockInitialServiceSessionToggle &&
          item.referenceType == SaleReferenceType.service &&
          !item.isServiceSessionCredit,
      serviceSessionToggleLockMessage:
          widget.lockInitialServiceSessionToggle &&
                  item.referenceType == SaleReferenceType.service &&
                  !item.isServiceSessionCredit
              ? 'Servizio gia erogato: non puo creare una sessione disponibile.'
              : null,
    );
  }

  void _handleLineChanged() {
    _syncManualTotalWithSubtotal();
    _recalculateLoyalty();
    _updatePackageCoveragePreview();
    setState(() {});
  }

  void _handleManualTotalChanged() {
    if (_programmaticManualUpdate) {
      return;
    }
    setState(() {
      _manualTotalOverridden = true;
    });
    _recalculateLoyalty();
  }

  void _handlePaidAmountChanged() {
    if (_programmaticPaidUpdate) {
      return;
    }
    setState(() {});
  }

  void _syncPaidAmountWithTotal(double total) {
    if (_paymentStatus != SalePaymentStatus.deposit) {
      if (_paidAmountController.text.isEmpty) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _setPaidAmountText('');
      });
      return;
    }

    final amount = _parseAmount(_paidAmountController.text);
    if (amount == null) {
      if (_paidAmountController.text.isEmpty || total > 0) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _setPaidAmountText('');
      });
      return;
    }

    var clamped = amount;
    if (clamped < 0) {
      clamped = 0;
    }
    if (clamped > total) {
      clamped = total;
    }
    if ((clamped - amount).abs() > 0.01) {
      final next = clamped == 0 ? '' : clamped.toStringAsFixed(2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _setPaidAmountText(next);
      });
    }
  }

  void _setPaidAmountText(String value) {
    if (_paidAmountController.text == value) {
      return;
    }
    _programmaticPaidUpdate = true;
    _paidAmountController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _programmaticPaidUpdate = false;
    setState(() {});
  }

  double _remainingBalance(double total) {
    final paid = _parseAmount(_paidAmountController.text) ?? 0;
    final remaining = total - paid;
    if (remaining <= 0) {
      return 0;
    }
    return double.parse(remaining.toStringAsFixed(2));
  }

  void _syncManualTotalWithSubtotal({bool force = false, double? base}) {
    if (!force && _manualTotalOverridden) {
      return;
    }
    final subtotal = _computeSubtotal();
    final target = () {
      if (subtotal <= 0) {
        return 0.0;
      }
      final desired = base ?? subtotal;
      final num clamped = desired.clamp(0, subtotal);
      return clamped.toDouble();
    }();
    _programmaticManualUpdate = true;
    if (target <= 0) {
      _manualTotalController.clear();
    } else {
      _manualTotalController.text = target.toStringAsFixed(2);
    }
    _programmaticManualUpdate = false;
    _manualTotalOverridden = false;
  }

  double _computeSubtotal() {
    var total = 0.0;
    for (final line in _lines) {
      final quantity = _parseAmount(line.quantityController.text) ?? 0;
      final price = _parseAmount(line.priceController.text) ?? 0;
      total += (quantity * price);
    }
    return double.parse(total.toStringAsFixed(2));
  }

  double _currentManualDiscount(double subtotal) {
    if (subtotal <= 0) {
      return 0;
    }
    final manual = _parseAmount(_manualTotalController.text);
    if (manual == null) {
      return 0;
    }
    final num clamped = manual.clamp(0, subtotal);
    final discount = subtotal - clamped.toDouble();
    return double.parse(discount.toStringAsFixed(2));
  }

  double _currentTotal(double subtotal, double discount) {
    final total = subtotal - discount;
    if (total <= 0) {
      return 0;
    }
    return double.parse(total.toStringAsFixed(2));
  }

  double _lineTotal(_SaleLineDraft line) {
    final quantity = _parseAmount(line.quantityController.text) ?? 0;
    final price = _parseAmount(line.priceController.text) ?? 0;
    final total = quantity * price;
    return total <= 0 ? 0 : double.parse(total.toStringAsFixed(2));
  }

  bool _validateSaleBasics() {
    if (_salonId == null) {
      _showSnackBar(_associateSalonHint);
      return false;
    }
    if (_clientId == null) {
      _showSnackBar('Seleziona il cliente.');
      return false;
    }
    if (_lines.isEmpty) {
      _showSnackBar('Aggiungi almeno un elemento alla vendita.');
      return false;
    }
    final subtotal = _computeSubtotal();
    final manualDiscount = _currentManualDiscount(subtotal);
    final baseTotal = _currentTotal(subtotal, manualDiscount);
    final loyaltyValue = _normalizeCurrency(_loyaltySummary.redeemedValue);
    final total = _normalizeCurrency(baseTotal - loyaltyValue);
    if (total < -0.009) {
      _showSnackBar('Il totale della vendita non può essere negativo.');
      return false;
    }
    return true;
  }

  List<SaleItem>? _collectSaleItems() {
    final items = <SaleItem>[];
    final Map<String, double> inventoryUsage = {};
    for (final line in _lines) {
      final description = line.descriptionController.text.trim();
      final quantityValue = _parseAmount(line.quantityController.text) ?? 0;
      final unitPriceValue = _parseAmount(line.priceController.text) ?? 0;
      final quantity = double.parse(quantityValue.toStringAsFixed(2));
      final unitPrice = double.parse(unitPriceValue.toStringAsFixed(2));
      if (description.isEmpty || quantity <= 0 || unitPrice < 0) {
        _showSnackBar('Controlla le voci inserite: valori non validi.');
        return null;
      }
      final referencedInventoryId = line.referenceId;
      if (line.referenceType == SaleReferenceType.product &&
          referencedInventoryId != null) {
        final inventoryItem = _inventoryItemById(referencedInventoryId);
        if (inventoryItem == null) {
          _showSnackBar(
            'Il prodotto selezionato non è più presente in magazzino.',
          );
          return null;
        }
        final alreadyReserved = inventoryUsage[referencedInventoryId] ?? 0;
        final remaining = inventoryItem.quantity - alreadyReserved;
        if (remaining <= 0) {
          _showSnackBar('Prodotto esaurito: ${inventoryItem.name}.');
          return null;
        }
        if (quantity > remaining + 0.000001) {
          final availableText =
              remaining % 1 == 0
                  ? remaining.toStringAsFixed(0)
                  : remaining.toStringAsFixed(2);
          _showSnackBar(
            'Quantità non disponibile per ${inventoryItem.name}. '
            'Disponibili: $availableText ${inventoryItem.unit}.',
          );
          return null;
        }
        inventoryUsage[referencedInventoryId] = alreadyReserved + quantity;
      }
      final referenceId = line.referenceId ?? 'manual-${line.id}';
      final metadata = line.packageMetadata;
      final SaleItem saleItem;
      if (line.referenceType == SaleReferenceType.package) {
        saleItem = SaleItem(
          referenceId: referenceId,
          referenceType: line.referenceType,
          description: description,
          quantity: quantity,
          unitPrice: unitPrice,
          totalSessions: metadata?.totalSessions(quantity),
          remainingSessions: metadata?.remainingSessionsValue(quantity),
          expirationDate: metadata?.expiration(_date),
          packageStatus: metadata?.status,
          packageServiceSessions:
              metadata?.serviceSessions ?? const <String, int>{},
        );
      } else if (line.referenceType == SaleReferenceType.service &&
          line.serviceCreatesSession) {
        final sessionCount = quantity.round();
        if ((quantity - sessionCount).abs() > 0.000001 ||
            sessionCount <= 0 ||
            referenceId.isEmpty) {
          _showSnackBar(
            'Per una sessione utilizzabile inserisci una quantità intera.',
          );
          return null;
        }
        final rawRemaining = line.serviceRemainingSessions ?? sessionCount;
        final remainingSessions = rawRemaining.clamp(0, sessionCount).toInt();
        saleItem = SaleItem(
          referenceId: referenceId,
          referenceType: line.referenceType,
          description: description,
          quantity: quantity,
          unitPrice: unitPrice,
          totalSessions: sessionCount,
          remainingSessions: remainingSessions,
          packageStatus:
              remainingSessions <= 0
                  ? PackagePurchaseStatus.completed
                  : PackagePurchaseStatus.active,
          remainingPackageServiceSessions: <String, int>{
            referenceId: remainingSessions,
          },
        );
      } else {
        saleItem = SaleItem(
          referenceId: referenceId,
          referenceType: line.referenceType,
          description: description,
          quantity: quantity,
          unitPrice: unitPrice,
        );
      }
      items.add(saleItem);
    }
    return items;
  }

  List<_CoverageLine> _saleItemsFromDraftsForCoveragePreview() {
    final previewItems = <_CoverageLine>[];
    for (final line in _lines) {
      final description = line.descriptionController.text.trim();
      final quantityValue = _parseAmount(line.quantityController.text) ?? 0;
      final unitPriceValue = _parseAmount(line.priceController.text) ?? 0;
      final quantity = double.parse(quantityValue.toStringAsFixed(2));
      final unitPrice = double.parse(unitPriceValue.toStringAsFixed(2));
      final referenceId = line.referenceId ?? 'manual-${line.id}';
      if (line.referenceType == SaleReferenceType.package) {
        previewItems.add(
          _CoverageLine(
            lineId: line.id,
            item: SaleItem(
              referenceId: referenceId,
              referenceType: line.referenceType,
              description: description,
              quantity: quantity,
              unitPrice: unitPrice,
              packageServiceSessions:
                  line.packageMetadata?.serviceSessions ??
                  const <String, int>{},
            ),
          ),
        );
        continue;
      }
      if (line.referenceType == SaleReferenceType.service &&
          line.serviceCreatesSession) {
        final sessionCount = quantity.round();
        previewItems.add(
          _CoverageLine(
            lineId: line.id,
            item: SaleItem(
              referenceId: referenceId,
              referenceType: line.referenceType,
              description: description,
              quantity: quantity,
              unitPrice: unitPrice,
              totalSessions: sessionCount,
              remainingSessions: sessionCount,
              remainingPackageServiceSessions: <String, int>{
                referenceId: sessionCount,
              },
            ),
          ),
        );
        continue;
      }
      previewItems.add(
        _CoverageLine(
          lineId: line.id,
          item: SaleItem(
            referenceId: referenceId,
            referenceType: line.referenceType,
            description: description,
            quantity: quantity,
            unitPrice: unitPrice,
          ),
        ),
      );
    }
    return previewItems;
  }

  void _updatePackageCoveragePreview() {
    final coverage = _packageCoverageFromItems(
      _saleItemsFromDraftsForCoveragePreview(),
    );
    _coveredServices
      ..clear()
      ..addEntries(
        coverage.usedSessions.entries.map(
          (entry) => MapEntry(_serviceNameForId(entry.key), entry.value),
        ),
      );
    _coveredLineQuantities
      ..clear()
      ..addAll(coverage.coveredLineQuantities);
    _serviceCoverageDetails
      ..clear()
      ..addEntries(
        coverage.usedSessions.entries.map((entry) {
          final total = coverage.serviceTotals[entry.key] ?? entry.value;
          return MapEntry(
            _serviceNameForId(entry.key),
            _ServiceCoverageDetail(entry.value, total),
          );
        }),
      );
    _updateServiceLinePrices();
  }

  void _restoreLinePriceIfNeeded(_SaleLineDraft line) {
    final cached = _lineCachedPrices.remove(line.id);
    if (cached != null && line.priceController.text != cached) {
      line.priceController.text = cached;
    }
  }

  void _updateServiceLinePrices() {
    for (final line in _lines) {
      if (line.referenceType != SaleReferenceType.service ||
          line.serviceCreatesSession) {
        _lineCachedPrices.remove(line.id);
        continue;
      }

      final referenceId = line.referenceId;
      final quantity =
          (_parseAmount(line.quantityController.text) ?? 0).round();
      if (referenceId == null || referenceId.isEmpty || quantity <= 0) {
        _restoreLinePriceIfNeeded(line);
        continue;
      }

      final coveredQuantity = _coveredLineQuantities[line.id] ?? 0;
      final isCovered = coveredQuantity >= quantity && quantity > 0;
      if (isCovered) {
        _lineCachedPrices.putIfAbsent(line.id, () => line.priceController.text);
        const zeroPrice = '0.00';
        if (line.priceController.text != zeroPrice) {
          line.priceController.text = zeroPrice;
        }
      } else {
        _restoreLinePriceIfNeeded(line);
      }
    }
  }

  void _continueToPaymentStep() {
    FocusScope.of(context).unfocus();
    if (_isPaymentStep) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_validateSaleBasics()) {
      return;
    }
    if (_collectSaleItems() == null) {
      return;
    }
    setState(() {
      _isPaymentStep = true;
    });
    _jumpToSheetTop();
  }

  void _exitPaymentStep() {
    FocusScope.of(context).unfocus();
    if (!_isPaymentStep) {
      return;
    }
    setState(() {
      _isPaymentStep = false;
    });
    _jumpToSheetTop();
  }

  void _jumpToSheetTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetScrollController.hasClients) {
        return;
      }
      _sheetScrollController.jumpTo(0);
    });
  }

  void _submit() {
    if (!_isPaymentStep) {
      _continueToPaymentStep();
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_validateSaleBasics()) {
      return;
    }

    var items = _collectSaleItems();
    if (items == null) {
      return;
    }
    items = _applyPackageSessionCoverage(items);
    final subtotal = _computeSubtotal();
    final manualDiscount = _currentManualDiscount(subtotal);
    final baseTotal = _currentTotal(subtotal, manualDiscount);
    final loyaltyValue = _normalizeCurrency(_loyaltySummary.redeemedValue);
    final total = _normalizeCurrency(baseTotal - loyaltyValue);
    final totalDiscount = _normalizeCurrency(manualDiscount + loyaltyValue);

    final invoice = _invoiceController.text.trim();
    final notes = _notesController.text.trim();

    final requiresPayment = total > 0.009;

    final PaymentMethod paymentMethod;
    SalePaymentStatus paymentStatus;
    double paidAmount;
    if (requiresPayment) {
      final selectedStatus = _paymentStatus;
      if (selectedStatus == null) {
        _showSnackBar('Seleziona lo stato del pagamento.');
        return;
      }
      paymentStatus = selectedStatus;
      if (paymentStatus == SalePaymentStatus.posticipated) {
        paymentMethod = PaymentMethod.posticipated;
        paidAmount = 0.0;
      } else {
        final selectedMethod = _payment;
        if (selectedMethod == null) {
          _showSnackBar('Seleziona il metodo di pagamento.');
          return;
        }
        paymentMethod = selectedMethod;
        if (paymentStatus == SalePaymentStatus.deposit) {
          final amount = _parseAmount(_paidAmountController.text) ?? 0;
          if (amount <= 0) {
            _showSnackBar('Inserisci un importo valido per l\'acconto.');
            return;
          }
          if (amount > total + 0.01) {
            _showSnackBar('L\'acconto supera il totale della vendita.');
            return;
          }
          if ((total - amount).abs() < 0.01) {
            paymentStatus = SalePaymentStatus.paid;
            paidAmount = total;
          } else {
            paidAmount = double.parse(amount.toStringAsFixed(2));
          }
        } else {
          paidAmount = total;
        }
      }
    } else {
      paymentMethod = PaymentMethod.imp0;
      paymentStatus = SalePaymentStatus.paid;
      paidAmount = 0;
    }

    final adjustedItems = _applyPackagePayments(
      items,
      paymentStatus,
      paidAmount,
      paymentMethod,
    );

    final staffId = _staffId;
    final recordedStaffId = _resolvedRecorderStaffId();
    if (recordedStaffId == null) {
      _showSnackBar('Seleziona l\'operatore che registra la vendita.');
      return;
    }
    final recordedByName =
        _recorderStaff
            .firstWhereOrNull((member) => member.id == recordedStaffId)
            ?.fullName;
    final paymentMovements = <SalePaymentMovement>[];
    final shouldRegisterMovement =
        paymentStatus == SalePaymentStatus.posticipated || paidAmount > 0;
    if (shouldRegisterMovement) {
      final movementAmount =
          paymentStatus == SalePaymentStatus.posticipated ? 0.0 : paidAmount;
      final movementType =
          paymentStatus == SalePaymentStatus.paid
              ? SalePaymentType.settlement
              : SalePaymentType.deposit;
      paymentMovements.add(
        SalePaymentMovement(
          id: _uuid.v4(),
          amount: movementAmount,
          type: movementType,
          date: _date,
          paymentMethod: paymentMethod,
          recordedBy: recordedByName,
          note:
              movementType == SalePaymentType.deposit
                  ? 'Acconto iniziale'
                  : 'Saldo iniziale',
        ),
      );
    }

    final resolvedMetadata = () {
      if (widget.initialSaleId != null) {
        final existing = widget.sales.firstWhereOrNull(
          (sale) => sale.id == widget.initialSaleId,
        );
        if (existing != null && existing.metadata.isNotEmpty) {
          return existing.metadata;
        }
      }
      return const <String, dynamic>{'source': 'backoffice'};
    }();
    final saleMetadata = Map<String, dynamic>.from(resolvedMetadata);
    saleMetadata['recordedByStaffId'] = recordedStaffId;

    final sale = Sale(
      id: widget.initialSaleId ?? _uuid.v4(),
      salonId: _salonId!,
      clientId: _clientId!,
      items: adjustedItems,
      total: double.parse(total.toStringAsFixed(2)),
      createdAt: _date,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      paidAmount: paidAmount,
      invoiceNumber: invoice.isEmpty ? null : invoice,
      notes: notes.isEmpty ? null : notes,
      discountAmount: totalDiscount,
      staffId: staffId,
      paymentHistory: paymentMovements,
      loyalty: _loyaltySummary,
      metadata: saleMetadata,
    );

    if (widget.onSaved != null) {
      widget.onSaved!(sale);
      return;
    }
    Navigator.of(context).pop(sale);
  }

  List<SaleItem> _applyPackagePayments(
    List<SaleItem> items,
    SalePaymentStatus paymentStatus,
    double paidAmount,
    PaymentMethod paymentMethod,
  ) {
    if (!items.any((item) => item.referenceType == SaleReferenceType.package)) {
      return items;
    }
    final updated = <SaleItem>[];
    if (paymentStatus != SalePaymentStatus.paid) {
      var remaining =
          paymentStatus == SalePaymentStatus.posticipated ? 0.0 : paidAmount;
      for (final item in items) {
        if (item.referenceType == SaleReferenceType.package) {
          final lineTotal = item.amount;
          final applied = _normalizeCurrency(
            remaining <= 0
                ? 0
                : remaining >= lineTotal
                ? lineTotal
                : remaining,
          );
          remaining = _normalizeCurrency(remaining - applied);
          final status =
              applied >= lineTotal - 0.009
                  ? PackagePaymentStatus.paid
                  : PackagePaymentStatus.deposit;
          List<PackageDeposit> deposits = item.deposits;
          if (deposits.isEmpty && applied > 0.009) {
            deposits = [
              PackageDeposit(
                id: _uuid.v4(),
                amount: applied,
                date: _date,
                note: 'Acconto iniziale',
                paymentMethod: paymentMethod,
              ),
            ];
          }
          updated.add(
            item.copyWith(
              depositAmount: applied,
              packagePaymentStatus: status,
              deposits: deposits,
            ),
          );
        } else {
          updated.add(item);
        }
      }
    } else {
      for (final item in items) {
        if (item.referenceType == SaleReferenceType.package) {
          updated.add(
            item.copyWith(
              depositAmount: _normalizeCurrency(item.amount),
              packagePaymentStatus: PackagePaymentStatus.paid,
            ),
          );
        } else {
          updated.add(item);
        }
      }
    }
    return updated;
  }

  double _normalizeCurrency(double value) {
    if (value <= 0) {
      return 0;
    }
    return double.parse(value.toStringAsFixed(2));
  }

  double? _parseAmount(String? value) {
    if (value == null) {
      return null;
    }
    final sanitized = value.replaceAll(',', '.').trim();
    if (sanitized.isEmpty) {
      return null;
    }
    return double.tryParse(sanitized);
  }

  IconData _lineTypeIcon(SaleReferenceType type) {
    switch (type) {
      case SaleReferenceType.service:
        return Icons.content_cut_rounded;
      case SaleReferenceType.package:
        return Icons.widgets_outlined;
      case SaleReferenceType.product:
        return Icons.shopping_bag_outlined;
    }
  }

  Widget _buildPackageCoverageSummary(ThemeData theme) {
    if (_serviceCoverageDetails.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Copertura pacchetti', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final entry in _serviceCoverageDetails.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _coverageSummaryText(entry.key, entry.value),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _coverageSummaryText(
    String serviceName,
    _ServiceCoverageDetail detail,
  ) {
    if (detail.total > 0) {
      final remaining = detail.remaining;
      return '$serviceName: ${detail.used} sessioni scalate · $remaining/${detail.total} rimanenti';
    }
    return '$serviceName: ${detail.used} sessioni scalate';
  }

  List<SaleItem> _applyPackageSessionCoverage(List<SaleItem> items) {
    if (!items.any((item) => item.referenceType == SaleReferenceType.package)) {
      _coveredServices.clear();
      return items;
    }
    final usedSessions = <String, int>{};
    final updatedPackages = <int, SaleItem>{};
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.referenceType == SaleReferenceType.package) {
        updatedPackages[i] = item;
      }
    }
    final adjustedItems = <SaleItem>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.referenceType == SaleReferenceType.package) {
        adjustedItems.add(updatedPackages[i]!);
        continue;
      }
      if (item.referenceType == SaleReferenceType.service) {
        if (item.isServiceSessionCredit) {
          adjustedItems.add(item);
          continue;
        }
        final fullyCovered = _consumeServiceFromPackages(
          serviceItem: item,
          packages: updatedPackages,
          usedSessions: usedSessions,
        );
        if (fullyCovered) {
          adjustedItems.add(item.copyWith(unitPrice: 0));
          continue;
        }
      }
      adjustedItems.add(item);
    }
    _coveredServices
      ..clear()
      ..addEntries(
        usedSessions.entries.map(
          (entry) => MapEntry(_serviceNameForId(entry.key), entry.value),
        ),
      );
    return adjustedItems;
  }

  _PackageCoverageResult _packageCoverageFromItems(List<_CoverageLine> items) {
    final usedSessions = <String, int>{};
    final coveredLines = <String, int>{};
    final serviceTotals = <String, int>{};
    final updatedPackages = <int, SaleItem>{};
    for (var i = 0; i < items.length; i++) {
      final item = items[i].item;
      if (item.referenceType == SaleReferenceType.package) {
        updatedPackages[i] = item;
        for (final entry in item.packageServiceSessions.entries) {
          serviceTotals.update(
            entry.key,
            (value) => value + entry.value,
            ifAbsent: () => entry.value,
          );
        }
      }
    }
    for (var i = 0; i < items.length; i++) {
      final item = items[i].item;
      if (item.referenceType != SaleReferenceType.service ||
          item.isServiceSessionCredit) {
        continue;
      }
      final fullyCovered = _consumeServiceFromPackages(
        serviceItem: item,
        packages: updatedPackages,
        usedSessions: usedSessions,
      );
      if (fullyCovered) {
        coveredLines[items[i].lineId] = item.quantity.round();
      }
    }
    return _PackageCoverageResult(usedSessions, coveredLines, serviceTotals);
  }

  bool _consumeServiceFromPackages({
    required SaleItem serviceItem,
    required Map<int, SaleItem> packages,
    required Map<String, int> usedSessions,
  }) {
    final serviceId = serviceItem.referenceId;
    if (serviceId.isEmpty) {
      return false;
    }
    var remaining = serviceItem.quantity.round();
    if (remaining <= 0) {
      return false;
    }
    var consumedAny = false;
    for (final index in packages.keys.toList()) {
      if (remaining <= 0) {
        break;
      }
      var packageItem = packages[index]!;
      final sessions = packageItem.packageServiceSessions[serviceId] ?? 0;
      if (sessions <= 0) {
        continue;
      }
      final use = math.min(sessions, remaining);
      remaining -= use;
      consumedAny = true;
      usedSessions.update(
        serviceId,
        (value) => value + use,
        ifAbsent: () => use,
      );
      final updatedSessions = Map<String, int>.from(
        packageItem.packageServiceSessions,
      );
      final updatedValue = sessions - use;
      if (updatedValue > 0) {
        updatedSessions[serviceId] = updatedValue;
      } else {
        updatedSessions.remove(serviceId);
      }
      packageItem = packageItem.copyWith(
        packageServiceSessions: updatedSessions,
      );
      packages[index] = packageItem;
    }
    return consumedAny && remaining <= 0;
  }

  String _serviceNameForId(String serviceId) {
    final service = widget.services.firstWhereOrNull(
      (item) => item.id == serviceId,
    );
    return service?.name ?? 'Servizio';
  }

  String _lineDisplayLabel(_SaleLineDraft line, int index) {
    final description =
        line.catalogLabel?.trim().isNotEmpty == true
            ? line.catalogLabel!.trim()
            : line.descriptionController.text.trim();
    if (description.isNotEmpty) {
      return description;
    }
    return 'Voce ${index + 1}';
  }

  String _paymentLabel(PaymentMethod method) {
    return method.label;
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    context.showAppNotice(message, tone: inferAppNoticeTone(message));
  }
}

class _PackageMetadata {
  _PackageMetadata({
    required this.isCustom,
    this.sessionCount,
    Map<String, int>? serviceSessions,
    this.validDays,
    this.status = PackagePurchaseStatus.active,
    this.remainingSessions,
    this.expirationDate,
  }) : serviceSessions =
           serviceSessions == null
               ? const <String, int>{}
               : Map.unmodifiable(serviceSessions);

  final bool isCustom;
  final int? sessionCount;
  final Map<String, int> serviceSessions;
  final int? validDays;
  final PackagePurchaseStatus status;
  final int? remainingSessions;
  final DateTime? expirationDate;

  int? _perPackageSessions() {
    if (serviceSessions.isNotEmpty) {
      return serviceSessions.values.fold<int>(0, (sum, value) => sum + value);
    }
    return sessionCount;
  }

  int? totalSessions(double quantity) {
    final perPackage = _perPackageSessions();
    if (perPackage == null) {
      return null;
    }
    final total = perPackage * quantity;
    return total.isFinite ? total.round() : null;
  }

  int? remainingSessionsValue(double quantity) {
    if (remainingSessions != null) {
      return remainingSessions;
    }
    return totalSessions(quantity);
  }

  DateTime? expiration(DateTime saleDate) {
    if (expirationDate != null) {
      return expirationDate;
    }
    if (validDays == null) {
      return null;
    }
    return saleDate.add(Duration(days: validDays!));
  }
}

class _SaleLineDraft {
  _SaleLineDraft({
    required this.id,
    required this.referenceType,
    this.referenceId,
    this.catalogLabel,
    required this.descriptionController,
    required this.quantityController,
    required this.priceController,
    this.packageMetadata,
    this.serviceCreatesSession = false,
    this.serviceRemainingSessions,
    this.serviceSessionToggleLocked = false,
    this.serviceSessionToggleLockMessage,
  });

  final String id;
  final SaleReferenceType referenceType;
  final String? referenceId;
  final String? catalogLabel;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final _PackageMetadata? packageMetadata;
  bool serviceCreatesSession;
  final int? serviceRemainingSessions;
  final bool serviceSessionToggleLocked;
  final String? serviceSessionToggleLockMessage;

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}

class _CoverageLine {
  const _CoverageLine({required this.lineId, required this.item});

  final String lineId;
  final SaleItem item;
}

class _PackageCoverageResult {
  _PackageCoverageResult(
    this.usedSessions,
    this.coveredLineQuantities,
    this.serviceTotals,
  );

  final Map<String, int> usedSessions;
  final Map<String, int> coveredLineQuantities;
  final Map<String, int> serviceTotals;
}

class _ServiceCoverageDetail {
  _ServiceCoverageDetail(this.used, this.total);

  final int used;
  final int total;

  int get remaining {
    if (total <= used) {
      return 0;
    }
    return total - used;
  }
}
