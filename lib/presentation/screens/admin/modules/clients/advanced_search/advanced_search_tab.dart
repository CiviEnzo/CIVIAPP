import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/presentation/screens/admin/modules/client_detail_page.dart';
import 'package:you_book/presentation/screens/admin/modules/clients/advanced_search/advanced_search_controller.dart';
import 'package:you_book/presentation/screens/admin/modules/clients/advanced_search/advanced_search_filters.dart';

class AdvancedSearchTab extends ConsumerStatefulWidget {
  const AdvancedSearchTab({
    super.key,
    required this.salonId,
    required this.onCreateClient,
    required this.onImportClients,
    required this.onEditClient,
    required this.onSendInvite,
    required this.isSendingInvite,
  });

  final String? salonId;
  final Future<void> Function() onCreateClient;
  final Future<void> Function() onImportClients;
  final Future<void> Function(Client client) onEditClient;
  final Future<void> Function(Client client) onSendInvite;
  final bool Function(String clientId) isSendingInvite;

  @override
  ConsumerState<AdvancedSearchTab> createState() => _AdvancedSearchTabState();
}

class _AdvancedSearchTabState extends ConsumerState<AdvancedSearchTab> {
  late AutoDisposeStateNotifierProvider<
    AdvancedClientSearchController,
    AdvancedClientSearchState
  > _provider;
  late ProviderSubscription<AdvancedClientSearchState> _subscription;

  final TextEditingController _generalQueryController = TextEditingController();
  final TextEditingController _clientNumberController = TextEditingController();
  final TextEditingController _clientNumberFromController = TextEditingController();
  final TextEditingController _clientNumberToController = TextEditingController();
  final TextEditingController _minAgeController = TextEditingController();
  final TextEditingController _maxAgeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _professionController = TextEditingController();
  final TextEditingController _loyaltyMinController = TextEditingController();
  final TextEditingController _loyaltyMaxController = TextEditingController();
  final TextEditingController _totalSpentMinController = TextEditingController();
  final TextEditingController _totalSpentMaxController = TextEditingController();
  final TextEditingController _lastPurchaseWithinController = TextEditingController();
  final TextEditingController _lastPurchaseOlderController = TextEditingController();
  final TextEditingController _upcomingWithinController = TextEditingController();
  final TextEditingController _lastCompletedWithinController = TextEditingController();
  final TextEditingController _lastCompletedOlderController = TextEditingController();

  final ScrollController _filtersScrollController = ScrollController();
  final ScrollController _resultsScrollController = ScrollController();

  String? _selectedClientId;

  @override
  void initState() {
    super.initState();
    _provider = advancedClientSearchControllerProvider(widget.salonId);
    final initialState = ref.read(_provider);
    _syncControllers(initialState.filters);
    _subscription = ref.listenManual<AdvancedClientSearchState>(
      _provider,
      (previous, next) {
        _syncControllers(next.filters);
        if (_selectedClientId != null &&
            !next.results.any((client) => client.id == _selectedClientId)) {
          if (mounted) {
            setState(() => _selectedClientId = null);
          }
        }
      },
    );
  }

  @override
  void didUpdateWidget(covariant AdvancedSearchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.salonId != widget.salonId) {
      _subscription.close();
      _provider = advancedClientSearchControllerProvider(widget.salonId);
      final initialState = ref.read(_provider);
      _syncControllers(initialState.filters);
      _subscription = ref.listenManual<AdvancedClientSearchState>(
        _provider,
        (previous, next) {
          _syncControllers(next.filters);
          if (_selectedClientId != null &&
              !next.results.any((client) => client.id == _selectedClientId)) {
            if (mounted) {
              setState(() => _selectedClientId = null);
            }
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _subscription.close();
    _generalQueryController.dispose();
    _clientNumberController.dispose();
    _clientNumberFromController.dispose();
    _clientNumberToController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    _cityController.dispose();
    _professionController.dispose();
    _loyaltyMinController.dispose();
    _loyaltyMaxController.dispose();
    _totalSpentMinController.dispose();
    _totalSpentMaxController.dispose();
    _lastPurchaseWithinController.dispose();
    _lastPurchaseOlderController.dispose();
    _upcomingWithinController.dispose();
    _lastCompletedWithinController.dispose();
    _lastCompletedOlderController.dispose();
    _filtersScrollController.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final data = ref.watch(appDataProvider);
    final filters = state.filters;

    final services = data.services
        .where(
          (service) =>
              widget.salonId == null || service.salonId == widget.salonId,
        )
        .sorted((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final categories = data.serviceCategories
        .where(
          (category) =>
              widget.salonId == null || category.salonId == widget.salonId,
        )
        .sorted((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final referralOptions = kClientReferralSourceOptions;

    final totalResults = state.results.length;
    final showResults = state.hasSearched || state.results.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final filtersWidget = _buildFilters(
          context: context,
          filters: filters,
          services: services,
          categories: categories,
          referralSources: referralOptions,
          isApplying: state.isApplying,
          compact: !isWide,
        );
        final resultsChildren = _buildResultsChildren(
          context: context,
          state: state,
          appData: data,
          totalResults: totalResults,
          showResults: showResults,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 48,
                child: Scrollbar(
                  controller: _filtersScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _filtersScrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 24, 24),
                    child: filtersWidget,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 52,
                child: Scrollbar(
                  controller: _resultsScrollController,
                  thumbVisibility: true,
                  child: ListView(
                    controller: _resultsScrollController,
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 24),
                    children: resultsChildren,
                  ),
                ),
              ),
            ],
          );
        }

        return Scrollbar(
          controller: _resultsScrollController,
          child: ListView(
            controller: _resultsScrollController,
            padding: const EdgeInsets.all(16),
            children: [
              filtersWidget,
              const SizedBox(height: 16),
              ...resultsChildren,
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilters({
    required BuildContext context,
    required AdvancedSearchFilters filters,
    required List<Service> services,
    required List<ServiceCategory> categories,
    required List<String> referralSources,
    required bool isApplying,
    required bool compact,
  }) {
    final spacing = compact ? 12.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActionsRow(
          context: context,
          isApplying: isApplying,
          compact: compact,
        ),
        SizedBox(height: spacing),
        _buildFilterCard(
          context: context,
          title: 'Ricerca rapida',
          compact: compact,
          initiallyExpanded: !compact,
          children: [
            _buildTextField(
              controller: _generalQueryController,
              label: 'Testo generico (nome, telefono, email, note)',
              icon: Icons.search_rounded,
              onChanged: (value) => _updateFilter(
                (builder) => builder.generalQuery = value,
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _clientNumberController,
              label: 'Numero cliente esatto',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              onChanged: (value) => _updateFilter(
                (builder) => builder.clientNumberExact =
                    value.trim().isEmpty ? null : value.trim(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _clientNumberFromController,
                    label: 'Numero cliente da',
                    icon: Icons.filter_alt_outlined,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.clientNumberFrom =
                          value.trim().isEmpty ? null : int.tryParse(value),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _clientNumberToController,
                    label: 'Numero cliente a',
                    icon: Icons.filter_alt_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.clientNumberTo =
                          value.trim().isEmpty ? null : int.tryParse(value),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: spacing),
        _buildFilterCard(
          context: context,
          title: 'Anagrafica',
          compact: compact,
          initiallyExpanded: false,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _cityController,
                    label: 'Città',
                    icon: Icons.location_city_rounded,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.city =
                          value.trim().isEmpty ? null : value.trim(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _professionController,
                    label: 'Professione',
                    icon: Icons.work_outline_rounded,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.profession =
                          value.trim().isEmpty ? null : value.trim(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildGenderChips(filters.genders),
            const SizedBox(height: 12),
            _buildReferralChips(
              selection: filters.referralSources,
              options: referralSources,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTriStateChoice(
                    label: 'Email presente',
                    value: filters.hasEmail,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.hasEmail = value,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTriStateChoice(
                    label: 'Telefono presente',
                    value: filters.hasPhone,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.hasPhone = value,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTriStateChoice(
              label: 'Note inserite',
              value: filters.hasNotes,
              onChanged: (value) => _updateFilter(
                (builder) => builder.hasNotes = value,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing),
        _buildFilterCard(
          context: context,
          title: 'Date e ricorrenze',
          compact: compact,
          initiallyExpanded: false,
          children: [
            _buildDateRangePickerRow(
              context: context,
              label: 'Creati tra',
              start: filters.createdAtFrom,
              end: filters.createdAtTo,
              onSelected: (range) => _updateFilter((builder) {
                builder.createdAtFrom = range?.start;
                builder.createdAtTo = range?.end;
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _minAgeController,
                    label: 'Età minima',
                    icon: Icons.cake_outlined,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.minAge =
                          value.trim().isEmpty ? null : int.tryParse(value),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _maxAgeController,
                    label: 'Età massima',
                    icon: Icons.cake_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.maxAge =
                          value.trim().isEmpty ? null : int.tryParse(value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDateRangePickerRow(
              context: context,
              label: 'Nati tra',
              start: filters.dateOfBirthFrom,
              end: filters.dateOfBirthTo,
              onSelected: (range) => _updateFilter((builder) {
                builder.dateOfBirthFrom = range?.start;
                builder.dateOfBirthTo = range?.end;
              }),
            ),
            const SizedBox(height: 12),
            _buildBirthdayShortcutSelector(filters.birthdayShortcut),
          ],
        ),
        SizedBox(height: spacing),
        _buildFilterCard(
          context: context,
          title: 'Onboarding e App',
          compact: compact,
          initiallyExpanded: false,
          children: [
            _buildOnboardingStatusChips(filters.onboardingStatuses),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTriStateChoice(
                    label: 'Ha effettuato il primo login',
                    value: filters.hasFirstLogin,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.hasFirstLogin = value,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTriStateChoice(
                    label: 'Ha token push',
                    value: filters.hasPushToken,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.hasPushToken = value,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: spacing),
        _buildFilterCard(
          context: context,
          title: 'Punti fedeltà',
          compact: compact,
          initiallyExpanded: false,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _loyaltyMinController,
                    label: 'Punti minimi',
                    icon: Icons.star_border_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.loyaltyPointsMin =
                          value.trim().isEmpty ? null : int.tryParse(value),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _loyaltyMaxController,
                    label: 'Punti massimi',
                    icon: Icons.star_rate_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.loyaltyPointsMax =
                          value.trim().isEmpty ? null : int.tryParse(value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSingleDatePickerRow(
              context: context,
              label: 'Punti aggiornati dopo',
              value: filters.loyaltyUpdatedSince,
              onSelected: (date) => _updateFilter(
                (builder) => builder.loyaltyUpdatedSince = date,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing),
        _buildFilterCard(
          context: context,
          title: 'Appuntamenti',
          compact: compact,
          initiallyExpanded: false,
          children: [
            _buildTextField(
              controller: _upcomingWithinController,
              label: 'Prossimo appuntamento entro (giorni)',
              icon: Icons.event_available_rounded,
              keyboardType: TextInputType.number,
              onChanged: (value) => _updateFilter(
                (builder) => builder.upcomingAppointmentWithinDays =
                    value.trim().isEmpty ? null : int.tryParse(value),
              ),
            ),
            const SizedBox(height: 12),
            _buildMultiSelectField(
              context: context,
              label: 'Servizi prossimi appuntamenti',
              items: services.map(_SelectableItem.fromService).toList(),
              selection: filters.upcomingAppointmentServiceIds,
              onSelected: (value) => _updateFilter(
                (builder) => builder.upcomingAppointmentServiceIds = value,
              ),
            ),
            const SizedBox(height: 12),
            _buildMultiSelectField(
              context: context,
              label: 'Categorie prossimi appuntamenti',
              items: categories.map(_SelectableItem.fromCategory).toList(),
              selection: filters.upcomingAppointmentCategoryIds,
              onSelected: (value) => _updateFilter(
                (builder) => builder.upcomingAppointmentCategoryIds = value,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _lastCompletedWithinController,
                    label: 'Ultima seduta entro (giorni)',
                    icon: Icons.event_note_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.lastCompletedWithinDays =
                          value.trim().isEmpty ? null : int.tryParse(value),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _lastCompletedOlderController,
                    label: 'Ultima seduta oltre (giorni)',
                    icon: Icons.history_toggle_off_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.lastCompletedOlderThanDays =
                          value.trim().isEmpty ? null : int.tryParse(value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMultiSelectField(
              context: context,
              label: 'Servizi ultima seduta',
              items: services.map(_SelectableItem.fromService).toList(),
              selection: filters.lastCompletedServiceIds,
              onSelected: (value) => _updateFilter(
                (builder) => builder.lastCompletedServiceIds = value,
              ),
            ),
            const SizedBox(height: 12),
            _buildMultiSelectField(
              context: context,
              label: 'Categorie ultima seduta',
              items: categories.map(_SelectableItem.fromCategory).toList(),
              selection: filters.lastCompletedCategoryIds,
              onSelected: (value) => _updateFilter(
                (builder) => builder.lastCompletedCategoryIds = value,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing),
        _buildFilterCard(
          context: context,
          title: 'Vendite',
          compact: compact,
          initiallyExpanded: false,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _totalSpentMinController,
                    label: 'Importo minimo',
                    icon: Icons.euro_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.totalSpentMin =
                          value.trim().isEmpty ? null : double.tryParse(value),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _totalSpentMaxController,
                    label: 'Importo massimo',
                    icon: Icons.payments_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.totalSpentMax =
                          value.trim().isEmpty ? null : double.tryParse(value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDateRangePickerRow(
              context: context,
              label: 'Vendite tra',
              start: filters.totalSpentFrom,
              end: filters.totalSpentTo,
              onSelected: (range) => _updateFilter((builder) {
                builder.totalSpentFrom = range?.start;
                builder.totalSpentTo = range?.end;
              }),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: filters.usePaidAmount,
              onChanged: (value) => _updateFilter(
                (builder) => builder.usePaidAmount = value,
              ),
              title: const Text('Usa importi incassati (paidAmount)'),
            ),
            const SizedBox(height: 12),
            _buildTriStateChoice(
              label: 'Saldo residuo > 0',
              value: filters.hasOutstandingBalance,
              onChanged: (value) => _updateFilter(
                (builder) => builder.hasOutstandingBalance = value,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _lastPurchaseWithinController,
                    label: 'Ultimo acquisto entro (giorni)',
                    icon: Icons.shopping_bag_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.lastPurchaseWithinDays =
                          value.trim().isEmpty ? null : int.tryParse(value),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _lastPurchaseOlderController,
                    label: 'Ultimo acquisto oltre (giorni)',
                    icon: Icons.history_outlined,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _updateFilter(
                      (builder) => builder.lastPurchaseOlderThanDays =
                          value.trim().isEmpty ? null : int.tryParse(value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMultiSelectField(
              context: context,
              label: 'Servizi da includere',
              items: services.map(_SelectableItem.fromService).toList(),
              selection: filters.includeSaleServiceIds,
              onSelected: (value) => _updateFilter(
                (builder) => builder.includeSaleServiceIds = value,
              ),
            ),
            const SizedBox(height: 12),
            _buildMultiSelectField(
              context: context,
              label: 'Servizi da escludere',
              items: services.map(_SelectableItem.fromService).toList(),
              selection: filters.excludeSaleServiceIds,
              onSelected: (value) => _updateFilter(
                (builder) => builder.excludeSaleServiceIds = value,
              ),
            ),
            const SizedBox(height: 12),
            _buildMultiSelectField(
              context: context,
              label: 'Categorie da includere',
              items: categories.map(_SelectableItem.fromCategory).toList(),
              selection: filters.includeSaleCategoryIds,
              onSelected: (value) => _updateFilter(
                (builder) => builder.includeSaleCategoryIds = value,
              ),
            ),
            const SizedBox(height: 12),
            _buildMultiSelectField(
              context: context,
              label: 'Categorie da escludere',
              items: categories.map(_SelectableItem.fromCategory).toList(),
              selection: filters.excludeSaleCategoryIds,
              onSelected: (value) => _updateFilter(
                (builder) => builder.excludeSaleCategoryIds = value,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: filters.onlyLastMinuteSales,
              onChanged: (value) => _updateFilter(
                (builder) => builder.onlyLastMinuteSales = value,
              ),
              title: const Text('Solo vendite last-minute'),
            ),
          ],
        ),
        SizedBox(height: spacing),
        _buildFilterCard(
          context: context,
          title: 'Pacchetti',
          compact: compact,
          initiallyExpanded: false,
          children: [
            _buildTriStateChoice(
              label: 'Ha pacchetti attivi',
              value: filters.hasActivePackages,
              onChanged: (value) => _updateFilter(
                (builder) => builder.hasActivePackages = value,
              ),
            ),
            const SizedBox(height: 12),
            _buildTriStateChoice(
              label: 'Ha sessioni residue',
              value: filters.hasPackagesWithRemainingSessions,
              onChanged: (value) => _updateFilter(
                (builder) => builder.hasPackagesWithRemainingSessions = value,
              ),
            ),
            const SizedBox(height: 12),
            _buildTriStateChoice(
              label: 'Ha pacchetti scaduti',
              value: filters.hasExpiredPackages,
              onChanged: (value) => _updateFilter(
                (builder) => builder.hasExpiredPackages = value,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionsRow({
    required BuildContext context,
    required bool isApplying,
    required bool compact,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: compact ? WrapAlignment.start : WrapAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: isApplying ? null : () => ref.read(_provider.notifier).apply(),
          icon: isApplying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.manage_search_rounded),
          label: Text(isApplying ? 'In corso...' : 'Cerca'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(_provider.notifier).clear();
            setState(() => _selectedClientId = null);
          },
          icon: const Icon(Icons.clear_rounded),
          label: const Text('Azzera'),
        ),
        FilledButton.icon(
          onPressed: widget.onCreateClient,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Nuovo cliente'),
        ),
        OutlinedButton.icon(
          onPressed: widget.onImportClients,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Importa CSV'),
        ),
      ],
    );
  }

  Widget _buildFilterCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
    required bool compact,
    bool initiallyExpanded = false,
  }) {
    final bodyChildren = _withSpacing(
      children,
      compact ? 12 : 16,
    ).toList();
    if (compact) {
      return Card(
        elevation: 1.5,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(title, style: Theme.of(context).textTheme.titleMedium),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: bodyChildren,
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      elevation: 2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...bodyChildren,
          ],
        ),
      ),
    );
  }

  Iterable<Widget> _withSpacing(List<Widget> widgets, double spacing) sync* {
    for (var i = 0; i < widgets.length; i++) {
      yield widgets[i];
      if (i != widgets.length - 1) {
        yield SizedBox(height: spacing);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildGenderChips(Set<String> selection) {
    const genders = <_SelectableItem>[
      _SelectableItem(id: 'male', label: 'Uomo'),
      _SelectableItem(id: 'female', label: 'Donna'),
      _SelectableItem(id: 'other', label: 'Altro'),
    ];
    return _buildChipSelector(
      title: 'Sesso',
      options: genders,
      selection: selection,
      onSelectionChanged: (value) => _updateFilter(
        (builder) => builder.genders = value,
      ),
    );
  }

  Widget _buildReferralChips({
    required Set<String> selection,
    required List<String> options,
  }) {
    final items = options
        .map(
          (option) => _SelectableItem(
            id: option.toLowerCase(),
            label: option,
          ),
        )
        .toList();
    final normalizedSelection = selection.map((value) => value.toLowerCase()).toSet();
    return _buildChipSelector(
      title: 'Come ci ha conosciuti',
      options: items,
      selection: normalizedSelection,
      onSelectionChanged: (value) => _updateFilter(
        (builder) => builder.referralSources = value,
      ),
    );
  }

  Widget _buildChipSelector({
    required String title,
    required List<_SelectableItem> options,
    required Set<String> selection,
    required ValueChanged<Set<String>> onSelectionChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => FilterChip(
                  selected: selection.contains(option.id),
                  label: Text(option.label),
                  onSelected: (selected) {
                    final updated = Set<String>.from(selection);
                    if (selected) {
                      updated.add(option.id);
                    } else {
                      updated.remove(option.id);
                    }
                    onSelectionChanged(updated);
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTriStateChoice({
    required String label,
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Qualsiasi'),
              selected: value == null,
              onSelected: (_) => onChanged(null),
            ),
            ChoiceChip(
              label: const Text('Sì'),
              selected: value == true,
              onSelected: (_) => onChanged(true),
            ),
            ChoiceChip(
              label: const Text('No'),
              selected: value == false,
              onSelected: (_) => onChanged(false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBirthdayShortcutSelector(
    AdvancedSearchBirthdayShortcut shortcut,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compleanni in arrivo',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Nessun filtro'),
              selected: shortcut == AdvancedSearchBirthdayShortcut.none,
              onSelected: (_) => _updateFilter(
                (builder) =>
                    builder.birthdayShortcut = AdvancedSearchBirthdayShortcut.none,
              ),
            ),
            ChoiceChip(
              label: const Text('Prossima settimana'),
              selected: shortcut == AdvancedSearchBirthdayShortcut.nextWeek,
              onSelected: (_) => _updateFilter(
                (builder) =>
                    builder.birthdayShortcut = AdvancedSearchBirthdayShortcut.nextWeek,
              ),
            ),
            ChoiceChip(
              label: const Text('Prossimo mese'),
              selected: shortcut == AdvancedSearchBirthdayShortcut.nextMonth,
              onSelected: (_) => _updateFilter(
                (builder) =>
                    builder.birthdayShortcut = AdvancedSearchBirthdayShortcut.nextMonth,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOnboardingStatusChips(
    Set<ClientOnboardingStatus> selection,
  ) {
    final options = ClientOnboardingStatus.values
        .map(
          (status) => _SelectableItem(
            id: status.name,
            label: _statusLabel(status),
          ),
        )
        .toList();
    final selectionIds = selection.map((status) => status.name).toSet();
    return _buildChipSelector(
      title: 'Stato onboarding',
      options: options,
      selection: selectionIds,
      onSelectionChanged: (value) => _updateFilter(
        (builder) => builder.onboardingStatuses = value
            .map(
              (id) => ClientOnboardingStatus.values.firstWhere(
                (status) => status.name == id,
                orElse: () => ClientOnboardingStatus.notSent,
              ),
            )
            .toSet(),
      ),
    );
  }

  Widget _buildDateRangePickerRow({
    required BuildContext context,
    required String label,
    required DateTime? start,
    required DateTime? end,
    required ValueChanged<DateTimeRange?> onSelected,
  }) {
    final format = DateFormat('dd/MM/yyyy');
    final hasSelection = start != null || end != null;
    final text = hasSelection
        ? '${start != null ? format.format(start) : '…'} - ${end != null ? format.format(end) : '…'}'
        : 'Nessun intervallo selezionato';
    return _RangeButton(
      label: label,
      valueLabel: text,
      onClear: hasSelection ? () => onSelected(null) : null,
      onPressed: () async {
        final now = DateTime.now();
        final initialRange =
            (start != null && end != null)
                ? DateTimeRange(start: start, end: end)
                : DateTimeRange(
                    start: DateTime(now.year, now.month, now.day),
                    end: DateTime(now.year, now.month, now.day),
                  );
        final picked = await showDateRangePicker(
          context: context,
          initialDateRange: initialRange,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        onSelected(picked);
      },
    );
  }

  Widget _buildSingleDatePickerRow({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onSelected,
  }) {
    final format = DateFormat('dd/MM/yyyy');
    return _RangeButton(
      label: label,
      valueLabel: value != null ? format.format(value) : 'Nessuna data',
      onClear: value != null ? () => onSelected(null) : null,
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialDate: value ?? DateTime.now(),
        );
        onSelected(picked);
      },
    );
  }

  Widget _buildMultiSelectField({
    required BuildContext context,
    required String label,
    required List<_SelectableItem> items,
    required Set<String> selection,
    required ValueChanged<Set<String>> onSelected,
  }) {
    final theme = Theme.of(context);
    final labels = {for (final item in items) item.id: item.label};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        if (selection.isEmpty)
          Text(
            'Nessuna selezione',
            style: theme.textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selection
                .map(
                  (id) => InputChip(
                    label: Text(labels[id] ?? id),
                    onDeleted: () {
                      final updated = Set<String>.from(selection)..remove(id);
                      onSelected(updated);
                    },
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await _showMultiSelectDialog(
                  context: context,
                  title: label,
                  items: items,
                  initialSelection: selection,
                );
                if (picked != null) {
                  onSelected(picked);
                }
              },
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Seleziona'),
            ),
            if (selection.isNotEmpty)
              TextButton.icon(
                onPressed: () => onSelected(<String>{}),
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Svuota'),
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildResultsChildren({
    required BuildContext context,
    required AdvancedClientSearchState state,
    required AppDataState appData,
    required int totalResults,
    required bool showResults,
  }) {
    if (!showResults) {
      return [
        _buildPlaceholder(
          context: context,
          icon: Icons.analytics_outlined,
          title: 'Imposta i filtri',
          message:
              'Configura i filtri desiderati e premi “Cerca” per avviare la ricerca avanzata.',
        ),
      ];
    }
    if (state.results.isEmpty) {
      return [
        _buildPlaceholder(
          context: context,
          icon: Icons.person_off_outlined,
          title: 'Nessun risultato',
          message:
              'Non ci sono clienti che rispettano i criteri selezionati. Modifica i filtri e riprova.',
        ),
      ];
    }
    final widgets = <Widget>[
      _buildResults(
        context: context,
        state: state,
        appData: appData,
        totalResults: totalResults,
      ),
    ];
    if (_selectedClientId != null) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(
        ClientDetailView(
          clientId: _selectedClientId!,
          showAppBar: false,
          onClose: () => setState(() => _selectedClientId = null),
        ),
      );
    }
    return widgets;
  }

  Widget _buildResults({
    required BuildContext context,
    required AdvancedClientSearchState state,
    required AppDataState appData,
    required int totalResults,
  }) {
    final clients = state.results;
    final theme = Theme.of(context);
    final salonId = widget.salonId;

    final appointmentsByClient = groupBy<Appointment, String>(
      appData.appointments.where(
        (appt) => salonId == null || appt.salonId == salonId,
      ),
      (appt) => appt.clientId,
    );
    final salesByClient = groupBy<Sale, String>(
      appData.sales.where(
        (sale) => salonId == null || sale.salonId == salonId,
      ),
      (sale) => sale.clientId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Risultati trovati: $totalResults',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...clients.map((client) {
          final appointments = appointmentsByClient[client.id]?.length ?? 0;
          final purchases = salesByClient[client.id]?.length ?? 0;
          final isSelected = client.id == _selectedClientId;
          final emailAvailable = client.email != null && client.email!.isNotEmpty;
          final isSending = widget.isSendingInvite(client.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color:
                  isSelected
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                      : theme.colorScheme.surface,
              elevation: 2,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _selectedClientId =
                        isSelected ? null : client.id;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            child: Text(_clientInitial(client)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _displayName(client),
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    if (client.clientNumber != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        'N° ${client.clientNumber}',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      client.phone,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                                if (client.email != null &&
                                    client.email!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.email_outlined, size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        client.email!,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    _QuickStat(
                                      icon: Icons.event_available_rounded,
                                      label: 'Appuntamenti: $appointments',
                                    ),
                                    _QuickStat(
                                      icon: Icons.shopping_bag_outlined,
                                      label: 'Acquisti: $purchases',
                                    ),
                                    if (client.loyaltyPoints > 0)
                                      _QuickStat(
                                        icon: Icons.star_rounded,
                                        label: 'Punti: ${client.loyaltyPoints}',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _buildStatusChip(context, client),
                                    FilledButton.tonalIcon(
                                      onPressed:
                                          emailAvailable && !isSending
                                              ? () => widget.onSendInvite(client)
                                              : null,
                                      icon:
                                          isSending
                                              ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                              : const Icon(Icons.mail_outline_rounded),
                                      label: Text(
                                        emailAvailable
                                            ? 'Invia link'
                                            : 'Email assente',
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => widget.onEditClient(client),
                                      icon: const Icon(Icons.edit_rounded),
                                      label: const Text('Modifica'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Scheda completa aperta sotto.',
                              style: theme.textTheme.bodySmall,
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => setState(() => _selectedClientId = null),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Chiudi scheda'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPlaceholder({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _updateFilter(AdvancedSearchFiltersBuilderCallback update) {
    ref.read(_provider.notifier).updateFilter(update);
  }

  void _syncControllers(AdvancedSearchFilters filters) {
    _setControllerText(_generalQueryController, filters.generalQuery);
    _setControllerText(
      _clientNumberController,
      filters.clientNumberExact ?? '',
    );
    _setControllerText(
      _clientNumberFromController,
      filters.clientNumberFrom?.toString() ?? '',
    );
    _setControllerText(
      _clientNumberToController,
      filters.clientNumberTo?.toString() ?? '',
    );
    _setControllerText(
      _minAgeController,
      filters.minAge?.toString() ?? '',
    );
    _setControllerText(
      _maxAgeController,
      filters.maxAge?.toString() ?? '',
    );
    _setControllerText(_cityController, filters.city ?? '');
    _setControllerText(_professionController, filters.profession ?? '');
    _setControllerText(
      _loyaltyMinController,
      filters.loyaltyPointsMin?.toString() ?? '',
    );
    _setControllerText(
      _loyaltyMaxController,
      filters.loyaltyPointsMax?.toString() ?? '',
    );
    _setControllerText(
      _totalSpentMinController,
      filters.totalSpentMin?.toString() ?? '',
    );
    _setControllerText(
      _totalSpentMaxController,
      filters.totalSpentMax?.toString() ?? '',
    );
    _setControllerText(
      _lastPurchaseWithinController,
      filters.lastPurchaseWithinDays?.toString() ?? '',
    );
    _setControllerText(
      _lastPurchaseOlderController,
      filters.lastPurchaseOlderThanDays?.toString() ?? '',
    );
    _setControllerText(
      _upcomingWithinController,
      filters.upcomingAppointmentWithinDays?.toString() ?? '',
    );
    _setControllerText(
      _lastCompletedWithinController,
      filters.lastCompletedWithinDays?.toString() ?? '',
    );
    _setControllerText(
      _lastCompletedOlderController,
      filters.lastCompletedOlderThanDays?.toString() ?? '',
    );
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  Future<Set<String>?> _showMultiSelectDialog({
    required BuildContext context,
    required String title,
    required List<_SelectableItem> items,
    required Set<String> initialSelection,
  }) {
    return showDialog<Set<String>>(
      context: context,
      builder:
          (ctx) => _MultiSelectDialog(
            title: title,
            items: items,
            initialSelection: initialSelection,
          ),
    );
  }

  Widget _buildStatusChip(BuildContext context, Client client) {
    final scheme = Theme.of(context).colorScheme;
    final status = client.onboardingStatus;
    late final Color background;
    late final Color foreground;
    late final IconData icon;

    switch (status) {
      case ClientOnboardingStatus.notSent:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurface;
        icon = Icons.hourglass_empty_rounded;
        break;
      case ClientOnboardingStatus.invitationSent:
        background = scheme.primary;
        foreground = scheme.onPrimary;
        icon = Icons.outgoing_mail;
        break;
      case ClientOnboardingStatus.firstLogin:
        background = scheme.tertiary;
        foreground = scheme.onTertiary;
        icon = Icons.login_rounded;
        break;
      case ClientOnboardingStatus.onboardingCompleted:
        background = scheme.secondary;
        foreground = scheme.onSecondary;
        icon = Icons.verified_rounded;
        break;
    }

    return Chip(
      backgroundColor: background,
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(_statusLabel(status), style: TextStyle(color: foreground)),
    );
  }

  String _statusLabel(ClientOnboardingStatus status) {
    switch (status) {
      case ClientOnboardingStatus.notSent:
        return 'Non inviato';
      case ClientOnboardingStatus.invitationSent:
        return 'Inviata';
      case ClientOnboardingStatus.firstLogin:
        return 'Primo accesso';
      case ClientOnboardingStatus.onboardingCompleted:
        return 'Onboarding completato';
    }
  }

  String _displayName(Client client) {
    final first = client.firstName.trim();
    final last = client.lastName.trim();
    if (first.isNotEmpty && last.isNotEmpty) {
      return '$first $last';
    }
    if (first.isNotEmpty) {
      return first;
    }
    if (last.isNotEmpty) {
      return last;
    }
    return 'Cliente senza nome';
  }

  String _clientInitial(Client client) {
    final first = client.firstName.trim();
    if (first.isNotEmpty) {
      final ch = first.characters.firstOrNull;
      if (ch != null && ch.isNotEmpty) {
        return ch.toUpperCase();
      }
    }
    final last = client.lastName.trim();
    if (last.isNotEmpty) {
      final ch = last.characters.firstOrNull;
      if (ch != null && ch.isNotEmpty) {
        return ch.toUpperCase();
      }
    }
    return '?';
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label, style: theme.textTheme.bodyMedium),
    );
  }
}

class _SelectableItem {
  const _SelectableItem({required this.id, required this.label});

  factory _SelectableItem.fromService(Service service) {
    return _SelectableItem(id: service.id, label: service.name);
  }

  factory _SelectableItem.fromCategory(ServiceCategory category) {
    return _SelectableItem(id: category.id, label: category.name);
  }

  final String id;
  final String label;
}

class _MultiSelectDialog extends StatefulWidget {
  const _MultiSelectDialog({
    required this.title,
    required this.items,
    required this.initialSelection,
  });

  final String title;
  final List<_SelectableItem> items;
  final Set<String> initialSelection;

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late final Set<String> _selection;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _selection = Set<String>.from(widget.initialSelection);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.items.where((item) {
      if (query.isEmpty) {
        return true;
      }
      return item.label.toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Filtra',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder:
                    (context, index) {
                      final item = filtered[index];
                      final selected = _selection.contains(item.id);
                      return CheckboxListTile(
                        value: selected,
                        title: Text(item.label),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selection.add(item.id);
                            } else {
                              _selection.remove(item.id);
                            }
                          });
                        },
                      );
                    },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(<String>{}),
          child: const Text('Svuota'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selection),
          child: const Text('Applica'),
        ),
      ],
    );
  }
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.label,
    required this.valueLabel,
    required this.onPressed,
    this.onClear,
  });

  final String label;
  final String valueLabel;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label, style: theme.textTheme.labelLarge),
            subtitle: Text(valueLabel, style: theme.textTheme.bodyMedium),
            trailing: IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.clear_rounded),
            ),
            onTap: onPressed,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.calendar_today_rounded),
          label: const Text('Scegli'),
        ),
      ],
    );
  }
}
