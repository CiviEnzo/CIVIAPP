import 'dart:async';

import 'package:you_book/app/providers.dart';
import 'package:you_book/app/theme_constants.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/entities/client_app_movement.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/payment_ticket.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/salon_access_request.dart';
import 'package:you_book/domain/entities/staff_absence_request.dart';
import 'package:you_book/presentation/common/theme_mode_action.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments_module.dart';
import 'package:you_book/presentation/screens/admin/modules/clients_module.dart';
import 'package:you_book/presentation/screens/admin/modules/client_app_movements_module.dart';
import 'package:you_book/presentation/screens/admin/modules/inventory_module.dart';
import 'package:you_book/presentation/screens/admin/modules/messages_module.dart';
import 'package:you_book/presentation/screens/admin/modules/overview_module.dart';
import 'package:you_book/presentation/screens/admin/modules/reports_module.dart';
import 'package:you_book/presentation/screens/admin/modules/sales_module.dart';
import 'package:you_book/presentation/screens/admin/modules/salon_management_module.dart';
import 'package:you_book/presentation/screens/admin/modules/services_module.dart';
import 'package:you_book/presentation/screens/admin/modules/staff_module.dart';
import 'package:you_book/presentation/screens/admin/modules/whatsapp_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

typedef AdminModuleBuilder =
    Widget Function(BuildContext context, WidgetRef ref, String? salonId);

class AdminModuleDefinition {
  const AdminModuleDefinition({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String title;
  final IconData icon;
  final AdminModuleBuilder builder;
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  static const String _movementPrefsKeyPrefix = 'admin_movements_last_seen';

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  ProviderSubscription<AdminDashboardIntent?>? _intentSubscription;
  SharedPreferences? _preferences;
  final Map<String, DateTime?> _movementLastSeen = <String, DateTime?>{};
  final Set<String> _movementLoadingKeys = <String>{};
  String? _currentSalonId;

  static final _modules = <AdminModuleDefinition>[
    AdminModuleDefinition(
      id: 'overview',
      title: 'Panoramica',
      icon: Icons.dashboard_rounded,
      builder: (context, ref, salonId) => AdminOverviewModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'salons',
      title: 'Saloni',
      icon: Icons.apartment_rounded,
      builder:
          (context, ref, salonId) =>
              SalonManagementModule(selectedSalonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'staff',
      title: 'Staff',
      icon: Icons.groups_2_rounded,
      builder: (context, ref, salonId) => StaffModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'clients',
      title: 'Clienti',
      icon: Icons.people_alt_rounded,
      builder: (context, ref, salonId) => ClientsModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'app_movements',
      title: 'Movimenti App',
      icon: Icons.timeline_rounded,
      builder:
          (context, ref, salonId) => ClientAppMovementsModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'appointments',
      title: 'Agenda',
      icon: Icons.event_available_rounded,
      builder: (context, ref, salonId) => AppointmentsModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'services',
      title: 'Servizi & Pacchetti',
      icon: Icons.spa_rounded,
      builder: (context, ref, salonId) => ServicesModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'inventory',
      title: 'Magazzino',
      icon: Icons.inventory_2_rounded,
      builder: (context, ref, salonId) => InventoryModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'sales',
      title: 'Vendite & Cassa',
      icon: Icons.point_of_sale_rounded,
      builder: (context, ref, salonId) => SalesModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'messages',
      title: 'Messaggi & Marketing',
      icon: Icons.chat_rounded,
      builder:
          (context, ref, salonId) => MessagesMarketingModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'whatsapp',
      title: 'WhatsApp',
      icon: Icons.phone_android_rounded,
      builder: (context, ref, salonId) => WhatsAppModule(salonId: salonId),
    ),
    AdminModuleDefinition(
      id: 'reports',
      title: 'Report',
      icon: Icons.insights_rounded,
      builder: (context, ref, salonId) => ReportsModule(salonId: salonId),
    ),
  ];

  @override
  void initState() {
    super.initState();
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
    if (_selectedIndex != index) {
      if (mounted) {
        setState(() => _selectedIndex = index);
      } else {
        _selectedIndex = index;
      }
    }
    _handleModuleSelectionSideEffects(_modules[index].id);
    if (allowPop) {
      Navigator.of(context).maybePop();
    }
  }

  void _handleModuleSelectionSideEffects(String moduleId) {
    if (moduleId == 'app_movements') {
      _markMovementsRead(ref.read(appDataProvider), _currentSalonId);
    }
  }

  String _movementSalonKey(String? salonId) => salonId ?? 'all';

  String _movementPrefsKey(String salonKey) =>
      '$_movementPrefsKeyPrefix::$salonKey';

  Future<SharedPreferences> _ensurePreferences() async {
    final cached = _preferences;
    if (cached != null) {
      return cached;
    }
    final resolved = await SharedPreferences.getInstance();
    _preferences = resolved;
    return resolved;
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
    final salons = data.salons;

    final salonIds = salons.map((salon) => salon.id).toSet();
    String? selectedSalonId;

    if (session.salonId != null && salonIds.contains(session.salonId)) {
      selectedSalonId = session.salonId;
    } else if (salons.isNotEmpty) {
      selectedSalonId = salons.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sessionControllerProvider.notifier).setSalon(selectedSalonId);
      });
    } else {
      selectedSalonId = null;
      if (session.salonId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(sessionControllerProvider.notifier).setSalon(null);
        });
      }
    }
    _currentSalonId = selectedSalonId;
    final badgeCounts = _moduleBadgeCounts(data, selectedSalonId);
    final selectedModule = _modules[_selectedIndex];
    final selectedBadgeCount = badgeCounts[selectedModule.id] ?? 0;

    final mediaQuery = MediaQuery.of(context);
    final baseScale = mediaQuery.textScaleFactor;
    final effectiveScale = baseScale * adminTextScaleFactor;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaleFactor: effectiveScale),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          final isLargeScreen = constraints.maxWidth >= 1080;
          final moduleBackground = theme.colorScheme.surfaceContainerLowest;
          final content = selectedModule.builder(context, ref, selectedSalonId);
          final showSalonSelector = selectedModule.id == 'salons';

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
                          onSelect:
                              (index) => _selectModule(index, allowPop: true),
                        ),
                      ),
                    ),
            appBar: AppBar(
              automaticallyImplyLeading: !isLargeScreen,
              title:
                  isLargeScreen
                      ? Row(
                        children: [
                          _ModuleBadge(
                            module: selectedModule,
                            badgeCount: selectedBadgeCount,
                          ),
                          if (showSalonSelector) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final maxWidth =
                                      constraints.maxWidth.clamp(160.0, 320.0)
                                          as double;
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: maxWidth,
                                      ),
                                      child: _SalonSelector(
                                        salons: salons,
                                        selectedSalonId: selectedSalonId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      )
                      : showSalonSelector
                      ? LayoutBuilder(
                        builder: (context, constraints) {
                          final maxWidth =
                              constraints.maxWidth.clamp(160.0, 320.0)
                                  as double;
                          return ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: _SalonSelector(
                              salons: salons,
                              selectedSalonId: selectedSalonId,
                            ),
                          );
                        },
                      )
                      : _ModuleBadge(
                        module: selectedModule,
                        badgeCount: selectedBadgeCount,
                      ),
              actions: [
                const ThemeModeAction(),
                IconButton(
                  tooltip: 'Esci',
                  onPressed: () async => _handleSignOutRequest(),
                  icon: const Icon(Icons.logout_rounded),
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
                    onSelect: (index) => _selectModule(index, allowPop: false),
                  ),
                Expanded(
                  child: ColoredBox(color: moduleBackground, child: content),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RailNavigation extends StatefulWidget {
  const _RailNavigation({
    required this.modules,
    required this.selectedIndex,
    required this.badgeCounts,
    required this.onSelect,
  });

  final List<AdminModuleDefinition> modules;
  final int selectedIndex;
  final Map<String, int> badgeCounts;
  final ValueChanged<int> onSelect;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        const double destinationExtent = 80;
        const double extraHeight = 120;
        final railTheme = theme.copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
        );
        final requiredHeight =
            widget.modules.length * destinationExtent + extraHeight;
        final rail = Theme(
          data: railTheme,
          child: NavigationRail(
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onSelect,
            minWidth: 68,
            useIndicator: false,
            labelType: NavigationRailLabelType.none,
            leading: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('Moduli', style: theme.textTheme.titleMedium),
            ),
            destinations:
                widget.modules
                    .map(
                      (module) => NavigationRailDestination(
                        icon: _navigationRailIcon(
                          module,
                          false,
                          context,
                          widget.badgeCounts[module.id] ?? 0,
                        ),
                        selectedIcon: _navigationRailIcon(
                          module,
                          true,
                          context,
                          widget.badgeCounts[module.id] ?? 0,
                        ),
                        label: Text(module.title, textAlign: TextAlign.center),
                      ),
                    )
                    .toList(),
          ),
        );

        if (constraints.maxHeight.isFinite &&
            constraints.maxHeight < requiredHeight) {
          return SizedBox(
            height: constraints.maxHeight,
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                child: SizedBox(height: requiredHeight, child: rail),
              ),
            ),
          );
        }

        return rail;
      },
    );
  }
}

class _DrawerNavigation extends StatelessWidget {
  const _DrawerNavigation({
    required this.modules,
    required this.selectedIndex,
    required this.badgeCounts,
    required this.onSelect,
  });

  final List<AdminModuleDefinition> modules;
  final int selectedIndex;
  final Map<String, int> badgeCounts;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final colorScheme = baseTheme.colorScheme;
    final navigationTheme = baseTheme.copyWith(
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
    );
    return Theme(
      data: navigationTheme,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: modules.length,
        itemBuilder: (context, index) {
          final module = modules[index];
          final selected = selectedIndex == index;
          final badgeCount = badgeCounts[module.id] ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor:
                  selected
                      ? colorScheme.surfaceContainerHighest.withOpacity(0.6)
                      : Colors.transparent,
              selectedTileColor: colorScheme.surfaceContainerHighest
                  .withOpacity(0.6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: _adminNavigationIcon(
                context,
                icon: module.icon,
                selected: selected,
                badgeCount: badgeCount,
              ),
              title: Text(
                module.title,
                style: baseTheme.textTheme.bodyLarge?.copyWith(
                  color: selected ? colorScheme.primary : colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              onTap: () => onSelect(index),
              selected: selected,
            ),
          );
        },
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(module.icon, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                module.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 8),
              _InlineCountBadge(count: badgeCount),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _adminNavigationIcon(
  BuildContext context, {
  required IconData icon,
  required bool selected,
  int badgeCount = 0,
}) {
  final scheme = Theme.of(context).colorScheme;

  if (!selected) {
    return _wrapWithBadge(
      context,
      badgeCount: badgeCount,
      child: Icon(icon, size: 28, color: scheme.onSurfaceVariant),
    );
  }

  return _wrapWithBadge(
    context,
    badgeCount: badgeCount,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary,
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 28, color: scheme.onPrimary),
      ),
    ),
  );
}

Widget _navigationRailIcon(
  AdminModuleDefinition module,
  bool selected,
  BuildContext context, [
  int badgeCount = 0,
]) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  return Tooltip(
    message: module.title,
    waitDuration: const Duration(milliseconds: 350),
    decoration: ShapeDecoration(
      color: scheme.inverseSurface.withOpacity(0.95),
      shape: const StadiumBorder(),
      shadows: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    textStyle: theme.textTheme.labelMedium?.copyWith(
      color: scheme.onInverseSurface,
      fontWeight: FontWeight.w600,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: 54,
        height: 54,
        child: Center(
          child: _adminNavigationIcon(
            context,
            icon: module.icon,
            selected: selected,
            badgeCount: badgeCount,
          ),
        ),
      ),
    ),
  );
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

class _SalonSelector extends ConsumerWidget {
  const _SalonSelector({required this.salons, required this.selectedSalonId});

  final List<Salon> salons;
  final String? selectedSalonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        isExpanded: true,
        value: selectedSalonId,
        hint: const Text('Tutti i saloni'),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Tutti i saloni'),
          ),
          ...salons.map(
            (salon) => DropdownMenuItem<String?>(
              value: salon.id,
              child: Text(salon.name),
            ),
          ),
        ],
        onChanged: (value) {
          ref.read(sessionControllerProvider.notifier).setSalon(value);
        },
      ),
    );
  }
}
