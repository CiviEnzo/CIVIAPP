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
  >
  _provider;
  late ProviderSubscription<AdvancedClientSearchState> _subscription;

  final TextEditingController _generalQueryController = TextEditingController();
  final TextEditingController _clientNumberController = TextEditingController();
  final TextEditingController _clientNumberFromController =
      TextEditingController();
  final TextEditingController _clientNumberToController =
      TextEditingController();
  final TextEditingController _minAgeController = TextEditingController();
  final TextEditingController _maxAgeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _professionController = TextEditingController();
  final TextEditingController _loyaltyMinController = TextEditingController();
  final TextEditingController _loyaltyMaxController = TextEditingController();
  final TextEditingController _totalSpentMinController =
      TextEditingController();
  final TextEditingController _totalSpentMaxController =
      TextEditingController();
  final TextEditingController _lastPurchaseWithinController =
      TextEditingController();
  final TextEditingController _lastPurchaseOlderController =
      TextEditingController();
  final TextEditingController _upcomingWithinController =
      TextEditingController();
  final TextEditingController _lastCompletedWithinController =
      TextEditingController();
  final TextEditingController _lastCompletedOlderController =
      TextEditingController();

  final ScrollController _filtersScrollController = ScrollController();
  final ScrollController _resultsScrollController = ScrollController();

  final Set<String> _bulkSelectedClientIds = <String>{};
  _SortOption _sortOption = _SortOption.name;
  bool _groupByUpcoming = false;

  List<Service> _cachedServices = const <Service>[];
  List<ServiceCategory> _cachedCategories = const <ServiceCategory>[];
  List<String> _cachedReferralSources = const <String>[];

  String? _selectedClientId;

  @override
  void initState() {
    super.initState();
    _provider = advancedClientSearchControllerProvider(widget.salonId);
    final initialState = ref.read(_provider);
    _syncControllers(initialState.filters);
    _subscription = ref.listenManual<AdvancedClientSearchState>(_provider, (
      previous,
      next,
    ) {
      _syncControllers(next.filters);
      if (_selectedClientId != null &&
          !next.results.any((client) => client.id == _selectedClientId)) {
        if (mounted) {
          setState(() => _selectedClientId = null);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant AdvancedSearchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.salonId != widget.salonId) {
      setState(() {
        _bulkSelectedClientIds.clear();
        _selectedClientId = null;
      });
      _subscription.close();
      _provider = advancedClientSearchControllerProvider(widget.salonId);
      final initialState = ref.read(_provider);
      _syncControllers(initialState.filters);
      _subscription = ref.listenManual<AdvancedClientSearchState>(_provider, (
        previous,
        next,
      ) {
        _syncControllers(next.filters);
        bool shouldUpdate = false;
        if (_selectedClientId != null &&
            !next.results.any((client) => client.id == _selectedClientId)) {
          _selectedClientId = null;
          shouldUpdate = true;
        }
        if (_bulkSelectedClientIds.isNotEmpty) {
          final validIds = next.results.map((client) => client.id).toSet();
          final previousSize = _bulkSelectedClientIds.length;
          _bulkSelectedClientIds.removeWhere((id) => !validIds.contains(id));
          if (_bulkSelectedClientIds.length != previousSize) {
            shouldUpdate = true;
          }
        }
        if (shouldUpdate && mounted) {
          setState(() {});
        }
      });
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
    final activeChips = _buildActiveFilterChips(filters);

    _cachedServices = services;
    _cachedCategories = categories;
    _cachedReferralSources = referralOptions;

    return LayoutBuilder(
      builder: (context, _) {
        final filtersWidget = _buildFilters(
          context: context,
          filters: filters,
          services: services,
          categories: categories,
          referralSources: referralOptions,
        );
        final resultsChildren = _buildResultsChildren(
          context: context,
          state: state,
          appData: data,
          totalResults: totalResults,
          showResults: showResults,
          filters: filters,
        );
        final hasBulkSelection = _bulkSelectedClientIds.isNotEmpty;

        final content = Scrollbar(
          controller: _resultsScrollController,
          child: ListView(
            controller: _resultsScrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              filtersWidget,
              const SizedBox(height: 16),
              ...resultsChildren,
            ],
          ),
        );

        return Column(
          children: [
            Expanded(child: content),
            if (hasBulkSelection) _buildBulkToolbar(),
            _buildPersistentActionsBar(
              isApplying: state.isApplying,
              activeChips: activeChips,
            ),
          ],
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
  }) {
    final children = <Widget>[
      _buildPrimaryFiltersCard(
        context: context,
        filters: filters,
        categories: categories,
        referralSources: referralSources,
      ),
      const SizedBox(height: 16),
      _buildQuestionnaireCard(
        context: context,
        filters: filters,
        services: services,
        categories: categories,
        referralSources: referralSources,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildPrimaryFiltersCard({
    required BuildContext context,
    required AdvancedSearchFilters filters,
    required List<ServiceCategory> categories,
    required List<String> referralSources,
  }) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width;
        final fieldWidth = _resolvePrimaryFieldWidth(maxWidth);
        const fieldSpacing = 12.0;

        Widget compactField(Widget child) => SizedBox(
          width: fieldWidth,
          child: child,
        );
        final sectionWidth = _resolvePrimarySectionWidth(maxWidth);
        final wideSectionWidth =
            _resolvePrimarySectionWidth(maxWidth, prefersWide: true);
        Widget section(
          Widget child, {
          bool wide = false,
        }) => SizedBox(
          width: wide ? wideSectionWidth : sectionWidth,
          child: child,
        );

        return Card(
          elevation: 2,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filtri principali', style: theme.textTheme.titleMedium),
                const SizedBox(height: fieldSpacing),
                Wrap(
                  spacing: fieldSpacing,
                  runSpacing: fieldSpacing,
                  children: [
                    compactField(
                      _buildTextField(
                        controller: _clientNumberFromController,
                        label: 'Numero cliente da',
                        icon: Icons.filter_alt_outlined,
                        keyboardType: TextInputType.number,
                        onChanged:
                            (value) => _updateFilter(
                              (builder) =>
                                  builder.clientNumberFrom =
                                      value.trim().isEmpty
                                          ? null
                                          : int.tryParse(value),
                            ),
                      ),
                    ),
                    compactField(
                      _buildTextField(
                        controller: _clientNumberToController,
                        label: 'Numero cliente a',
                        icon: Icons.filter_alt_rounded,
                        keyboardType: TextInputType.number,
                        onChanged:
                            (value) => _updateFilter(
                              (builder) =>
                                  builder.clientNumberTo =
                                      value.trim().isEmpty
                                          ? null
                                          : int.tryParse(value),
                            ),
                      ),
                    ),
                    compactField(
                      _buildTextField(
                        controller: _minAgeController,
                        label: 'Età minima',
                        icon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                        onChanged:
                            (value) => _updateFilter(
                              (builder) =>
                                  builder.minAge =
                                      value.trim().isEmpty
                                          ? null
                                          : int.tryParse(value),
                            ),
                      ),
                    ),
                    compactField(
                      _buildTextField(
                        controller: _maxAgeController,
                        label: 'Età massima',
                        icon: Icons.cake_rounded,
                        keyboardType: TextInputType.number,
                        onChanged:
                            (value) => _updateFilter(
                              (builder) =>
                                  builder.maxAge =
                                      value.trim().isEmpty
                                          ? null
                                          : int.tryParse(value),
                            ),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: fieldSpacing,
              runSpacing: 16,
              children: [
                section(_buildGenderChips(filters.genders)),
                section(
                  _buildTriStateChoice(
                    label: 'Hanno installato l’app',
                    value: filters.hasPushToken,
                    onChanged:
                        (value) => _updateFilter(
                          (builder) => builder.hasPushToken = value,
                        ),
                  ),
                ),
                section(
                  _buildReferralChips(
                    selection: filters.referralSources,
                    options: referralSources,
                  ),
                  wide: true,
                ),
                section(
                  _buildMultiSelectField(
                    context: context,
                    label: 'Categorie preferite',
                    items: categories.map(_SelectableItem.fromCategory).toList(),
                    selection: filters.includeSaleCategoryIds,
                    onSelected:
                        (value) => _updateFilter(
                          (builder) => builder.includeSaleCategoryIds = value,
                        ),
                  ),
                  wide: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildQuestionnaireCard({
    required BuildContext context,
    required AdvancedSearchFilters filters,
    required List<Service> services,
    required List<ServiceCategory> categories,
    required List<String> referralSources,
  }) {
    final theme = Theme.of(context);
    final sections = _buildAdvancedFilterSectionsData(
      context: context,
      filters: filters,
      services: services,
      categories: categories,
      referralSources: referralSources,
      includePrimaryFields: false,
    );

    final tiles = <Widget>[
      _QuestionTile(
        title: 'Vuoi cercare per testo libero?',
        subtitle: 'Nome, telefono, email o note',
        child: _buildTextField(
          controller: _generalQueryController,
          label: 'Testo generico',
          icon: Icons.search_rounded,
          onChanged:
              (value) =>
                  _updateFilter((builder) => builder.generalQuery = value),
        ),
      ),
      _QuestionTile(
        title: 'Conosci un numero cliente preciso?',
        child: _buildTextField(
          controller: _clientNumberController,
          label: 'Numero cliente esatto',
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.text,
          onChanged:
              (value) => _updateFilter(
                (builder) =>
                    builder.clientNumberExact =
                        value.trim().isEmpty ? null : value.trim(),
              ),
        ),
      ),
      _QuestionTile(
        title: 'Vuoi monitorare i punti fedeltà?',
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _loyaltyMinController,
                    label: 'Punti minimi',
                    icon: Icons.star_border_rounded,
                    keyboardType: TextInputType.number,
                    onChanged:
                        (value) => _updateFilter(
                          (builder) =>
                              builder.loyaltyPointsMin =
                                  value.trim().isEmpty
                                      ? null
                                      : int.tryParse(value),
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
                    onChanged:
                        (value) => _updateFilter(
                          (builder) =>
                              builder.loyaltyPointsMax =
                                  value.trim().isEmpty
                                      ? null
                                      : int.tryParse(value),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSingleDatePickerRow(
              context: context,
              label: 'Ultimo aggiornamento punti da',
              value: filters.loyaltyUpdatedSince,
              onSelected:
                  (date) => _updateFilter(
                    (builder) => builder.loyaltyUpdatedSince = date,
                  ),
            ),
          ],
        ),
      ),
      ...sections.map(
        (section) => _QuestionTile(
          title: 'Filtrare per ${section.title.toLowerCase()}?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _withSpacing(section.children, 12).toList(),
          ),
        ),
      ),
    ];

    return Card(
      elevation: 1.5,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Domande guidate', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ..._withSpacing(tiles, 12),
          ],
        ),
      ),
    );
  }

  Widget _buildPersistentActionsBar({
    required bool isApplying,
    required List<_FilterChipData> activeChips,
  }) {
    final theme = Theme.of(context);
    return Material(
      elevation: 12,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed:
                        isApplying
                            ? null
                            : () => ref.read(_provider.notifier).apply(),
                    icon:
                        isApplying
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.manage_search_rounded),
                    label: Text(isApplying ? 'Ricerca in corso...' : 'Cerca'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(_provider.notifier).clear();
                      setState(() => _selectedClientId = null);
                    },
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Azzera'),
                  ),
                ],
              ),
              if (activeChips.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filtri attivi', style: theme.textTheme.labelLarge),
                    TextButton.icon(
                      onPressed: () {
                        ref.read(_provider.notifier).clear();
                        setState(() => _selectedClientId = null);
                      },
                      icon: const Icon(Icons.clear_all_rounded),
                      label: const Text('Azzera tutto'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      activeChips
                          .map(
                            (chip) => InputChip(
                              label: Text(chip.label),
                              onDeleted: chip.onRemoved,
                            ),
                          )
                          .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<_AdvancedFilterSection> _buildAdvancedFilterSectionsData({
    required BuildContext context,
    required AdvancedSearchFilters filters,
    required List<Service> services,
    required List<ServiceCategory> categories,
    required List<String> referralSources,
    bool includePrimaryFields = true,
  }) {
    final sections = <_AdvancedFilterSection>[];

    final anagraficaChildren = <Widget>[
      Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: _cityController,
              label: 'Città',
              icon: Icons.location_city_rounded,
              onChanged:
                  (value) => _updateFilter(
                    (builder) =>
                        builder.city =
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
              onChanged:
                  (value) => _updateFilter(
                    (builder) =>
                        builder.profession =
                            value.trim().isEmpty ? null : value.trim(),
                  ),
            ),
          ),
        ],
      ),
    ];
    if (includePrimaryFields) {
      anagraficaChildren
        ..add(const SizedBox(height: 12))
        ..add(_buildGenderChips(filters.genders))
        ..add(const SizedBox(height: 12))
        ..add(
          _buildReferralChips(
            selection: filters.referralSources,
            options: referralSources,
          ),
        );
    }
    anagraficaChildren
      ..add(const SizedBox(height: 12))
      ..add(
        Row(
          children: [
            Expanded(
              child: _buildTriStateChoice(
                label: 'Email presente',
                value: filters.hasEmail,
                onChanged:
                    (value) =>
                        _updateFilter((builder) => builder.hasEmail = value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTriStateChoice(
                label: 'Telefono presente',
                value: filters.hasPhone,
                onChanged:
                    (value) =>
                        _updateFilter((builder) => builder.hasPhone = value),
              ),
            ),
          ],
        ),
      )
      ..add(const SizedBox(height: 12))
      ..add(
        _buildTriStateChoice(
          label: 'Note inserite',
          value: filters.hasNotes,
          onChanged:
              (value) => _updateFilter((builder) => builder.hasNotes = value),
        ),
      );
    sections.add(
      _AdvancedFilterSection(title: 'Anagrafica', children: anagraficaChildren),
    );

    final datesChildren = <Widget>[
      _buildDateRangePickerRow(
        context: context,
        label: 'Creati tra',
        start: filters.createdAtFrom,
        end: filters.createdAtTo,
        onSelected:
            (range) => _updateFilter((builder) {
              builder.createdAtFrom = range?.start;
              builder.createdAtTo = range?.end;
            }),
      ),
    ];
    if (includePrimaryFields) {
      datesChildren
        ..add(const SizedBox(height: 12))
        ..add(
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _minAgeController,
                  label: 'Età minima',
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                  onChanged:
                      (value) => _updateFilter(
                        (builder) =>
                            builder.minAge =
                                value.trim().isEmpty
                                    ? null
                                    : int.tryParse(value),
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
                  onChanged:
                      (value) => _updateFilter(
                        (builder) =>
                            builder.maxAge =
                                value.trim().isEmpty
                                    ? null
                                    : int.tryParse(value),
                      ),
                ),
              ),
            ],
          ),
        );
    }
    datesChildren
      ..add(const SizedBox(height: 12))
      ..add(
        _buildDateRangePickerRow(
          context: context,
          label: 'Nati tra',
          start: filters.dateOfBirthFrom,
          end: filters.dateOfBirthTo,
          onSelected:
              (range) => _updateFilter((builder) {
                builder.dateOfBirthFrom = range?.start;
                builder.dateOfBirthTo = range?.end;
              }),
        ),
      )
      ..add(const SizedBox(height: 12))
      ..add(_buildBirthdayShortcutSelector(filters.birthdayShortcut));
    sections.add(
      _AdvancedFilterSection(
        title: 'Date e ricorrenze',
        children: datesChildren,
      ),
    );

    final onboardingChildren = <Widget>[
      _buildOnboardingStatusChips(filters.onboardingStatuses),
      const SizedBox(height: 12),
      if (includePrimaryFields)
        Row(
          children: [
            Expanded(
              child: _buildTriStateChoice(
                label: 'Ha effettuato il primo login',
                value: filters.hasFirstLogin,
                onChanged:
                    (value) => _updateFilter(
                      (builder) => builder.hasFirstLogin = value,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTriStateChoice(
                label: 'Ha token push',
                value: filters.hasPushToken,
                onChanged:
                    (value) => _updateFilter(
                      (builder) => builder.hasPushToken = value,
                    ),
              ),
            ),
          ],
        )
      else
        _buildTriStateChoice(
          label: 'Ha effettuato il primo login',
          value: filters.hasFirstLogin,
          onChanged:
              (value) =>
                  _updateFilter((builder) => builder.hasFirstLogin = value),
        ),
    ];
    sections.add(
      _AdvancedFilterSection(
        title: 'Onboarding e App',
        children: onboardingChildren,
      ),
    );

    sections.add(
      _AdvancedFilterSection(
        title: 'Appuntamenti',
        children: [
          _buildTextField(
            controller: _upcomingWithinController,
            label: 'Prossimo appuntamento entro (giorni)',
            icon: Icons.event_available_rounded,
            keyboardType: TextInputType.number,
            onChanged:
                (value) => _updateFilter(
                  (builder) =>
                      builder.upcomingAppointmentWithinDays =
                          value.trim().isEmpty ? null : int.tryParse(value),
                ),
          ),
          const SizedBox(height: 12),
          _buildMultiSelectField(
            context: context,
            label: 'Servizi prossimi appuntamenti',
            items: services.map(_SelectableItem.fromService).toList(),
            selection: filters.upcomingAppointmentServiceIds,
            onSelected:
                (value) => _updateFilter(
                  (builder) => builder.upcomingAppointmentServiceIds = value,
                ),
          ),
          const SizedBox(height: 12),
          _buildMultiSelectField(
            context: context,
            label: 'Categorie prossimi appuntamenti',
            items: categories.map(_SelectableItem.fromCategory).toList(),
            selection: filters.upcomingAppointmentCategoryIds,
            onSelected:
                (value) => _updateFilter(
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
                  onChanged:
                      (value) => _updateFilter(
                        (builder) =>
                            builder.lastCompletedWithinDays =
                                value.trim().isEmpty
                                    ? null
                                    : int.tryParse(value),
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
                  onChanged:
                      (value) => _updateFilter(
                        (builder) =>
                            builder.lastCompletedOlderThanDays =
                                value.trim().isEmpty
                                    ? null
                                    : int.tryParse(value),
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
            onSelected:
                (value) => _updateFilter(
                  (builder) => builder.lastCompletedServiceIds = value,
                ),
          ),
          const SizedBox(height: 12),
          _buildMultiSelectField(
            context: context,
            label: 'Categorie ultima seduta',
            items: categories.map(_SelectableItem.fromCategory).toList(),
            selection: filters.lastCompletedCategoryIds,
            onSelected:
                (value) => _updateFilter(
                  (builder) => builder.lastCompletedCategoryIds = value,
                ),
          ),
        ],
      ),
    );

    final salesChildren = <Widget>[
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
              onChanged:
                  (value) => _updateFilter(
                    (builder) =>
                        builder.totalSpentMin =
                            value.trim().isEmpty
                                ? null
                                : double.tryParse(value),
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
              onChanged:
                  (value) => _updateFilter(
                    (builder) =>
                        builder.totalSpentMax =
                            value.trim().isEmpty
                                ? null
                                : double.tryParse(value),
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
        onSelected:
            (range) => _updateFilter((builder) {
              builder.totalSpentFrom = range?.start;
              builder.totalSpentTo = range?.end;
            }),
      ),
      const SizedBox(height: 12),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: filters.usePaidAmount,
        onChanged:
            (value) =>
                _updateFilter((builder) => builder.usePaidAmount = value),
        title: const Text('Usa importi incassati (paidAmount)'),
      ),
      const SizedBox(height: 12),
      _buildTriStateChoice(
        label: 'Saldo residuo > 0',
        value: filters.hasOutstandingBalance,
        onChanged:
            (value) => _updateFilter(
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
              onChanged:
                  (value) => _updateFilter(
                    (builder) =>
                        builder.lastPurchaseWithinDays =
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
              onChanged:
                  (value) => _updateFilter(
                    (builder) =>
                        builder.lastPurchaseOlderThanDays =
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
        onSelected:
            (value) => _updateFilter(
              (builder) => builder.includeSaleServiceIds = value,
            ),
      ),
      const SizedBox(height: 12),
      _buildMultiSelectField(
        context: context,
        label: 'Servizi da escludere',
        items: services.map(_SelectableItem.fromService).toList(),
        selection: filters.excludeSaleServiceIds,
        onSelected:
            (value) => _updateFilter(
              (builder) => builder.excludeSaleServiceIds = value,
            ),
      ),
      if (includePrimaryFields) ...[
        const SizedBox(height: 12),
        _buildMultiSelectField(
          context: context,
          label: 'Categorie da includere',
          items: categories.map(_SelectableItem.fromCategory).toList(),
          selection: filters.includeSaleCategoryIds,
          onSelected:
              (value) => _updateFilter(
                (builder) => builder.includeSaleCategoryIds = value,
              ),
        ),
      ],
      const SizedBox(height: 12),
      _buildMultiSelectField(
        context: context,
        label: 'Categorie da escludere',
        items: categories.map(_SelectableItem.fromCategory).toList(),
        selection: filters.excludeSaleCategoryIds,
        onSelected:
            (value) => _updateFilter(
              (builder) => builder.excludeSaleCategoryIds = value,
            ),
      ),
      const SizedBox(height: 12),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: filters.onlyLastMinuteSales,
        onChanged:
            (value) =>
                _updateFilter((builder) => builder.onlyLastMinuteSales = value),
        title: const Text('Solo vendite last-minute'),
      ),
    ];
    sections.add(
      _AdvancedFilterSection(title: 'Vendite', children: salesChildren),
    );

    sections.add(
      _AdvancedFilterSection(
        title: 'Pacchetti',
        children: [
          _buildTriStateChoice(
            label: 'Ha pacchetti attivi',
            value: filters.hasActivePackages,
            onChanged:
                (value) => _updateFilter(
                  (builder) => builder.hasActivePackages = value,
                ),
          ),
          const SizedBox(height: 12),
          _buildTriStateChoice(
            label: 'Ha sessioni residue',
            value: filters.hasPackagesWithRemainingSessions,
            onChanged:
                (value) => _updateFilter(
                  (builder) => builder.hasPackagesWithRemainingSessions = value,
                ),
          ),
          const SizedBox(height: 12),
          _buildTriStateChoice(
            label: 'Ha pacchetti scaduti',
            value: filters.hasExpiredPackages,
            onChanged:
                (value) => _updateFilter(
                  (builder) => builder.hasExpiredPackages = value,
                ),
          ),
        ],
      ),
    );

    return sections;
  }

  Iterable<Widget> _withSpacing(List<Widget> widgets, double spacing) sync* {
    for (var i = 0; i < widgets.length; i++) {
      yield widgets[i];
      if (i != widgets.length - 1) {
        yield SizedBox(height: spacing);
      }
    }
  }

  double _resolvePrimaryFieldWidth(double availableWidth) {
    if (!availableWidth.isFinite || availableWidth <= 0) {
      return 260;
    }
    if (availableWidth < 600) {
      return availableWidth;
    }
    if (availableWidth < 900) {
      return 260;
    }
    if (availableWidth < 1200) {
      return 240;
    }
    return 220;
  }

  double _resolvePrimarySectionWidth(
    double availableWidth, {
    bool prefersWide = false,
  }) {
    if (!availableWidth.isFinite || availableWidth <= 0) {
      return prefersWide ? 360 : 280;
    }
    if (availableWidth < 600) {
      return availableWidth;
    }
    if (prefersWide) {
      if (availableWidth < 900) return availableWidth * 0.9;
      if (availableWidth < 1200) return 360;
      return 420;
    }
    if (availableWidth < 900) {
      return 280;
    }
    if (availableWidth < 1200) {
      return 300;
    }
    return 320;
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
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      onChanged: onChanged,
    );
  }

  bool get _isBulkSelecting => _bulkSelectedClientIds.isNotEmpty;

  void _toggleBulkSelection(String clientId) {
    setState(() {
      if (_bulkSelectedClientIds.contains(clientId)) {
        _bulkSelectedClientIds.remove(clientId);
      } else {
        _bulkSelectedClientIds.add(clientId);
      }
    });
  }

  void _toggleBulkSelectionForRows(List<_ResultRowData> rows, bool select) {
    if (rows.isEmpty) {
      return;
    }
    setState(() {
      if (select) {
        for (final row in rows) {
          _bulkSelectedClientIds.add(row.client.id);
        }
      } else {
        for (final row in rows) {
          _bulkSelectedClientIds.remove(row.client.id);
        }
      }
    });
  }

  void _clearBulkSelection() {
    if (_bulkSelectedClientIds.isEmpty) {
      return;
    }
    setState(() => _bulkSelectedClientIds.clear());
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
      onSelectionChanged:
          (value) => _updateFilter((builder) => builder.genders = value),
    );
  }

  Widget _buildReferralChips({
    required Set<String> selection,
    required List<String> options,
  }) {
    final normalizedSelection =
        selection.map((value) => value.toLowerCase()).toSet();
    final items =
        options
            .map(
              (option) => _SelectableItem(
                id: option.toLowerCase(),
                label: option,
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );
    return _buildMultiSelectField(
      context: context,
      label: 'Come ci ha conosciuti',
      items: items,
      selection: normalizedSelection,
      onSelected:
          (value) =>
              _updateFilter((builder) => builder.referralSources = value),
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
          children:
              options
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
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

  Widget _buildBulkToolbar() {
    final theme = Theme.of(context);
    final selectedCount = _bulkSelectedClientIds.length;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 8,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fact_check_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                '$selectedCount selezionati',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: _clearBulkSelection,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Annulla'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Azioni di gruppo disponibili a breve.'),
                    ),
                  );
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('Azioni'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBirthdayShortcutSelector(
    AdvancedSearchBirthdayShortcut shortcut,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Compleanni in arrivo', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Nessun filtro'),
              selected: shortcut == AdvancedSearchBirthdayShortcut.none,
              onSelected:
                  (_) => _updateFilter(
                    (builder) =>
                        builder.birthdayShortcut =
                            AdvancedSearchBirthdayShortcut.none,
                  ),
            ),
            ChoiceChip(
              label: const Text('Prossima settimana'),
              selected: shortcut == AdvancedSearchBirthdayShortcut.nextWeek,
              onSelected:
                  (_) => _updateFilter(
                    (builder) =>
                        builder.birthdayShortcut =
                            AdvancedSearchBirthdayShortcut.nextWeek,
                  ),
            ),
            ChoiceChip(
              label: const Text('Prossimo mese'),
              selected: shortcut == AdvancedSearchBirthdayShortcut.nextMonth,
              onSelected:
                  (_) => _updateFilter(
                    (builder) =>
                        builder.birthdayShortcut =
                            AdvancedSearchBirthdayShortcut.nextMonth,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOnboardingStatusChips(Set<ClientOnboardingStatus> selection) {
    final options =
        ClientOnboardingStatus.values
            .map(
              (status) =>
                  _SelectableItem(id: status.name, label: _statusLabel(status)),
            )
            .toList();
    final selectionIds = selection.map((status) => status.name).toSet();
    return _buildChipSelector(
      title: 'Stato onboarding',
      options: options,
      selection: selectionIds,
      onSelectionChanged:
          (value) => _updateFilter(
            (builder) =>
                builder.onboardingStatuses =
                    value
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
    final text =
        hasSelection
            ? '${start != null ? format.format(start) : '…'} • ${end != null ? format.format(end) : '…'}'
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
          Text('Nessuna selezione', style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                selection
                    .map(
                      (id) => InputChip(
                        label: Text(labels[id] ?? id),
                        onDeleted: () {
                          final updated = Set<String>.from(selection)
                            ..remove(id);
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

  List<_FilterChipData> _buildActiveFilterChips(AdvancedSearchFilters filters) {
    final chips = <_FilterChipData>[];
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');

    void addChip(
      bool condition,
      String label,
      AdvancedSearchFiltersBuilderCallback clear,
    ) {
      if (!condition) {
        return;
      }
      chips.add(
        _FilterChipData(label: label, onRemoved: () => _updateFilter(clear)),
      );
    }

    String formatRange(num? from, num? to, {String unit = ''}) {
      final parts = <String>[];
      if (from != null) {
        parts.add('da $from$unit');
      }
      if (to != null) {
        parts.add('a $to$unit');
      }
      return parts.join(' ');
    }

    String formatDateRange(DateTime? from, DateTime? to, String prefix) {
      if (from == null && to == null) {
        return '';
      }
      final fromLabel = from != null ? dateFormat.format(from) : '—';
      final toLabel = to != null ? dateFormat.format(to) : '—';
      return '$prefix $fromLabel • $toLabel';
    }

    String summarizeLabels(Iterable<String> values) {
      final list =
          values.where((element) => element.trim().isNotEmpty).toList();
      if (list.isEmpty) return '';
      if (list.length <= 3) {
        return list.join(', ');
      }
      final shown = list.take(3).join(', ');
      return '$shown +${list.length - 3}';
    }

    final general = filters.generalQuery.trim();
    addChip(
      general.isNotEmpty,
      'Testo: "$general"',
      (builder) => builder.generalQuery = '',
    );

    final clientExact = filters.clientNumberExact?.trim();
    addChip(
      clientExact != null && clientExact.isNotEmpty,
      'N° cliente: $clientExact',
      (builder) => builder.clientNumberExact = null,
    );

    addChip(
      filters.clientNumberFrom != null || filters.clientNumberTo != null,
      'N° cliente ${formatRange(filters.clientNumberFrom, filters.clientNumberTo)}',
      (builder) {
        builder.clientNumberFrom = null;
        builder.clientNumberTo = null;
      },
    );

    addChip(
      filters.createdAtFrom != null || filters.createdAtTo != null,
      formatDateRange(filters.createdAtFrom, filters.createdAtTo, 'Creato'),
      (builder) {
        builder.createdAtFrom = null;
        builder.createdAtTo = null;
      },
    );

    addChip(
      filters.minAge != null || filters.maxAge != null,
      'Età ${formatRange(filters.minAge, filters.maxAge)}',
      (builder) {
        builder.minAge = null;
        builder.maxAge = null;
      },
    );

    addChip(
      filters.dateOfBirthFrom != null || filters.dateOfBirthTo != null,
      formatDateRange(filters.dateOfBirthFrom, filters.dateOfBirthTo, 'Nati'),
      (builder) {
        builder.dateOfBirthFrom = null;
        builder.dateOfBirthTo = null;
      },
    );

    addChip(
      filters.birthdayShortcut != AdvancedSearchBirthdayShortcut.none,
      filters.birthdayShortcut == AdvancedSearchBirthdayShortcut.nextWeek
          ? 'Compleanni: prossima settimana'
          : 'Compleanni: prossimo mese',
      (builder) =>
          builder.birthdayShortcut = AdvancedSearchBirthdayShortcut.none,
    );

    addChip(
      filters.genders.isNotEmpty,
      'Sesso: ${summarizeLabels(filters.genders.map(_genderLabelFromCode))}',
      (builder) => builder.genders = <String>{},
    );

    final city = filters.city?.trim();
    addChip(
      city != null && city.isNotEmpty,
      'Città: $city',
      (builder) => builder.city = null,
    );

    final profession = filters.profession?.trim();
    addChip(
      profession != null && profession.isNotEmpty,
      'Professione: $profession',
      (builder) => builder.profession = null,
    );

    addChip(
      filters.referralSources.isNotEmpty,
      'Referral: ${summarizeLabels(filters.referralSources.map(_referralLabel))}',
      (builder) => builder.referralSources = <String>{},
    );

    addChip(
      filters.hasEmail != null,
      'Email: ${filters.hasEmail == true ? 'presente' : 'assente'}',
      (builder) => builder.hasEmail = null,
    );

    addChip(
      filters.hasPhone != null,
      'Telefono: ${filters.hasPhone == true ? 'presente' : 'assente'}',
      (builder) => builder.hasPhone = null,
    );

    addChip(
      filters.hasNotes != null,
      'Note: ${filters.hasNotes == true ? 'presenti' : 'assenti'}',
      (builder) => builder.hasNotes = null,
    );

    addChip(
      filters.onboardingStatuses.isNotEmpty,
      'Onboarding: ${summarizeLabels(filters.onboardingStatuses.map(_statusLabel))}',
      (builder) => builder.onboardingStatuses = <ClientOnboardingStatus>{},
    );

    addChip(
      filters.hasFirstLogin != null,
      'Primo login: ${filters.hasFirstLogin == true ? 'sì' : 'no'}',
      (builder) => builder.hasFirstLogin = null,
    );

    addChip(
      filters.hasPushToken != null,
      'Token push: ${filters.hasPushToken == true ? 'sì' : 'no'}',
      (builder) => builder.hasPushToken = null,
    );

    final loyaltyMin = filters.loyaltyPointsMin;
    addChip(
      loyaltyMin != null,
      'Punti ≥ $loyaltyMin',
      (builder) => builder.loyaltyPointsMin = null,
    );

    final loyaltyMax = filters.loyaltyPointsMax;
    addChip(
      loyaltyMax != null,
      'Punti ≤ $loyaltyMax',
      (builder) => builder.loyaltyPointsMax = null,
    );

    final loyaltyUpdatedSince = filters.loyaltyUpdatedSince;
    addChip(
      loyaltyUpdatedSince != null,
      'Punti aggiornati dal ${loyaltyUpdatedSince != null ? dateFormat.format(loyaltyUpdatedSince) : ''}',
      (builder) => builder.loyaltyUpdatedSince = null,
    );

    final totalSpentMin = filters.totalSpentMin;
    addChip(
      totalSpentMin != null,
      'Spesa ≥ ${_formatCurrencySafely(currencyFormat, totalSpentMin)}',
      (builder) => builder.totalSpentMin = null,
    );

    final totalSpentMax = filters.totalSpentMax;
    addChip(
      totalSpentMax != null,
      'Spesa ≤ ${_formatCurrencySafely(currencyFormat, totalSpentMax)}',
      (builder) => builder.totalSpentMax = null,
    );

    addChip(
      filters.totalSpentFrom != null || filters.totalSpentTo != null,
      formatDateRange(filters.totalSpentFrom, filters.totalSpentTo, 'Vendite'),
      (builder) {
        builder.totalSpentFrom = null;
        builder.totalSpentTo = null;
      },
    );

    addChip(
      filters.usePaidAmount,
      'Importi incassati',
      (builder) => builder.usePaidAmount = false,
    );

    final hasOutstanding = filters.hasOutstandingBalance;
    addChip(
      hasOutstanding != null,
      'Saldo residuo ${hasOutstanding == true ? '> 0' : '= 0'}',
      (builder) => builder.hasOutstandingBalance = null,
    );

    addChip(
      filters.lastPurchaseWithinDays != null,
      'Acquisto entro ${filters.lastPurchaseWithinDays}g',
      (builder) => builder.lastPurchaseWithinDays = null,
    );

    addChip(
      filters.lastPurchaseOlderThanDays != null,
      'Acquisto oltre ${filters.lastPurchaseOlderThanDays}g',
      (builder) => builder.lastPurchaseOlderThanDays = null,
    );

    addChip(
      filters.includeSaleServiceIds.isNotEmpty,
      'Servizi inclusi: ${summarizeLabels(filters.includeSaleServiceIds.map(_serviceLabel))}',
      (builder) => builder.includeSaleServiceIds = <String>{},
    );

    addChip(
      filters.excludeSaleServiceIds.isNotEmpty,
      'Servizi esclusi: ${summarizeLabels(filters.excludeSaleServiceIds.map(_serviceLabel))}',
      (builder) => builder.excludeSaleServiceIds = <String>{},
    );

    addChip(
      filters.includeSaleCategoryIds.isNotEmpty,
      'Categorie incluse: ${summarizeLabels(filters.includeSaleCategoryIds.map(_categoryLabel))}',
      (builder) => builder.includeSaleCategoryIds = <String>{},
    );

    addChip(
      filters.excludeSaleCategoryIds.isNotEmpty,
      'Categorie escluse: ${summarizeLabels(filters.excludeSaleCategoryIds.map(_categoryLabel))}',
      (builder) => builder.excludeSaleCategoryIds = <String>{},
    );

    addChip(
      filters.onlyLastMinuteSales,
      'Solo vendite last-minute',
      (builder) => builder.onlyLastMinuteSales = false,
    );

    addChip(
      filters.upcomingAppointmentWithinDays != null,
      'Prossimi appuntamenti entro ${filters.upcomingAppointmentWithinDays}g',
      (builder) => builder.upcomingAppointmentWithinDays = null,
    );

    addChip(
      filters.upcomingAppointmentServiceIds.isNotEmpty,
      'Prossimi servizi: ${summarizeLabels(filters.upcomingAppointmentServiceIds.map(_serviceLabel))}',
      (builder) => builder.upcomingAppointmentServiceIds = <String>{},
    );

    addChip(
      filters.upcomingAppointmentCategoryIds.isNotEmpty,
      'Prossime categorie: ${summarizeLabels(filters.upcomingAppointmentCategoryIds.map(_categoryLabel))}',
      (builder) => builder.upcomingAppointmentCategoryIds = <String>{},
    );

    addChip(
      filters.lastCompletedWithinDays != null,
      'Ultima seduta entro ${filters.lastCompletedWithinDays}g',
      (builder) => builder.lastCompletedWithinDays = null,
    );

    addChip(
      filters.lastCompletedOlderThanDays != null,
      'Ultima seduta oltre ${filters.lastCompletedOlderThanDays}g',
      (builder) => builder.lastCompletedOlderThanDays = null,
    );

    addChip(
      filters.lastCompletedServiceIds.isNotEmpty,
      'Ultima seduta servizi: ${summarizeLabels(filters.lastCompletedServiceIds.map(_serviceLabel))}',
      (builder) => builder.lastCompletedServiceIds = <String>{},
    );

    addChip(
      filters.lastCompletedCategoryIds.isNotEmpty,
      'Ultima seduta categorie: ${summarizeLabels(filters.lastCompletedCategoryIds.map(_categoryLabel))}',
      (builder) => builder.lastCompletedCategoryIds = <String>{},
    );

    final hasActivePackages = filters.hasActivePackages;
    addChip(
      hasActivePackages != null,
      'Pacchetti attivi: ${hasActivePackages == true ? 'sì' : 'no'}',
      (builder) => builder.hasActivePackages = null,
    );

    final hasPackagesWithRemaining = filters.hasPackagesWithRemainingSessions;
    addChip(
      hasPackagesWithRemaining != null,
      'Sessioni residue: ${hasPackagesWithRemaining == true ? 'sì' : 'no'}',
      (builder) => builder.hasPackagesWithRemainingSessions = null,
    );

    final hasExpiredPackages = filters.hasExpiredPackages;
    addChip(
      hasExpiredPackages != null,
      'Pacchetti scaduti: ${hasExpiredPackages == true ? 'sì' : 'no'}',
      (builder) => builder.hasExpiredPackages = null,
    );

    return chips;
  }

  String _serviceLabel(String id) {
    return _cachedServices
            .firstWhereOrNull((service) => service.id == id)
            ?.name ??
        id;
  }

  String _categoryLabel(String id) {
    return _cachedCategories
            .firstWhereOrNull((category) => category.id == id)
            ?.name ??
        id;
  }

  String _referralLabel(String value) {
    final match = _cachedReferralSources.firstWhereOrNull(
      (option) => option.toLowerCase() == value.toLowerCase(),
    );
    return match ?? value;
  }

  String _genderLabelFromCode(String code) {
    switch (code.toLowerCase()) {
      case 'male':
        return 'Uomo';
      case 'female':
        return 'Donna';
      default:
        return 'Altro';
    }
  }

  String _formatCurrencySafely(NumberFormat formatter, double? value) {
    if (value == null) {
      return formatter.format(0);
    }
    return value.isNaN || value.isInfinite
        ? formatter.format(0)
        : formatter.format(value);
  }

  List<Widget> _buildResultsChildren({
    required BuildContext context,
    required AdvancedClientSearchState state,
    required AppDataState appData,
    required int totalResults,
    required bool showResults,
    required AdvancedSearchFilters filters,
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
        filters: filters,
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
    required AdvancedSearchFilters filters,
  }) {
    final salonId = widget.salonId;
    final now = DateTime.now();
    final currencyFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final usePaidAmount = filters.usePaidAmount;

    final appointmentsByClient = groupBy<Appointment, String>(
      appData.appointments.where(
        (appt) => salonId == null || appt.salonId == salonId,
      ),
      (appt) => appt.clientId,
    );
    final salesByClient = groupBy<Sale, String>(
      appData.sales.where((sale) => salonId == null || sale.salonId == salonId),
      (sale) => sale.clientId,
    );

    final rows = <_ResultRowData>[];
    for (final client in state.results) {
      final clientAppointments =
          appointmentsByClient[client.id] ?? const <Appointment>[];
      final upcomingAppointments =
          clientAppointments
              .where(
                (appt) =>
                    appt.status == AppointmentStatus.scheduled &&
                    appt.start.isAfter(now),
              )
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start));
      final completedAppointments =
          clientAppointments
              .where((appt) => appt.status == AppointmentStatus.completed)
              .toList()
            ..sort((a, b) => b.end.compareTo(a.end));
      final sales = salesByClient[client.id] ?? const <Sale>[];

      var totalSpent = 0.0;
      var hasOutstanding = false;
      for (final sale in sales) {
        totalSpent += usePaidAmount ? sale.paidAmount : sale.total;
        hasOutstanding = hasOutstanding || sale.outstandingAmount > 0;
      }

      rows.add(
        _ResultRowData(
          client: client,
          appointmentsCount: clientAppointments.length,
          purchasesCount: sales.length,
          totalSpent: totalSpent,
          hasOutstanding: hasOutstanding,
          nextAppointment:
              upcomingAppointments.isNotEmpty
                  ? upcomingAppointments.first.start
                  : null,
          lastCompleted:
              completedAppointments.isNotEmpty
                  ? completedAppointments.first.end
                  : null,
          loyaltyPoints: client.loyaltyPoints,
          hasUpcoming: upcomingAppointments.isNotEmpty,
          hasPushToken: client.fcmTokens.isNotEmpty,
          hasEmail: client.email?.trim().isNotEmpty ?? false,
          onboardingStatus: client.onboardingStatus,
        ),
      );
    }

    rows.sort((a, b) {
      switch (_sortOption) {
        case _SortOption.name:
          return a.client.fullName.toLowerCase().compareTo(
            b.client.fullName.toLowerCase(),
          );
        case _SortOption.lastCompleted:
          final aDate =
              a.lastCompleted ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              b.lastCompleted ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        case _SortOption.totalSpent:
          return b.totalSpent.compareTo(a.totalSpent);
      }
    });

    final sections = <_ResultRowSection>[];
    if (_groupByUpcoming) {
      final withUpcoming = rows.where((row) => row.hasUpcoming).toList();
      final withoutUpcoming = rows.where((row) => !row.hasUpcoming).toList();
      sections.add(
        _ResultRowSection(
          title: 'Con appuntamenti imminenti',
          rows: withUpcoming,
        ),
      );
      sections.add(
        _ResultRowSection(
          title: 'Senza appuntamenti imminenti',
          rows: withoutUpcoming,
        ),
      );
    } else {
      sections.add(_ResultRowSection(title: null, rows: rows));
    }

    final children = <Widget>[
      _buildResultsToolbar(
        context: context,
        totalResults: totalResults,
        visibleResults: rows.length,
      ),
      const SizedBox(height: 12),
    ];

    for (final section in sections) {
      if (section.rows.isEmpty) {
        continue;
      }
      children.add(
        _buildResultSectionCard(
          context: context,
          section: section,
          currencyFormat: currencyFormat,
        ),
      );
      children.add(const SizedBox(height: 16));
    }

    if (children.length > 2) {
      children.removeLast();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildResultSectionCard({
    required BuildContext context,
    required _ResultRowSection section,
    required NumberFormat currencyFormat,
  }) {
    final theme = Theme.of(context);
    final rows = section.rows;
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final tableChildren = <Widget>[
      _buildResultsHeaderRow(context: context, rows: rows),
      const Divider(height: 1, thickness: 1),
    ];

    for (var i = 0; i < rows.length; i += 1) {
      tableChildren.add(
        _buildResultRow(
          context: context,
          data: rows[i],
          currencyFormat: currencyFormat,
        ),
      );
      if (i != rows.length - 1) {
        tableChildren.add(const Divider(height: 1, thickness: 1));
      }
    }

    final borderRadius = BorderRadius.circular(16);
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                section.title!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft:
                  section.title == null ? borderRadius.topLeft : Radius.zero,
              topRight:
                  section.title == null ? borderRadius.topRight : Radius.zero,
              bottomLeft: borderRadius.bottomLeft,
              bottomRight: borderRadius.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: tableChildren,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeaderRow({
    required BuildContext context,
    required List<_ResultRowData> rows,
  }) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final hasRows = rows.isNotEmpty;
    final allSelected =
        hasRows &&
        rows.every((row) => _bulkSelectedClientIds.contains(row.client.id));
    final anySelected =
        hasRows &&
        rows.any((row) => _bulkSelectedClientIds.contains(row.client.id));
    final checkboxValue =
        !hasRows ? false : (allSelected ? true : (anySelected ? null : false));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 42,
            child: Checkbox(
              tristate: true,
              value: checkboxValue,
              onChanged:
                  hasRows
                      ? (value) =>
                          _toggleBulkSelectionForRows(rows, value ?? true)
                      : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: Text('Cliente', style: headerStyle)),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: Text('Contatti', style: headerStyle)),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: Text('Storico', style: headerStyle)),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text('Indicatori rapidi', style: headerStyle),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            child: Align(
              alignment: Alignment.center,
              child: Text('Azioni', style: headerStyle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsToolbar({
    required BuildContext context,
    required int totalResults,
    required int visibleResults,
  }) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Risultati: $visibleResults / $totalResults',
          style: theme.textTheme.titleMedium,
        ),
        DropdownButton<_SortOption>(
          value: _sortOption,
          onChanged: (value) {
            if (value == null) return;
            setState(() => _sortOption = value);
          },
          items:
              _SortOption.values
                  .map(
                    (option) => DropdownMenuItem<_SortOption>(
                      value: option,
                      child: Text(_sortOptionLabel(option)),
                    ),
                  )
                  .toList(),
        ),
        FilterChip(
          avatar: const Icon(Icons.group_work_rounded, size: 18),
          label: const Text('Raggruppa per appuntamenti'),
          selected: _groupByUpcoming,
          onSelected: (value) => setState(() => _groupByUpcoming = value),
        ),
        if (_bulkSelectedClientIds.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.check_circle_rounded, size: 18),
            label: Text('${_bulkSelectedClientIds.length} selezionati'),
          ),
      ],
    );
  }

  Widget _buildResultRow({
    required BuildContext context,
    required _ResultRowData data,
    required NumberFormat currencyFormat,
  }) {
    final theme = Theme.of(context);
    final client = data.client;
    final isDetailSelected = _selectedClientId == client.id;
    final isBulkSelected = _bulkSelectedClientIds.contains(client.id);
    final backgroundColor =
        isDetailSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : isBulkSelected
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surface;
    final nameStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final emphasisStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.outline,
    );
    final bodyStyle = theme.textTheme.bodySmall;
    final indicatorChips = _buildIndicatorChips(data, currencyFormat);

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () {
          if (_isBulkSelecting) {
            _toggleBulkSelection(client.id);
          } else {
            setState(() {
              _selectedClientId = isDetailSelected ? null : client.id;
            });
          }
        },
        onLongPress: () => _toggleBulkSelection(client.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 42,
                child: Checkbox(
                  value: isBulkSelected,
                  onChanged: (_) => _toggleBulkSelection(client.id),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _buildClientCell(
                  client: client,
                  nameStyle: nameStyle,
                  metaStyle: emphasisStyle,
                  bodyStyle: bodyStyle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _buildContactsCell(
                  theme: theme,
                  phone: client.phone,
                  email: client.email,
                  hasEmail: data.hasEmail,
                  hasPushToken: data.hasPushToken,
                  bodyStyle: bodyStyle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _buildStatsCell(
                  theme: theme,
                  data: data,
                  currencyFormat: currencyFormat,
                  bodyStyle: bodyStyle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child:
                    indicatorChips.isEmpty
                        ? Text(
                          '—',
                          style: bodyStyle?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        )
                        : Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: indicatorChips,
                        ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                child: IconButton(
                  tooltip: 'Apri dettaglio',
                  onPressed:
                      () => setState(() => _selectedClientId = client.id),
                  icon: const Icon(Icons.open_in_new_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientCell({
    required Client client,
    TextStyle? nameStyle,
    TextStyle? metaStyle,
    TextStyle? bodyStyle,
  }) {
    final city = client.city?.trim();
    final profession = client.profession?.trim();
    final subtitleColor = metaStyle?.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_displayName(client), style: nameStyle),
        if (client.clientNumber != null &&
            client.clientNumber!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('N° ${client.clientNumber!.trim()}', style: metaStyle),
          ),
        if (city != null && city.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(city, style: bodyStyle),
          ),
        if (profession != null && profession.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              profession,
              style: bodyStyle?.copyWith(color: subtitleColor),
            ),
          ),
      ],
    );
  }

  Widget _buildContactsCell({
    required ThemeData theme,
    required String phone,
    required String? email,
    required bool hasEmail,
    required bool hasPushToken,
    TextStyle? bodyStyle,
  }) {
    final entries = <Widget>[];
    if (phone.trim().isNotEmpty) {
      entries.add(
        _buildIconLabelRow(
          icon: Icons.phone_rounded,
          label: phone.trim(),
          style: bodyStyle,
        ),
      );
    }
    entries.add(
      _buildIconLabelRow(
        icon:
            hasEmail ? Icons.email_outlined : Icons.mark_email_unread_outlined,
        label: hasEmail ? email!.trim() : 'Email assente',
        style:
            hasEmail
                ? bodyStyle
                : bodyStyle?.copyWith(color: theme.colorScheme.error),
        iconColor: hasEmail ? null : theme.colorScheme.error,
      ),
    );
    if (hasPushToken) {
      entries.add(
        _buildIconLabelRow(
          icon: Icons.notifications_active_rounded,
          label: 'Push attivo',
          style: bodyStyle,
          iconColor: theme.colorScheme.primary,
        ),
      );
    }
    if (entries.isEmpty) {
      entries.add(
        Text('—', style: bodyStyle?.copyWith(color: theme.colorScheme.outline)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i != 0) const SizedBox(height: 4),
          entries[i],
        ],
      ],
    );
  }

  Widget _buildStatsCell({
    required ThemeData theme,
    required _ResultRowData data,
    required NumberFormat currencyFormat,
    TextStyle? bodyStyle,
  }) {
    final stats = <Widget>[
      Text('Appuntamenti: ${data.appointmentsCount}', style: bodyStyle),
      Text('Acquisti: ${data.purchasesCount}', style: bodyStyle),
    ];
    if (data.loyaltyPoints > 0) {
      stats.add(Text('Punti: ${data.loyaltyPoints}', style: bodyStyle));
    }
    stats.add(
      Text(
        'Spesa: ${_formatCurrencySafely(currencyFormat, data.totalSpent)}',
        style: bodyStyle,
      ),
    );
    if (data.hasOutstanding) {
      stats.add(
        Text(
          'Saldo residuo',
          style: bodyStyle?.copyWith(color: theme.colorScheme.error),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i != 0) const SizedBox(height: 4),
          stats[i],
        ],
      ],
    );
  }

  Widget _buildIconLabelRow({
    required IconData icon,
    required String label,
    TextStyle? style,
    Color? iconColor,
  }) {
    final effectiveIconColor = iconColor ?? style?.color;
    return Row(
      children: [
        Icon(icon, size: 16, color: effectiveIconColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text(label, style: style, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  List<Widget> _buildIndicatorChips(
    _ResultRowData data,
    NumberFormat currencyFormat,
  ) {
    final chips = <Widget>[];
    final onboardingTone = () {
      switch (data.onboardingStatus) {
        case ClientOnboardingStatus.notSent:
          return ChipTone.warning;
        case ClientOnboardingStatus.invitationSent:
        case ClientOnboardingStatus.firstLogin:
          return ChipTone.emphasis;
        case ClientOnboardingStatus.onboardingCompleted:
          return ChipTone.neutral;
      }
    }();
    chips.add(
      _buildInfoChip(
        icon: Icons.how_to_reg_rounded,
        label: _statusLabel(data.onboardingStatus),
        tone: onboardingTone,
      ),
    );
    if (data.nextAppointment != null) {
      chips.add(
        _buildInfoChip(
          icon: Icons.event_available_rounded,
          label: 'Prossimo: ${_formatUpcomingLabel(data.nextAppointment!)}',
          tone: ChipTone.emphasis,
        ),
      );
    }
    if (data.lastCompleted != null) {
      chips.add(
        _buildInfoChip(
          icon: Icons.history_toggle_off_rounded,
          label: 'Ultima seduta: ${_formatPastLabel(data.lastCompleted!)}',
        ),
      );
    }
    if (data.totalSpent > 0) {
      chips.add(
        _buildInfoChip(
          icon: Icons.euro_rounded,
          label:
              'Spesa: ${_formatCurrencySafely(currencyFormat, data.totalSpent)}',
        ),
      );
    }
    if (data.hasOutstanding) {
      chips.add(
        _buildInfoChip(
          icon: Icons.report_gmailerrorred_rounded,
          label: 'Saldo residuo',
          tone: ChipTone.warning,
        ),
      );
    }
    return chips;
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    ChipTone tone = ChipTone.neutral,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Color background;
    Color foreground;
    switch (tone) {
      case ChipTone.emphasis:
        background = colorScheme.primaryContainer;
        foreground = colorScheme.onPrimaryContainer;
        break;
      case ChipTone.warning:
        background = colorScheme.errorContainer;
        foreground = colorScheme.onErrorContainer;
        break;
      case ChipTone.neutral:
        background = colorScheme.surfaceContainerHighest;
        foreground = colorScheme.onSurfaceVariant;
        break;
    }
    return Chip(
      backgroundColor: background,
      avatar: Icon(icon, size: 16, color: foreground),
      label: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(color: foreground),
      ),
    );
  }

  String _formatUpcomingLabel(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    if (diff <= 0) {
      return 'oggi ${DateFormat('HH:mm').format(date)}';
    }
    if (diff == 1) {
      return 'domani ${DateFormat('HH:mm').format(date)}';
    }
    return 'tra $diff g';
  }

  String _formatPastLabel(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff <= 0) {
      return 'oggi';
    }
    if (diff == 1) {
      return 'ieri';
    }
    return '$diff g fa';
  }

  String _sortOptionLabel(_SortOption option) {
    switch (option) {
      case _SortOption.name:
        return 'Ordina per nome';
      case _SortOption.lastCompleted:
        return 'Ultima seduta';
      case _SortOption.totalSpent:
        return 'Spesa totale';
    }
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
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
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
    _setControllerText(_minAgeController, filters.minAge?.toString() ?? '');
    _setControllerText(_maxAgeController, filters.maxAge?.toString() ?? '');
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
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        maintainState: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle:
            subtitle != null
                ? Text(subtitle!, style: theme.textTheme.bodySmall)
                : null,
        children: [Align(alignment: Alignment.centerLeft, child: child)],
      ),
    );
  }
}

class _AdvancedFilterSection {
  const _AdvancedFilterSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;
}

class _FilterChipData {
  _FilterChipData({required this.label, required this.onRemoved});

  final String label;
  final VoidCallback onRemoved;
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
    final query = _searchController.text.trim().toLowerCase();
    final filtered =
        widget.items.where((item) {
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
                itemBuilder: (context, index) {
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

enum _SortOption { name, lastCompleted, totalSpent }

enum ChipTone { neutral, emphasis, warning }

class _ResultRowSection {
  const _ResultRowSection({required this.title, required this.rows});

  final String? title;
  final List<_ResultRowData> rows;
}

class _ResultRowData {
  const _ResultRowData({
    required this.client,
    required this.appointmentsCount,
    required this.purchasesCount,
    required this.totalSpent,
    required this.hasOutstanding,
    required this.nextAppointment,
    required this.lastCompleted,
    required this.loyaltyPoints,
    required this.hasUpcoming,
    required this.hasPushToken,
    required this.hasEmail,
    required this.onboardingStatus,
  });

  final Client client;
  final int appointmentsCount;
  final int purchasesCount;
  final double totalSpent;
  final bool hasOutstanding;
  final DateTime? nextAppointment;
  final DateTime? lastCompleted;
  final int loyaltyPoints;
  final bool hasUpcoming;
  final bool hasPushToken;
  final bool hasEmail;
  final ClientOnboardingStatus onboardingStatus;
}
