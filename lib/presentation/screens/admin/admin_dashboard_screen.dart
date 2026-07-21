import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/app/theme_constants.dart';
import 'package:you_book/data/models/app_user.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/entities/client_app_movement.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/payment_ticket.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/salon_access_request.dart';
import 'package:you_book/domain/entities/staff_absence_request.dart';
import 'package:you_book/presentation/common/app_feedback_dialog.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments_module.dart';
import 'package:you_book/presentation/screens/admin/modules/clients_module.dart';
import 'package:you_book/presentation/screens/admin/modules/client_app_movements_module.dart';
import 'package:you_book/presentation/screens/admin/modules/expenses_module.dart';
import 'package:you_book/presentation/screens/admin/modules/inventory_module.dart';
import 'package:you_book/presentation/screens/admin/modules/messages_module.dart';
import 'package:you_book/presentation/screens/admin/modules/overview_module.dart';
import 'package:you_book/presentation/screens/admin/modules/reports_module.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_aggregator.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_export_service.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_models.dart';
import 'package:you_book/presentation/screens/admin/modules/sales_module.dart';
import 'package:you_book/presentation/screens/admin/modules/salon_management_module.dart';
import 'package:you_book/presentation/screens/admin/modules/services_module.dart';
import 'package:you_book/presentation/screens/admin/modules/staff_module.dart';
import 'package:you_book/presentation/screens/admin/modules/whatsapp_module.dart';
import 'package:you_book/presentation/screens/admin/widgets/admin_responsive_helpers.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

typedef AdminModuleBuilder =
    Widget Function(BuildContext context, WidgetRef ref, String? salonId);

enum AdminNavigationSection { top, business, core, sales, promo }

class AdminNavigationSectionConfig {
  const AdminNavigationSectionConfig({
    required this.section,
    required this.label,
    required this.expandable,
    required this.defaultVisibleModuleIds,
    this.hiddenModuleIds = const <String>[],
  });

  final AdminNavigationSection section;
  final String? label;
  final bool expandable;
  final List<String> defaultVisibleModuleIds;
  final List<String> hiddenModuleIds;
}

class AdminModuleDefinition {
  const AdminModuleDefinition({
    required this.id,
    required this.title,
    required this.icon,
    required this.section,
    required this.builder,
    this.subtitle,
    this.highlighted = false,
  });

  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final AdminNavigationSection section;
  final bool highlighted;
  final AdminModuleBuilder builder;
}

const Map<AdminNavigationSection, AdminNavigationSectionConfig>
_adminNavigationSectionConfigs =
    <AdminNavigationSection, AdminNavigationSectionConfig>{
      AdminNavigationSection.top: AdminNavigationSectionConfig(
        section: AdminNavigationSection.top,
        label: null,
        expandable: false,
        defaultVisibleModuleIds: <String>['overview'],
      ),
      AdminNavigationSection.business: AdminNavigationSectionConfig(
        section: AdminNavigationSection.business,
        label: 'BUSINESS',
        expandable: true,
        defaultVisibleModuleIds: <String>['salons', 'clients'],
        hiddenModuleIds: <String>['app_movements', 'reports'],
      ),
      AdminNavigationSection.core: AdminNavigationSectionConfig(
        section: AdminNavigationSection.core,
        label: 'OPERATIVO',
        expandable: false,
        defaultVisibleModuleIds: <String>['appointments', 'sales', 'expenses'],
      ),
      AdminNavigationSection.sales: AdminNavigationSectionConfig(
        section: AdminNavigationSection.sales,
        label: 'GESTIONE',
        expandable: true,
        defaultVisibleModuleIds: <String>['staff'],
        hiddenModuleIds: <String>['services', 'inventory'],
      ),
      AdminNavigationSection.promo: AdminNavigationSectionConfig(
        section: AdminNavigationSection.promo,
        label: 'PROMO',
        expandable: false,
        defaultVisibleModuleIds: <String>['messages', 'whatsapp'],
      ),
    };

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  static const String _movementPrefsKeyPrefix = 'admin_movements_last_seen';
  static const String _sidebarPrefsKeyPrefix =
      'admin_sidebar_expanded_sections';
  static const Map<AdminNavigationSection, bool> _defaultExpandedSections =
      <AdminNavigationSection, bool>{
        AdminNavigationSection.business: false,
        AdminNavigationSection.sales: false,
      };

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  ProviderSubscription<AdminDashboardIntent?>? _intentSubscription;
  SharedPreferences? _preferences;
  final Map<String, DateTime?> _movementLastSeen = <String, DateTime?>{};
  final Set<String> _movementLoadingKeys = <String>{};
  String? _currentSalonId;
  String? _expandedSectionsUid;
  final ReportExportService _reportExportService = const ReportExportService();
  bool _isExportingReportsPdf = false;
  late final Map<AdminNavigationSection, bool> _expandedSections;

  static final _modules = <AdminModuleDefinition>[
    AdminModuleDefinition(
      id: 'overview',
      title: 'Panoramica',
      subtitle: 'Vista generale dell\'attività',
      icon: FontAwesomeIcons.tableCellsLarge,
      section: AdminNavigationSection.top,
      builder: (context, ref, salonId) => AdminOverviewModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'salons',
      title: 'Saloni',
      icon: FontAwesomeIcons.building,
      section: AdminNavigationSection.business,
      builder:
          (context, ref, salonId) =>
              SalonManagementModule(selectedSalonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'clients',
      title: 'Clienti',
      icon: FontAwesomeIcons.users,
      section: AdminNavigationSection.business,
      builder: (context, ref, salonId) => ClientsModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'app_movements',
      title: 'Movimenti App',
      icon: FontAwesomeIcons.arrowTrendUp,
      section: AdminNavigationSection.business,
      builder:
          (context, ref, salonId) => ClientAppMovementsModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'reports',
      title: 'Report',
      icon: FontAwesomeIcons.chartColumn,
      section: AdminNavigationSection.business,
      builder: (context, ref, salonId) => ReportsModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'appointments',
      title: 'Agenda',
      icon: FontAwesomeIcons.calendarDays,
      section: AdminNavigationSection.core,
      highlighted: true,
      builder: (context, ref, salonId) => AppointmentsModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'staff',
      title: 'Staff',
      icon: FontAwesomeIcons.userGear,
      section: AdminNavigationSection.sales,
      builder: (context, ref, salonId) => StaffModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'sales',
      title: 'Vendite & Cassa',
      icon: FontAwesomeIcons.cartShopping,
      section: AdminNavigationSection.core,
      builder: (context, ref, salonId) => SalesModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'expenses',
      title: 'Uscite',
      icon: FontAwesomeIcons.fileInvoiceDollar,
      section: AdminNavigationSection.core,
      builder: (context, ref, salonId) => ExpensesModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'services',
      title: 'Servizi & Pacchetti',
      icon: FontAwesomeIcons.cube,
      section: AdminNavigationSection.sales,
      builder: (context, ref, salonId) => ServicesModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'inventory',
      title: 'Magazzino',
      icon: FontAwesomeIcons.boxesStacked,
      section: AdminNavigationSection.sales,
      builder: (context, ref, salonId) => InventoryModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'messages',
      title: 'Messaggi & Marketing',
      icon: FontAwesomeIcons.message,
      section: AdminNavigationSection.promo,
      builder:
          (context, ref, salonId) => MessagesMarketingModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'whatsapp',
      title: 'WhatsApp',
      icon: FontAwesomeIcons.whatsapp,
      section: AdminNavigationSection.promo,
      builder: (context, ref, salonId) => WhatsAppModule(salonId: salonId),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _expandedSections = Map<AdminNavigationSection, bool>.from(
      _defaultExpandedSections,
    );
    _intentSubscription = ref.listenManual<AdminDashboardIntent?>(
      adminDashboardIntentProvider,
      (previous, next) {
        final intent = next;
        if (intent == null) {
          return;
        }
        _handleAdminIntent(intent);
        ref.read(adminDashboardIntentProvider.notifier).state = null;
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final moduleId = GoRouterState.of(context).uri.queryParameters['module'];
      if (moduleId == null || moduleId.isEmpty) {
        return;
      }
      _handleAdminIntent(AdminDashboardIntent(moduleId: moduleId));
    });
  }

  @override
  void dispose() {
    _intentSubscription?.close();
    super.dispose();
  }

  void _handleAdminIntent(AdminDashboardIntent intent) {
    final targetIndex = _modules.indexWhere(
      (module) => module.id == intent.moduleId,
    );
    if (targetIndex == -1) {
      return;
    }

    _selectModule(targetIndex, allowPop: false);

    if (intent.moduleId == 'clients') {
      final payload = intent.payload;
      final detailTabIndexValue = payload['detailTabIndex'];
      final detailTabIndex =
          detailTabIndexValue is int ? detailTabIndexValue : null;
      ref
          .read(clientsModuleIntentProvider.notifier)
          .state = ClientsModuleIntent(
        generalQuery: payload['generalQuery'] as String?,
        clientNumber: payload['clientNumber'] as String?,
        clientId: payload['clientId'] as String?,
        detailTabIndex: detailTabIndex,
      );
      return;
    }

    if (intent.moduleId == 'appointments') {
      final payload = intent.payload;
      final rawFocusDateTime = payload['focusDateTime'];
      DateTime? focusDateTime;
      if (rawFocusDateTime is DateTime) {
        focusDateTime = rawFocusDateTime;
      } else if (rawFocusDateTime is String) {
        focusDateTime = DateTime.tryParse(rawFocusDateTime);
      }
      if (focusDateTime != null) {
        ref
            .read(appointmentsModuleIntentProvider.notifier)
            .state = AppointmentsModuleIntent(focusDateTime: focusDateTime);
      }
    }
  }

  void _selectModule(int index, {required bool allowPop}) {
    final previousModuleId = _modules[_selectedIndex].id;
    final nextModuleId = _modules[index].id;
    _expandSectionForModule(nextModuleId);
    if (_selectedIndex != index) {
      if (mounted) {
        setState(() => _selectedIndex = index);
      } else {
        _selectedIndex = index;
      }
    }
    if (previousModuleId == 'appointments' && nextModuleId != 'appointments') {
      ref.read(appointmentsModuleAppBarStateProvider.notifier).state = null;
    }
    _handleModuleSelectionSideEffects(nextModuleId);
    if (allowPop) {
      Navigator.of(context).maybePop();
    }
  }

  void _handleModuleSelectionSideEffects(String moduleId) {
    if (moduleId == 'app_movements') {
      _markMovementsRead(ref.read(appDataProvider), _currentSalonId);
    }
  }

  void _toggleSection(AdminNavigationSection section) {
    final config = _adminNavigationSectionConfigs[section];
    if (config == null ||
        !config.expandable ||
        config.hiddenModuleIds.isEmpty) {
      return;
    }
    setState(() {
      _expandedSections[section] = !(_expandedSections[section] ?? false);
    });
    unawaited(_persistExpandedSections());
  }

  void _expandSectionForModule(String moduleId) {
    for (final entry in _adminNavigationSectionConfigs.entries) {
      final config = entry.value;
      if (!config.expandable || !config.hiddenModuleIds.contains(moduleId)) {
        continue;
      }
      if (_expandedSections[entry.key] == true) {
        return;
      }
      if (mounted) {
        setState(() => _expandedSections[entry.key] = true);
      } else {
        _expandedSections[entry.key] = true;
      }
      unawaited(_persistExpandedSections());
      return;
    }
  }

  String _movementSalonKey(String? salonId) => salonId ?? 'all';

  String _movementPrefsKey(String salonKey) =>
      '$_movementPrefsKeyPrefix::$salonKey';

  String _expandedSectionsPrefsKey(String uid) =>
      '$_sidebarPrefsKeyPrefix::$uid';

  Map<AdminNavigationSection, bool> _collapsedExpandedSectionsState() =>
      Map<AdminNavigationSection, bool>.from(_defaultExpandedSections);

  Future<SharedPreferences> _ensurePreferences() async {
    final cached = _preferences;
    if (cached != null) {
      return cached;
    }
    final resolved = await SharedPreferences.getInstance();
    _preferences = resolved;
    return resolved;
  }

  Future<void> _restoreExpandedSections(String uid) async {
    SharedPreferences prefs;
    try {
      prefs = await _ensurePreferences();
    } catch (_) {
      return;
    }
    final raw = prefs.getStringList(_expandedSectionsPrefsKey(uid));
    final restored = _collapsedExpandedSectionsState();
    if (raw != null) {
      for (final rawSection in raw) {
        final section =
            AdminNavigationSection.values.where((value) {
              final config = _adminNavigationSectionConfigs[value];
              return value.name == rawSection && (config?.expandable ?? false);
            }).firstOrNull;
        if (section != null) {
          restored[section] = true;
        }
      }
    }
    if (!mounted || _expandedSectionsUid != uid) {
      return;
    }
    setState(() {
      _expandedSections
        ..clear()
        ..addAll(restored);
    });
  }

  Future<void> _persistExpandedSections() async {
    final uid = _expandedSectionsUid;
    if (uid == null || uid.isEmpty) {
      return;
    }
    SharedPreferences prefs;
    try {
      prefs = await _ensurePreferences();
    } catch (_) {
      return;
    }
    final expanded = _expandedSections.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key.name)
        .toList(growable: false);
    await prefs.setStringList(_expandedSectionsPrefsKey(uid), expanded);
  }

  void _restoreExpandedSectionsForAdmin(String? uid) {
    final normalizedUid = uid?.trim();
    if (_expandedSectionsUid == normalizedUid) {
      return;
    }
    _expandedSectionsUid = normalizedUid;
    _expandedSections
      ..clear()
      ..addAll(_collapsedExpandedSectionsState());
    if (normalizedUid == null || normalizedUid.isEmpty) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    unawaited(_restoreExpandedSections(normalizedUid));
  }

  void _restoreMovementLastSeenIfNeeded(String salonKey) {
    if (_movementLastSeen.containsKey(salonKey) ||
        _movementLoadingKeys.contains(salonKey)) {
      return;
    }
    _movementLoadingKeys.add(salonKey);
    unawaited(_restoreMovementLastSeen(salonKey));
  }

  Future<void> _restoreMovementLastSeen(String salonKey) async {
    SharedPreferences prefs;
    try {
      prefs = await _ensurePreferences();
    } catch (_) {
      _movementLoadingKeys.remove(salonKey);
      return;
    }
    final raw = prefs.getString(_movementPrefsKey(salonKey));
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (!mounted) {
      _movementLoadingKeys.remove(salonKey);
      return;
    }
    setState(() {
      _movementLastSeen[salonKey] = parsed;
      _movementLoadingKeys.remove(salonKey);
    });
  }

  Future<void> _persistMovementLastSeen(
    String salonKey,
    DateTime timestamp,
  ) async {
    SharedPreferences prefs;
    try {
      prefs = await _ensurePreferences();
    } catch (_) {
      return;
    }
    await prefs.setString(
      _movementPrefsKey(salonKey),
      timestamp.toIso8601String(),
    );
  }

  void _updateMovementLastSeen(String salonKey, DateTime timestamp) {
    final previous = _movementLastSeen[salonKey];
    if (previous != null && !timestamp.isAfter(previous)) {
      return;
    }
    setState(() => _movementLastSeen[salonKey] = timestamp);
    unawaited(_persistMovementLastSeen(salonKey, timestamp));
  }

  void _markMovementsRead(AppDataState data, String? salonId) {
    final salonKey = _movementSalonKey(salonId);
    final movements =
        data.clientAppMovements
            .where(
              (movement) =>
                  (salonId == null || movement.salonId == salonId) &&
                  _isClientAppMovement(movement),
            )
            .toList();
    if (movements.isEmpty) {
      _updateMovementLastSeen(salonKey, DateTime.now());
      return;
    }
    movements.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _updateMovementLastSeen(salonKey, movements.first.timestamp);
  }

  bool _isClientAppMovement(ClientAppMovement movement) {
    final tokens = <String>[];

    void collect(dynamic value) {
      if (value == null) {
        return;
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          tokens.add(trimmed.toLowerCase());
        }
      } else if (value is Iterable) {
        for (final item in value) {
          collect(item);
        }
      } else if (value is Map) {
        for (final entry in value.entries) {
          collect(entry.value);
        }
      }
    }

    collect(movement.source);
    collect(movement.channel);
    collect(movement.createdBy);
    collect(movement.metadata);

    bool hasAppIndicator = false;
    bool hasStripeIndicator = false;
    bool hasStaffIndicator = false;

    for (final token in tokens) {
      if (token.contains('stripe')) {
        hasStripeIndicator = true;
      }
      if (token.contains('app') ||
          token.contains('client') ||
          token.contains('mobile') ||
          token.contains('ios') ||
          token.contains('android') ||
          token.contains('self') ||
          token.contains('online') ||
          token.contains('web')) {
        hasAppIndicator = true;
      }
      if (token.contains('admin') ||
          token.contains('staff') ||
          token.contains('operator') ||
          token.contains('desk') ||
          token.contains('backoffice')) {
        hasStaffIndicator = true;
      }
    }

    if (hasStripeIndicator || hasAppIndicator) {
      return true;
    }
    if (hasStaffIndicator) {
      return false;
    }
    return true;
  }

  Map<String, int> _moduleBadgeCounts(AppDataState data, String? salonId) {
    bool matchesSalon(String? candidate) =>
        salonId == null || candidate == salonId;

    final pendingAccess =
        data.salonAccessRequests
            .where(
              (request) =>
                  request.status == SalonAccessRequestStatus.pending &&
                  matchesSalon(request.salonId),
            )
            .length;

    final pendingAbsences =
        data.staffAbsenceRequests
            .where(
              (request) =>
                  request.status == StaffAbsenceRequestStatus.pending &&
                  matchesSalon(request.salonId),
            )
            .length;

    final salonKey = _movementSalonKey(salonId);
    _restoreMovementLastSeenIfNeeded(salonKey);
    final movementCutoff = _movementLastSeen[salonKey];
    final unreadMovements =
        data.clientAppMovements
            .where(
              (movement) =>
                  matchesSalon(movement.salonId) &&
                  _isClientAppMovement(movement) &&
                  (movementCutoff == null ||
                      movement.timestamp.isAfter(movementCutoff)),
            )
            .length;

    final lowInventory =
        data.inventoryItems
            .where(
              (item) => matchesSalon(item.salonId) && _isLowInventory(item),
            )
            .length;

    final openTickets =
        data.paymentTickets
            .where(
              (ticket) =>
                  ticket.status == PaymentTicketStatus.open &&
                  matchesSalon(ticket.salonId),
            )
            .length;

    return <String, int>{
      'clients': pendingAccess,
      'staff': pendingAbsences,
      'app_movements': unreadMovements,
      'inventory': lowInventory,
      'sales': openTickets,
    };
  }

  bool _isLowInventory(InventoryItem item) => item.quantity <= item.threshold;

  Future<void> _exportReportsPdf(ReportsSnapshot snapshot) async {
    if (_isExportingReportsPdf || !snapshot.hasAnyData) {
      return;
    }
    setState(() => _isExportingReportsPdf = true);
    try {
      final pdf = await _reportExportService.buildExecutivePdf(
        snapshot: snapshot,
      );
      await _reportExportService.shareFiles(
        files: [pdf],
        subject: 'Report analytics youbook',
        text: 'Report esportato dal modulo analytics.',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('PDF report generato correttamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Impossibile esportare il PDF: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingReportsPdf = false);
      } else {
        _isExportingReportsPdf = false;
      }
    }
  }

  Future<void> _handleSignOutRequest() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Conferma logout'),
          content: const Text(
            'Sei sicuro di voler uscire dall\'account amministratore?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Esci'),
            ),
          ],
        );
      },
    );
    if (shouldSignOut != true) {
      return;
    }
    if (!mounted) {
      return;
    }
    await performSignOut(ref);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final session = ref.watch(sessionControllerProvider);
    _restoreExpandedSectionsForAdmin(session.uid);
    final salons = data.salons;

    final salonIds = salons.map((salon) => salon.id).toSet();
    final availableSalonIds =
        session.availableSalonIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet();
    final requestedSalonId = session.selectedSalonId ?? session.salonId;
    String? selectedSalonId;

    if (requestedSalonId != null && salonIds.contains(requestedSalonId)) {
      selectedSalonId = requestedSalonId;
    } else if (requestedSalonId != null &&
        availableSalonIds.contains(requestedSalonId.trim())) {
      selectedSalonId = requestedSalonId;
    } else if (salons.isNotEmpty) {
      selectedSalonId = salons.first.id;
    } else {
      selectedSalonId = requestedSalonId;
    }
    _currentSalonId = selectedSalonId;
    final badgeCounts = _moduleBadgeCounts(data, selectedSalonId);
    final selectedModule = _modules[_selectedIndex];
    final selectedBadgeCount = badgeCounts[selectedModule.id] ?? 0;
    final isReportsModule = selectedModule.id == 'reports';
    final isAppointmentsModule = selectedModule.id == 'appointments';
    final appointmentsAppBarState =
        isAppointmentsModule
            ? ref.watch(appointmentsModuleAppBarStateProvider)
            : null;
    final routerState = GoRouterState.of(context);
    final reportsFilters =
        isReportsModule
            ? ReportFilters.fromUri(
              routerState.uri,
              defaultSalonId: selectedSalonId,
            )
            : null;
    final reportsSnapshot =
        reportsFilters == null
            ? null
            : ReportsAggregator.build(data: data, filters: reportsFilters);

    final mediaQuery = MediaQuery.of(context);
    final baseScale = mediaQuery.textScaler.scale(1);
    final adminScaleFactor = resolveAdminTextScaleFactor(mediaQuery.size.width);
    final effectiveScale = baseScale * adminScaleFactor;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.linear(effectiveScale)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          final isLargeScreen = constraints.maxWidth >= 1080;
          final moduleBackground = theme.colorScheme.surfaceContainerLowest;
          final content = selectedModule.builder(context, ref, selectedSalonId);
          final selectedSalon =
              selectedSalonId == null
                  ? null
                  : salons.firstWhereOrNull(
                    (salon) => salon.id == selectedSalonId,
                  );
          final appointmentsToolbarHeight =
              appointmentsAppBarState == null
                  ? null
                  : (isLargeScreen ? kToolbarHeight : 118.0);
          final endDrawerWidth =
              constraints.maxWidth < 320
                  ? constraints.maxWidth
                  : math.min(420.0, constraints.maxWidth * 0.92);

          return Scaffold(
            key: _scaffoldKey,
            drawer:
                isLargeScreen
                    ? null
                    : Drawer(
                      child: SafeArea(
                        child: _DrawerNavigation(
                          modules: _modules,
                          selectedIndex: _selectedIndex,
                          badgeCounts: badgeCounts,
                          expandedSections: _expandedSections,
                          onSelect:
                              (index) => _selectModule(index, allowPop: true),
                          onToggleSection: _toggleSection,
                        ),
                      ),
                    ),
            endDrawer: Drawer(
              width: endDrawerWidth,
              child: SafeArea(
                child: _AdminAccountDrawer(
                  selectedSalon: selectedSalon,
                  salonCount: salons.length,
                  onSignOut: _handleSignOutRequest,
                  onDeleteAccount: () => context.go('/eliminazione-account'),
                ),
              ),
            ),
            appBar: AppBar(
              toolbarHeight:
                  appointmentsToolbarHeight ??
                  (selectedModule.subtitle == null
                      ? null
                      : kToolbarHeight + 12),
              centerTitle: false,
              titleSpacing: appointmentsAppBarState != null ? 8 : null,
              automaticallyImplyLeading: !isLargeScreen,
              title:
                  appointmentsAppBarState != null
                      ? _AppointmentsAppBarTitle(
                        module: selectedModule,
                        badgeCount: selectedBadgeCount,
                        state: appointmentsAppBarState,
                        isLargeScreen: isLargeScreen,
                        onPrevious: () {
                          ref
                                  .read(
                                    appointmentsModuleAppBarCommandProvider
                                        .notifier,
                                  )
                                  .state =
                              AppointmentsModuleAppBarCommand.previousRange;
                        },
                        onToday: () {
                          ref
                                  .read(
                                    appointmentsModuleAppBarCommandProvider
                                        .notifier,
                                  )
                                  .state =
                              AppointmentsModuleAppBarCommand.goToToday;
                        },
                        onPickDate: () {
                          ref
                              .read(
                                appointmentsModuleAppBarCommandProvider
                                    .notifier,
                              )
                              .state = AppointmentsModuleAppBarCommand.pickDate;
                        },
                        onNext: () {
                          ref
                                  .read(
                                    appointmentsModuleAppBarCommandProvider
                                        .notifier,
                                  )
                                  .state =
                              AppointmentsModuleAppBarCommand.nextRange;
                        },
                        onOpenVision: () {
                          ref
                                  .read(
                                    appointmentsModuleAppBarCommandProvider
                                        .notifier,
                                  )
                                  .state =
                              AppointmentsModuleAppBarCommand.openVision;
                        },
                      )
                      : isLargeScreen
                      ? Row(
                        children: [
                          _ModuleBadge(
                            module: selectedModule,
                            badgeCount: selectedBadgeCount,
                          ),
                        ],
                      )
                      : _ModuleBadge(
                        module: selectedModule,
                        badgeCount: selectedBadgeCount,
                      ),
              actions: [
                if (isReportsModule && reportsSnapshot != null)
                  IconButton(
                    tooltip: 'Esporta PDF',
                    onPressed:
                        _isExportingReportsPdf || !reportsSnapshot.hasAnyData
                            ? null
                            : () => _exportReportsPdf(reportsSnapshot),
                    icon:
                        _isExportingReportsPdf
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.picture_as_pdf_rounded),
                  ),
                IconButton(
                  tooltip: 'Impostazioni account',
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  icon: const Icon(Icons.settings_rounded),
                ),
              ],
            ),
            body: Row(
              children: [
                if (isLargeScreen)
                  _RailNavigation(
                    modules: _modules,
                    selectedIndex: _selectedIndex,
                    badgeCounts: badgeCounts,
                    expandedSections: _expandedSections,
                    onSelect: (index) => _selectModule(index, allowPop: false),
                    onToggleSection: _toggleSection,
                  ),
                Expanded(
                  child: ColoredBox(
                    color: moduleBackground,
                    child: _AdminModuleShell(child: content),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminAccountDrawer extends ConsumerWidget {
  const _AdminAccountDrawer({
    required this.selectedSalon,
    required this.salonCount,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final Salon? selectedSalon;
  final int salonCount;
  final Future<void> Function() onSignOut;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    final displayName = _displayName(user);
    final email = _trimmedOrNull(user?.email);
    final activeSalonLabel =
        selectedSalon?.name ??
        (salonCount == 0 ? 'Nessun salone collegato' : 'Tutti i saloni');
    final activeSalonDetail = _salonDetail(selectedSalon);
    final assignedSalonsLabel =
        salonCount == 1 ? '1 salone assegnato' : '$salonCount saloni assegnati';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Account',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Chiudi impostazioni',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: Text(
                        _initials(displayName),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Admin salone',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _AdminAccountInfoRow(
                  icon: Icons.alternate_email_rounded,
                  label: 'Email',
                  value: email ?? 'Non disponibile',
                ),
                const SizedBox(height: 12),
                _AdminAccountInfoRow(
                  icon: Icons.storefront_rounded,
                  label: 'Salone attivo',
                  value: activeSalonLabel,
                  detail: activeSalonDetail,
                ),
                const SizedBox(height: 12),
                _AdminAccountInfoRow(
                  icon: Icons.business_center_rounded,
                  label: 'Accesso',
                  value: assignedSalonsLabel,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _AdminDrawerSectionLabel(label: 'Preferenze'),
        const SizedBox(height: 8),
        _AdminDrawerSurface(
          child: SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: Icon(
              isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: scheme.primary,
            ),
            title: const Text('Tema scuro'),
            subtitle: const Text('Applica il tema scuro alla dashboard'),
            value: isDarkMode,
            onChanged: ref.read(themeModeProvider.notifier).setDarkEnabled,
          ),
        ),
        const SizedBox(height: 20),
        _AdminDrawerSectionLabel(label: 'Supporto'),
        const SizedBox(height: 8),
        _AdminDrawerSurface(
          child: Column(
            children: [
              _AdminDrawerTile(
                icon: Icons.star_rate_rounded,
                title: 'Valuta l\'app',
                subtitle: 'Apri la pagina store ufficiale di You Book',
                onTap: () => unawaited(_rateApp(context, ref)),
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
              _AdminDrawerTile(
                icon: Icons.feedback_rounded,
                title: 'Invia feedback app',
                subtitle: 'Segnala problemi o suggerimenti sul gestionale',
                onTap:
                    () => unawaited(
                      showAppFeedbackDialog(
                        context,
                        ref,
                        source: 'admin_account_drawer',
                      ),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _AdminDrawerSectionLabel(label: 'Sessione'),
        const SizedBox(height: 8),
        _AdminDrawerSurface(
          child: _AdminDrawerTile(
            icon: Icons.logout_rounded,
            title: 'Esci',
            subtitle: 'Termina la sessione amministratore',
            onTap: () => _closeAndRun(context, onSignOut),
          ),
        ),
        const SizedBox(height: 20),
        _AdminDrawerSectionLabel(label: 'Avanzate'),
        const SizedBox(height: 8),
        _AdminDrawerSurface(
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              leading: Icon(
                Icons.manage_accounts_rounded,
                color: scheme.onSurfaceVariant,
              ),
              title: const Text('Gestione account'),
              subtitle: const Text('Azioni sensibili e irreversibili'),
              children: [
                _AdminDrawerTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Eliminazione account',
                  subtitle: 'Apri il flusso di conferma dedicato',
                  iconColor: scheme.error,
                  titleColor: scheme.error,
                  onTap: () => _closeAndRun(context, onDeleteAccount),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _rateApp(BuildContext context, WidgetRef ref) async {
    final launched = await ref
        .read(appRatingServiceProvider)
        .openStoreListing(source: 'admin_account_drawer');
    if (!context.mounted || launched) {
      return;
    }
    ScaffoldMessenger.of(context).showAppSnackBar(
      const SnackBar(content: Text('Impossibile aprire lo store.')),
    );
  }

  static Future<void> _closeAndRun(
    BuildContext context,
    FutureOr<void> Function() action,
  ) async {
    await Navigator.of(context).maybePop();
    await action();
  }

  static String _displayName(AppUser? user) {
    final displayName = _trimmedOrNull(user?.displayName);
    if (displayName != null) {
      return displayName;
    }
    final email = _trimmedOrNull(user?.email);
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Admin salone';
  }

  static String? _salonDetail(Salon? salon) {
    if (salon == null) {
      return null;
    }
    final parts = <String>[
      if (salon.city.trim().isNotEmpty) salon.city.trim(),
      if (salon.address.trim().isNotEmpty) salon.address.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' - ');
  }

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static String _initials(String label) {
    final parts = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'A';
    }
    final first = parts.first.substring(0, 1).toUpperCase();
    if (parts.length == 1) {
      return first;
    }
    return '$first${parts.last.substring(0, 1).toUpperCase()}';
  }
}

class _AdminAccountInfoRow extends StatelessWidget {
  const _AdminAccountInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminDrawerSectionLabel extends StatelessWidget {
  const _AdminDrawerSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _AdminDrawerSurface extends StatelessWidget {
  const _AdminDrawerSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: child,
    );
  }
}

class _AdminDrawerTile extends StatelessWidget {
  const _AdminDrawerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resolvedIconColor = iconColor ?? scheme.primary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: resolvedIconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: resolvedIconColor, size: 22),
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class _AppointmentsAppBarTitle extends StatelessWidget {
  const _AppointmentsAppBarTitle({
    required this.module,
    required this.badgeCount,
    required this.state,
    required this.isLargeScreen,
    required this.onPrevious,
    required this.onToday,
    required this.onPickDate,
    required this.onNext,
    required this.onOpenVision,
  });

  final AdminModuleDefinition module;
  final int badgeCount;
  final AppointmentsModuleAppBarState state;
  final bool isLargeScreen;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onPickDate;
  final VoidCallback onNext;
  final VoidCallback onOpenVision;

  @override
  Widget build(BuildContext context) {
    if (!isLargeScreen) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: _ModuleBadge(module: module, badgeCount: badgeCount),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: _AppointmentsAppBarContent(
              state: state,
              isLargeScreen: false,
              onPrevious: onPrevious,
              onToday: onToday,
              onPickDate: onPickDate,
              onNext: onNext,
              onOpenVision: onOpenVision,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final reservedLeftWidth = math.min(260.0, constraints.maxWidth * 0.28);
        return Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: reservedLeftWidth),
                child: _ModuleBadge(module: module, badgeCount: badgeCount),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: reservedLeftWidth + 16),
              child: Center(
                child: _AppointmentsAppBarContent(
                  state: state,
                  isLargeScreen: true,
                  onPrevious: onPrevious,
                  onToday: onToday,
                  onPickDate: onPickDate,
                  onNext: onNext,
                  onOpenVision: onOpenVision,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AppointmentsAppBarContent extends StatelessWidget {
  const _AppointmentsAppBarContent({
    required this.state,
    required this.isLargeScreen,
    required this.onPrevious,
    required this.onToday,
    required this.onPickDate,
    required this.onNext,
    required this.onOpenVision,
  });

  final AppointmentsModuleAppBarState state;
  final bool isLargeScreen;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onPickDate;
  final VoidCallback onNext;
  final VoidCallback onOpenVision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rangeChip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 14 : 12,
        vertical: isLargeScreen ? 8 : 5,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.85),
        ),
      ),
      child: Text(
        state.rangeLabel,
        textAlign: TextAlign.center,
        maxLines: isLargeScreen ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        style: (isLargeScreen
                ? theme.textTheme.labelLarge
                : theme.textTheme.labelMedium)
            ?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
    final compactIconStyle = IconButton.styleFrom(
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      minimumSize: const Size(36, 36),
      padding: const EdgeInsets.all(8),
    );
    final todayButtonStyle = FilledButton.styleFrom(
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
    final dateNavigator = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isLargeScreen ? 348 : 220),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          IconButton(
            tooltip: 'Periodo precedente',
            onPressed: onPrevious,
            style: compactIconStyle,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLargeScreen ? 260 : 160),
              child: rangeChip,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Periodo successivo',
            onPressed: onNext,
            style: compactIconStyle,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );

    if (isLargeScreen) {
      return Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Visione agenda',
                onPressed: onOpenVision,
                icon: const Icon(Icons.tune_rounded),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                style: todayButtonStyle,
                onPressed: onToday,
                child: const Text('Oggi'),
              ),
              const SizedBox(width: 8),
              dateNavigator,
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                style: todayButtonStyle,
                onPressed: onPickDate,
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('Vai a data'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          IconButton(
            tooltip: 'Visione agenda',
            onPressed: onOpenVision,
            style: compactIconStyle,
            icon: const Icon(Icons.tune_rounded),
          ),
          FilledButton.tonal(
            style: todayButtonStyle,
            onPressed: onToday,
            child: const Text('Oggi'),
          ),
          dateNavigator,
          IconButton(
            tooltip: 'Vai a data',
            onPressed: onPickDate,
            style: compactIconStyle,
            icon: const Icon(Icons.event_available_rounded),
          ),
        ],
      ),
    );
  }
}

class _AdminModuleShell extends StatelessWidget {
  const _AdminModuleShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal:
              width >= 834 ? 8 : (width >= kAdminPhoneBreakpoint ? 6 : 2),
          vertical: width >= kAdminPhoneBreakpoint ? 6 : 4,
        ),
        child: child,
      ),
    );
  }
}

class _AdminNavigationGroup {
  const _AdminNavigationGroup({
    required this.section,
    required this.label,
    required this.expandable,
    required this.expanded,
    required this.visibleModules,
    required this.hiddenModules,
  });

  final AdminNavigationSection section;
  final String? label;
  final bool expandable;
  final bool expanded;
  final List<AdminModuleDefinition> visibleModules;
  final List<AdminModuleDefinition> hiddenModules;

  bool get hasToggle => expandable && hiddenModules.isNotEmpty;

  List<AdminModuleDefinition> get displayedModules =>
      expanded
          ? <AdminModuleDefinition>[...visibleModules, ...hiddenModules]
          : visibleModules;
}

List<_AdminNavigationGroup> _buildAdminNavigationGroups(
  List<AdminModuleDefinition> modules,
  Map<AdminNavigationSection, bool> expandedSections,
) {
  final moduleById = <String, AdminModuleDefinition>{
    for (final module in modules) module.id: module,
  };
  return AdminNavigationSection.values
      .map((section) {
        final config = _adminNavigationSectionConfigs[section];
        if (config == null) {
          return null;
        }
        final visibleModules = config.defaultVisibleModuleIds
            .map((moduleId) => moduleById[moduleId])
            .whereType<AdminModuleDefinition>()
            .toList(growable: false);
        final hiddenModules = config.hiddenModuleIds
            .map((moduleId) => moduleById[moduleId])
            .whereType<AdminModuleDefinition>()
            .toList(growable: false);
        if (visibleModules.isEmpty && hiddenModules.isEmpty) {
          return null;
        }
        return _AdminNavigationGroup(
          section: section,
          label: config.label,
          expandable: config.expandable,
          expanded: config.expandable && (expandedSections[section] ?? false),
          visibleModules: visibleModules,
          hiddenModules: hiddenModules,
        );
      })
      .whereType<_AdminNavigationGroup>()
      .toList(growable: false);
}

class _RailNavigation extends StatefulWidget {
  const _RailNavigation({
    required this.modules,
    required this.selectedIndex,
    required this.badgeCounts,
    required this.expandedSections,
    required this.onSelect,
    required this.onToggleSection,
  });

  final List<AdminModuleDefinition> modules;
  final int selectedIndex;
  final Map<String, int> badgeCounts;
  final Map<AdminNavigationSection, bool> expandedSections;
  final ValueChanged<int> onSelect;
  final ValueChanged<AdminNavigationSection> onToggleSection;

  @override
  State<_RailNavigation> createState() => _RailNavigationState();
}

class _RailNavigationState extends State<_RailNavigation> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final groups = _buildAdminNavigationGroups(
      widget.modules,
      widget.expandedSections,
    );
    final topGroup = groups.firstWhere(
      (group) => group.section == AdminNavigationSection.top,
      orElse:
          () => const _AdminNavigationGroup(
            section: AdminNavigationSection.top,
            label: null,
            expandable: false,
            expanded: false,
            visibleModules: <AdminModuleDefinition>[],
            hiddenModules: <AdminModuleDefinition>[],
          ),
    );
    final regularGroups = groups
        .where((group) => group.section != AdminNavigationSection.top)
        .toList(growable: false);
    return SizedBox(
      width: 92,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            right: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.75),
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              controller: _scrollController,
              thumbVisibility: false,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      for (final module in topGroup.displayedModules)
                        _DesktopNavigationButton(
                          key: ValueKey('admin_sidebar_item_${module.id}'),
                          module: module,
                          selected:
                              widget.modules[widget.selectedIndex].id ==
                              module.id,
                          badgeCount: widget.badgeCounts[module.id] ?? 0,
                          onTap:
                              () => widget.onSelect(
                                widget.modules.indexOf(module),
                              ),
                        ),
                      if (topGroup.displayedModules.isNotEmpty &&
                          regularGroups.isNotEmpty)
                        const SizedBox(height: 18),
                      for (final group in regularGroups) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                          child: _DesktopSectionHeader(
                            key: ValueKey(
                              'admin_sidebar_section_${group.section.name}',
                            ),
                            group: group,
                            onTap:
                                group.hasToggle
                                    ? () =>
                                        widget.onToggleSection(group.section)
                                    : null,
                          ),
                        ),
                        _AnimatedSectionModules(
                          axis: Axis.vertical,
                          contentKey:
                              'desktop-${group.section.name}-${group.expanded}',
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final module in group.displayedModules)
                                _DesktopNavigationButton(
                                  key: ValueKey(
                                    'admin_sidebar_item_${module.id}',
                                  ),
                                  module: module,
                                  selected:
                                      widget.modules[widget.selectedIndex].id ==
                                      module.id,
                                  badgeCount:
                                      widget.badgeCounts[module.id] ?? 0,
                                  onTap:
                                      () => widget.onSelect(
                                        widget.modules.indexOf(module),
                                      ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DrawerNavigation extends StatelessWidget {
  const _DrawerNavigation({
    required this.modules,
    required this.selectedIndex,
    required this.badgeCounts,
    required this.expandedSections,
    required this.onSelect,
    required this.onToggleSection,
  });

  final List<AdminModuleDefinition> modules;
  final int selectedIndex;
  final Map<String, int> badgeCounts;
  final Map<AdminNavigationSection, bool> expandedSections;
  final ValueChanged<int> onSelect;
  final ValueChanged<AdminNavigationSection> onToggleSection;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final colorScheme = baseTheme.colorScheme;
    final groups = _buildAdminNavigationGroups(modules, expandedSections);
    final topGroup = groups.firstWhere(
      (group) => group.section == AdminNavigationSection.top,
      orElse:
          () => const _AdminNavigationGroup(
            section: AdminNavigationSection.top,
            label: null,
            expandable: false,
            expanded: false,
            visibleModules: <AdminModuleDefinition>[],
            hiddenModules: <AdminModuleDefinition>[],
          ),
    );
    final regularGroups = groups
        .where((group) => group.section != AdminNavigationSection.top)
        .toList(growable: false);
    final navigationTheme = baseTheme.copyWith(
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
    );
    return Theme(
      data: navigationTheme,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          for (final module in topGroup.displayedModules)
            _DrawerNavigationTile(
              key: ValueKey('admin_drawer_item_${module.id}'),
              module: module,
              selected: selectedIndex == modules.indexOf(module),
              badgeCount: badgeCounts[module.id] ?? 0,
              onTap: () => onSelect(modules.indexOf(module)),
            ),
          if (topGroup.displayedModules.isNotEmpty && regularGroups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.8),
              ),
            ),
          for (final group in regularGroups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _DrawerSectionHeader(
                key: ValueKey('admin_drawer_section_${group.section.name}'),
                group: group,
                onTap:
                    group.hasToggle
                        ? () => onToggleSection(group.section)
                        : null,
              ),
            ),
            _AnimatedSectionModules(
              axis: Axis.vertical,
              contentKey: 'drawer-${group.section.name}-${group.expanded}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final module in group.displayedModules)
                    _DrawerNavigationTile(
                      key: ValueKey('admin_drawer_item_${module.id}'),
                      module: module,
                      selected: selectedIndex == modules.indexOf(module),
                      badgeCount: badgeCounts[module.id] ?? 0,
                      onTap: () => onSelect(modules.indexOf(module)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopNavigationButton extends StatefulWidget {
  const _DesktopNavigationButton({
    super.key,
    required this.module,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final AdminModuleDefinition module;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  State<_DesktopNavigationButton> createState() =>
      _DesktopNavigationButtonState();
}

class _AnimatedSectionModules extends StatelessWidget {
  const _AnimatedSectionModules({
    required this.axis,
    required this.contentKey,
    required this.child,
  });

  final Axis axis;
  final String contentKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final slideAnimation = Tween<Offset>(
              begin:
                  axis == Axis.vertical
                      ? const Offset(0, -0.04)
                      : const Offset(-0.04, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: slideAnimation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axis: axis,
                  axisAlignment: -1,
                  child: child,
                ),
              ),
            );
          },
          child: KeyedSubtree(key: ValueKey(contentKey), child: child),
        ),
      ),
    );
  }
}

class _DesktopSectionHeader extends StatelessWidget {
  const _DesktopSectionHeader({super.key, required this.group, this.onTap});

  final _AdminNavigationGroup group;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final label = group.label;
    if (label == null) {
      return const SizedBox.shrink();
    }
    final isCore = group.section == AdminNavigationSection.core;
    final toggleDotColors = <Color>[
      scheme.primary,
      Color.lerp(scheme.primary, scheme.tertiary, 0.48) ?? scheme.tertiary,
      Color.lerp(scheme.tertiary, scheme.secondary, 0.4) ?? scheme.secondary,
    ];
    final coreDotColors = <Color>[
      Color.lerp(scheme.primary, scheme.tertiary, 0.22) ?? scheme.primary,
      Color.lerp(scheme.primary, scheme.secondary, 0.35) ?? scheme.secondary,
    ];
    final Widget indicator = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Container(
            height: isCore ? 3 : 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors:
                    isCore
                        ? [
                          scheme.primary.withValues(alpha: 0.15),
                          scheme.primary.withValues(alpha: 0.6),
                          scheme.primary.withValues(alpha: 0.15),
                        ]
                        : [
                          scheme.primary.withValues(alpha: 0.12),
                          scheme.primary.withValues(alpha: 0.4),
                          scheme.primary.withValues(alpha: 0.12),
                        ],
              ),
            ),
          ),
        ),
        if (group.hasToggle) ...[
          const SizedBox(width: 8),
          if (isCore) ...[
            _SectionDot(
              size: 6,
              color: coreDotColors[0].withValues(alpha: isDark ? 0.98 : 0.94),
              shadowColor: coreDotColors[0].withValues(
                alpha: isDark ? 0.62 : 0.4,
              ),
            ),
            const SizedBox(width: 4),
            _SectionDot(
              size: 6,
              color: coreDotColors[1].withValues(alpha: isDark ? 0.9 : 0.82),
              shadowColor: coreDotColors[1].withValues(
                alpha: isDark ? 0.5 : 0.32,
              ),
            ),
          ] else ...[
            _SectionDot(
              size: 5,
              color: toggleDotColors[0].withValues(alpha: isDark ? 0.99 : 0.96),
              shadowColor: toggleDotColors[0].withValues(
                alpha: isDark ? 0.68 : 0.44,
              ),
            ),
            const SizedBox(width: 4),
            _SectionDot(
              size: 5,
              color: toggleDotColors[1].withValues(alpha: isDark ? 0.92 : 0.84),
              shadowColor: toggleDotColors[1].withValues(
                alpha: isDark ? 0.58 : 0.36,
              ),
            ),
            const SizedBox(width: 4),
            _SectionDot(
              size: 5,
              color: toggleDotColors[2].withValues(alpha: isDark ? 0.86 : 0.74),
              shadowColor: toggleDotColors[2].withValues(
                alpha: isDark ? 0.46 : 0.28,
              ),
            ),
          ],
          const SizedBox(width: 8),
          AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            turns: group.expanded ? 0.5 : 0,
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Color(0xFFD4AF37),
            ),
          ),
        ],
      ],
    );

    final decorated = Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 320),
      verticalOffset: 14,
      preferBelow: true,
      decoration: ShapeDecoration(
        color: scheme.inverseSurface.withValues(alpha: 0.95),
        shape: const StadiumBorder(),
        shadows: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      textStyle: theme.textTheme.labelMedium?.copyWith(
        color: scheme.onInverseSurface,
        fontWeight: FontWeight.w600,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 68,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: group.hasToggle ? const Color(0x0F000000) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: indicator,
      ),
    );

    if (!group.hasToggle) {
      return Center(child: decorated);
    }
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('admin_sidebar_toggle_${group.section.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0x12000000),
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: decorated,
        ),
      ),
    );
  }
}

class _SectionDot extends StatelessWidget {
  const _SectionDot({
    required this.size,
    required this.color,
    this.shadowColor,
  });

  final double size;
  final Color color;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow:
            shadowColor == null
                ? null
                : <BoxShadow>[
                  BoxShadow(
                    color: shadowColor!,
                    blurRadius: size * 2.4,
                    spreadRadius: 0.4,
                  ),
                ],
      ),
    );
  }
}

class _DrawerSectionHeader extends StatelessWidget {
  const _DrawerSectionHeader({super.key, required this.group, this.onTap});

  final _AdminNavigationGroup group;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = group.label;
    if (label == null) {
      return const SizedBox.shrink();
    }
    final content = Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 1.1,
            ),
          ),
        ),
        if (group.hasToggle)
          AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            turns: group.expanded ? 0.5 : 0,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    if (!group.hasToggle) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('admin_drawer_toggle_${group.section.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      ),
    );
  }
}

class _DesktopNavigationButtonState extends State<_DesktopNavigationButton> {
  static const Duration _tooltipShowDelay = Duration(milliseconds: 450);
  static const Duration _tooltipHideDelay = Duration(milliseconds: 240);

  final LayerLink _tooltipLayerLink = LayerLink();
  final OverlayPortalController _tooltipController = OverlayPortalController();
  bool _isHovered = false;
  bool _focused = false;
  Timer? _tooltipShowTimer;
  Timer? _tooltipHideTimer;

  @override
  void dispose() {
    _tooltipShowTimer?.cancel();
    _tooltipHideTimer?.cancel();
    if (_tooltipController.isShowing) {
      _tooltipController.hide();
    }
    super.dispose();
  }

  void _setHovered(bool value) {
    if (_isHovered == value) {
      return;
    }
    setState(() => _isHovered = value);
    if (value) {
      _scheduleTooltipShow();
    } else {
      _scheduleTooltipHide();
    }
  }

  void _scheduleTooltipShow() {
    _tooltipHideTimer?.cancel();
    if (_tooltipController.isShowing || _tooltipShowTimer?.isActive == true) {
      return;
    }
    _tooltipShowTimer = Timer(_tooltipShowDelay, () {
      if (!mounted || (!_isHovered && !_focused)) {
        return;
      }
      _tooltipController.show();
      setState(() {});
    });
  }

  void _scheduleTooltipHide() {
    _tooltipShowTimer?.cancel();
    _tooltipHideTimer?.cancel();
    if (_isHovered || _focused) {
      return;
    }
    if (!_tooltipController.isShowing) {
      return;
    }
    _tooltipHideTimer = Timer(_tooltipHideDelay, () {
      if (!mounted || _isHovered || _focused) {
        return;
      }
      _tooltipController.hide();
      setState(() {});
    });
  }

  Widget _buildDesktopTooltip(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      ignoring: true,
      child: CompositedTransformFollower(
        link: _tooltipLayerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.centerRight,
        followerAnchor: Alignment.centerLeft,
        offset: const Offset(10, 0),
        child: UnconstrainedBox(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset((1 - value) * -8, 0),
                  child: child,
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                key: ValueKey('admin_sidebar_tooltip_${widget.module.id}'),
                decoration: ShapeDecoration(
                  color: scheme.inverseSurface.withValues(alpha: 0.95),
                  shape: const StadiumBorder(),
                  shadows: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    widget.module.title,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isHighlighted = widget.module.highlighted && !widget.selected;
    final isInteractiveHighlight = (_isHovered || _focused) && !widget.selected;
    final decoration = BoxDecoration(
      color:
          widget.selected
              ? const Color(0xFFD4AF37)
              : isHighlighted
              ? const Color(0xFFF2E1A4)
              : isInteractiveHighlight
              ? const Color(0xFFE8E8E8)
              : const Color.fromARGB(0, 0, 0, 0),
      borderRadius: BorderRadius.circular(18),
      border:
          isHighlighted
              ? Border.all(color: const Color(0x66D4AF37), width: 1)
              : null,
      boxShadow:
          widget.selected
              ? const [
                BoxShadow(
                  color: Color.fromARGB(31, 139, 123, 123),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ]
              : isHighlighted
              ? const [
                BoxShadow(
                  color: Color.fromARGB(23, 222, 171, 69),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ]
              : const [],
    );
    final iconColor =
        widget.selected
            ? const Color(0xFF1E1E1E)
            : isHighlighted
            ? const Color(0xFF6A4B00)
            : scheme.onSurface.withValues(alpha: 0.88);
    final visualScale =
        widget.selected
            ? 1.0
            : isInteractiveHighlight
            ? 1.04
            : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: OverlayPortal(
        controller: _tooltipController,
        overlayChildBuilder: _buildDesktopTooltip,
        child: CompositedTransformTarget(
          link: _tooltipLayerLink,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => _setHovered(true),
            onExit: (_) => _setHovered(false),
            child: FocusableActionDetector(
              onShowFocusHighlight: (value) {
                setState(() => _focused = value);
                if (value) {
                  _scheduleTooltipShow();
                } else {
                  _scheduleTooltipHide();
                }
              },
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(18),
                  splashFactory: NoSplash.splashFactory,
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: SizedBox(
                    width: 68,
                    height: 64,
                    child: Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        scale: visualScale,
                        child: AnimatedContainer(
                          key: ValueKey(
                            'admin_sidebar_visual_${widget.module.id}',
                          ),
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          width: 56,
                          height: 56,
                          decoration: decoration,
                          alignment: Alignment.center,
                          child: _wrapWithBadge(
                            context,
                            badgeCount: widget.badgeCount,
                            child: _adminModuleGlyph(
                              widget.module,
                              size: 19,
                              color: iconColor,
                              preferBrandAsset: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerNavigationTile extends StatelessWidget {
  const _DrawerNavigationTile({
    super.key,
    required this.module,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final AdminModuleDefinition module;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color:
              selected
                  ? const Color(0xFFD4AF37).withValues(alpha: 0.18)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          tileColor: Colors.transparent,
          selectedTileColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: _adminNavigationIcon(
            context,
            module: module,
            selected: selected,
            highlighted: module.highlighted,
            badgeCount: badgeCount,
          ),
          title: Text(
            module.title,
            style: theme.textTheme.bodyLarge?.copyWith(
              color:
                  selected
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withValues(alpha: 0.92),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          onTap: onTap,
          selected: selected,
        ),
      ),
    );
  }
}

class _ModuleBadge extends StatelessWidget {
  const _ModuleBadge({required this.module, this.badgeCount = 0});

  final AdminModuleDefinition module;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isPhone = isAdminPhoneWidth(MediaQuery.sizeOf(context).width);
    final subtitle = isPhone ? null : module.subtitle;
    final hasSubtitle = subtitle != null && subtitle.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isPhone ? 10 : 12,
          vertical: hasSubtitle ? (isPhone ? 8 : 10) : (isPhone ? 6 : 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _adminModuleGlyph(
              module,
              size: isPhone ? 18 : 20,
              color: scheme.primary,
            ),
            SizedBox(width: isPhone ? 6 : 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (isPhone
                            ? theme.textTheme.titleSmall
                            : theme.textTheme.titleMedium)
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                  ),
                  if (hasSubtitle)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (badgeCount > 0) ...[
              SizedBox(width: isPhone ? 6 : 8),
              Align(
                alignment: hasSubtitle ? Alignment.topCenter : Alignment.center,
                child: _InlineCountBadge(count: badgeCount),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _adminNavigationIcon(
  BuildContext context, {
  required AdminModuleDefinition module,
  required bool selected,
  bool highlighted = false,
  int badgeCount = 0,
}) {
  final scheme = Theme.of(context).colorScheme;
  final isHighlighted = highlighted && !selected;
  const Color accentGold = Color(0xFFD4AF37);
  const Color iconOnGold = Color(0xFF1E1E1E);

  final iconColor =
      isHighlighted
          ? const Color(0xFF6A4B00)
          : selected
          ? iconOnGold
          : scheme.onSurface.withValues(alpha: 0.88);
  final iconSize =
      isHighlighted
          ? 18.0
          : selected
          ? 17.0
          : 16.5;

  final BoxDecoration selectedDecoration = BoxDecoration(
    shape: BoxShape.circle,
    color: accentGold,
    boxShadow: const [
      BoxShadow(color: Color(0x2A000000), blurRadius: 8, offset: Offset(0, 4)),
    ],
  );
  final BoxDecoration highlightedDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    color: const Color(0xFFF2E1A4),
    border: Border.all(color: const Color(0x66D4AF37), width: 1),
    boxShadow: const [
      BoxShadow(color: Color(0x18A26B00), blurRadius: 12, offset: Offset(0, 6)),
    ],
  );

  Widget iconContent;
  if (isHighlighted) {
    iconContent = DecoratedBox(
      decoration: highlightedDecoration,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: _adminModuleGlyph(module, size: iconSize, color: iconColor),
          ),
        ],
      ),
    );
  } else if (selected) {
    iconContent = DecoratedBox(
      decoration: selectedDecoration,
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: _adminModuleGlyph(module, size: iconSize, color: iconColor),
      ),
    );
  } else {
    iconContent = _adminModuleGlyph(module, size: iconSize, color: iconColor);
  }

  return _wrapWithBadge(context, badgeCount: badgeCount, child: iconContent);
}

Widget _adminModuleGlyph(
  AdminModuleDefinition module, {
  required double size,
  required Color color,
  bool preferBrandAsset = true,
}) {
  if (preferBrandAsset && module.id == 'whatsapp') {
    return Image.asset(
      'assets/social_logo/whatsapp.PNG',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
  return Icon(module.icon, size: size, color: color);
}

Widget _wrapWithBadge(
  BuildContext context, {
  required Widget child,
  required int badgeCount,
}) {
  if (badgeCount <= 0) {
    return child;
  }
  final scheme = Theme.of(context).colorScheme;
  return Badge.count(
    count: badgeCount,
    isLabelVisible: badgeCount > 0,
    backgroundColor: scheme.error,
    textColor: scheme.onError,
    child: child,
  );
}

class _InlineCountBadge extends StatelessWidget {
  const _InlineCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : count.toString();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onError,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
