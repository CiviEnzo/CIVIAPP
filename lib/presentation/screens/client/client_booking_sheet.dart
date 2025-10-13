import 'dart:async';

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/data/repositories/app_data_state.dart';
import 'package:civiapp/domain/availability/appointment_conflicts.dart';
import 'package:civiapp/domain/availability/equipment_availability.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/last_minute_slot.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/service_category.dart';
import 'package:civiapp/domain/entities/shift.dart';
import 'package:civiapp/domain/entities/staff_absence.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/presentation/shared/client_package_purchase.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'client_theme.dart';

class ClientBookingSheet extends ConsumerStatefulWidget {
  const ClientBookingSheet({
    super.key,
    required this.client,
    this.initialServiceId,
    this.initialAppointment,
    this.lastMinuteSlot,
  });

  final Client client;
  final String? initialServiceId;
  final Appointment? initialAppointment;
  final LastMinuteSlot? lastMinuteSlot;

  static Future<Appointment?> show(
    BuildContext context, {
    required Client client,
    Service? preselectedService,
    Appointment? existingAppointment,
    LastMinuteSlot? lastMinuteSlot,
  }) {
    return showAppModalSheet<Appointment>(
      context: context,
      builder:
          (ctx) => ClientBookingSheet(
            client: client,
            initialServiceId: preselectedService?.id,
            initialAppointment: existingAppointment,
            lastMinuteSlot: lastMinuteSlot,
          ),
    );
  }

  @override
  ConsumerState<ClientBookingSheet> createState() => _ClientBookingSheetState();
}

class _ServiceBookingSelection {
  _ServiceBookingSelection({
    this.categoryId,
    List<String> serviceIds = const <String>[],
    this.staffId,
    this.start,
    this.end,
    this.usePackageSession = false,
    this.packageId,
  }) : serviceIds = List.unmodifiable(serviceIds);

  final String? categoryId;
  final List<String> serviceIds;
  final String? staffId;
  final DateTime? start;
  final DateTime? end;
  final bool usePackageSession;
  final String? packageId;

  String get primaryServiceId => serviceIds.isNotEmpty ? serviceIds.first : '';
  bool get hasServices => serviceIds.isNotEmpty;
  bool get hasScheduledSlot => start != null && end != null;

  _ServiceBookingSelection copyWith({
    String? categoryId,
    List<String>? serviceIds,
    String? staffId,
    DateTime? start,
    DateTime? end,
    bool? usePackageSession,
    String? packageId,
  }) {
    return _ServiceBookingSelection(
      categoryId: categoryId ?? this.categoryId,
      serviceIds:
          serviceIds != null
              ? List<String>.unmodifiable(serviceIds)
              : this.serviceIds,
      staffId: staffId ?? this.staffId,
      start: start ?? this.start,
      end: end ?? this.end,
      usePackageSession: usePackageSession ?? this.usePackageSession,
      packageId: packageId ?? this.packageId,
    );
  }
}

enum _BookingStep { category, services, date, availability, summary }

class _ClientBookingSheetState extends ConsumerState<ClientBookingSheet> {
  static const _slotIntervalMinutes = 15;
  static const String _uncategorizedCategoryId = 'uncategorized';
  static const ListEquality<String> _listEquality = ListEquality<String>();
  final _uuid = const Uuid();
  final DateFormat _dayLabel = DateFormat('EEE d MMM', 'it_IT');
  final DateFormat _timeLabel = DateFormat('HH:mm', 'it_IT');
  _BookingStep _currentStep = _BookingStep.category;
  String? _selectedCategoryId;
  DateTime? _selectedDay;
  bool _isSubmitting = false;
  bool _packageSelectionManuallyChanged = false;
  String? _selectedServiceId;
  String? _selectedStaffId;
  String? _staffFilterId;
  DateTime? _selectedSlotStart;
  bool _usePackageSession = false;
  String? _selectedPackageId;
  List<_ServiceBookingSelection> _selections = <_ServiceBookingSelection>[];
  int _activeSelectionIndex = 0;
  Map<String, Service> _servicesById = const {};
  Timer? _countdownTimer;
  Duration _remainingCountdown = Duration.zero;
  LastMinuteSlot? _expressSlot;

  bool get _isLastMinuteExpress => _expressSlot != null;
  bool get _isCountdownExpired =>
      _isLastMinuteExpress && _remainingCountdown <= Duration.zero;

  @override
  void initState() {
    super.initState();
    final slot = widget.lastMinuteSlot;
    if (slot != null) {
      _expressSlot = slot;
      _initializeExpressBooking(slot);
      return;
    }

    final appointment = widget.initialAppointment;
    final initialServiceIds = <String>[];
    if (appointment != null) {
      initialServiceIds.addAll(appointment.serviceIds);
      if (initialServiceIds.isNotEmpty) {
        _selectedServiceId = initialServiceIds.first;
      }
    } else if (widget.initialServiceId != null &&
        widget.initialServiceId!.isNotEmpty) {
      initialServiceIds.add(widget.initialServiceId!);
      _selectedServiceId = widget.initialServiceId;
    }
    _selectedStaffId = appointment?.staffId;
    if (appointment != null) {
      _currentStep = _BookingStep.availability;
    } else if (_selectedServiceId != null && _selectedServiceId!.isNotEmpty) {
      _currentStep = _BookingStep.services;
    } else {
      _currentStep = _BookingStep.category;
    }
    if (appointment != null) {
      _selectedDay = _dayFrom(appointment.start);
      _selectedSlotStart = appointment.start;
      _usePackageSession = appointment.packageId != null;
      _selectedPackageId = appointment.packageId;
    }
    _staffFilterId = _selectedStaffId;
    _selections = [
      _ServiceBookingSelection(
        categoryId: null,
        serviceIds: initialServiceIds,
        staffId: _selectedStaffId,
        start: _selectedSlotStart,
        end: appointment?.end,
        usePackageSession: _usePackageSession,
        packageId: _selectedPackageId,
      ),
    ];
    _activeSelectionIndex = 0;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _initializeExpressBooking(LastMinuteSlot slot) {
    _expressSlot = slot;
    final end = slot.end;
    final serviceId =
        slot.serviceId != null && slot.serviceId!.isNotEmpty
            ? slot.serviceId
            : null;
    _selectedServiceId = serviceId;
    _selectedStaffId = slot.operatorId;
    _staffFilterId = slot.operatorId;
    _selectedSlotStart = slot.start;
    _selectedDay = _dayFrom(slot.start);
    _usePackageSession = false;
    _selectedPackageId = null;
    _selections = [
      _ServiceBookingSelection(
        categoryId: null,
        serviceIds: serviceId != null ? <String>[serviceId] : const <String>[],
        staffId: slot.operatorId,
        start: slot.start,
        end: end,
        usePackageSession: false,
        packageId: null,
      ),
    ];
    _activeSelectionIndex = 0;
    _currentStep =
        serviceId != null ? _BookingStep.summary : _BookingStep.services;
    _remainingCountdown = _safeCountdown(slot.start);
    _startCountdown();
  }

  void _startCountdown() {
    final slot = _expressSlot;
    if (slot == null) {
      return;
    }
    _countdownTimer?.cancel();
    void update() {
      if (!mounted) {
        _countdownTimer?.cancel();
        return;
      }
      final remaining = _safeCountdown(slot.start);
      setState(() => _remainingCountdown = remaining);
      if (remaining <= Duration.zero) {
        _countdownTimer?.cancel();
      }
    }

    update();
    if (_remainingCountdown > Duration.zero) {
      _countdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => update(),
      );
    }
  }

  Duration _safeCountdown(DateTime target) {
    final remaining = target.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final salon = data.salons.firstWhereOrNull(
      (item) => item.id == widget.client.salonId,
    );
    final initialServiceId =
        widget.initialServiceId ?? widget.initialAppointment?.serviceId;
    final services =
        data.services.where((service) {
            if (service.salonId != widget.client.salonId) {
              return false;
            }
            if (service.isActive) {
              return true;
            }
            return initialServiceId != null && service.id == initialServiceId;
          }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    if (services.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Nessun servizio disponibile per la prenotazione.'),
      );
    }

    final bookingCategories = _composeBookingCategories(
      services: services,
      categories: data.serviceCategories,
      salonId: widget.client.salonId,
    );

    final serviceById = {for (final service in services) service.id: service};
    _servicesById = serviceById;

    final activeSelection =
        _selections.isNotEmpty ? _selections[_activeSelectionIndex] : null;
    final currentCategoryId =
        _selectedCategoryId ?? activeSelection?.categoryId;
    final selectedCategory = bookingCategories.firstWhereOrNull(
      (item) => item.id == currentCategoryId,
    );
    final visibleServices = selectedCategory?.services ?? const <Service>[];

    final selectedServiceIds = activeSelection?.serviceIds ?? const <String>[];
    final selectedServices =
        selectedServiceIds.map((id) => serviceById[id]).whereNotNull().toList();

    if (selectedServices.isNotEmpty && currentCategoryId == null) {
      final primaryService = selectedServices.first;
      final matchingCategory = bookingCategories.firstWhereOrNull(
        (category) =>
            category.services.any((service) => service.id == primaryService.id),
      );
      if (matchingCategory != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _selectedCategoryId = matchingCategory.id;
            if (_selections.isNotEmpty &&
                _activeSelectionIndex < _selections.length) {
              final selection = _selections[_activeSelectionIndex];
              _selections[_activeSelectionIndex] = selection.copyWith(
                categoryId: matchingCategory.id,
              );
            }
          });
        });
      }
    }

    if (selectedServices.isNotEmpty) {
      final primaryId = selectedServices.first.id;
      if (_selectedServiceId != primaryId) {
        _selectedServiceId = primaryId;
      }
    } else {
      _selectedServiceId = null;
    }

    if (_selectedCategoryId == null && activeSelection?.categoryId != null) {
      _selectedCategoryId = activeSelection!.categoryId;
    }

    if (activeSelection != null &&
        selectedCategory != null &&
        activeSelection.categoryId != selectedCategory.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          final updated = activeSelection.copyWith(
            categoryId: selectedCategory.id,
          );
          _selections[_activeSelectionIndex] = updated;
          _selectedCategoryId = selectedCategory.id;
        });
      });
    }

    final staff =
        selectedServices.isNotEmpty
            ? _availableStaff(data: data, services: selectedServices)
            : const <StaffMember>[];

    if (_staffFilterId != null &&
        staff.every((member) => member.id != _staffFilterId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _staffFilterId = null;
        });
      });
    }

    if (_selectedStaffId != null &&
        staff.every((member) => member.id != _selectedStaffId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedStaffId = null;
          _selectedSlotStart = null;
        });
      });
    }

    final availabilityByStaff = <String, Map<DateTime, List<_AvailableSlot>>>{};
    if (selectedServices.isNotEmpty) {
      for (final member in staff) {
        availabilityByStaff[member.id] = _computeAvailability(
          data: data,
          services: selectedServices,
          staffId: member.id,
        );
      }
    }
    final combinedAvailability = _combineAvailability(availabilityByStaff);

    if (_selectedSlotStart != null && !_isLastMinuteExpress) {
      final slotStillAvailable = availabilityByStaff.entries.any((entry) {
        if (_selectedStaffId != null && entry.key != _selectedStaffId) {
          return false;
        }
        return entry.value.entries.any(
          (item) => item.value.any((slot) => slot.start == _selectedSlotStart),
        );
      });
      if (!slotStillAvailable) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _selectedSlotStart = null;
            _selectedStaffId = null;
          });
        });
      }
    }

    final visibleAppointments = _visibleAppointments(
      data,
      excludeAppointmentId: widget.initialAppointment?.id,
    );

    final packagePurchases = resolveClientPackagePurchases(
      sales: data.sales,
      packages: data.packages,
      appointments: visibleAppointments,
      services: data.services,
      clientId: widget.client.id,
      salonId: widget.client.salonId,
    );

    final List<ClientPackagePurchase> packagesForService;
    if (selectedServices.length == 1) {
      final serviceId = selectedServices.first.id;
      packagesForService = _dedupePurchasesByReferenceId(
        packagePurchases
            .where(
              (purchase) =>
                  purchase.isActive &&
                  purchase.supportsService(serviceId) &&
                  purchase.effectiveRemainingSessions > 0,
            )
            .toList()
          ..sort((a, b) {
            final aExpiration = a.expirationDate ?? DateTime(9999, 1, 1);
            final bExpiration = b.expirationDate ?? DateTime(9999, 1, 1);
            final expirationCompare = aExpiration.compareTo(bExpiration);
            if (expirationCompare != 0) {
              return expirationCompare;
            }
            return a.sale.createdAt.compareTo(b.sale.createdAt);
          }),
      );
    } else {
      packagesForService = const <ClientPackagePurchase>[];
      if (_usePackageSession && !_packageSelectionManuallyChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _usePackageSession = false;
            _selectedPackageId = null;
            _packageSelectionManuallyChanged = false;
          });
        });
      }
    }

    ClientPackagePurchase? selectedPackage;
    String? packageSubtitle;

    if (packagesForService.isNotEmpty) {
      if (!_usePackageSession && !_packageSelectionManuallyChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _usePackageSession = true;
            _selectedPackageId = packagesForService.first.item.referenceId;
          });
        });
      }

      if (_usePackageSession) {
        final availableIds =
            packagesForService
                .map((purchase) => purchase.item.referenceId)
                .toSet();
        if (!availableIds.contains(_selectedPackageId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              if (packagesForService.isEmpty) {
                _usePackageSession = false;
                _selectedPackageId = null;
                _packageSelectionManuallyChanged = false;
              } else {
                _selectedPackageId = packagesForService.first.item.referenceId;
              }
            });
          });
        }
      }

      for (final purchase in packagesForService) {
        if (purchase.item.referenceId == _selectedPackageId) {
          selectedPackage = purchase;
          break;
        }
      }
      selectedPackage ??= packagesForService.first;

      if (_usePackageSession) {
        packageSubtitle =
            '${selectedPackage.displayName} • ${selectedPackage.effectiveRemainingSessions} sessioni disponibili';
      } else {
        if (packagesForService.length == 1) {
          final preview = packagesForService.first;
          packageSubtitle =
              '${preview.displayName} • ${preview.effectiveRemainingSessions} sessioni disponibili';
        } else {
          packageSubtitle =
              '${packagesForService.length} pacchetti disponibili per questo servizio';
        }
      }
    } else if (_usePackageSession && !_packageSelectionManuallyChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _usePackageSession = false;
          _selectedPackageId = null;
        });
      });
    }

    final selectedDayKey =
        _selectedDay != null ? _dayFrom(_selectedDay!) : null;

    final selectedDayClosures =
        selectedDayKey == null
            ? const <SalonClosure>[]
            : _findOverlappingClosures(
              closures: salon?.closures ?? const <SalonClosure>[],
              start: selectedDayKey,
              end: selectedDayKey.add(const Duration(days: 1)),
            );

    final availabilityForSuggestions =
        _staffFilterId != null && _staffFilterId!.isNotEmpty
            ? (availabilityByStaff[_staffFilterId!] ?? const {})
            : combinedAvailability;

    final suggestions =
        selectedDayKey != null
            ? _nextAvailableSuggestions(
              availability: availabilityForSuggestions,
              selectedDay: selectedDayKey,
            )
            : const <_DaySuggestion>[];
    final hasAnyAvailability = availabilityForSuggestions.isNotEmpty;

    final staffByIdMap = {
      for (final member in data.staff.where(
        (item) => item.salonId == widget.client.salonId,
      ))
        member.id: member,
    };

    final showSelectionNavigator = _selections.isNotEmpty;

    final themedData = ClientTheme.resolve(Theme.of(context));

    return Theme(
      data: themedData,
      child: Builder(
        builder: (themeContext) {
          final theme = Theme.of(themeContext);
          final bottomPadding =
              16.0 + MediaQuery.of(themeContext).viewInsets.bottom;

          final stepContent = _buildStepContent(
            theme: theme,
            bookingCategories: bookingCategories,
            selectedCategory: selectedCategory,
            visibleServices: visibleServices,
            serviceById: serviceById,
            selectedServices: selectedServices,
            salon: salon,
            staff: staff,
            staffById: staffByIdMap,
            availabilityByStaff: availabilityByStaff,
            combinedAvailability: combinedAvailability,
            selectedDayClosures: selectedDayClosures,
            suggestions: suggestions,
            hasAnyAvailability: hasAnyAvailability,
            packagesForService: packagesForService,
            selectedPackage: selectedPackage,
            packageSubtitle: packageSubtitle,
          );

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prenota un appuntamento',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Scegli il tuo trattamento',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildProgressHeader(theme),
                  if (showSelectionNavigator) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Servizi in prenotazione',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildSelectionNavigator(
                      theme: theme,
                      serviceById: serviceById,
                    ),
                  ],
                  const SizedBox(height: 24),
                  stepContent,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressHeader(ThemeData theme) {
    const labels = <String>[
      'Categoria',
      'Servizi',
      'Giorno',
      'Orario',
      'Riepilogo',
    ];
    final items = <Widget>[];
    for (var index = 0; index < labels.length; index++) {
      final step = _BookingStep.values[index];
      final isActive = _currentStep == step;
      final isCompleted = _currentStep.index > step.index;
      final baseColor = theme.colorScheme.primary;
      final backgroundColor =
          isActive
              ? baseColor
              : isCompleted
              ? baseColor.withOpacity(0.2)
              : theme.colorScheme.surfaceVariant;
      final foregroundColor =
          isActive
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant;
      items.add(
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                child: Text('${index + 1}'),
              ),
              const SizedBox(height: 6),
              Text(
                labels[index],
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color:
                      isActive ? baseColor : theme.textTheme.labelMedium?.color,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Row(children: items);
  }

  Widget _buildSelectionNavigator({
    required ThemeData theme,
    required Map<String, Service> serviceById,
  }) {
    if (_selections.isEmpty) {
      return const SizedBox.shrink();
    }
    final chips = <Widget>[];
    for (var index = 0; index < _selections.length; index++) {
      final label = _selectionLabel(index, serviceById);
      chips.add(
        InputChip(
          label: Text(label),
          selected: index == _activeSelectionIndex,
          selectedColor: theme.colorScheme.primary.withOpacity(0.12),
          onPressed: () => _beginEditingSelection(index),
          onDeleted:
              _selections.length > 1 ? () => _removeSelectionAt(index) : null,
          deleteIcon:
              _selections.length > 1 ? const Icon(Icons.close_rounded) : null,
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _buildStepContent({
    required ThemeData theme,
    required List<_BookingCategory> bookingCategories,
    required _BookingCategory? selectedCategory,
    required List<Service> visibleServices,
    required Map<String, Service> serviceById,
    required List<Service> selectedServices,
    required Salon? salon,
    required List<StaffMember> staff,
    required Map<String, StaffMember> staffById,
    required Map<String, Map<DateTime, List<_AvailableSlot>>>
    availabilityByStaff,
    required Map<DateTime, List<_AvailableSlot>> combinedAvailability,
    required List<SalonClosure> selectedDayClosures,
    required List<_DaySuggestion> suggestions,
    required bool hasAnyAvailability,
    required List<ClientPackagePurchase> packagesForService,
    ClientPackagePurchase? selectedPackage,
    String? packageSubtitle,
  }) {
    switch (_currentStep) {
      case _BookingStep.category:
        return _buildCategoryStep(
          theme: theme,
          bookingCategories: bookingCategories,
        );
      case _BookingStep.services:
        return _buildServicesStep(
          theme: theme,
          bookingCategories: bookingCategories,
          selectedCategory: selectedCategory,
          visibleServices: visibleServices,
        );
      case _BookingStep.date:
        return _buildDateStep(theme: theme);
      case _BookingStep.availability:
        return _buildAvailabilityStep(
          theme: theme,
          selectedServices: selectedServices,
          staff: staff,
          staffById: staffById,
          availabilityByStaff: availabilityByStaff,
          combinedAvailability: combinedAvailability,
          selectedDayClosures: selectedDayClosures,
          suggestions: suggestions,
          hasAnyAvailability: hasAnyAvailability,
          packagesForService: packagesForService,
          selectedPackage: selectedPackage,
          packageSubtitle: packageSubtitle,
        );
      case _BookingStep.summary:
        return _buildSummaryStep(
          theme: theme,
          serviceById: serviceById,
          staffById: staffById,
        );
    }
  }

  Widget _buildCategoryStep({
    required ThemeData theme,
    required List<_BookingCategory> bookingCategories,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Step 1 · Categoria', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (bookingCategories.isEmpty)
          const Text('Nessuna categoria disponibile.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                bookingCategories
                    .map(
                      (category) => ChoiceChip(
                        label: Text(category.label),
                        selected: category.id == _selectedCategoryId,
                        onSelected: (selected) {
                          if (!selected) return;
                          setState(() {
                            _selectedCategoryId = category.id;
                            _selectedServiceId = null;
                            _selectedStaffId = null;
                            _staffFilterId = null;
                            _selectedDay = null;
                            _selectedSlotStart = null;
                            _usePackageSession = false;
                            _selectedPackageId = null;
                            _packageSelectionManuallyChanged = false;
                            _updateActiveSelection(
                              (current) => current.copyWith(
                                categoryId: category.id,
                                serviceIds: const <String>[],
                                staffId: null,
                                start: null,
                                end: null,
                                usePackageSession: false,
                                packageId: null,
                              ),
                            );
                          });
                        },
                      ),
                    )
                    .toList(),
          ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed:
                _selectedCategoryId != null
                    ? () => _goToStep(_BookingStep.services)
                    : null,
            child: const Text('Continua'),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesStep({
    required ThemeData theme,
    required List<_BookingCategory> bookingCategories,
    required _BookingCategory? selectedCategory,
    required List<Service> visibleServices,
  }) {
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final activeSelection =
        _selections.isNotEmpty ? _selections[_activeSelectionIndex] : null;
    if (_selectedCategoryId == null && activeSelection?.categoryId != null) {
      _selectedCategoryId = activeSelection!.categoryId;
    }
    final selectedIdsInCategory =
        activeSelection == null
            ? <String>{}
            : activeSelection.serviceIds
                .where(
                  (id) => visibleServices.any((service) => service.id == id),
                )
                .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Step 2 · Servizi', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (_selectedCategoryId == null)
          const Text('Seleziona prima una categoria per continuare.')
        else if (visibleServices.isEmpty)
          const Text('Nessun servizio disponibile per questa categoria.')
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...visibleServices.map((service) {
                final isSelected = selectedIdsInCategory.contains(service.id);
                final durationLabel = _formatDuration(service.totalDuration);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (checked) {
                      _toggleServiceSelection(
                        service: service,
                        isSelected: checked ?? false,
                      );
                    },
                    title: Text(service.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Durata $durationLabel'),
                        Text(currency.format(service.price)),
                        if (service.description != null &&
                            service.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              service.description!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  selectedIdsInCategory.isEmpty
                      ? 'Seleziona uno o più servizi per continuare.'
                      : 'Hai selezionato ${selectedIdsInCategory.length} '
                          '${selectedIdsInCategory.length == 1 ? 'servizio' : 'servizi'} in questa categoria.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => _goToStep(_BookingStep.category),
              child: const Text('Indietro'),
            ),
            FilledButton(
              onPressed:
                  selectedIdsInCategory.isNotEmpty
                      ? () => _goToStep(_BookingStep.date)
                      : null,
              child: const Text('Continua'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateStep({required ThemeData theme}) {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final horizon = DateTime(
      now.year,
      now.month + 3,
      now.day,
    ).add(const Duration(days: 1));
    final lastDate = horizon.subtract(const Duration(days: 1));
    final initialDate = _selectedDay ?? firstDate;
    final adjustedInitial =
        initialDate.isBefore(firstDate)
            ? firstDate
            : initialDate.isAfter(lastDate)
            ? lastDate
            : initialDate;
    final activeSelection =
        _selections.isNotEmpty ? _selections[_activeSelectionIndex] : null;
    final hasServicesSelected =
        activeSelection != null && activeSelection.serviceIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Step 3 · Data', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (!hasServicesSelected)
          const Text('Seleziona almeno un servizio per scegliere una data.')
        else ...[
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: CalendarDatePicker(
              initialDate: adjustedInitial,
              firstDate: firstDate,
              lastDate: lastDate,
              onDateChanged: _onDateSelected,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedDay != null
                ? 'Data selezionata: ${_capitalize(_dayLabel.format(_selectedDay!))}'
                : 'Nessuna data selezionata',
            style: theme.textTheme.bodyMedium,
          ),
        ],
        if (hasServicesSelected)
          const SizedBox(height: 24)
        else
          const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => _goToStep(_BookingStep.date),
              child: const Text('Indietro'),
            ),
            FilledButton(
              onPressed:
                  hasServicesSelected && _selectedDay != null
                      ? () => _goToStep(_BookingStep.availability)
                      : null,
              child: const Text('Continua'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailabilityStep({
    required ThemeData theme,
    required List<Service> selectedServices,
    required List<StaffMember> staff,
    required Map<String, StaffMember> staffById,
    required Map<String, Map<DateTime, List<_AvailableSlot>>>
    availabilityByStaff,
    required Map<DateTime, List<_AvailableSlot>> combinedAvailability,
    required List<SalonClosure> selectedDayClosures,
    required List<_DaySuggestion> suggestions,
    required bool hasAnyAvailability,
    required List<ClientPackagePurchase> packagesForService,
    ClientPackagePurchase? selectedPackage,
    String? packageSubtitle,
  }) {
    if (selectedServices.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 4 · Disponibilita\'', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const Text(
            'Seleziona almeno un servizio per vedere le disponibilita\'.',
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => _goToStep(_BookingStep.services),
            child: const Text('Torna allo step precedente'),
          ),
        ],
      );
    }

    final selectedDay = _selectedDay;
    final selectedDayKey = selectedDay != null ? _dayFrom(selectedDay) : null;
    final availabilityForFilter =
        _staffFilterId != null && _staffFilterId!.isNotEmpty
            ? availabilityByStaff[_staffFilterId!] ?? const {}
            : combinedAvailability;
    final slotsForDay =
        selectedDayKey != null
            ? availabilityForFilter[selectedDayKey] ?? const <_AvailableSlot>[]
            : const <_AvailableSlot>[];

    final packageWidgets = <Widget>[];
    if (packagesForService.isNotEmpty) {
      packageWidgets
        ..add(Text('Sessioni pacchetto', style: theme.textTheme.titleMedium))
        ..add(const SizedBox(height: 8))
        ..add(
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _usePackageSession,
            onChanged: (checked) {
              setState(() {
                _packageSelectionManuallyChanged = true;
                _usePackageSession = checked ?? false;
                if (_usePackageSession) {
                  _selectedPackageId =
                      selectedPackage?.item.referenceId ??
                      packagesForService.first.item.referenceId;
                } else {
                  _selectedPackageId = null;
                }
                _updateActiveSelection(
                  (current) => current.copyWith(
                    usePackageSession: _usePackageSession,
                    packageId: _selectedPackageId,
                  ),
                );
              });
            },
            title: const Text('Scala una sessione da un pacchetto'),
            subtitle: packageSubtitle != null ? Text(packageSubtitle) : null,
          ),
        );
      if (_usePackageSession && packagesForService.length > 1) {
        packageWidgets
          ..add(const SizedBox(height: 12))
          ..add(
            DropdownButtonFormField<String>(
              value: _selectedPackageId,
              decoration: const InputDecoration(
                labelText: 'Seleziona il pacchetto',
              ),
              items:
                  packagesForService
                      .map(
                        (purchase) => DropdownMenuItem(
                          value: purchase.item.referenceId,
                          child: Text(
                            '${purchase.displayName} • ${purchase.effectiveRemainingSessions} sessioni',
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPackageId = value;
                  _updateActiveSelection(
                    (current) => current.copyWith(packageId: value),
                  );
                });
              },
            ),
          );
      }
      packageWidgets.add(const SizedBox(height: 16));
    }

    final operatorWidgets = <Widget>[];
    if (staff.isNotEmpty) {
      operatorWidgets
        ..add(Text('Operatore', style: theme.textTheme.titleMedium))
        ..add(const SizedBox(height: 8))
        ..add(
          DropdownButtonFormField<String?>(
            value: _staffFilterId,
            decoration: const InputDecoration(
              labelText: 'Filtra per operatore (opzionale)',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Tutti gli operatori'),
              ),
              ...staff.map(
                (member) => DropdownMenuItem<String?>(
                  value: member.id,
                  child: Text(member.fullName),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _staffFilterId = value;
                if (value == null) {
                  _selectedStaffId = null;
                  _selectedSlotStart = null;
                } else if (value != _selectedStaffId) {
                  _selectedStaffId = null;
                  _selectedSlotStart = null;
                }
              });
            },
          ),
        );
      operatorWidgets.add(const SizedBox(height: 16));
    }

    final availabilityWidgets = <Widget>[];
    availabilityWidgets.add(
      Text('Disponibilita\'', style: theme.textTheme.titleMedium),
    );
    availabilityWidgets.add(const SizedBox(height: 8));

    if (staff.isEmpty) {
      availabilityWidgets.add(
        const Text('Nessun operatore disponibile per questo servizio.'),
      );
    } else if (_selectedDay == null) {
      availabilityWidgets
        ..add(const Text('Seleziona un giorno nello step precedente.'))
        ..add(
          TextButton(
            onPressed: () => _goToStep(_BookingStep.date),
            child: const Text('Vai alla selezione data'),
          ),
        );
    } else {
      if (selectedDayClosures.isNotEmpty) {
        for (final closure in selectedDayClosures) {
          availabilityWidgets.add(
            _buildClosureNotice(
              context: context,
              message: _describeClosure(closure),
            ),
          );
          availabilityWidgets.add(const SizedBox(height: 8));
        }
        availabilityWidgets.add(const SizedBox(height: 4));
      }

      final dayKey = selectedDayKey!;
      if ((_staffFilterId == null || _staffFilterId!.isEmpty)) {
        var hasVisibleSlots = false;
        for (final member in staff) {
          final memberSlots =
              availabilityByStaff[member.id]?[dayKey] ??
              const <_AvailableSlot>[];
          if (memberSlots.isEmpty) {
            continue;
          }
          hasVisibleSlots = true;
          availabilityWidgets
            ..add(Text(member.fullName, style: theme.textTheme.bodyLarge))
            ..add(const SizedBox(height: 6))
            ..add(
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    memberSlots
                        .map(
                          (slot) => ChoiceChip(
                            label: Text(_timeLabel.format(slot.start)),
                            selected:
                                slot.start == _selectedSlotStart &&
                                member.id == _selectedStaffId,
                            onSelected: (selected) {
                              if (!selected) return;
                              _handleSlotSelection(
                                staffId: member.id,
                                slot: slot,
                                dayOverride: selectedDayKey,
                              );
                            },
                          ),
                        )
                        .toList(),
              ),
            )
            ..add(const SizedBox(height: 12));
        }
        if (!hasVisibleSlots) {
          availabilityWidgets.add(
            const Text('Nessuno slot disponibile per la data selezionata.'),
          );
        }
      } else {
        final staffId = _staffFilterId!;
        final filteredSlots =
            availabilityByStaff[staffId]?[dayKey] ?? const <_AvailableSlot>[];
        if (filteredSlots.isEmpty) {
          availabilityWidgets.add(
            const Text('Nessuno slot disponibile per la data selezionata.'),
          );
        } else {
          availabilityWidgets.add(
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  filteredSlots
                      .map(
                        (slot) => ChoiceChip(
                          label: Text(_timeLabel.format(slot.start)),
                          selected:
                              slot.start == _selectedSlotStart &&
                              staffId == _selectedStaffId,
                          onSelected: (selected) {
                            if (!selected) return;
                            _handleSlotSelection(
                              staffId: staffId,
                              slot: slot,
                              dayOverride: selectedDayKey,
                            );
                          },
                        ),
                      )
                      .toList(),
            ),
          );
        }
      }

      if (slotsForDay.isEmpty) {
        if (suggestions.isNotEmpty) {
          availabilityWidgets
            ..add(const SizedBox(height: 12))
            ..add(const Text('Prossime disponibilita\''))
            ..add(const SizedBox(height: 8));
          for (final suggestion in suggestions) {
            final dayLabel = _capitalize(_dayLabel.format(suggestion.day));
            availabilityWidgets
              ..add(Text(dayLabel, style: theme.textTheme.bodyLarge))
              ..add(const SizedBox(height: 6))
              ..add(
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      suggestion.slots.map((slot) {
                        final staffMember = staffById[slot.staffId];
                        final label =
                            staffMember == null
                                ? _timeLabel.format(slot.start)
                                : '${_timeLabel.format(slot.start)} · ${staffMember.fullName}';
                        return ChoiceChip(
                          label: Text(label),
                          selected:
                              slot.start == _selectedSlotStart &&
                              slot.staffId == _selectedStaffId,
                          onSelected: (_) {
                            _handleSlotSelection(
                              staffId: slot.staffId,
                              slot: slot,
                              dayOverride: suggestion.day,
                            );
                          },
                        );
                      }).toList(),
                ),
              )
              ..add(const SizedBox(height: 12));
          }
        } else if (!hasAnyAvailability) {
          availabilityWidgets.add(
            const Text('Nessuna disponibilita\' nelle prossime settimane.'),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 4 · Disponibilita\'', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        ...operatorWidgets,
        ...packageWidgets,
        ...availabilityWidgets,
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => _goToStep(_BookingStep.date),
              child: const Text('Indietro'),
            ),
            FilledButton(
              onPressed:
                  (_selectedSlotStart != null && _selectedStaffId != null)
                      ? () => _goToStep(_BookingStep.summary)
                      : null,
              child: const Text('Vai al riepilogo'),
            ),
          ],
        ),
      ],
    );
  }

  void _toggleServiceSelection({
    required Service service,
    required bool isSelected,
  }) {
    if (_selections.isEmpty) {
      return;
    }
    final currentSelection = _selections[_activeSelectionIndex];
    final updatedIds = currentSelection.serviceIds.toList();
    final contains = updatedIds.contains(service.id);
    if (isSelected) {
      if (!contains) {
        updatedIds.add(service.id);
      }
    } else {
      updatedIds.remove(service.id);
    }
    setState(() {
      final effectiveCategoryId =
          _selectedCategoryId ??
          currentSelection.categoryId ??
          service.categoryId;
      final updatedSelection = currentSelection.copyWith(
        categoryId: effectiveCategoryId,
        serviceIds: updatedIds,
        staffId: updatedIds.isEmpty ? null : currentSelection.staffId,
        start: updatedIds.isEmpty ? null : currentSelection.start,
        end: updatedIds.isEmpty ? null : currentSelection.end,
        usePackageSession:
            updatedIds.isEmpty ? false : currentSelection.usePackageSession,
        packageId: updatedIds.isEmpty ? null : currentSelection.packageId,
      );
      _selections[_activeSelectionIndex] = updatedSelection;
      if (updatedIds.isEmpty) {
        _selectedStaffId = null;
        _staffFilterId = null;
        _selectedSlotStart = null;
        _usePackageSession = false;
        _selectedPackageId = null;
      }
      _selectedServiceId = updatedIds.isNotEmpty ? updatedIds.first : null;
      _packageSelectionManuallyChanged = false;
      _applySelectionToForm(updatedSelection);
    });
  }

  void _onDateSelected(DateTime date) {
    final normalized = _dayFrom(date);
    final previousDay = _selectedDay;
    final hasChanged =
        previousDay == null || !_isSameDay(previousDay, normalized);
    setState(() {
      _selectedDay = normalized;
      if (hasChanged) {
        _selectedSlotStart = null;
        _selectedStaffId = null;
        _staffFilterId = null;
        _selections =
            _selections
                .map(
                  (selection) =>
                      selection.copyWith(staffId: null, start: null, end: null),
                )
                .toList();
      }
    });
    if (_selections.isNotEmpty) {
      _applySelectionToForm(_selections[_activeSelectionIndex]);
    }
  }

  void _handleSlotSelection({
    required String staffId,
    required _AvailableSlot slot,
    DateTime? dayOverride,
  }) {
    final slotDay = dayOverride ?? _dayFrom(slot.start);
    setState(() {
      _selectedStaffId = staffId;
      _staffFilterId = staffId;
      _selectedDay = _dayFrom(slotDay);
      _selectedSlotStart = slot.start;
      _updateActiveSelection(
        (current) => current.copyWith(
          staffId: staffId,
          start: slot.start,
          end: slot.end,
        ),
      );
    });
  }

  Widget _buildSummaryStep({
    required ThemeData theme,
    required Map<String, Service> serviceById,
    required Map<String, StaffMember> staffById,
  }) {
    if (_selections.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 5 · Riepilogo', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const Text('Non hai ancora selezionato alcun servizio.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _goToStep(_BookingStep.category),
            child: const Text('Aggiungi un servizio'),
          ),
        ],
      );
    }

    final isExpress = _isLastMinuteExpress;
    final isExpired = _isCountdownExpired;
    final needsServiceSelection = _selections.any(
      (selection) => !selection.hasServices,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isExpress ? 'Last-Minute Express' : 'Step 5 · Riepilogo',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (isExpress)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildLastMinuteExpressBanner(
              theme: theme,
              currency: NumberFormat.simpleCurrency(locale: 'it_IT'),
            ),
          ),
        _buildSelectionsSummary(
          theme: theme,
          servicesById: serviceById,
          staffById: staffById,
        ),
        const SizedBox(height: 24),
        if (!isExpress || needsServiceSelection)
          OutlinedButton.icon(
            onPressed:
                needsServiceSelection && isExpress
                    ? () => _goToStep(_BookingStep.services)
                    : _startAdditionalServiceFlow,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              needsServiceSelection && isExpress
                  ? 'Seleziona servizio'
                  : 'Aggiungi un altro servizio',
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            TextButton(
              onPressed: () {
                if (_isLastMinuteExpress) {
                  Navigator.of(context).maybePop();
                } else {
                  _goToStep(_BookingStep.availability);
                }
              },
              child: Text(isExpress ? 'Annulla' : 'Indietro'),
            ),
            FilledButton(
              onPressed: _canSubmit ? _confirmBooking : null,
              child:
                  _isSubmitting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        isExpired ? 'Slot scaduto' : 'Conferma prenotazione',
                      ),
            ),
          ],
        ),
      ],
    );
  }

  void _startAdditionalServiceFlow() {
    setState(() {
      final newSelection = _ServiceBookingSelection();
      _selections = [..._selections, newSelection];
      _activeSelectionIndex = _selections.length - 1;
      _selectedCategoryId = null;
      _selectedServiceId = null;
      _selectedStaffId = null;
      _staffFilterId = null;
      _selectedDay = null;
      _selectedSlotStart = null;
      _usePackageSession = false;
      _selectedPackageId = null;
      _packageSelectionManuallyChanged = false;
      _applySelectionToForm(newSelection);
      _currentStep = _BookingStep.category;
    });
  }

  Widget _buildLastMinuteExpressBanner({
    required ThemeData theme,
    required NumberFormat currency,
  }) {
    final slot = _expressSlot!;
    final scheme = theme.colorScheme;
    final countdownLabel = _formatCountdownLabel(_remainingCountdown);
    final savings = slot.basePrice - slot.priceNow;
    final hasSavings = savings > 0.01;
    final timeFormat = DateFormat('HH:mm', 'it_IT');
    final dateLabel = _capitalize(_dayLabel.format(slot.start));
    final isExpired = _isCountdownExpired;
    return Card(
      color: scheme.inversePrimary.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Slot last-minute confermabile entro $countdownLabel',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isExpired ? scheme.error : scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$dateLabel • ${timeFormat.format(slot.start)} (${slot.duration.inMinutes} min)',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  currency.format(slot.priceNow),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                if (hasSavings)
                  Flexible(
                    child: Text(
                      currency.format(slot.basePrice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                  ),
                if (hasSavings) ...[
                  const SizedBox(width: 12),
                  Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    avatar: const Icon(Icons.percent_rounded, size: 16),
                    label: Text(
                      '-${slot.discountPercentage.toStringAsFixed(0)}%',
                    ),
                  ),
                ],
                const Spacer(),
                if (hasSavings)
                  Flexible(
                    child: Text(
                      'Risparmi ${currency.format(savings)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Last-minute non rimborsabile. Puoi cedere lo slot a un amico fino a 10 minuti prima.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  void _goToStep(_BookingStep step) {
    if (_currentStep == step) {
      return;
    }
    setState(() {
      _currentStep = step;
    });
  }

  void _beginEditingSelection(int index) {
    if (index < 0 || index >= _selections.length) {
      return;
    }
    setState(() {
      _activeSelectionIndex = index;
      _packageSelectionManuallyChanged = false;
      final selection = _selections[index];
      _applySelectionToForm(selection);
      _currentStep = _determineStepForSelection(selection);
    });
  }

  void _removeSelectionAt(int index) {
    if (_selections.length <= 1 || index < 0 || index >= _selections.length) {
      return;
    }
    setState(() {
      _selections.removeAt(index);
      if (_activeSelectionIndex >= _selections.length) {
        _activeSelectionIndex = _selections.length - 1;
      }
      _packageSelectionManuallyChanged = false;
      final active = _selections[_activeSelectionIndex];
      _applySelectionToForm(active);
      _currentStep = _determineStepForSelection(active);
    });
  }

  _BookingStep _determineStepForSelection(_ServiceBookingSelection selection) {
    if (!selection.hasServices) {
      return _BookingStep.category;
    }
    if (_selectedDay == null) {
      return _BookingStep.date;
    }
    if (selection.start == null || selection.staffId == null) {
      return _BookingStep.availability;
    }
    return _BookingStep.summary;
  }

  bool get _canSubmit {
    if (_isSubmitting || _selections.isEmpty) {
      return false;
    }
    if (_isCountdownExpired) {
      return false;
    }
    for (final selection in _selections) {
      if (!selection.hasServices ||
          selection.staffId == null ||
          selection.start == null ||
          selection.end == null) {
        return false;
      }
      if (selection.usePackageSession && selection.packageId == null) {
        return false;
      }
    }
    return true;
  }

  Future<void> _confirmBooking() async {
    if (!_canSubmit) {
      return;
    }
    final data = ref.read(appDataProvider);
    final salon = data.salons.firstWhereOrNull(
      (item) => item.id == widget.client.salonId,
    );

    final editingAppointmentId = widget.initialAppointment?.id;
    final existingAppointments = _visibleAppointments(
      data,
      excludeAppointmentId: editingAppointmentId,
    );
    final plannedAppointments = <Appointment>[];
    final appointmentsToSave = <Appointment>[];

    for (var index = 0; index < _selections.length; index++) {
      final selection = _selections[index];
      final servicesForSelection =
          selection.serviceIds
              .map(
                (id) =>
                    _servicesById[id] ??
                    data.services.firstWhereOrNull((svc) => svc.id == id),
              )
              .whereNotNull()
              .toList();
      if (servicesForSelection.isEmpty) {
        _showError('Selezione servizi non valida.');
        return;
      }
      if (_isLastMinuteExpress && index == 0 && _expressSlot != null) {
        final currentSlot = data.lastMinuteSlots.firstWhereOrNull(
          (item) => item.id == _expressSlot!.id,
        );
        if (currentSlot == null || !currentSlot.isAvailable) {
          _showError(
            'Lo slot last-minute selezionato non è più disponibile. Scegli un altro orario.',
          );
          return;
        }
      }

      final staff = data.staff.firstWhereOrNull(
        (member) => member.id == selection.staffId,
      );
      if (staff == null) {
        _showError('Operatore selezionato non valido.');
        return;
      }
      final slotStart = selection.start!;
      final totalDuration = servicesForSelection.fold<Duration>(
        Duration.zero,
        (previous, service) => previous + service.totalDuration,
      );
      final slotEnd = selection.end ?? slotStart.add(totalDuration);
      final blockingSlots =
          _activeLastMinuteSlotsForStaff(
            data: data,
            staffId: staff.id,
            ignoreSlotId: index == 0 ? _expressSlot?.id : null,
          ).toList();
      final blockingSlotAppointments =
          blockingSlots.map(_appointmentFromLastMinuteSlot).toList();

      final appointmentsForConflicts = [
        ...existingAppointments,
        ...plannedAppointments,
        ...blockingSlotAppointments,
      ];

      final staffConflicts =
          appointmentsForConflicts.where((existing) {
            if (existing.staffId != staff.id) return false;
            if (existing.status == AppointmentStatus.cancelled ||
                existing.status == AppointmentStatus.noShow) {
              return false;
            }
            return existing.start.isBefore(slotEnd) &&
                existing.end.isAfter(slotStart);
          }).toList();
      if (staffConflicts.isNotEmpty) {
        _showError(
          'Lo slot selezionato non è più disponibile. Scegli un altro orario.',
        );
        return;
      }

      final absences =
          data.staffAbsences.where((absence) {
            if (absence.staffId != staff.id) return false;
            return absence.start.isBefore(slotEnd) &&
                absence.end.isAfter(slotStart);
          }).toList();
      if (absences.isNotEmpty) {
        _showError('L\'operatore non è disponibile in questo orario.');
        return;
      }

      final closureConflicts =
          salon == null
              ? const <SalonClosure>[]
              : _findOverlappingClosures(
                closures: salon.closures,
                start: slotStart,
                end: slotEnd,
              );
      if (closureConflicts.isNotEmpty) {
        final description = _describeClosure(closureConflicts.first);
        _showError('Il salone è chiuso in questo orario. $description');
        return;
      }

      var equipmentStart = slotStart;
      for (final service in servicesForSelection) {
        final equipmentEnd = equipmentStart.add(service.totalDuration);
        final equipmentCheck = EquipmentAvailabilityChecker.check(
          salon: salon,
          service: service,
          allServices: data.services,
          appointments: appointmentsForConflicts,
          start: equipmentStart,
          end: equipmentEnd,
        );
        if (equipmentCheck.hasConflicts) {
          final equipmentLabel = equipmentCheck.blockingEquipment.join(', ');
          final message =
              equipmentLabel.isEmpty
                  ? 'Macchinario non disponibile per questo orario.'
                  : 'Macchinario non disponibile per questo orario: $equipmentLabel';
          _showError('$message. Scegli un altro slot.');
          return;
        }
        equipmentStart = equipmentEnd;
      }

      final hasClientConflict = hasClientBookingConflict(
        appointments: [...data.appointments, ...plannedAppointments],
        clientId: widget.client.id,
        start: slotStart,
        end: slotEnd,
        excludeAppointmentId: index == 0 ? editingAppointmentId : null,
      );
      if (hasClientConflict) {
        _showError(
          'Hai già un appuntamento in questo orario. Scegli un altro slot.',
        );
        return;
      }

      final packageId =
          selection.usePackageSession ? selection.packageId : null;
      if (packageId != null && servicesForSelection.length > 1) {
        _showError(
          'Non è possibile utilizzare un pacchetto quando sono selezionati più servizi.',
        );
        return;
      }
      final existing =
          widget.initialAppointment != null && index == 0
              ? widget.initialAppointment
              : null;
      final appointment =
          existing?.copyWith(
            staffId: staff.id,
            serviceIds: selection.serviceIds,
            start: slotStart,
            end: slotEnd,
            packageId: packageId,
            lastMinuteSlotId:
                _isLastMinuteExpress && index == 0 && _expressSlot != null
                    ? _expressSlot!.id
                    : existing?.lastMinuteSlotId,
          ) ??
          Appointment(
            id: _uuid.v4(),
            salonId: widget.client.salonId,
            clientId: widget.client.id,
            staffId: staff.id,
            serviceIds: selection.serviceIds,
            start: slotStart,
            end: slotEnd,
            status: AppointmentStatus.scheduled,
            packageId: packageId,
            lastMinuteSlotId:
                _isLastMinuteExpress && index == 0 && _expressSlot != null
                    ? _expressSlot!.id
                    : null,
          );
      var appointmentToSave = appointment;
      if (_isLastMinuteExpress && index == 0 && _expressSlot != null) {
        final note = appointment.notes;
        final expressNote = 'Prenotazione last-minute ${_expressSlot!.id}';
        if (note == null || note.isEmpty) {
          appointmentToSave = appointment.copyWith(notes: expressNote);
        } else if (!note.contains(expressNote)) {
          appointmentToSave = appointment.copyWith(
            notes: '$note\n$expressNote',
          );
        }
      }
      plannedAppointments.add(appointmentToSave);
      appointmentsToSave.add(appointmentToSave);
    }

    setState(() => _isSubmitting = true);
    try {
      final expressSlotId = _expressSlot?.id;
      for (var index = 0; index < appointmentsToSave.length; index++) {
        final appointment = appointmentsToSave[index];
        final consumeSlotId =
            _isLastMinuteExpress && index == 0 ? expressSlotId : null;
        await ref
            .read(appDataProvider.notifier)
            .upsertAppointment(
              appointment,
              consumeLastMinuteSlotId: consumeSlotId,
            );
      }
      if (!mounted) return;
      Navigator.of(context).pop(appointmentsToSave.first);
    } on StateError catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Non è stato possibile completare la prenotazione. Riprova.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _selectionEquals(
    _ServiceBookingSelection a,
    _ServiceBookingSelection b,
  ) {
    return a.categoryId == b.categoryId &&
        _listEquality.equals(a.serviceIds, b.serviceIds) &&
        a.staffId == b.staffId &&
        a.start == b.start &&
        a.end == b.end &&
        a.usePackageSession == b.usePackageSession &&
        a.packageId == b.packageId;
  }

  void _applySelectionToForm(_ServiceBookingSelection selection) {
    _selectedCategoryId = selection.categoryId;
    _selectedServiceId =
        selection.serviceIds.isNotEmpty ? selection.serviceIds.first : null;
    _selectedStaffId = selection.staffId;
    _staffFilterId = selection.staffId;
    _selectedSlotStart = selection.start;
    _usePackageSession = selection.usePackageSession;
    _selectedPackageId = selection.packageId;
    if (selection.start != null) {
      _selectedDay = _dayFrom(selection.start!);
    }
  }

  void _updateActiveSelection(
    _ServiceBookingSelection Function(_ServiceBookingSelection current)
    transform,
  ) {
    if (_selections.isEmpty) {
      return;
    }
    final updated = transform(_selections[_activeSelectionIndex]);
    _selections[_activeSelectionIndex] = updated;
  }

  Iterable<LastMinuteSlot> _activeLastMinuteSlotsForStaff({
    required AppDataState data,
    required String staffId,
    String? ignoreSlotId,
  }) {
    if (staffId.isEmpty) {
      return const <LastMinuteSlot>[];
    }
    final now = DateTime.now();
    return data.lastMinuteSlots.where((slot) {
      if (slot.salonId != widget.client.salonId) {
        return false;
      }
      if (slot.operatorId != staffId) {
        return false;
      }
      if (!slot.isAvailable) {
        return false;
      }
      if (!slot.end.isAfter(now)) {
        return false;
      }
      if (ignoreSlotId != null && slot.id == ignoreSlotId) {
        return false;
      }
      return true;
    });
  }

  Appointment _appointmentFromLastMinuteSlot(LastMinuteSlot slot) {
    final serviceIds =
        slot.serviceId != null && slot.serviceId!.isNotEmpty
            ? <String>[slot.serviceId!]
            : const <String>[];
    return Appointment(
      id: 'last-minute-${slot.id}',
      salonId: slot.salonId,
      clientId: 'last-minute-${slot.id}',
      staffId: slot.operatorId ?? '',
      serviceIds: serviceIds,
      start: slot.start,
      end: slot.end,
      status: AppointmentStatus.scheduled,
      roomId: slot.roomId,
    );
  }

  String _selectionLabel(int index, Map<String, Service> serviceById) {
    final selection = _selections[index];
    final names =
        selection.serviceIds
            .map((id) => serviceById[id]?.name)
            .whereType<String>()
            .toList();
    if (names.isNotEmpty) {
      return names.join(', ');
    }
    return 'Servizio ${index + 1}';
  }

  Widget _buildSelectionsSummary({
    required ThemeData theme,
    required Map<String, Service> servicesById,
    required Map<String, StaffMember> staffById,
  }) {
    final titleStyle = theme.textTheme.titleSmall;
    final infoStyle = theme.textTheme.bodySmall;
    final warningStyle = infoStyle?.copyWith(color: theme.colorScheme.error);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    Duration totalDuration = Duration.zero;
    double totalBasePrice = 0;
    double totalPayablePrice = 0;
    final tiles = <Widget>[];
    for (var index = 0; index < _selections.length; index++) {
      final selection = _selections[index];
      final services =
          selection.serviceIds
              .map((id) => servicesById[id])
              .whereNotNull()
              .toList();
      final staff =
          selection.staffId != null ? staffById[selection.staffId!] : null;
      final serviceLabel =
          services.isNotEmpty
              ? services.map((service) => service.name).join(', ')
              : 'Servizi da selezionare';
      final staffLabel = staff?.fullName ?? 'Operatore da selezionare';
      final start = selection.start;
      final end = selection.end;
      String slotLabel;
      TextStyle? slotStyle = infoStyle;
      if (start != null && end != null) {
        final dayLabel = _capitalize(_dayLabel.format(start));
        final startLabel = _timeLabel.format(start);
        final endLabel = _timeLabel.format(end);
        slotLabel = '$dayLabel · $startLabel - $endLabel';
      } else {
        slotLabel = 'Orario da selezionare';
        slotStyle = warningStyle;
      }
      String packageLabel;
      if (selection.usePackageSession) {
        packageLabel =
            selection.packageId != null
                ? 'Sessione pacchetto: #${selection.packageId}'
                : 'Sessione pacchetto: seleziona pacchetto';
      } else {
        packageLabel = 'Pacchetto: non utilizzato';
      }
      final packageStyle =
          selection.usePackageSession && selection.packageId == null
              ? warningStyle
              : infoStyle;

      final selectionBasePrice = services.fold<double>(
        0,
        (sum, service) => sum + service.price,
      );
      double selectionPayablePrice = selectionBasePrice;
      if (_isLastMinuteExpress && index == 0 && _expressSlot != null) {
        selectionPayablePrice = _expressSlot!.priceNow;
      }

      if (services.isNotEmpty) {
        final contribution =
            selection.start != null && selection.end != null
                ? selection.end!.difference(selection.start!)
                : services.fold<Duration>(
                  Duration.zero,
                  (sum, service) => sum + service.totalDuration,
                );
        totalDuration += contribution;
        totalBasePrice += selectionBasePrice;
        totalPayablePrice += selectionPayablePrice;
      }

      tiles.add(
        Card(
          margin: EdgeInsets.only(
            bottom: index == _selections.length - 1 ? 0 : 12,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      child: Text('${index + 1}'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        serviceLabel,
                        style: services.isNotEmpty ? titleStyle : warningStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  staffLabel,
                  style: staff != null ? infoStyle : warningStyle,
                ),
                const SizedBox(height: 4),
                Text(slotLabel, style: slotStyle),
                const SizedBox(height: 4),
                Text(packageLabel, style: packageStyle),
                if (services.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        currency.format(selectionPayablePrice),
                        style: theme.textTheme.titleMedium,
                      ),
                      if (_isLastMinuteExpress &&
                          index == 0 &&
                          _expressSlot != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            currency.format(selectionBasePrice),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final summaryTiles = <Widget>[];
    if (totalDuration > Duration.zero || totalPayablePrice > 0) {
      final hasDiscount =
          _isLastMinuteExpress && totalBasePrice > totalPayablePrice + 0.01;
      summaryTiles.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Durata totale', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(totalDuration),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Costo stimato', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            totalPayablePrice > 0
                                ? currency.format(totalPayablePrice)
                                : '—',
                            style: theme.textTheme.titleMedium,
                          ),
                          if (hasDiscount)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                currency.format(totalBasePrice),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      summaryTiles.add(const SizedBox(height: 12));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...summaryTiles, ...tiles],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) {
      return '—';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final parts = <String>[];
    if (hours > 0) {
      parts.add('${hours}h');
    }
    if (minutes > 0 || parts.isEmpty) {
      parts.add('${minutes}m');
    }
    return parts.join(' ');
  }

  String _formatCountdownLabel(Duration duration) {
    if (duration <= Duration.zero) {
      return '00:00';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      final minutesTwo = minutes.toString().padLeft(2, '0');
      return '${hours}h$minutesTwo\'';
    }
    final minutesTwo = minutes.toString().padLeft(2, '0');
    final secondsTwo = seconds.toString().padLeft(2, '0');
    return '$minutesTwo:$secondsTwo';
  }

  List<StaffMember> _availableStaff({
    required AppDataState data,
    required List<Service> services,
  }) {
    if (services.isEmpty) {
      return const <StaffMember>[];
    }
    return data.staff.where((member) {
        if (member.salonId != widget.client.salonId || !member.isActive) {
          return false;
        }
        for (final service in services) {
          final allowedRoles = service.staffRoles;
          if (allowedRoles.isEmpty) {
            continue;
          }
          final matchesRole = member.roleIds.any(
            (roleId) => allowedRoles.contains(roleId),
          );
          if (!matchesRole) {
            return false;
          }
        }
        return true;
      }).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  List<_BookingCategory> _composeBookingCategories({
    required List<Service> services,
    required List<ServiceCategory> categories,
    required String salonId,
  }) {
    final categoriesById = {
      for (final category in categories.where(
        (item) => item.salonId == salonId,
      ))
        category.id: category,
    };
    final Map<String, List<Service>> servicesByCategoryId = {};
    final Map<String, List<Service>> servicesByLegacyName = {};
    final Map<String, String> legacyLabels = {};
    final List<Service> uncategorized = [];

    for (final service in services) {
      ServiceCategory? category;
      final categoryId = service.categoryId;
      if (categoryId != null && categoryId.isNotEmpty) {
        category = categoriesById[categoryId];
      }
      category ??= categoriesById.values.firstWhereOrNull(
        (candidate) =>
            candidate.name.toLowerCase() == service.category.toLowerCase() &&
            candidate.salonId == service.salonId,
      );

      if (category != null) {
        servicesByCategoryId
            .putIfAbsent(category.id, () => <Service>[])
            .add(service);
        continue;
      }

      final trimmedName = service.category.trim();
      if (trimmedName.isNotEmpty) {
        final legacyKey = 'legacy::${trimmedName.toLowerCase()}';
        servicesByLegacyName
            .putIfAbsent(legacyKey, () => <Service>[])
            .add(service);
        legacyLabels.putIfAbsent(legacyKey, () => trimmedName);
      } else {
        uncategorized.add(service);
      }
    }

    final result = <_BookingCategory>[];
    final sortedCategories = categoriesById.values.sortedByDisplayOrder();
    for (final category in sortedCategories) {
      final matchingServices = List<Service>.from(
        servicesByCategoryId[category.id] ?? const <Service>[],
      )..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (matchingServices.isEmpty) {
        continue;
      }
      result.add(
        _BookingCategory(
          id: category.id,
          label: category.name,
          services: matchingServices,
        ),
      );
    }

    final legacyEntries =
        servicesByLegacyName.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in legacyEntries) {
      final label =
          legacyLabels[entry.key] ?? entry.key.replaceFirst('legacy::', '');
      final servicesForCategory =
          entry.value..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
      result.add(
        _BookingCategory(
          id: entry.key,
          label: label.isEmpty ? 'Altro' : label,
          services: servicesForCategory,
        ),
      );
    }

    if (uncategorized.isNotEmpty) {
      uncategorized.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      result.add(
        _BookingCategory(
          id: _uncategorizedCategoryId,
          label: 'Altro',
          services: uncategorized,
        ),
      );
    }

    return result;
  }

  Map<DateTime, List<_AvailableSlot>> _computeAvailability({
    required AppDataState data,
    required List<Service> services,
    required String staffId,
  }) {
    if (services.isEmpty) {
      return const <DateTime, List<_AvailableSlot>>{};
    }
    final now = DateTime.now();
    final horizon = DateTime(
      now.year,
      now.month + 3,
      now.day,
    ).add(const Duration(days: 1));
    final salon = data.salons.firstWhereOrNull(
      (item) => item.id == widget.client.salonId,
    );
    final salonClosures =
        salon == null
            ? const <SalonClosure>[]
            : _findOverlappingClosures(
              closures: salon.closures,
              start: now,
              end: horizon,
            );
    final editingAppointmentId = widget.initialAppointment?.id;
    final visibleAppointments = _visibleAppointments(
      data,
      excludeAppointmentId: editingAppointmentId,
    );
    final blockingExpressSlots =
        _activeLastMinuteSlotsForStaff(
          data: data,
          staffId: staffId,
          ignoreSlotId: null,
        ).map(_appointmentFromLastMinuteSlot).toList();
    final allAppointments = <Appointment>[
      ...visibleAppointments,
      ...blockingExpressSlots,
    ];

    const slotStep = Duration(minutes: _slotIntervalMinutes);
    final clientAppointments =
        data.appointments.where((appointment) {
          if (appointment.clientId != widget.client.id) {
            return false;
          }
          if (editingAppointmentId != null &&
              appointment.id == editingAppointmentId) {
            return false;
          }
          if (!appointmentBlocksAvailability(appointment)) {
            return false;
          }
          return appointment.end.isAfter(now);
        }).toList();

    final relevantShifts =
        data.shifts.where((shift) {
            if (shift.staffId != staffId) return false;
            if (shift.salonId != widget.client.salonId) return false;
            if (!shift.end.isAfter(now)) return false;
            if (!shift.start.isBefore(horizon)) return false;
            return true;
          }).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    final busyAppointments =
        allAppointments.where((appointment) {
          if (appointment.staffId != staffId) return false;
          if (appointment.status == AppointmentStatus.cancelled ||
              appointment.status == AppointmentStatus.noShow) {
            return false;
          }
          if (editingAppointmentId != null &&
              appointment.id == editingAppointmentId) {
            return false;
          }
          if (!appointment.end.isAfter(now)) {
            return false;
          }
          return true;
        }).toList();

    final busyAbsences =
        _visibleStaffAbsences(data).where((absence) {
          if (absence.staffId != staffId) return false;
          if (!absence.end.isAfter(now)) return false;
          return true;
        }).toList();

    final totalDuration = services.fold<Duration>(
      Duration.zero,
      (sum, service) => sum + service.totalDuration,
    );
    final buckets = <DateTime, List<_AvailableSlot>>{};

    for (final shift in relevantShifts) {
      final windowStart = shift.start.isAfter(now) ? shift.start : now;
      if (!windowStart.isBefore(horizon)) {
        continue;
      }
      final windows = _buildShiftWindows(
        shift: shift,
        from: windowStart,
        busyAppointments: busyAppointments,
        busyAbsences: busyAbsences,
        salonClosures: salonClosures,
      );

      for (final window in windows) {
        if (!window.start.isBefore(horizon)) {
          continue;
        }
        final cappedWindowEnd =
            window.end.isBefore(horizon) ? window.end : horizon;
        if (!cappedWindowEnd.isAfter(window.start)) {
          continue;
        }
        var slotStart = _ceilToInterval(window.start, _slotIntervalMinutes);
        while (slotStart.isBefore(cappedWindowEnd)) {
          final slotEnd = slotStart.add(totalDuration);
          if (slotEnd.isAfter(cappedWindowEnd)) {
            break;
          }
          if (slotStart.isBefore(now)) {
            slotStart = slotStart.add(slotStep);
            continue;
          }

          final appointmentsForConflicts = [...allAppointments];

          var equipmentStart = slotStart;
          var equipmentOk = true;
          for (final service in services) {
            final equipmentEnd = equipmentStart.add(service.totalDuration);
            final equipmentCheck = EquipmentAvailabilityChecker.check(
              salon: salon,
              service: service,
              allServices: data.services,
              appointments: appointmentsForConflicts,
              start: equipmentStart,
              end: equipmentEnd,
            );
            if (equipmentCheck.hasConflicts) {
              equipmentOk = false;
              break;
            }
            equipmentStart = equipmentEnd;
          }
          if (!equipmentOk) {
            slotStart = slotStart.add(slotStep);
            continue;
          }

          final hasClientConflict = hasClientBookingConflict(
            appointments: clientAppointments,
            clientId: widget.client.id,
            start: slotStart,
            end: slotEnd,
          );
          if (hasClientConflict) {
            slotStart = slotStart.add(slotStep);
            continue;
          }

          final dayKey = DateTime(
            slotStart.year,
            slotStart.month,
            slotStart.day,
          );
          final slots = buckets.putIfAbsent(dayKey, () => []);
          slots.add(
            _AvailableSlot(
              start: slotStart,
              end: slotEnd,
              shiftId: shift.id,
              staffId: staffId,
            ),
          );
          slotStart = slotStart.add(slotStep);
        }
      }
    }

    for (final entry in buckets.entries) {
      entry.value.sort((a, b) => a.start.compareTo(b.start));
    }

    return buckets;
  }

  List<_DaySuggestion> _nextAvailableSuggestions({
    required Map<DateTime, List<_AvailableSlot>> availability,
    required DateTime selectedDay,
    int maxDays = 3,
  }) {
    final suggestions = <_DaySuggestion>[];
    for (var offset = 1; offset <= maxDays; offset++) {
      final candidateDay = _dayFrom(selectedDay.add(Duration(days: offset)));
      final candidateSlots = availability[candidateDay];
      if (candidateSlots != null && candidateSlots.isNotEmpty) {
        suggestions.add(
          _DaySuggestion(day: candidateDay, slots: candidateSlots),
        );
      }
    }
    return suggestions;
  }

  Map<DateTime, List<_AvailableSlot>> _combineAvailability(
    Map<String, Map<DateTime, List<_AvailableSlot>>> availabilityByStaff,
  ) {
    final combined = <DateTime, List<_AvailableSlot>>{};
    for (final entry in availabilityByStaff.entries) {
      for (final dayEntry in entry.value.entries) {
        final slots = combined.putIfAbsent(
          dayEntry.key,
          () => <_AvailableSlot>[],
        );
        slots.addAll(dayEntry.value);
      }
    }
    for (final entry in combined.entries) {
      entry.value.sort((a, b) => a.start.compareTo(b.start));
    }
    return combined;
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

  List<Appointment> _visibleAppointments(
    AppDataState data, {
    String? excludeAppointmentId,
  }) {
    final appointments = data.appointments;
    if (excludeAppointmentId == null) {
      return List.unmodifiable(appointments);
    }
    return List.unmodifiable(
      appointments.where(
        (appointment) => appointment.id != excludeAppointmentId,
      ),
    );
  }

  List<StaffAbsence> _visibleStaffAbsences(AppDataState data) {
    final map = <String, StaffAbsence>{};
    for (final absence in data.publicStaffAbsences) {
      map[absence.id] = absence;
    }
    for (final absence in data.staffAbsences) {
      map[absence.id] = absence;
    }
    return List.unmodifiable(map.values);
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
        color: color.withOpacity(0.08),
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

  DateTime _dayFrom(DateTime value) {
    return DateTime(value.year, value.month, value.day);
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

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BookingCategory {
  const _BookingCategory({
    required this.id,
    required this.label,
    required this.services,
  });

  final String id;
  final String label;
  final List<Service> services;
}

class _DaySuggestion {
  const _DaySuggestion({required this.day, required this.slots});

  final DateTime day;
  final List<_AvailableSlot> slots;
}

class _AvailableSlot {
  const _AvailableSlot({
    required this.start,
    required this.end,
    required this.shiftId,
    required this.staffId,
  });

  final DateTime start;
  final DateTime end;
  final String shiftId;
  final String staffId;

  _AvailableSlot copyWith({
    DateTime? start,
    DateTime? end,
    String? shiftId,
    String? staffId,
  }) {
    return _AvailableSlot(
      start: start ?? this.start,
      end: end ?? this.end,
      shiftId: shiftId ?? this.shiftId,
      staffId: staffId ?? this.staffId,
    );
  }
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
