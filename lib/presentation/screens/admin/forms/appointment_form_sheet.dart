import 'dart:async';
import 'dart:ui' as ui;

import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/availability/appointment_conflicts.dart';
import 'package:you_book/domain/availability/equipment_availability.dart';
import 'package:you_book/domain/availability/package_session_allocator.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/appointment_clipboard.dart';
import 'package:you_book/domain/entities/appointment_service_allocation.dart';
import 'package:you_book/domain/entities/body_zone.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/domain/entities/staff_absence.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/shared/client_package_purchase.dart';
import 'package:you_book/presentation/screens/admin/forms/client_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/client_search_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

enum AppointmentFormAction { save, copy, delete }

enum _ClientSearchMode { general, number }

class AppointmentFormResult {
  const AppointmentFormResult({
    required this.action,
    required this.appointment,
  });

  final AppointmentFormAction action;
  final Appointment appointment;
}

class AppointmentFormSheet extends ConsumerStatefulWidget {
  const AppointmentFormSheet({
    super.key,
    required this.salons,
    required this.clients,
    required this.staff,
    required this.services,
    required this.serviceCategories,
    this.initial,
    this.defaultSalonId,
    this.defaultClientId,
    this.suggestedStart,
    this.suggestedEnd,
    this.suggestedStaffId,
    this.enableDelete = false,
    this.onSaved,
  });

  final List<Salon> salons;
  final List<Client> clients;
  final List<StaffMember> staff;
  final List<Service> services;
  final List<ServiceCategory> serviceCategories;
  final Appointment? initial;
  final String? defaultSalonId;
  final String? defaultClientId;
  final DateTime? suggestedStart;
  final DateTime? suggestedEnd;
  final String? suggestedStaffId;
  final bool enableDelete;
  final void Function(AppointmentFormResult result)? onSaved;

  @override
  ConsumerState<AppointmentFormSheet> createState() =>
      _AppointmentFormSheetState();
}

class _AppointmentFormSheetState extends ConsumerState<AppointmentFormSheet> {
  static const _slotIntervalMinutes = 15;
  static String? _lastSavedClientId;
  final _formKey = GlobalKey<FormState>();
  final _clientFieldKey = GlobalKey<FormFieldState<String>>();
  final _uuid = const Uuid();
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _clientNumberSearchController =
      TextEditingController();
  final FocusNode _clientSearchFocusNode = FocusNode();
  final FocusNode _clientNumberSearchFocusNode = FocusNode();
  _ClientSearchMode _clientSearchMode = _ClientSearchMode.general;
  List<Client> _clientSuggestions = const <Client>[];
  late DateTime _start;
  late DateTime _end;
  String? _salonId;
  String? _clientId;
  String? _staffId;
  late List<String> _serviceIds;
  final Map<String, int> _serviceQuantities = {};
  final Map<String, String?> _servicePackageSelections = {};
  final Set<String> _manualPackageSelections = {};
  final Map<String, Duration> _serviceDurationAdjustments = {};
  PackageSessionAllocationSuggestion? _latestSuggestion;
  String _lastSuggestionKey = '';
  final PackageSessionAllocator _sessionAllocator =
      const PackageSessionAllocator();
  AppointmentStatus _status = AppointmentStatus.scheduled;
  late TextEditingController _notes;
  bool _isDeleting = false;
  bool _copyJustCompleted = false;
  Timer? _copyFeedbackTimer;
  static const Duration _copyFeedbackDuration = Duration(seconds: 2);
  String? _inlineErrorMessage;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _clientId = initial?.clientId ?? widget.defaultClientId;
    _staffId = initial?.staffId ?? widget.suggestedStaffId;
    final initialServiceIds = initial?.serviceIds ?? const <String>[];
    final fallbackServiceId = initial?.serviceId;
    _serviceIds =
        initialServiceIds.isNotEmpty
            ? List<String>.from(initialServiceIds)
            : [
              if (fallbackServiceId != null && fallbackServiceId.isNotEmpty)
                fallbackServiceId,
            ];
    _status = initial?.status ?? AppointmentStatus.scheduled;
    final fallbackStart = DateTime.now().add(const Duration(hours: 1));
    _start = initial?.start ?? widget.suggestedStart ?? fallbackStart;
    var end =
        initial?.end ??
        widget.suggestedEnd ??
        _start.add(const Duration(minutes: 30));
    if (!end.isAfter(_start)) {
      end = _start.add(const Duration(minutes: 30));
    }
    _end = end;
    _notes = TextEditingController(text: initial?.notes ?? '');
    if (_start.isAfter(DateTime.now()) &&
        _status == AppointmentStatus.completed) {
      _status = AppointmentStatus.scheduled;
    }

    if (initial != null && initial.serviceAllocations.isNotEmpty) {
      for (final allocation in initial.serviceAllocations) {
        if (allocation.serviceId.isEmpty) continue;
        _serviceQuantities[allocation.serviceId] = allocation.quantity;
      final firstConsumption =
          allocation.packageConsumptions.isNotEmpty
              ? allocation.packageConsumptions.first
              : null;
      final packageId = firstConsumption?.packageReferenceId;
      _servicePackageSelections[allocation.serviceId] =
          packageId != null && packageId.isNotEmpty ? packageId : null;
      if (packageId != null && packageId.isNotEmpty) {
        _manualPackageSelections.add(allocation.serviceId);
      }
      if (allocation.durationAdjustmentMinutes != 0) {
        _serviceDurationAdjustments[allocation.serviceId] =
            Duration(minutes: allocation.durationAdjustmentMinutes);
      }
    }
    } else if (initial?.packageId != null &&
        initial!.packageId!.isNotEmpty &&
        _serviceIds.isNotEmpty) {
      _servicePackageSelections[_serviceIds.first] = initial.packageId;
      _manualPackageSelections.add(_serviceIds.first);
    }

    _ensureServiceState(_serviceIds);
  }

  @override
  void dispose() {
    _copyFeedbackTimer?.cancel();
    _clientSearchController.dispose();
    _clientNumberSearchController.dispose();
    _clientSearchFocusNode.dispose();
    _clientNumberSearchFocusNode.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _showInlineError(String message) {
    if (!mounted) return;
    setState(() => _inlineErrorMessage = message);
  }

  void _clearInlineError() {
    if (!mounted || _inlineErrorMessage == null) return;
    setState(() => _inlineErrorMessage = null);
  }

  List<Service> _selectedServicesInOrder(Iterable<Service> services) {
    if (_serviceIds.isEmpty) {
      return <Service>[];
    }
    final servicesById = {for (final service in services) service.id: service};
    final ordered = <Service>[];
    for (final id in _serviceIds) {
      final service = servicesById[id];
      if (service != null) {
        ordered.add(service);
      }
    }
    return ordered;
  }

  List<ServiceCategory> _categoriesForCurrentSalon() {
    final salonId = _salonId;
    if (salonId == null || salonId.isEmpty) {
      return widget.serviceCategories;
    }
    return widget.serviceCategories
        .where((category) => category.salonId == salonId)
        .toList(growable: false);
  }

  List<_ZoneServiceEntry> _zoneEntriesForCategory(
    ServiceCategory category,
    Map<String, Service> servicesById,
  ) {
    final entries = <_ZoneServiceEntry>[];
    category.zoneServiceIds.forEach((zoneId, serviceId) {
      final zone = bodyZonesById[zoneId];
      final service = servicesById[serviceId];
      if (zone != null && service != null) {
        entries.add(_ZoneServiceEntry(zone: zone, service: service));
      }
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bookingDateFormat = DateFormat('EEEE d MMMM yyyy', 'it_IT');
    final timeFormat = DateFormat('HH:mm', 'it_IT');
    final formattedBookingDate = bookingDateFormat.format(_start);
    final String? bookingDateRaw = toBeginningOfSentenceCase(
      formattedBookingDate,
    );
    final String bookingDateLabel = bookingDateRaw ?? formattedBookingDate;
    final startTimeLabel = timeFormat.format(_start);
    final endTimeLabel = timeFormat.format(_end);
    final durationMinutes = _end.difference(_start).inMinutes;
    final data = ref.watch(appDataProvider);
    final salons = data.salons.isNotEmpty ? data.salons : widget.salons;
    final clients = data.clients.isNotEmpty ? data.clients : widget.clients;
    final staffMembers = data.staff.isNotEmpty ? data.staff : widget.staff;
    final allServices =
        data.services.isNotEmpty ? data.services : widget.services;
    final preservedServiceId = widget.initial?.serviceId;
    final services =
        allServices
            .where(
              (service) =>
                  service.isActive ||
                  (preservedServiceId != null &&
                      service.id == preservedServiceId),
            )
            .toList();
    services.sort((a, b) => a.name.compareTo(b.name));

    final filteredClients =
        clients
            .where((client) => _salonId == null || client.salonId == _salonId)
            .toList()
          ..sort((a, b) => a.lastName.compareTo(b.lastName));
    final selectedStaffMember = staffMembers.firstWhereOrNull(
      (member) => member.id == _staffId,
    );
    final bool hasLockedStaffSelection =
        widget.initial?.staffId != null && selectedStaffMember != null;
    final bool showStaffDropdown = !hasLockedStaffSelection;
    final operatorSectionTitle = 'Cliente';
    final lastClient = clients.firstWhereOrNull(
      (client) => client.id == _lastSavedClientId,
    );
    final canApplyLastClient = lastClient != null && lastClient.id != _clientId;
    final Widget? lastClientButton =
        lastClient == null
            ? null
            : TextButton.icon(
              onPressed:
                  canApplyLastClient
                      ? () {
                        FocusScope.of(context).unfocus();
                        _applyClientSelection(lastClient!);
                      }
                      : null,
              icon: const Icon(Icons.history_rounded),
              label: const Text('Ultimo cliente'),
            );
    final filteredServices =
        services.where((service) {
          if (_salonId != null && service.salonId != _salonId) {
            return false;
          }
          if (selectedStaffMember != null) {
            final allowedRoles = service.staffRoles;
            if (allowedRoles.isNotEmpty &&
                !selectedStaffMember.roleIds.any(
                  (roleId) => allowedRoles.contains(roleId),
                )) {
              return false;
            }
          }
          return true;
        }).toList();
    final filteredServiceIds =
        filteredServices.map((service) => service.id).toSet();
    final hasRemovedServices = _serviceIds.any(
      (id) => !filteredServiceIds.contains(id),
    );
    if (hasRemovedServices) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _serviceIds = _serviceIds
              .where(filteredServiceIds.contains)
              .toList(growable: false);
          _ensureServiceState(_serviceIds);
          _manualPackageSelections.removeWhere(
            (serviceId) => !_serviceIds.contains(serviceId),
          );
          if (_serviceIds.isEmpty) {
            _serviceQuantities.clear();
            _clearAllPackageSelections();
          } else {
            _lastSuggestionKey = '';
            _latestSuggestion = null;
          }
        });
      });
    }
    final baseSelectedServices = _selectedServicesInOrder(services);
    final selectedServices = _applyDurationAdjustments(baseSelectedServices);
    final filteredStaff =
        staffMembers.where((member) {
          if (selectedServices.isNotEmpty) {
            for (final service in selectedServices) {
              final allowedRoles = service.staffRoles;
              if (allowedRoles.isNotEmpty &&
                  !member.roleIds.any(
                    (roleId) => allowedRoles.contains(roleId),
                  )) {
                return false;
              }
            }
          }
          return true;
        }).toList();
    if (_staffId != null &&
        filteredStaff.every((member) => member.id != _staffId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _staffId = null);
      });
    }

    final selectedSalon = salons.firstWhereOrNull(
      (salon) => salon.id == _salonId,
    );

    final selectedClient = clients.firstWhereOrNull(
      (client) => client.id == _clientId,
    );

    final clientPackagePurchases =
        selectedClient != null
            ? resolveClientPackagePurchases(
              sales: data.sales,
              packages: data.packages,
              appointments: data.appointments,
              services: allServices,
              clientId: selectedClient.id,
              salonId: selectedClient.salonId,
            )
            : const <ClientPackagePurchase>[];
    final allClientPackages = _dedupePurchasesByReferenceId(
      List<ClientPackagePurchase>.from(
        clientPackagePurchases.where((purchase) => purchase.isActive),
      ),
    );
    allClientPackages.sort((a, b) {
      final aExpiration = a.expirationDate ?? DateTime(9999, 1, 1);
      final bExpiration = b.expirationDate ?? DateTime(9999, 1, 1);
      final expirationCompare = aExpiration.compareTo(bExpiration);
      if (expirationCompare != 0) {
        return expirationCompare;
      }
      return a.sale.createdAt.compareTo(b.sale.createdAt);
    });
    final packagesByService = <String, List<ClientPackagePurchase>>{};

    final staffFieldValue =
        _staffId != null && filteredStaff.any((member) => member.id == _staffId)
            ? _staffId
            : null;

    final now = DateTime.now();
    final startDateOnly = DateTime(_start.year, _start.month, _start.day);
    final today = DateTime(now.year, now.month, now.day);
    final isFutureStart = startDateOnly.isAfter(today);
    final statusItems =
        AppointmentStatus.values
            .where(
              (status) =>
                  !(isFutureStart && status == AppointmentStatus.completed),
            )
            .map((status) {
              return DropdownMenuItem<AppointmentStatus>(
                value: status,
                child: Row(
                  children: [
                    Icon(
                      _statusIcon(status),
                      color: _statusColor(theme.colorScheme, status),
                    ),
                    SizedBox(width: 4),
                    Text(_statusLabel(status)),
                  ],
                ),
              );
            })
            .toList();

    if (selectedClient != null) {
      for (final service in selectedServices) {
        final matching =
            allClientPackages
                .where((purchase) => purchase.supportsService(service.id))
                .toList()
              ..sort((a, b) {
                final aExpiration = a.expirationDate ?? DateTime(9999, 1, 1);
                final bExpiration = b.expirationDate ?? DateTime(9999, 1, 1);
                final expirationCompare = aExpiration.compareTo(bExpiration);
                if (expirationCompare != 0) {
                  return expirationCompare;
                }
                return a.sale.createdAt.compareTo(b.sale.createdAt);
              });
        packagesByService[service.id] = _dedupePurchasesByReferenceId(matching);
      }
      _ensureServiceState(_serviceIds);
      _scheduleAllocatorUpdate(
        selectedServices: selectedServices,
        packages: allClientPackages,
      );
    }

    final showPackageSection = selectedClient != null;

    final closureConflicts =
        selectedSalon == null
            ? const <SalonClosure>[]
            : _findOverlappingClosures(
              closures: selectedSalon.closures,
              start: _start,
              end: _end,
            );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.initial == null
                                          ? 'Nuovo appuntamento'
                                          : 'Modifica appuntamento',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      bookingDateLabel,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color:
                                                theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 280,
                                child:
                                    showStaffDropdown
                                        ? DropdownButtonFormField<String>(
                                          value: staffFieldValue,
                                          decoration: const InputDecoration(
                                            labelText: 'Operatore',
                                            floatingLabelBehavior:
                                                FloatingLabelBehavior.always,
                                          ),
                                          items:
                                              filteredStaff
                                                  .map(
                                                    (member) =>
                                                        DropdownMenuItem(
                                                          value: member.id,
                                                          child: Text(
                                                            member.fullName,
                                                          ),
                                                        ),
                                                  )
                                                  .toList(),
                                          onChanged: (value) {
                                            final staffMember =
                                                value == null
                                                    ? null
                                                    : staffMembers
                                                        .firstWhereOrNull(
                                                          (member) =>
                                                              member.id ==
                                                              value,
                                                        );
                                            final previousSalonId = _salonId;
                                            final newSalonId =
                                                staffMember?.salonId;
                                            final salonChanged =
                                                previousSalonId != newSalonId;

                                            setState(() {
                                              _staffId = value;
                                              _salonId = newSalonId;

                                              if (salonChanged) {
                                                _clientId = null;
                                                _clientSearchController.clear();
                                                _clientSuggestions =
                                                    const <Client>[];
                                                _serviceIds = const [];
                                                _serviceQuantities.clear();
                                                _clearAllPackageSelections();
                                              }

                                              if (staffMember == null) {
                                                if (!salonChanged) {
                                                  _serviceIds = const [];
                                                  _serviceQuantities.clear();
                                                  _clearAllPackageSelections();
                                                }
                                                _ensureServiceState(
                                                  _serviceIds,
                                                );
                                                _lastSuggestionKey = '';
                                                _latestSuggestion = null;
                                                return;
                                              }

                                              final allowedServiceIds =
                                                  services
                                                      .where((service) {
                                                        final roles =
                                                            service.staffRoles;
                                                        if (roles.isEmpty) {
                                                          return true;
                                                        }
                                                        return staffMember
                                                            .roleIds
                                                            .any(
                                                              (roleId) => roles
                                                                  .contains(
                                                                    roleId,
                                                                  ),
                                                            );
                                                      })
                                                      .map(
                                                        (service) => service.id,
                                                      )
                                                      .toSet();
                                              final filteredSelections =
                                                  _serviceIds
                                                      .where(
                                                        allowedServiceIds
                                                            .contains,
                                                      )
                                                      .toList();
                                              if (filteredSelections.length !=
                                                  _serviceIds.length) {
                                                _serviceIds =
                                                    filteredSelections;
                                                _ensureServiceState(
                                                  _serviceIds,
                                                );
                                                _manualPackageSelections
                                                    .removeWhere(
                                                      (serviceId) =>
                                                          !_serviceIds.contains(
                                                            serviceId,
                                                          ),
                                                    );
                                                _lastSuggestionKey = '';
                                                _latestSuggestion = null;
                                              }
                                            });

                                            _clearInlineError();

                                            if (salonChanged) {
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                    _clientFieldKey.currentState
                                                        ?.didChange(_clientId);
                                                  });
                                            }
                                          },
                                          validator:
                                              (value) =>
                                                  value == null
                                                      ? 'Scegli un operatore'
                                                      : null,
                                        )
                                        : FormField<String>(
                                          initialValue:
                                              selectedStaffMember?.id ??
                                              widget.initial?.staffId,
                                          validator:
                                              (_) =>
                                                  selectedStaffMember == null
                                                      ? 'Scegli un operatore'
                                                      : null,
                                          builder: (state) {
                                            final theme = Theme.of(context);
                                            return InputDecorator(
                                              decoration: InputDecoration(
                                                labelText: 'Operatore',
                                                floatingLabelBehavior:
                                                    FloatingLabelBehavior
                                                        .always,
                                                errorText: state.errorText,
                                              ),
                                              child: Text(
                                                selectedStaffMember?.fullName ??
                                                    'Operatore non disponibile',
                                                style:
                                                    theme.textTheme.bodyLarge,
                                              ),
                                            );
                                          },
                                        ),
                              ),
                            ],
                          ),
                          if (_inlineErrorMessage != null) ...[
                            const SizedBox(height: 16),
                            Material(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.warning_rounded,
                                      color: colorScheme.onErrorContainer,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _inlineErrorMessage!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onErrorContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Chiudi avviso',
                                      onPressed: _clearInlineError,
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildSectionHeader(
                            icon: Icons.group_add_rounded,
                            title: operatorSectionTitle,
                            subtitle:
                                "Seleziona l'operatore e collega il cliente per l'appuntamento",
                            trailing: lastClientButton,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: FormField<String>(
                                  key: _clientFieldKey,
                                  validator:
                                      (_) =>
                                          _clientId == null
                                              ? 'Scegli un cliente'
                                              : null,
                                  builder: (state) {
                                    final selectedClient = clients
                                        .firstWhereOrNull(
                                          (client) => client.id == _clientId,
                                        );
                                    if (selectedClient != null &&
                                        _clientSearchController.text !=
                                            selectedClient.fullName) {
                                      _clientSearchController.text =
                                          selectedClient.fullName;
                                    }
                                    final hasSelection = selectedClient != null;
                                    final suggestions =
                                        hasSelection
                                            ? const <Client>[]
                                            : _clientSuggestions;
                                    final theme = Theme.of(context);
                                    final colorScheme = theme.colorScheme;
                                    final clientNumberText =
                                        selectedClient?.clientNumber;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Expanded(
                                                        child:
                                                            hasSelection &&
                                                                    selectedClient !=
                                                                        null
                                                                ? InputDecorator(
                                                                  decoration: InputDecoration(
                                                                    labelText:
                                                                        'Cliente',
                                                                    floatingLabelBehavior:
                                                                        FloatingLabelBehavior
                                                                            .always,
                                                                    errorText:
                                                                        state
                                                                            .errorText,
                                                                    suffixIcon: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        IconButton(
                                                                          tooltip:
                                                                              'Apri scheda cliente',
                                                                          icon: const Icon(
                                                                            Icons.open_in_new_rounded,
                                                                          ),
                                                                          onPressed:
                                                                              () => _openClientDetails(
                                                                                selectedClient,
                                                                              ),
                                                                        ),
                                                                        IconButton(
                                                                          tooltip:
                                                                              'Rimuovi cliente',
                                                                          icon: const Icon(
                                                                            Icons.close_rounded,
                                                                          ),
                                                                          onPressed:
                                                                              _clearClientSelection,
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  isEmpty:
                                                                      false,
                                                                  child: Padding(
                                                                    padding:
                                                                        const EdgeInsets.symmetric(
                                                                          vertical:
                                                                              12,
                                                                        ),
                                                                    child: Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Text(
                                                                          selectedClient
                                                                              .fullName,
                                                                          style:
                                                                              theme.textTheme.bodyLarge ??
                                                                              theme.textTheme.bodyMedium,
                                                                        ),
                                                                        if (selectedClient
                                                                            .phone
                                                                            .trim()
                                                                            .isNotEmpty)
                                                                          Padding(
                                                                            padding: const EdgeInsets.only(
                                                                              top:
                                                                                  4,
                                                                            ),
                                                                            child: Text(
                                                                              selectedClient.phone,
                                                                              style:
                                                                                  theme.textTheme.bodyMedium?.copyWith(
                                                                                    color:
                                                                                        colorScheme.onSurfaceVariant,
                                                                                  ) ??
                                                                                  theme.textTheme.bodyMedium,
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                )
                                                                : TextField(
                                                                  controller:
                                                                      _clientSearchController,
                                                                  focusNode:
                                                                      _clientSearchFocusNode,
                                                                  decoration: InputDecoration(
                                                                    labelText:
                                                                        'Cliente',
                                                                    floatingLabelBehavior:
                                                                        FloatingLabelBehavior
                                                                            .always,
                                                                    hintText:
                                                                        'Nome, cognome, telefono o email',
                                                                    errorText:
                                                                        state
                                                                            .errorText,
                                                                    suffixIcon:
                                                                        _clientSearchController.text.isEmpty
                                                                            ? const Icon(
                                                                              Icons.search_rounded,
                                                                              size:
                                                                                  20,
                                                                            )
                                                                            : IconButton(
                                                                              tooltip:
                                                                                  'Pulisci ricerca',
                                                                              icon: const Icon(
                                                                                Icons.clear_rounded,
                                                                              ),
                                                                              onPressed:
                                                                                  _clearClientSearch,
                                                                            ),
                                                                  ),
                                                                  keyboardType:
                                                                      TextInputType
                                                                          .text,
                                                                  textInputAction:
                                                                      TextInputAction
                                                                          .search,
                                                                  onChanged:
                                                                      (
                                                                        value,
                                                                      ) => _onClientSearchChanged(
                                                                        value,
                                                                        filteredClients,
                                                                        _ClientSearchMode
                                                                            .general,
                                                                      ),
                                                                ),
                                                      ),
                                                      if (_clientId ==
                                                          null) ...[
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        IconButton(
                                                          onPressed:
                                                              _createClient,
                                                          tooltip:
                                                              'Nuovo cliente',
                                                          icon: const Icon(
                                                            Icons
                                                                .person_add_alt_1_rounded,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if (!hasSelection) ...[
                                                    const SizedBox(height: 8),
                                                    _buildClientSuggestions(
                                                      suggestions,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            SizedBox(
                                              width: 220,
                                              child:
                                                  hasSelection &&
                                                          selectedClient != null
                                                      ? InputDecorator(
                                                        decoration: const InputDecoration(
                                                          labelText:
                                                              'Numero cliente',
                                                          floatingLabelBehavior:
                                                              FloatingLabelBehavior
                                                                  .always,
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 12,
                                                              ),
                                                          child: Text(
                                                            (clientNumberText !=
                                                                        null &&
                                                                    clientNumberText
                                                                        .isNotEmpty)
                                                                ? clientNumberText
                                                                : 'Numero non disponibile',
                                                            style:
                                                                theme
                                                                    .textTheme
                                                                    .bodyLarge ??
                                                                theme
                                                                    .textTheme
                                                                    .bodyMedium,
                                                          ),
                                                        ),
                                                      )
                                                      : TextField(
                                                        controller:
                                                            _clientNumberSearchController,
                                                        focusNode:
                                                            _clientNumberSearchFocusNode,
                                                        decoration: InputDecoration(
                                                          labelText:
                                                              'Numero cliente',
                                                          floatingLabelBehavior:
                                                              FloatingLabelBehavior
                                                                  .always,
                                                          hintText:
                                                              'Numero cliente',
                                                          suffixIcon:
                                                              _clientNumberSearchController
                                                                      .text
                                                                      .isEmpty
                                                                  ? const Icon(
                                                                    Icons
                                                                        .search_rounded,
                                                                    size: 20,
                                                                  )
                                                                  : IconButton(
                                                                    tooltip:
                                                                        'Pulisci ricerca',
                                                                    icon: const Icon(
                                                                      Icons
                                                                          .clear_rounded,
                                                                    ),
                                                                    onPressed:
                                                                        _clearClientNumberSearch,
                                                                  ),
                                                        ),
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                        textInputAction:
                                                            TextInputAction
                                                                .search,
                                                        inputFormatters: [
                                                          FilteringTextInputFormatter
                                                              .digitsOnly,
                                                        ],
                                                        onChanged:
                                                            (
                                                              value,
                                                            ) => _onClientSearchChanged(
                                                              value,
                                                              filteredClients,
                                                              _ClientSearchMode
                                                                  .number,
                                                            ),
                                                      ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSectionHeader(
                            icon: Icons.design_services_rounded,
                            title: 'Servizi e pacchetti',
                            subtitle:
                                'Scegli i trattamenti e decidi se scalare sessioni da un pacchetto',
                          ),
                          const SizedBox(height: 12),
                          FormField<List<String>>(
                            validator:
                                (_) =>
                                    _serviceIds.isEmpty
                                        ? 'Scegli almeno un servizio'
                                        : null,
                            builder: (state) {
                              final theme = Theme.of(context);
                              final selectedNames =
                                  selectedServices
                                      .map((service) => service.name)
                                      .toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      final selection =
                                          await _openServicePicker(
                                            context,
                                            services: filteredServices,
                                            categories:
                                                _categoriesForCurrentSalon(),
                                            selectedStaff: staffMembers
                                                .firstWhereOrNull(
                                                  (member) =>
                                                      member.id == _staffId,
                                                ),
                                          );
                                          if (selection != null) {
                                            setState(() {
                                              _serviceIds = selection;
                                              _ensureServiceState(_serviceIds);
                                              _manualPackageSelections.removeWhere(
                                                (serviceId) =>
                                                    !_serviceIds.contains(
                                                      serviceId,
                                                    ),
                                              );
                                              if (_serviceIds.isEmpty) {
                                                _clearAllPackageSelections();
                                              } else {
                                                _lastSuggestionKey = '';
                                                _latestSuggestion = null;
                                                final baseSelectedServices =
                                                    _selectedServicesInOrder(
                                                  services,
                                                );
                                                final adjustedServices =
                                                    _applyDurationAdjustments(
                                                  baseSelectedServices,
                                                );
                                                final totalDuration =
                                                    _sumServiceDurations(
                                                  adjustedServices,
                                                );
                                                if (totalDuration >
                                                    Duration.zero) {
                                                  _end = _start.add(
                                                    totalDuration,
                                                  );
                                                }
                                              }
                                            });
                                            _clearInlineError();
                                        state.didChange(_serviceIds);
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Servizi',
                                        floatingLabelBehavior:
                                            FloatingLabelBehavior.always,
                                        errorText: state.errorText,
                                        suffixIcon: const Icon(
                                          Icons.segment_rounded,
                                        ),
                                      ),
                                      isEmpty: selectedNames.isEmpty,
                                      child: selectedNames.isEmpty
                                          ? Text(
                                              'Seleziona uno o più servizi',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                color: theme.hintColor,
                                              ),
                                            )
                                          : _buildReorderableServiceChips(
                                              theme,
                                              selectedServices,
                                            ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          if (showPackageSection)
                            _buildPackageSection(
                              theme: theme,
                              selectedServices: selectedServices,
                              packagesByService: packagesByService,
                              allClientPackages: allClientPackages,
                            ),
                          const SizedBox(height: 24),

                          _buildScheduleCard(
                            bookingDateLabel: bookingDateLabel,
                            startTimeLabel: startTimeLabel,
                            endTimeLabel: endTimeLabel,
                            baseServices: baseSelectedServices,
                          ),
                          _buildServiceDurationAdjustmentPanel(
                            baseServices: baseSelectedServices,
                            adjustedServices: selectedServices,
                          ),

                          if (closureConflicts.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ...closureConflicts.map(
                              (closure) => _buildClosureNotice(
                                context: context,
                                message: _describeClosure(closure),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionButtons(context, statusItems, isFutureStart),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    List<DropdownMenuItem<AppointmentStatus>> statusItems,
    bool isFutureStart,
  ) {
    final theme = Theme.of(context);
    final deleteEnabled = widget.enableDelete && widget.initial != null;
    return Row(
      children: [
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<AppointmentStatus>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Stato'),
            items: statusItems,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              if (isFutureStart && value == AppointmentStatus.completed) {
                _showInlineError(
                  'Non puoi impostare lo stato "Completato" per un appuntamento futuro.',
                );
                return;
              }
              _clearInlineError();
              setState(() => _status = value);
            },
          ),
        ),
        const SizedBox(width: 12),
        if (deleteEnabled)
          TextButton.icon(
            onPressed: _isDeleting ? null : _confirmDelete,
            icon:
                _isDeleting
                    ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.delete_outline_rounded),
            label: Text(_isDeleting ? 'Eliminazione...' : 'Elimina'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          )
        else
          const SizedBox.shrink(),
        const Spacer(),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _notes,
          builder: (context, value, _) {
            final hasNote = value.text.trim().isNotEmpty;
            return FilledButton.tonalIcon(
              onPressed: _isDeleting ? null : _showNotesDialog,
              icon: const Icon(Icons.note_alt_rounded),
              label: Text(hasNote ? 'Modifica nota' : 'Nota'),
            );
          },
        ),
        const SizedBox(width: 12),
        FilledButton.tonal(
          onPressed: _isDeleting ? null : _copy,
          child:
              _copyJustCompleted
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_rounded),
                      SizedBox(width: 8),
                      Text('Copiato!'),
                    ],
                  )
                  : const Text('Copia'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _isDeleting ? null : _submit,
          child: const Text('Salva'),
        ),
      ],
    );
  }

  Future<void> _showNotesDialog() async {
    final controller = TextEditingController(text: _notes.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Note'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Nota',
                hintText: 'Aggiungi una nota per l\'appuntamento',
                alignLabelWithHint: true,
              ),
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Salva nota'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      setState(() {
        _notes.text = result;
      });
    }
    controller.dispose();
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment:
            subtitle == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing],
        ],
      ),
    );
  }

  Widget _buildPackageSection({
    required ThemeData theme,
    required List<Service> selectedServices,
    required Map<String, List<ClientPackagePurchase>> packagesByService,
    required List<ClientPackagePurchase> allClientPackages,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Pacchetti disponibili', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          if (selectedServices.isEmpty)
            allClientPackages.isNotEmpty
                ? _ClientPackageSummaryList(packages: allClientPackages)
                : Text(
                  'Il cliente non ha pacchetti attivi.',
                  style: theme.textTheme.bodyMedium,
                )
          else if (allClientPackages.isEmpty)
            Text(
              'Il cliente non ha pacchetti attivi.',
              style: theme.textTheme.bodyMedium,
            )
          else
            _buildPerServicePackageList(
              selectedServices: selectedServices,
              packagesByService: packagesByService,
              theme: theme,
            ),
        ],
      ),
    );
  }

  Widget _buildPerServicePackageList({
    required List<Service> selectedServices,
    required Map<String, List<ClientPackagePurchase>> packagesByService,
    required ThemeData theme,
  }) {
    final entries = selectedServices
        .map(
          (service) =>
              MapEntry(service, packagesByService[service.id] ?? const []),
        )
        .where((entry) => entry.value.isNotEmpty)
        .toList(growable: false);
    if (entries.isEmpty) {
      return Text(
        'I servizi selezionati non sono coperti da alcun pacchetto.',
        style: theme.textTheme.bodyMedium,
      );
    }
    return Column(
      children: [
        for (final entry in entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ServicePackageSelector(
              service: entry.key,
              packages: entry.value,
              selectedPackageId: _servicePackageSelections[entry.key.id],
              suggestedPackageId: _suggestedPackageForService(entry.key.id),
              uncoveredQuantity:
                  _latestSuggestion?.uncoveredServices[entry.key.id] ?? 0,
              onSelect: (value) {
                setState(() {
                  _manualPackageSelections.add(entry.key.id);
                  _servicePackageSelections[entry.key.id] = value;
                });
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScheduleCard({
    required String bookingDateLabel,
    required String startTimeLabel,
    required String endTimeLabel,
    required List<Service> baseServices,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final durationMinutes = _end.difference(_start).inMinutes;
    final canDecreaseDuration = durationMinutes > _slotIntervalMinutes;
    final lastService =
        baseServices.isNotEmpty ? baseServices.last : null;
    final canAdjustLastService = lastService != null;
    final canDecreaseLastService = canDecreaseDuration && canAdjustLastService;
    final canIncreaseLastService = canAdjustLastService;
    void adjustLastService(int delta) {
      if (lastService == null || delta == 0) return;
      _updateServiceDurationDelta(lastService.id, delta, baseServices);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickStart,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            color: colorScheme.surfaceContainerLowest,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      bookingDateLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timelapse_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$durationMinutes min',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimelineInfoBox(
                      label: 'Ora di inizio',
                      value: startTimeLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimelineInfoBox(
                      label: 'Ora di fine',
                      value: endTimeLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Regola durata complessiva',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        tooltip: '-$_slotIntervalMinutes min',
                        onPressed: canDecreaseLastService
                            ? () => adjustLastService(-_slotIntervalMinutes)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        tooltip: '+$_slotIntervalMinutes min',
                        onPressed: canIncreaseLastService
                            ? () => adjustLastService(_slotIntervalMinutes)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tocca per scegliere un altro slot disponibile',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceDurationAdjustmentPanel({
    required List<Service> baseServices,
    required List<Service> adjustedServices,
  }) {
    if (baseServices.isEmpty) {
      return const SizedBox.shrink();
    }
    final adjustedById = {
      for (final service in adjustedServices) service.id: service,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Theme.of(context).dividerColor.withOpacity(0.4),
          ),
          child: ExpansionTile(
            collapsedTextColor: Theme.of(context).colorScheme.onSurfaceVariant,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            leading: Icon(
              Icons.timeline,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Regola durata servizi'),
            subtitle: Text(
              'Modifica ogni servizio di ±$_slotIntervalMinutes min',
            ),
            children: [
              for (var index = 0; index < baseServices.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                  title: Text(baseServices[index].name),
                  subtitle: Text(
                    _serviceDurationAdjustmentSubtitle(
                      baseServices[index],
                      adjustedService: adjustedById[baseServices[index].id],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      tooltip: '-$_slotIntervalMinutes min',
                      onPressed: (adjustedById[baseServices[index].id]
                                  ?.totalDuration ??
                              baseServices[index].totalDuration) >
                          Duration.zero
                          ? () => _updateServiceDurationDelta(
                                baseServices[index].id,
                                -_slotIntervalMinutes,
                                baseServices,
                              )
                          : null,
                    ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        tooltip: '+$_slotIntervalMinutes min',
                        onPressed: () => _updateServiceDurationDelta(
                          baseServices[index].id,
                          _slotIntervalMinutes,
                          baseServices,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _serviceDurationAdjustmentSubtitle(
    Service baseService, {
    Service? adjustedService,
  }) {
    final adjustment = _serviceDurationAdjustments[baseService.id] ?? Duration.zero;
    final adjustedTotal =
        adjustedService?.totalDuration ?? baseService.totalDuration;
    final adjustmentMinutes = adjustment.inMinutes;
    final adjustmentLabel = adjustmentMinutes == 0
        ? 'Durata standard'
        : '${adjustmentMinutes > 0 ? '+' : ''}$adjustmentMinutes min';
    return '${adjustedTotal.inMinutes} min ($adjustmentLabel)';
  }

  Future<void> _pickStart() async {
    if (_salonId == null) {
      _showInlineError(
        'Seleziona un operatore associato a un salone prima di scegliere l\'orario.',
      );
      return;
    }
    if (_staffId == null) {
      _showInlineError('Seleziona un operatore prima di scegliere l\'orario.');
      return;
    }
    if (_serviceIds.isEmpty) {
      _showInlineError(
        'Seleziona almeno un servizio prima di scegliere l\'orario.',
      );
      return;
    }

    final data = ref.read(appDataProvider);
    final salons = data.salons.isNotEmpty ? data.salons : widget.salons;
    final staffMembers = data.staff.isNotEmpty ? data.staff : widget.staff;
    final allServices =
        data.services.isNotEmpty ? data.services : widget.services;
    final services = allServices;
    final salon = salons.firstWhereOrNull((item) => item.id == _salonId);
    final staffMember = staffMembers.firstWhereOrNull(
      (member) => member.id == _staffId,
    );
    final baseSelectedServices = _selectedServicesInOrder(services);
    final selectedServices =
        _applyDurationAdjustments(baseSelectedServices);
    if (staffMember == null || selectedServices.isEmpty) {
      _showInlineError('Operatore o servizi non validi.');
      return;
    }
    final totalDuration = _sumServiceDurations(selectedServices);
    if (totalDuration <= Duration.zero) {
      _showInlineError('Durata complessiva servizi non valida.');
      return;
    }

    final now = DateTime.now();
    final initialDate = _start;
    final firstDate = now.subtract(const Duration(days: 365));
    final lastDate = now.add(const Duration(days: 365));
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('it', 'IT'),
    );
    if (selectedDate == null || !mounted) {
      return;
    }
    final day = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final dayEnd = day.add(const Duration(days: 1));
    final salonClosures = _findOverlappingClosures(
      closures: salon?.closures ?? const <SalonClosure>[],
      start: day,
      end: dayEnd,
    );

    final slots = _availableSlotsForDay(
      data: data,
      day: day,
      salon: salon,
      services: selectedServices,
      totalDuration: totalDuration,
      staffMember: staffMember,
      allServices: allServices,
      salonId: _salonId!,
      clientId: _clientId,
      excludeAppointmentId: widget.initial?.id,
      salonClosures: salonClosures,
    );
    if (slots.isEmpty) {
      if (!mounted) return;
      if (salonClosures.isNotEmpty) {
        await _showClosureAlert(salonClosures);
      } else {
        _showInlineError(
          'Nessuno slot disponibile per l\'operatore nella data selezionata.',
        );
      }
      return;
    }

    final sameDay =
        _start.year == day.year &&
        _start.month == day.month &&
        _start.day == day.day;
    final selectedSlotStart = await _showSlotPicker(
      day: day,
      slots: slots,
      initialSelection: sameDay ? _start : null,
    );
    if (selectedSlotStart == null || !mounted) {
      return;
    }

    setState(() {
      _start = selectedSlotStart;
      _end = _start.add(totalDuration);
      if (_start.isAfter(DateTime.now()) &&
          _status == AppointmentStatus.completed) {
        _status = AppointmentStatus.scheduled;
      }
    });
    _clearInlineError();
  }

  List<_AvailableSlot> _availableSlotsForDay({
    required AppDataState data,
    required DateTime day,
    required Salon? salon,
    required List<Service> services,
    required Duration totalDuration,
    required StaffMember staffMember,
    required List<Service> allServices,
    required String salonId,
    String? clientId,
    String? excludeAppointmentId,
    required List<SalonClosure> salonClosures,
  }) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final slotStep = Duration(minutes: _slotIntervalMinutes);
    final existingAppointments = data.appointments;
    final now = DateTime.now();
    final expressPlaceholders =
        data.lastMinuteSlots
            .where((slot) {
              if (slot.salonId != salonId) {
                return false;
              }
              if (slot.operatorId != staffMember.id) {
                return false;
              }
              if (!slot.isAvailable) {
                return false;
              }
              if (!slot.end.isAfter(now)) {
                return false;
              }
              return true;
            })
            .map(
              (slot) => Appointment(
                id: 'last-minute-${slot.id}',
                salonId: slot.salonId,
                clientId: 'last-minute-${slot.id}',
                staffId: slot.operatorId ?? staffMember.id,
                serviceIds:
                    slot.serviceId != null && slot.serviceId!.isNotEmpty
                        ? <String>[slot.serviceId!]
                        : const <String>[],
                start: slot.start,
                end: slot.end,
                status: AppointmentStatus.scheduled,
                roomId: slot.roomId,
              ),
            )
            .toList();
    final allAppointments = <Appointment>[
      ...existingAppointments,
      ...expressPlaceholders,
    ];

    final busyAppointments =
        allAppointments.where((appointment) {
          if (appointment.staffId != staffMember.id) {
            return false;
          }
          if (excludeAppointmentId != null &&
              appointment.id == excludeAppointmentId) {
            return false;
          }
          if (!appointmentBlocksAvailability(appointment)) {
            return false;
          }
          if (!appointment.end.isAfter(dayStart) ||
              !appointment.start.isBefore(dayEnd)) {
            return false;
          }
          return true;
        }).toList();

    final busyAbsences =
        _combinedAbsences(data).where((absence) {
          if (absence.staffId != staffMember.id) {
            return false;
          }
          if (!absence.end.isAfter(dayStart) ||
              !absence.start.isBefore(dayEnd)) {
            return false;
          }
          return true;
        }).toList();

    final relevantShifts =
        data.shifts.where((shift) {
            if (shift.staffId != staffMember.id) {
              return false;
            }
            if (shift.salonId != salonId) {
              return false;
            }
            if (!shift.end.isAfter(dayStart)) {
              return false;
            }
            if (!shift.start.isBefore(dayEnd)) {
              return false;
            }
            return true;
          }).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    final clientAppointments =
        clientId == null
            ? const <Appointment>[]
            : allAppointments.where((appointment) {
              if (appointment.clientId != clientId) {
                return false;
              }
              if (excludeAppointmentId != null &&
                  appointment.id == excludeAppointmentId) {
                return false;
              }
              if (!appointmentBlocksAvailability(appointment)) {
                return false;
              }
              return true;
            }).toList();

    final slots = <_AvailableSlot>[];

    for (final shift in relevantShifts) {
      final windowStart =
          shift.start.isAfter(dayStart) ? shift.start : dayStart;
      final windows = _buildShiftWindows(
        shift: shift,
        from: windowStart,
        busyAppointments: busyAppointments,
        busyAbsences: busyAbsences,
        salonClosures: salonClosures,
      );
      for (final window in windows) {
        final clampedStart =
            window.start.isBefore(dayStart) ? dayStart : window.start;
        final clampedEnd = window.end.isAfter(dayEnd) ? dayEnd : window.end;
        if (!clampedEnd.isAfter(clampedStart)) {
          continue;
        }
        var slotStart = _ceilToInterval(clampedStart, _slotIntervalMinutes);
        while (slotStart.isBefore(clampedEnd)) {
          final slotEnd = slotStart.add(totalDuration);
          if (slotEnd.isAfter(clampedEnd)) {
            break;
          }

          final hasStaffConflict = hasStaffBookingConflict(
            appointments: allAppointments,
            staffId: staffMember.id,
            start: slotStart,
            end: slotEnd,
            excludeAppointmentId: excludeAppointmentId,
          );
          if (hasStaffConflict) {
            slotStart = slotStart.add(slotStep);
            continue;
          }

          if (clientId != null) {
            final hasClientConflict = hasClientBookingConflict(
              appointments: clientAppointments,
              clientId: clientId,
              start: slotStart,
              end: slotEnd,
              excludeAppointmentId: excludeAppointmentId,
            );
            if (hasClientConflict) {
              slotStart = slotStart.add(slotStep);
              continue;
            }
          }

          final blockingEquipment = <String>{};
          var equipmentStart = slotStart;
          for (final service in services) {
            final equipmentEnd = equipmentStart.add(service.totalDuration);
            final equipmentCheck = EquipmentAvailabilityChecker.check(
              salon: salon,
              service: service,
              allServices: allServices,
              appointments: allAppointments,
              start: equipmentStart,
              end: equipmentEnd,
              excludeAppointmentId: excludeAppointmentId,
            );
            if (equipmentCheck.hasConflicts) {
              blockingEquipment.addAll(equipmentCheck.blockingEquipment);
            }
            equipmentStart = equipmentEnd;
          }
          if (blockingEquipment.isNotEmpty) {
            slotStart = slotStart.add(slotStep);
            continue;
          }

          slots.add(
            _AvailableSlot(start: slotStart, end: slotEnd, shiftId: shift.id),
          );
          slotStart = slotStart.add(slotStep);
        }
      }
    }

    slots.sort((a, b) => a.start.compareTo(b.start));
    return slots;
  }

  Future<DateTime?> _showSlotPicker({
    required DateTime day,
    required List<_AvailableSlot> slots,
    DateTime? initialSelection,
  }) {
    final dayFormat = DateFormat('EEEE d MMMM yyyy', 'it_IT');
    final timeFormat = DateFormat('HH:mm', 'it_IT');
    return showAppModalSheet<DateTime>(
      context: context,
      builder: (ctx) {
        final bottomPadding = 16.0 + MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Orari disponibili',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(_capitalize(dayFormat.format(day))),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      slots
                          .map(
                            (slot) => ChoiceChip(
                              label: Text(
                                '${timeFormat.format(slot.start)} - ${timeFormat.format(slot.end)}',
                              ),
                              selected:
                                  initialSelection != null &&
                                  slot.start == initialSelection,
                              onSelected: (selected) {
                                if (!selected) return;
                                Navigator.of(ctx).pop(slot.start);
                              },
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_TimeRange> _buildShiftWindows({
    required Shift shift,
    required DateTime from,
    required List<Appointment> busyAppointments,
    required List<StaffAbsence> busyAbsences,
    required List<SalonClosure> salonClosures,
  }) {
    final windows = <_TimeRange>[];
    if (from.isAfter(shift.end)) {
      return windows;
    }
    windows.add(_TimeRange(start: shift.start, end: shift.end));

    if (shift.breakStart != null && shift.breakEnd != null) {
      final breakRange = _TimeRange(
        start: shift.breakStart!,
        end: shift.breakEnd!,
      );
      _subtractRange(windows, breakRange);
    }

    for (final appointment in busyAppointments) {
      if (!appointment.end.isAfter(shift.start) ||
          !appointment.start.isBefore(shift.end)) {
        continue;
      }
      _subtractRange(
        windows,
        _TimeRange(start: appointment.start, end: appointment.end),
      );
    }

    for (final absence in busyAbsences) {
      if (!absence.end.isAfter(shift.start) ||
          !absence.start.isBefore(shift.end)) {
        continue;
      }
      _subtractRange(
        windows,
        _TimeRange(start: absence.start, end: absence.end),
      );
    }

    for (final closure in salonClosures) {
      if (!closure.end.isAfter(shift.start) ||
          !closure.start.isBefore(shift.end)) {
        continue;
      }
      _subtractRange(
        windows,
        _TimeRange(start: closure.start, end: closure.end),
      );
    }

    return windows
        .map((window) => window.trim(from: from))
        .whereType<_TimeRange>()
        .toList();
  }

  void _subtractRange(List<_TimeRange> windows, _TimeRange busy) {
    for (var i = 0; i < windows.length; i++) {
      final window = windows[i];
      if (!window.overlaps(busy)) {
        continue;
      }
      final replacement = window.subtract(busy);
      windows.removeAt(i);
      windows.insertAll(i, replacement);
      i += replacement.length - 1;
    }
  }

  DateTime _ceilToInterval(DateTime time, int minutes) {
    final remainder = time.minute % minutes;
    final needsCeil =
        remainder != 0 ||
        time.second != 0 ||
        time.millisecond != 0 ||
        time.microsecond != 0;
    final truncated = DateTime(
      time.year,
      time.month,
      time.day,
      time.hour,
      time.minute - remainder,
    );
    if (!needsCeil) {
      return truncated;
    }
    return truncated.add(Duration(minutes: minutes));
  }

  List<StaffAbsence> _combinedAbsences(AppDataState data) {
    final map = <String, StaffAbsence>{};
    for (final absence in data.publicStaffAbsences) {
      map[absence.id] = absence;
    }
    for (final absence in data.staffAbsences) {
      map[absence.id] = absence;
    }
    return map.values.toList();
  }

  List<SalonClosure> _findOverlappingClosures({
    required Iterable<SalonClosure> closures,
    required DateTime start,
    required DateTime end,
  }) {
    final map = <String, SalonClosure>{};
    for (final closure in closures) {
      if (!closure.end.isAfter(start) || !closure.start.isBefore(end)) {
        continue;
      }
      map[closure.id] = closure;
    }
    final list =
        map.values.toList()..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  Future<void> _showClosureAlert(List<SalonClosure> closures) async {
    if (closures.isEmpty || !mounted) {
      return;
    }
    final message = closures.map(_describeClosure).join('\n\n');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Salone chiuso'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _describeClosure(SalonClosure closure) {
    final dateFormat = DateFormat('d MMMM yyyy', 'it_IT');
    final timeFormat = DateFormat('HH:mm', 'it_IT');
    final isSameDay =
        closure.start.year == closure.end.year &&
        closure.start.month == closure.end.month &&
        closure.start.day == closure.end.day;
    final startDate = dateFormat.format(closure.start);
    final endDate = dateFormat.format(closure.end);
    final startTime = timeFormat.format(closure.start);
    final endTime = timeFormat.format(closure.end);
    final base =
        isSameDay
            ? 'Il $startDate dalle $startTime alle $endTime'
            : 'Dal $startDate $startTime al $endDate $endTime';
    final reason = closure.reason?.trim();
    if (reason == null || reason.isEmpty) {
      return base;
    }
    return '$base • Motivo: $reason';
  }

  Widget _buildClosureNotice({
    required BuildContext context,
    required String message,
  }) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }

  Future<List<String>?> _openServicePicker(
    BuildContext context, {
    required List<Service> services,
    required List<ServiceCategory> categories,
    StaffMember? selectedStaff,
  }) async {
    if (services.isEmpty) {
      return const <String>[];
    }
    final initialSelection = List<String>.from(_serviceIds);
    final sortedServices = List<Service>.from(services)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final theme = Theme.of(context);
    final servicesById = {
      for (final service in sortedServices) service.id: service,
    };
    final zoneCategories =
        categories
            .where((category) => category.zoneServiceIds.isNotEmpty)
            .map((category) {
              final entries = _zoneEntriesForCategory(category, servicesById);
              if (entries.isEmpty) {
                return null;
              }
              return _ZoneCategoryData(category: category, entries: entries);
            })
            .whereType<_ZoneCategoryData>()
            .toList();
    zoneCategories.sort(
      (a, b) => a.category.name.toLowerCase().compareTo(
        b.category.name.toLowerCase(),
      ),
    );
    final hasZoneTab = zoneCategories.isNotEmpty;
    final zoneCategoryIds = zoneCategories.map((data) => data.category.id).toSet();
    final zoneCategoryNames = zoneCategories
        .map((data) => data.category.name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();

    final searchController = TextEditingController();
    final result = await showAppModalSheet<List<String>>(
      context: context,
      builder: (context) {
        var query = '';
        var workingSelection = List<String>.from(initialSelection);
        var selectedZoneCategoryId =
            zoneCategories.isNotEmpty ? zoneCategories.first.category.id : '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            void toggleSelection(String serviceId) {
              setModalState(() {
                if (workingSelection.contains(serviceId)) {
                  workingSelection = workingSelection
                      .where((id) => id != serviceId)
                      .toList(growable: false);
                } else {
                  workingSelection = [...workingSelection, serviceId];
                }
              });
            }

            final listableServices = sortedServices.where((service) {
              if (service.categoryId != null &&
                  zoneCategoryIds.contains(service.categoryId)) {
                return false;
              }
              final normalizedCategory =
                  service.category.trim().toLowerCase();
              if (normalizedCategory.isNotEmpty &&
                  zoneCategoryNames.contains(normalizedCategory)) {
                return false;
              }
              return true;
            }).toList();
            final lowerQuery = query.trim().toLowerCase();
            final filtered =
                lowerQuery.isEmpty
                    ? listableServices
                    : listableServices.where((service) {
                      final nameMatch = service.name.toLowerCase().contains(
                        lowerQuery,
                      );
                      final categoryMatch = service.category
                          .toLowerCase()
                          .contains(lowerQuery);
                      return nameMatch || categoryMatch;
                    }).toList();
            final grouped = groupBy<Service, String>(filtered, (service) {
              final label = service.category.trim();
              if (label.isNotEmpty) return label;
              return 'Altri servizi';
            });
            final categories =
                grouped.keys.toList()
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

            Widget buildServiceListTab() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Cerca servizio',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon:
                          query.isEmpty
                              ? null
                              : IconButton(
                                tooltip: 'Pulisci ricerca',
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  searchController.clear();
                                  setModalState(() => query = '');
                                },
                              ),
                    ),
                    onChanged: (value) => setModalState(() => query = value),
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Nessun servizio trovato',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final categoryServices =
                              grouped[category] ?? const [];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (categoryServices.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    category,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                              ...categoryServices.map((service) {
                                final selected = workingSelection.contains(
                                  service.id,
                                );
                                final subtitleParts = <String>[];
                                final durationMinutes =
                                    service.totalDuration.inMinutes;
                                if (durationMinutes > 0) {
                                  subtitleParts.add(
                                    'Durata $durationMinutes min',
                                  );
                                }
                                if (service.price > 0) {
                                  subtitleParts.add(
                                    '€ ${service.price.toStringAsFixed(2)}',
                                  );
                                }
                                final subtitle =
                                    subtitleParts.isEmpty
                                        ? null
                                        : subtitleParts.join(' • ');
                                return CheckboxListTile(
                                  value: selected,
                                  onChanged: (_) => toggleSelection(service.id),
                                  dense: true,
                                  title: Text(service.name),
                                  subtitle:
                                      subtitle != null ? Text(subtitle) : null,
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              );
            }

            Widget buildZoneTab() {
              if (!hasZoneTab) {
                return const SizedBox.shrink();
              }
              final activeCategoryIndex = zoneCategories.indexWhere(
                (data) => data.category.id == selectedZoneCategoryId,
              );
              final activeCategoryData =
                  activeCategoryIndex != -1
                      ? zoneCategories[activeCategoryIndex]
                      : zoneCategories.first;
              final activeEntries = activeCategoryData.entries;
              final activeServiceIds =
                  activeEntries.map((entry) => entry.service.id).toSet();
              final activeSelectedServiceIds =
                  workingSelection.where(activeServiceIds.contains).toSet();
              final categorySelectionCounts = {
                for (final data in zoneCategories)
                  data.category.id:
                      workingSelection
                          .where(
                            (id) => data.entries.any(
                              (entry) => entry.service.id == id,
                            ),
                          )
                          .length,
              };

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          zoneCategories.map((data) {
                            final count =
                                categorySelectionCounts[data.category.id] ?? 0;
                            final isActive =
                                selectedZoneCategoryId == data.category.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                selected: isActive,
                                label: Text(data.category.name),
                                avatar:
                                    count > 0
                                        ? CircleAvatar(
                                          radius: 10,
                                          backgroundColor:
                                              isActive
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.primary
                                                      .withOpacity(0.6),
                                          child: Text(
                                            count.toString(),
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                ),
                                          ),
                                        )
                                        : null,
                                onSelected:
                                    (_) => setModalState(() {
                                      selectedZoneCategoryId = data.category.id;
                                    }),
                              ),
                            );
                          }).toList(),
                    ),
                  ),

                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (activeEntries.isEmpty) {
                          return Center(
                            child: Text(
                              'Non ci sono zone configurate per questa categoria.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return Center(
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: AspectRatio(
                              aspectRatio:
                                  bodyZonesCanvasSize.width /
                                  bodyZonesCanvasSize.height,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: bodyZonesCanvasSize.width,
                                  height: bodyZonesCanvasSize.height,
                                  child: _BodyZoneMapCanvas(
                                    entries: activeEntries,
                                    selectedServiceIds:
                                        activeSelectedServiceIds,
                                    onToggle: toggleSelection,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activeSelectedServiceIds.isEmpty
                              ? 'Nessun servizio selezionato'
                              : activeSelectedServiceIds.length == 1
                              ? '1 servizio selezionato'
                              : '${activeSelectedServiceIds.length} servizi selezionati',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed:
                            activeSelectedServiceIds.isEmpty
                                ? null
                                : () => setModalState(() {
                                  workingSelection = workingSelection
                                      .where(
                                        (id) => !activeServiceIds.contains(id),
                                      )
                                      .toList(growable: true);
                                }),
                        child: const Text('Deseleziona'),
                      ),
                    ],
                  ),
                ],
              );
            }

            return DefaultTabController(
              length: hasZoneTab ? 2 : 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seleziona servizi',
                              style: theme.textTheme.titleLarge,
                            ),
                            if (selectedStaff != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Operatore: ${selectedStaff.fullName}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                        TextButton(
                          onPressed:
                              workingSelection.isEmpty
                                  ? null
                                  : () => setModalState(
                                    () => workingSelection = const [],
                                  ),
                          child: const Text('Pulisci'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (hasZoneTab)
                      Material(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        child: TabBar(
                          labelColor: theme.colorScheme.primary,
                          indicatorColor: theme.colorScheme.primary,
                          unselectedLabelColor: theme.colorScheme.onSurface
                              .withOpacity(0.7),
                          tabs: const [
                            Tab(text: 'Elenco servizi'),
                            Tab(text: 'Servizi a zona'),
                          ],
                        ),
                      ),
                    if (hasZoneTab) const SizedBox(height: 12),
                    Expanded(
                      child:
                          hasZoneTab
                              ? TabBarView(
                                children: [
                                  buildServiceListTab(),
                                  buildZoneTab(),
                                ],
                              )
                              : buildServiceListTab(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pop<List<String>>(workingSelection);
                            },
                            child: const Text('Conferma'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
    return result;
  }

  Future<void> _pickEnd() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: _start.add(const Duration(days: 7)),
    );
    if (selectedDate == null) return;
    if (!mounted) return;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end),
    );
    if (selectedTime == null) return;
    if (!mounted) return;
    setState(() {
      _end = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      if (_end.isBefore(_start)) {
        _end = _start.add(const Duration(hours: 1));
      }
      if (_start.isAfter(DateTime.now()) &&
          _status == AppointmentStatus.completed) {
        _status = AppointmentStatus.scheduled;
      }
    });
    _clearInlineError();
  }


  Appointment? _buildAppointment({required bool skipAvailabilityChecks}) {
    _clearInlineError();
    if (!_formKey.currentState!.validate()) {
      return null;
    }
    if (_salonId == null) {
      _showInlineError(
        'Impossibile completare: seleziona un operatore collegato a un salone.',
      );
      return null;
    }

    final data = ref.read(appDataProvider);
    final salons = data.salons.isNotEmpty ? data.salons : widget.salons;
    final allServices =
        data.services.isNotEmpty ? data.services : widget.services;
    final services = allServices;
    final staffMembers = data.staff.isNotEmpty ? data.staff : widget.staff;

    final baseSelectedServices = _selectedServicesInOrder(services);
    final selectedServices = _applyDurationAdjustments(baseSelectedServices);
    if (selectedServices.isEmpty) {
      _showInlineError('Servizi non validi.');
      return null;
    }

    final staffMember = staffMembers.firstWhereOrNull(
      (member) => member.id == _staffId,
    );
    if (staffMember == null) {
      _showInlineError('Operatore non valido.');
      return null;
    }

    final incompatibleService = selectedServices.firstWhereOrNull((service) {
      final allowedRoles = service.staffRoles;
      if (allowedRoles.isEmpty) {
        return false;
      }
      return !staffMember.roleIds.any(
        (roleId) => allowedRoles.contains(roleId),
      );
    });
    if (incompatibleService != null) {
      _showInlineError(
        'L\'operatore selezionato non può erogare "${incompatibleService.name}".',
      );
      return null;
    }

    final selectedSalon = salons.firstWhereOrNull(
      (item) => item.id == _salonId,
    );
    final closureConflicts =
        selectedSalon == null
            ? const <SalonClosure>[]
            : _findOverlappingClosures(
              closures: selectedSalon.closures,
              start: _start,
              end: _end,
            );
    if (closureConflicts.isNotEmpty) {
      final firstConflict = _describeClosure(closureConflicts.first);
      _showInlineError('Il salone è chiuso in questo orario. $firstConflict');
      return null;
    }

    final appointment = Appointment(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      clientId: _clientId!,
      staffId: _staffId!,
      serviceIds: _serviceIds,
      serviceAllocations: _buildServiceAllocations(),
      start: _start,
      end: _end,
      status: _status,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      packageId: null,
      roomId: widget.initial?.roomId,
    );

    if (appointment.start.isAfter(DateTime.now()) &&
        appointment.status == AppointmentStatus.completed) {
      _showInlineError(
        'Non puoi impostare lo stato "Completato" per un appuntamento futuro.',
      );
      return null;
    }

    if (!skipAvailabilityChecks) {
      final existingAppointments = data.appointments;
      final hasStaffConflict = hasStaffBookingConflict(
        appointments: existingAppointments,
        staffId: appointment.staffId,
        start: appointment.start,
        end: appointment.end,
        excludeAppointmentId: appointment.id,
      );
      if (hasStaffConflict) {
        _showInlineError(
          'Impossibile salvare: operatore già occupato in quel periodo',
        );
        return null;
      }

      final hasClientConflict = hasClientBookingConflict(
        appointments: existingAppointments,
        clientId: appointment.clientId,
        start: appointment.start,
        end: appointment.end,
        excludeAppointmentId: appointment.id,
      );
      if (hasClientConflict) {
        _showInlineError(
          'Impossibile salvare: il cliente ha già un appuntamento in quel periodo',
        );
        return null;
      }

      final blockingEquipment = <String>{};
      var equipmentStart = appointment.start;
      for (final service in selectedServices) {
        final equipmentEnd = equipmentStart.add(service.totalDuration);
        final equipmentCheck = EquipmentAvailabilityChecker.check(
          salon: selectedSalon,
          service: service,
          allServices: allServices,
          appointments: existingAppointments,
          start: equipmentStart,
          end: equipmentEnd,
          excludeAppointmentId: appointment.id,
        );
        if (equipmentCheck.hasConflicts) {
          blockingEquipment.addAll(equipmentCheck.blockingEquipment);
        }
        equipmentStart = equipmentEnd;
      }
      if (blockingEquipment.isNotEmpty) {
        final equipmentLabel = blockingEquipment.join(', ');
        final message =
            equipmentLabel.isEmpty
                ? 'Macchinario non disponibile per questo orario.'
                : 'Macchinario non disponibile per questo orario: $equipmentLabel.';
        _showInlineError('$message Scegli un altro slot.');
        return null;
      }
    }

    return appointment;
  }

  void _submit() {
    final appointment = _buildAppointment(skipAvailabilityChecks: false);
    if (appointment == null) {
      return;
    }

    _lastSavedClientId = appointment.clientId;

    final result = AppointmentFormResult(
      action: AppointmentFormAction.save,
      appointment: appointment,
    );
    if (widget.onSaved != null) {
      widget.onSaved!(result);
      return;
    }
    Navigator.of(context).pop(result);
  }

  void _copy() {
    final appointment = _buildAppointment(skipAvailabilityChecks: true);
    if (appointment == null) {
      return;
    }
    final copied = appointment.copyWith(
      id: _uuid.v4(),
      status: AppointmentStatus.scheduled,
    );
    ref.read(appointmentClipboardProvider.notifier).state =
        AppointmentClipboard(appointment: copied, copiedAt: DateTime.now());
    setState(() {
      _copyJustCompleted = true;
    });
    _copyFeedbackTimer?.cancel();
    _copyFeedbackTimer = Timer(_copyFeedbackDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _copyJustCompleted = false;
      });
    });
  }

  Future<void> _confirmDelete() async {
    if (!mounted || _isDeleting) {
      return;
    }
    final appointment = widget.initial;
    if (appointment == null) {
      return;
    }
    final dateFormat = DateFormat('dd MMMM yyyy HH:mm', 'it_IT');
    final appointmentLabel = dateFormat.format(appointment.start);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Elimina appuntamento'),
          content: Text(
            'Confermi l\'eliminazione dell\'appuntamento del $appointmentLabel? L\'operazione è definitiva.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true || !mounted) {
      return;
    }
    setState(() => _isDeleting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(appDataProvider.notifier)
          .deleteAppointment(appointment.id);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Appuntamento del $appointmentLabel eliminato.'),
        ),
      );
      Navigator.of(context).pop(
        AppointmentFormResult(
          action: AppointmentFormAction.delete,
          appointment: appointment,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message =
          error.code == 'permission-denied'
              ? 'Non hai i permessi per eliminare questo appuntamento.'
              : (error.message?.isNotEmpty == true
                  ? error.message!
                  : 'Impossibile eliminare l\'appuntamento. Riprova.');
      messenger.showSnackBar(SnackBar(content: Text(message)));
      setState(() => _isDeleting = false);
    } on StateError catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      setState(() => _isDeleting = false);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Errore durante l\'eliminazione: $error')),
      );
      setState(() => _isDeleting = false);
    }
  }

  Future<void> _createClient() async {
    if (_salonId == null) {
      _showInlineError(
        'Seleziona un operatore per determinare il salone prima di creare un cliente',
      );
      return;
    }

    final data = ref.read(appDataProvider);
    final salons = data.salons.isNotEmpty ? data.salons : widget.salons;
    final clients = data.clients.isNotEmpty ? data.clients : widget.clients;

    final newClient = await showAppModalSheet<Client>(
      context: context,
      builder:
          (ctx) => ClientFormSheet(
            salons: salons,
            clients: clients,
            defaultSalonId: _salonId,
          ),
    );

    if (newClient != null) {
      _applyClientSelection(newClient);
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cliente aggiunto. Salvataggio in corso...'),
        ),
      );
      final notifier = ref.read(appDataProvider.notifier);
      Future<void> persistClient() async {
        try {
          await notifier.upsertClient(newClient);
          if (!mounted) return;
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            const SnackBar(content: Text('Cliente salvato con successo.')),
          );
        } catch (error) {
          if (!mounted) return;
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(content: Text('Impossibile salvare il cliente: $error')),
          );
        }
      }

      unawaited(persistClient());
    }
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
    if (query.isEmpty) {
      setState(() {
        _clientSearchMode = mode;
        _clientSuggestions = const <Client>[];
      });
      return;
    }

    final filtered = ClientSearchUtils.filterClients(
      clients: clients,
      generalQuery: mode == _ClientSearchMode.general ? query : '',
      clientNumberQuery: mode == _ClientSearchMode.number ? query : '',
      exactNumberMatch: mode == _ClientSearchMode.number,
    )..sort((a, b) => a.lastName.compareTo(b.lastName));

    setState(() {
      _clientSearchMode = mode;
      _clientSuggestions =
          filtered.length > 8 ? filtered.sublist(0, 8) : filtered;
    });
  }

  void _handleClientSuggestionTap(Client client) {
    FocusScope.of(context).unfocus();
    _applyClientSelection(client);
  }

  void _applyClientSelection(Client client) {
    setState(() {
      _clientId = client.id;
      _clientSearchController.text = client.fullName;
      _clientNumberSearchController.text = client.clientNumber ?? '';
      _clientSearchMode = _ClientSearchMode.general;
      _clientSuggestions = const <Client>[];
      _clearAllPackageSelections();
      _ensureServiceState(_serviceIds);
    });
    _clientFieldKey.currentState?.didChange(client.id);
  }

  void _clearClientSelection() {
    setState(() {
      _clientId = null;
      _clientSearchController.clear();
      _clientNumberSearchController.clear();
      _clientSearchMode = _ClientSearchMode.general;
      _clientSuggestions = const <Client>[];
      _clearAllPackageSelections();
      _ensureServiceState(_serviceIds);
    });
    _clientFieldKey.currentState?.didChange(null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_clientSearchFocusNode);
    });
  }

  void _openClientDetails(Client client) {
    FocusScope.of(context).unfocus();
    final payload = <String, Object?>{'clientId': client.id};
    final clientNumber = client.clientNumber;
    if (clientNumber != null && clientNumber.isNotEmpty) {
      payload['clientNumber'] = clientNumber;
    }
    ref
        .read(adminDashboardIntentProvider.notifier)
        .state = AdminDashboardIntent(moduleId: 'clients', payload: payload);
    Navigator.of(context).maybePop();
  }

  Widget _buildClientSuggestions(List<Client> suggestions) {
    final query =
        _clientSearchMode == _ClientSearchMode.number
            ? _clientNumberSearchController.text.trim()
            : _clientSearchController.text.trim();
    if (query.isEmpty) {
      return const SizedBox.shrink();
    }
    if (suggestions.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(
            'Nessun cliente trovato. Prova a modificare la ricerca.',
            style: Theme.of(context).textTheme.bodyMedium,
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
            _buildClientSuggestionTile(suggestions[i]),
            if (i != suggestions.length - 1)
              const Divider(height: 1, thickness: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildClientSuggestionTile(Client client) {
    final subtitle = _buildClientSubtitle(client);
    final initials =
        client.firstName.characters.firstOrNull?.toUpperCase() ??
        client.lastName.characters.firstOrNull?.toUpperCase() ??
        '?';
    return ListTile(
      onTap: () => _handleClientSuggestionTap(client),
      leading: CircleAvatar(child: Text(initials)),
      title: Text(client.fullName),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  String _buildClientSubtitle(Client client) {
    final parts = <String>[];
    if (client.clientNumber != null && client.clientNumber!.isNotEmpty) {
      parts.add('N° ${client.clientNumber}');
    }
    if (client.phone.isNotEmpty) {
      parts.add(client.phone);
    }
    if (client.email != null && client.email!.isNotEmpty) {
      parts.add(client.email!);
    }
    return parts.join(' · ');
  }

  void _clearAllPackageSelections() {
    _servicePackageSelections.clear();
    _manualPackageSelections.clear();
    _latestSuggestion = null;
    _lastSuggestionKey = '';
  }

  void _ensureServiceState(List<String> serviceIds) {
    final expected = serviceIds.toSet();
    for (final id in serviceIds) {
      _serviceQuantities.putIfAbsent(id, () => 1);
      _servicePackageSelections.putIfAbsent(id, () => null);
    }
    final existing = _servicePackageSelections.keys.toList(growable: false);
    for (final id in existing) {
      if (!expected.contains(id)) {
        _servicePackageSelections.remove(id);
        _serviceQuantities.remove(id);
        _manualPackageSelections.remove(id);
      }
    }
    _syncServiceDurationAdjustments(serviceIds);
  }

  void _syncServiceDurationAdjustments(List<String> serviceIds) {
    final expected = serviceIds.toSet();
    _serviceDurationAdjustments.removeWhere((key, _) => !expected.contains(key));
    for (final id in serviceIds) {
      _serviceDurationAdjustments.putIfAbsent(id, () => Duration.zero);
    }
  }

  List<Service> _applyDurationAdjustments(List<Service> services) {
    return services
        .map((service) {
          final adjustment = _serviceDurationAdjustments[service.id] ?? Duration.zero;
          return service.copyWith(
            extraDuration: service.extraDuration + adjustment,
          );
        })
        .toList(growable: false);
  }

  Duration _sumServiceDurations(List<Service> services) {
    return services.fold(
      Duration.zero,
      (acc, service) => acc + service.totalDuration,
    );
  }

  void _updateServiceDurationDelta(
    String serviceId,
    int deltaMinutes,
    List<Service> baseServices,
  ) {
    final baseService = baseServices.firstWhereOrNull(
      (service) => service.id == serviceId,
    );
    if (baseService == null || deltaMinutes == 0) {
      return;
    }
    final currentAdjustment =
        _serviceDurationAdjustments[serviceId] ?? Duration.zero;
    final currentTotal = baseService.duration +
        baseService.extraDuration +
        currentAdjustment;
    var deltaDuration = Duration(minutes: deltaMinutes);
    final candidateTotal = currentTotal + deltaDuration;
    if (candidateTotal < Duration.zero) {
      deltaDuration = Duration.zero - currentTotal;
    }
    if (deltaDuration == Duration.zero) {
      return;
    }
    final nextAdjustment = currentAdjustment + deltaDuration;
    final newTotal = baseService.duration +
        baseService.extraDuration +
        nextAdjustment;
    if (newTotal < Duration.zero) {
      return;
    }
    setState(() {
      _serviceDurationAdjustments[serviceId] = nextAdjustment;
      final adjustedServices = _applyDurationAdjustments(baseServices);
      final totalDuration = _sumServiceDurations(adjustedServices);
      if (totalDuration > Duration.zero) {
        _end = _start.add(totalDuration);
      }
      _lastSuggestionKey = '';
      _latestSuggestion = null;
    });
    _clearInlineError();
  }

  void _reorderService(int fromIndex, int toIndex) {
    if (fromIndex == toIndex ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= _serviceIds.length ||
        toIndex >= _serviceIds.length) {
      return;
    }
    setState(() {
      final ids = List<String>.from(_serviceIds);
      final serviceId = ids.removeAt(fromIndex);
      ids.insert(toIndex, serviceId);
      _serviceIds = ids;
      _ensureServiceState(_serviceIds);
      _lastSuggestionKey = '';
      _latestSuggestion = null;
    });
  }

  Widget _buildReorderableServiceChips(
    ThemeData theme,
    List<Service> selectedServices,
  ) {
    if (selectedServices.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < selectedServices.length; index++)
          Container(
            key: ValueKey(selectedServices[index].id),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  iconSize: 18,
                  tooltip: 'Sposta indietro',
                  onPressed: index > 0
                      ? () => _reorderService(index, index - 1)
                      : null,
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: theme.iconTheme.color?.withOpacity(
                      index > 0 ? 1 : 0.35,
                    ),
                  ),
                ),
                Chip(
                  label: Text(selectedServices[index].name),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  iconSize: 18,
                  tooltip: 'Sposta avanti',
                  onPressed: index < selectedServices.length - 1
                      ? () => _reorderService(index, index + 1)
                      : null,
                  icon: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: theme.iconTheme.color?.withOpacity(
                      index < selectedServices.length - 1 ? 1 : 0.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _scheduleAllocatorUpdate({
    required List<Service> selectedServices,
    required List<ClientPackagePurchase> packages,
  }) {
    if (_clientId == null ||
        selectedServices.isEmpty ||
        packages.isEmpty ||
        !mounted) {
      return;
    }
    final key = _buildAllocatorKey(
      selectedServices: selectedServices,
      packages: packages,
    );
    if (key == _lastSuggestionKey) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final requested = <String, int>{};
      for (final service in selectedServices) {
        requested[service.id] = _serviceQuantities[service.id] ?? 1;
      }
      final suggestion = _sessionAllocator.suggest(
        requestedServices: requested,
        availablePackages: packages,
      );
      setState(() {
        _latestSuggestion = suggestion;
        for (final allocation in suggestion.allocations) {
          if (_manualPackageSelections.contains(allocation.serviceId)) {
            continue;
          }
          final consumption =
              allocation.packageConsumptions.isNotEmpty
                  ? allocation.packageConsumptions.first
                  : null;
          final packageId = consumption?.packageReferenceId;
          _servicePackageSelections[allocation.serviceId] =
              packageId != null && packageId.isNotEmpty ? packageId : null;
        }
        _lastSuggestionKey = key;
      });
    });
  }

  String _buildAllocatorKey({
    required List<Service> selectedServices,
    required List<ClientPackagePurchase> packages,
  }) {
    final servicePart =
        selectedServices
            .map(
              (service) =>
                  '${service.id}:${_serviceQuantities[service.id] ?? 1}',
            )
            .toList()
          ..sort();
    final packagePart =
        packages.map((purchase) {
            final buffer =
                StringBuffer(purchase.item.referenceId)
                  ..write(':')
                  ..write(purchase.effectiveRemainingSessions);
            for (final service in selectedServices) {
              buffer
                ..write(':')
                ..write(service.id)
                ..write('=')
                ..write(purchase.remainingSessionsForService(service.id));
            }
            return buffer.toString();
          }).toList()
          ..sort();
    return [
      _clientId ?? '',
      servicePart.join(','),
      packagePart.join(','),
    ].join('|');
  }

  String? _suggestedPackageForService(String serviceId) {
    final suggestion = _latestSuggestion;
    if (suggestion == null) {
      return null;
    }
    final allocation = suggestion.allocations.firstWhereOrNull(
      (item) => item.serviceId == serviceId,
    );
    if (allocation == null || allocation.packageConsumptions.isEmpty) {
      return null;
    }
    final consumption = allocation.packageConsumptions.first;
    final packageId = consumption.packageReferenceId;
    return packageId.isNotEmpty ? packageId : null;
  }

  List<AppointmentServiceAllocation> _buildServiceAllocations() {
    final allocations = <AppointmentServiceAllocation>[];
    for (final serviceId in _serviceIds) {
      final quantity = _serviceQuantities[serviceId] ?? 1;
      final packageId = _servicePackageSelections[serviceId];
      final consumptions = <AppointmentPackageConsumption>[];
      if (packageId != null && packageId.isNotEmpty) {
        consumptions.add(
          AppointmentPackageConsumption(
            packageReferenceId: packageId,
            quantity: quantity,
          ),
        );
      }
      final adjustmentMinutes =
          _serviceDurationAdjustments[serviceId]?.inMinutes ?? 0;
      allocations.add(
        AppointmentServiceAllocation(
          serviceId: serviceId,
          quantity: quantity,
          packageConsumptions: consumptions,
          durationAdjustmentMinutes: adjustmentMinutes,
        ),
      );
    }
    return allocations;
  }

  List<ClientPackagePurchase> _dedupePurchasesByReferenceId(
    List<ClientPackagePurchase> purchases,
  ) {
    final seen = <String>{};
    final unique = <ClientPackagePurchase>[];
    for (final purchase in purchases) {
      final referenceId = purchase.item.referenceId;
      if (seen.add(referenceId)) {
        unique.add(purchase);
      }
    }
    return unique;
  }

  IconData _statusIcon(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return Icons.event_available_rounded;
      case AppointmentStatus.completed:
        return Icons.check_circle_rounded;
      case AppointmentStatus.cancelled:
        return Icons.cancel_rounded;
      case AppointmentStatus.noShow:
        return Icons.report_problem_rounded;
    }
  }

  Color _statusColor(ColorScheme scheme, AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return scheme.primary;
      case AppointmentStatus.completed:
        return scheme.tertiary;
      case AppointmentStatus.cancelled:
        return scheme.onSurfaceVariant;
      case AppointmentStatus.noShow:
        return scheme.error.withAlpha(180);
    }
  }

  String _statusLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return 'Programmato';
      case AppointmentStatus.completed:
        return 'Completato';
      case AppointmentStatus.cancelled:
        return 'Annullato';
      case AppointmentStatus.noShow:
        return 'No show';
    }
  }
}

class _ClientPackageSummaryList extends StatelessWidget {
  const _ClientPackageSummaryList({required this.packages});

  final List<ClientPackagePurchase> packages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...packages.map((purchase) {
          final subtitleSegments = <String>[];
          final remaining = purchase.effectiveRemainingSessions;
          subtitleSegments.add(
            remaining == 1
                ? '1 sessione disponibile'
                : '$remaining sessioni disponibili',
          );
          final expiration = purchase.expirationDate;
          if (expiration != null) {
            subtitleSegments.add('Scadenza ${dateFormat.format(expiration)}');
          }
          final services =
              purchase.serviceNames.where((name) => name.isNotEmpty).toList();
          if (services.isNotEmpty) {
            const maxVisibleServices = 2;
            final visibleServices = services
                .take(maxVisibleServices)
                .join(', ');
            final remainingCount = services.length - maxVisibleServices;
            final servicesLabel =
                remainingCount > 0
                    ? "$visibleServices ${remainingCount == 1 ? 'e un altro servizio' : 'e altri $remainingCount servizi'}"
                    : visibleServices;
            subtitleSegments.add('Copre: $servicesLabel');
          }
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                Icons.card_membership_rounded,
                color: colorScheme.primary,
              ),
              title: Text(purchase.displayName),
              subtitle: Text(subtitleSegments.join(' • ')),
              dense: true,
            ),
          );
        }),
      ],
    );
  }
}

class _ServicePackageSelector extends StatelessWidget {
  const _ServicePackageSelector({
    required this.service,
    required this.packages,
    required this.selectedPackageId,
    required this.suggestedPackageId,
    required this.uncoveredQuantity,
    required this.onSelect,
  });

  final Service service;
  final List<ClientPackagePurchase> packages;
  final String? selectedPackageId;
  final String? suggestedPackageId;
  final int uncoveredQuantity;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (uncoveredQuantity > 0)
                  Chip(
                    label: Text('$uncoveredQuantity fuori pacchetto'),
                    backgroundColor: colorScheme.errorContainer,
                    labelStyle: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (packages.isEmpty)
              Text(
                'Nessun pacchetto compatibile.',
                style: theme.textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...packages.map((purchase) {
                    final packageId = purchase.item.referenceId;
                    final remaining = purchase.remainingSessionsForService(
                      service.id,
                    );
                    final enabled = remaining > 0;
                    final isSelected = selectedPackageId == packageId;
                    final isSuggested = suggestedPackageId == packageId;
                    final expiration = purchase.expirationDate;
                    final detailsBuffer = StringBuffer(
                      '$remaining sessioni disponibili',
                    );
                    if (expiration != null) {
                      detailsBuffer
                        ..write(' • Scade il ')
                        ..write(DateFormat('dd/MM/yyyy').format(expiration));
                    }
                    return _PackageSelectionCard(
                      title: purchase.displayName,
                      subtitle: detailsBuffer.toString(),
                      selected: isSelected,
                      enabled: enabled || isSelected,
                      recommended: isSuggested,
                      onTap:
                          enabled || isSelected
                              ? () => onSelect(isSelected ? null : packageId)
                              : null,
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PackageSelectionCard extends StatelessWidget {
  const _PackageSelectionCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.recommended = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor =
        selected
            ? colorScheme.primary
            : colorScheme.outlineVariant.withValues(alpha: 0.4);
    final backgroundColor =
        selected
            ? colorScheme.primary.withValues(alpha: 0.08)
            : colorScheme.surfaceContainerLowest;
    final foregroundColor =
        enabled
            ? colorScheme.onSurface
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minWidth: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color:
                    enabled
                        ? (selected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant)
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foregroundColor,
                      ),
                    ),
                    if (recommended && !selected)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Suggerito',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                          ),
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

class _TimelineInfoBox extends StatelessWidget {
  const _TimelineInfoBox({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline.withValues(alpha: 0.5);
    final valueStyle = theme.textTheme.titleMedium;
    final Widget valueContent =
        trailing == null
            ? Text(value, style: valueStyle)
            : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Text(value, style: valueStyle)),
                const SizedBox(width: 8),
                trailing!,
              ],
            );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          valueContent,
        ],
      ),
    );
  }
}

class _AvailableSlot {
  const _AvailableSlot({
    required this.start,
    required this.end,
    required this.shiftId,
  });

  final DateTime start;
  final DateTime end;
  final String shiftId;
}

class _TimeRange {
  _TimeRange({required this.start, required this.end})
    : assert(!end.isBefore(start), 'end must be after start');

  final DateTime start;
  final DateTime end;

  bool overlaps(_TimeRange other) {
    return start.isBefore(other.end) && end.isAfter(other.start);
  }

  List<_TimeRange> subtract(_TimeRange other) {
    if (!overlaps(other)) {
      return [this];
    }
    final ranges = <_TimeRange>[];
    if (other.start.isAfter(start)) {
      ranges.add(_TimeRange(start: start, end: other.start));
    }
    if (other.end.isBefore(end)) {
      ranges.add(_TimeRange(start: other.end, end: end));
    }
    return ranges;
  }

  _TimeRange? trim({required DateTime from}) {
    if (end.isBefore(from)) {
      return null;
    }
    final boundedStart = start.isBefore(from) ? from : start;
    return _TimeRange(start: boundedStart, end: end);
  }
}

class _ZoneCategoryData {
  const _ZoneCategoryData({required this.category, required this.entries});

  final ServiceCategory category;
  final List<_ZoneServiceEntry> entries;
}

class _ZoneServiceEntry {
  const _ZoneServiceEntry({required this.zone, required this.service});

  final BodyZoneDefinition zone;
  final Service service;
}

class _BodyZoneMapCanvas extends StatelessWidget {
  const _BodyZoneMapCanvas({
    required this.entries,
    required this.selectedServiceIds,
    required this.onToggle,
  });

  final List<_ZoneServiceEntry> entries;
  final Set<String> selectedServiceIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final hit = _hitTest(details.localPosition, size);
            if (hit != null) {
              onToggle(hit.service.id);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              SvgPicture.asset('assets/4SlqSS01-2.svg', fit: BoxFit.cover),
              Center(
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: bodyZonesCanvasSize.width,
                    height: bodyZonesCanvasSize.height,
                    child: CustomPaint(
                      painter: _BodyZoneOverlayPainter(
                        entries: entries,
                        selectedServiceIds: selectedServiceIds,
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

  _ZoneServiceEntry? _hitTest(Offset position, Size renderSize) {
    final scaleX = renderSize.width / bodyZonesCanvasSize.width;
    final scaleY = renderSize.height / bodyZonesCanvasSize.height;
    final normalized = Offset(position.dx / scaleX, position.dy / scaleY);
    for (final entry in entries) {
      if (entry.zone.path.contains(normalized) ||
          entry.zone.bounds.inflate(12).contains(normalized)) {
        return entry;
      }
    }
    return null;
  }
}

class _BodyZoneOverlayPainter extends CustomPainter {
  _BodyZoneOverlayPainter({
    required this.entries,
    required this.selectedServiceIds,
  });

  final List<_ZoneServiceEntry> entries;
  final Set<String> selectedServiceIds;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / bodyZonesCanvasSize.width;
    final scaleY = size.height / bodyZonesCanvasSize.height;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    final baseFill =
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.transparent;
    final selectedFill =
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.transparent; //civi hook color
    for (final entry in entries) {
      final isSelected = selectedServiceIds.contains(entry.service.id);
      final path = entry.zone.path;
      canvas.drawPath(path, isSelected ? selectedFill : baseFill);
    }
    canvas.restore();

    for (final entry in entries) {
      if (!selectedServiceIds.contains(entry.service.id)) {
        continue;
      }
      final center = entry.zone.bounds.center.scale(scaleX, scaleY);
      canvas.drawCircle(center, 24, Paint()..color = const Color(0xFFB71C1C));
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '✓',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BodyZoneOverlayPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.selectedServiceIds != selectedServiceIds;
  }
}
