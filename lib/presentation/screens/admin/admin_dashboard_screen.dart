import 'package:you_book/app/providers.dart';
import 'package:you_book/app/theme_constants.dart';
import 'package:you_book/domain/entities/salon.dart';
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  ProviderSubscription<AdminDashboardIntent?>? _intentSubscription;

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

    if (_selectedIndex != targetIndex) {
      if (mounted) {
        setState(() => _selectedIndex = targetIndex);
      } else {
        _selectedIndex = targetIndex;
      }
    }

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
    final selectedModule = _modules[_selectedIndex];

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
                          onSelect: (index) {
                            setState(() => _selectedIndex = index);
                            Navigator.of(context).maybePop();
                          },
                        ),
                      ),
                    ),
            appBar: AppBar(
              automaticallyImplyLeading: !isLargeScreen,
              title: Text(selectedModule.title),
              actions: [
                if (salons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SalonSelector(
                      salons: salons,
                      selectedSalonId: selectedSalonId,
                    ),
                  ),
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
                    onSelect: (index) => setState(() => _selectedIndex = index),
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
    required this.onSelect,
  });

  final List<AdminModuleDefinition> modules;
  final int selectedIndex;
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
                        icon: _navigationRailIcon(module, false, context),
                        selectedIcon: _navigationRailIcon(
                          module,
                          true,
                          context,
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
    required this.onSelect,
  });

  final List<AdminModuleDefinition> modules;
  final int selectedIndex;
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

Widget _adminNavigationIcon(
  BuildContext context, {
  required IconData icon,
  required bool selected,
}) {
  final scheme = Theme.of(context).colorScheme;

  if (!selected) {
    return Icon(icon, size: 28, color: scheme.onSurfaceVariant);
  }

  return DecoratedBox(
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
  );
}

Widget _navigationRailIcon(
  AdminModuleDefinition module,
  bool selected,
  BuildContext context,
) {
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
          ),
        ),
      ),
    ),
  );
}

class _SalonSelector extends ConsumerWidget {
  const _SalonSelector({required this.salons, required this.selectedSalonId});

  final List<Salon> salons;
  final String? selectedSalonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
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
