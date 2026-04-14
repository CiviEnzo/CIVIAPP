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
import 'package:you_book/presentation/screens/admin/modules/client_detail_page.dart';
import 'package:you_book/presentation/screens/admin/forms/client_search_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/client_search_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/client_save_feedback.dart';
import 'package:you_book/presentation/shared/client_package_purchase.dart';
import 'package:you_book/presentation/shared/widgets/client_notes_section.dart';
import 'package:you_book/presentation/screens/admin/forms/client_form_sheet.dart';
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

enum _AppointmentMobileAction { copy, delete }

const Color _kFigmaModalBg = Color(0xFFF4F4F6);
const Color _kFigmaCardBg = Color(0xFFF6F6F8);
const Color _kFigmaInputBg = Color(0xFFF9F9FA);
const Color _kFigmaBorder = Color(0xFFCDCDD2);
const Color _kFigmaTextPrimary = Color(0xFF1F1F22);
const Color _kFigmaTextSecondary = Color(0xFF717178);
const Color _kFigmaGold = Color(0xFFD3AE2C);
const Color _kFigmaGoldStrong = Color(0xFFF2A007);
const Color _kFigmaSuccess = Color(0xFF1BC46A);
const Color _kFigmaDanger = Color(0xFFE05A5A);

Color _blendWithSurface(Color surface, Color tint, double alpha) {
  return Color.alphaBlend(tint.withValues(alpha: alpha), surface);
}

class _AppointmentFormPalette {
  const _AppointmentFormPalette({
    required this.modalBg,
    required this.cardBg,
    required this.inputBg,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentStrong,
    required this.accentSoftBg,
    required this.accentSectionBg,
    required this.accentOnSection,
    required this.success,
    required this.successBg,
    required this.danger,
    required this.dangerBg,
    required this.summaryGradient,
    required this.packageBg,
    required this.selectedItemBg,
    required this.controlBg,
    required this.controlDisabledBg,
  });

  factory _AppointmentFormPalette.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return _AppointmentFormPalette(
      modalBg: isDark ? scheme.surface : _kFigmaModalBg,
      cardBg: isDark ? scheme.surfaceContainerLow : _kFigmaCardBg,
      inputBg: isDark ? scheme.surfaceContainerHigh : _kFigmaInputBg,
      border:
          isDark
              ? scheme.outlineVariant.withValues(alpha: 0.78)
              : _kFigmaBorder,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      accent: _kFigmaGold,
      accentStrong: _kFigmaGoldStrong,
      accentSoftBg:
          isDark
              ? _kFigmaGold.withValues(alpha: 0.18)
              : const Color(0x1AD3AE2C),
      accentSectionBg:
          isDark ? _kFigmaGold.withValues(alpha: 0.18) : _kFigmaGold,
      accentOnSection: isDark ? _kFigmaGold : _kFigmaTextPrimary,
      success: isDark ? scheme.tertiary : _kFigmaSuccess,
      successBg:
          isDark
              ? scheme.tertiaryContainer.withValues(alpha: 0.38)
              : const Color(0x1A1BC46A),
      danger: scheme.error,
      dangerBg:
          isDark
              ? scheme.errorContainer.withValues(alpha: 0.32)
              : const Color(0xFFFFE9E9),
      summaryGradient:
          isDark
              ? LinearGradient(
                colors: [
                  _blendWithSurface(
                    scheme.surfaceContainerHigh,
                    _kFigmaGold,
                    0.08,
                  ),
                  scheme.surface,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
              : const LinearGradient(
                colors: [Color(0xFFF5F0DF), Color(0xFFF8F8F9)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
      packageBg:
          isDark
              ? _blendWithSurface(scheme.surfaceContainerLow, _kFigmaGold, 0.06)
              : const Color(0xFFFFFAEF),
      selectedItemBg:
          isDark
              ? _blendWithSurface(
                scheme.surfaceContainerHigh,
                _kFigmaGoldStrong,
                0.10,
              )
              : Colors.white,
      controlBg:
          isDark ? scheme.surfaceContainerHighest : const Color(0xFFEEEEF1),
      controlDisabledBg:
          isDark ? scheme.surfaceContainerLow : const Color(0xFFF4F4F6),
    );
  }

  final Color modalBg;
  final Color cardBg;
  final Color inputBg;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color accentStrong;
  final Color accentSoftBg;
  final Color accentSectionBg;
  final Color accentOnSection;
  final Color success;
  final Color successBg;
  final Color danger;
  final Color dangerBg;
  final Gradient summaryGradient;
  final Color packageBg;
  final Color selectedItemBg;
  final Color controlBg;
  final Color controlDisabledBg;
}

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
    this.showSheetHeader = true,
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
  final bool showSheetHeader;
  final void Function(AppointmentFormResult result)? onSaved;

  @override
  ConsumerState<AppointmentFormSheet> createState() =>
      _AppointmentFormSheetState();
}

class _AppointmentFormSheetState extends ConsumerState<AppointmentFormSheet> {
  static const _slotIntervalMinutes = 15;
  static const Duration _minTotalDuration = Duration(
    minutes: _slotIntervalMinutes,
  );
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
    final initialClient = widget.clients.firstWhereOrNull(
      (client) => client.id == _clientId,
    );
    if (initialClient != null) {
      _clientSearchController.text = initialClient.fullName;
      _clientNumberSearchController.text = initialClient.clientNumber ?? '';
    }
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
          _serviceDurationAdjustments[allocation.serviceId] = Duration(
            minutes: allocation.durationAdjustmentMinutes,
          );
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
    final palette = _AppointmentFormPalette.fromTheme(theme);
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
    final operatorSectionTitle = 'Cliente';
    final lastClient = clients.firstWhereOrNull(
      (client) =>
          client.id == _lastSavedClientId &&
          (_salonId == null || client.salonId == _salonId),
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
                        _applyClientSelection(lastClient);
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
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _statusLabel(status),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
        final isCompactWidth = constraints.maxWidth < 720;
        final isSingleColumnLayout = constraints.maxWidth < 1060;
        final isPhoneLayout = isAppSheetPhoneLayout(context);
        final isEditing = widget.initial != null;
        final appointmentTitle =
            isEditing ? 'Modifica appuntamento' : 'Nuovo appuntamento';
        final mobileStandalone = isPhoneLayout && widget.showSheetHeader;

        final titleSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appointmentTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              bookingDateLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        );

        final Widget staffField = SizedBox(
          width: isSingleColumnLayout ? double.infinity : 280,
          child: DropdownButtonFormField<String>(
            initialValue: staffFieldValue,
            decoration: InputDecoration(
              hintText: 'Seleziona operatore',
              filled: true,
              fillColor: palette.inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: palette.accent, width: 1.3),
              ),
            ),
            isExpanded: true,
            items:
                filteredStaff
                    .map(
                      (member) => DropdownMenuItem(
                        value: member.id,
                        child: Text(member.fullName),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              final staffMember =
                  value == null
                      ? null
                      : staffMembers.firstWhereOrNull(
                        (member) => member.id == value,
                      );
              final previousSalonId = _salonId;
              final newSalonId = staffMember?.salonId;
              final salonChanged = previousSalonId != newSalonId;

              setState(() {
                _staffId = value;
                _salonId = newSalonId;

                if (salonChanged) {
                  _clientId = null;
                  _clientSearchController.clear();
                  _clientNumberSearchController.clear();
                  _clientSearchMode = _ClientSearchMode.general;
                  _clientSuggestions = const <Client>[];
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
                  _ensureServiceState(_serviceIds);
                  _lastSuggestionKey = '';
                  _latestSuggestion = null;
                  return;
                }

                final allowedServiceIds =
                    services
                        .where((service) {
                          final roles = service.staffRoles;
                          if (roles.isEmpty) {
                            return true;
                          }
                          return staffMember.roleIds.any(
                            (roleId) => roles.contains(roleId),
                          );
                        })
                        .map((service) => service.id)
                        .toSet();
                final filteredSelections =
                    _serviceIds.where(allowedServiceIds.contains).toList();
                if (filteredSelections.length != _serviceIds.length) {
                  _serviceIds = filteredSelections;
                  _ensureServiceState(_serviceIds);
                  _manualPackageSelections.removeWhere(
                    (serviceId) => !_serviceIds.contains(serviceId),
                  );
                  _lastSuggestionKey = '';
                  _latestSuggestion = null;
                }
              });

              _clearInlineError();

              if (salonChanged) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _clientFieldKey.currentState?.didChange(_clientId);
                });
              }
            },
            validator: (value) => value == null ? 'Scegli un operatore' : null,
          ),
        );

        final summaryCard = Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: palette.accent.withValues(alpha: 0.7),
              width: 1,
            ),
            gradient: palette.summaryGradient,
          ),
          child:
              isPhoneLayout
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookingDateLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'OPERATORE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      staffField,
                    ],
                  )
                  : isSingleColumnLayout
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleSection,
                      const SizedBox(height: 14),
                      Text(
                        'OPERATORE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      staffField,
                    ],
                  )
                  : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 18),
                      SizedBox(
                        width: 320,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OPERATORE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: palette.accent,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            staffField,
                          ],
                        ),
                      ),
                    ],
                  ),
        );

        final clientSection = _buildDetailSectionCard(
          icon: Icons.group_rounded,
          title: operatorSectionTitle,
          trailing: lastClientButton,
          child: _buildClientSelectionBody(filteredClients),
        );

        final serviceSection = _buildDetailSectionCard(
          icon: Icons.calendar_today_rounded,
          title: 'Servizi e pacchetti',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FormField<List<String>>(
                validator:
                    (_) =>
                        _serviceIds.isEmpty
                            ? 'Scegli almeno un servizio'
                            : null,
                builder: (state) {
                  final theme = Theme.of(context);
                  final selectedNames =
                      selectedServices.map((service) => service.name).toList();
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final selection = await _openServicePicker(
                        context,
                        services: filteredServices,
                        categories: _categoriesForCurrentSalon(),
                        selectedStaff: staffMembers.firstWhereOrNull(
                          (member) => member.id == _staffId,
                        ),
                      );
                      if (selection != null) {
                        setState(() {
                          _serviceIds = selection;
                          _ensureServiceState(_serviceIds);
                          _manualPackageSelections.removeWhere(
                            (serviceId) => !_serviceIds.contains(serviceId),
                          );
                          if (_serviceIds.isEmpty) {
                            _clearAllPackageSelections();
                          } else {
                            _lastSuggestionKey = '';
                            _latestSuggestion = null;
                            final baseSelectedServices =
                                _selectedServicesInOrder(services);
                            final adjustedServices = _applyDurationAdjustments(
                              baseSelectedServices,
                            );
                            final totalDuration = _sumServiceDurations(
                              adjustedServices,
                            );
                            if (totalDuration > Duration.zero) {
                              _end = _start.add(totalDuration);
                            }
                          }
                        });
                        _clearInlineError();
                        state.didChange(_serviceIds);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'SERVIZI',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        errorText: state.errorText,
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: palette.accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                        filled: true,
                        fillColor: palette.inputBg,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: palette.accent,
                            width: 1.2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.chevron_left_rounded,
                          color: palette.textPrimary,
                        ),
                        suffixIcon: SizedBox(
                          width: 86,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chevron_right_rounded,
                                color: palette.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: palette.accentSectionBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.segment_rounded,
                                  size: 17,
                                  color: palette.accentOnSection,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      isEmpty: selectedNames.isEmpty,
                      child:
                          selectedNames.isEmpty
                              ? Text(
                                'Seleziona uno o più servizi',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                              : _buildReorderableServiceChips(
                                theme,
                                selectedServices,
                              ),
                    ),
                  );
                },
              ),
              if (showPackageSection) ...[
                const SizedBox(height: 12),
                _buildPackageSection(
                  theme: theme,
                  selectedServices: selectedServices,
                  packagesByService: packagesByService,
                  allClientPackages: allClientPackages,
                ),
              ],
            ],
          ),
        );

        final scheduleSection = _buildDetailSectionCard(
          icon: Icons.schedule_rounded,
          title: 'Orario',
          trailing: _buildDurationBadge(durationMinutes: durationMinutes),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildScheduleCard(
                startTimeLabel: startTimeLabel,
                endTimeLabel: endTimeLabel,
                baseServices: baseSelectedServices,
              ),
              if (baseSelectedServices.length > 1) ...[
                const SizedBox(height: 12),
                _buildServiceDurationAdjustmentPanel(
                  baseServices: baseSelectedServices,
                  adjustedServices: selectedServices,
                ),
              ],
              if (closureConflicts.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...closureConflicts.map(
                  (closure) => _buildClosureNotice(
                    context: context,
                    message: _describeClosure(closure),
                  ),
                ),
              ],
            ],
          ),
        );

        final notesSection = _buildDetailSectionCard(
          icon: Icons.sticky_note_2_rounded,
          title: 'Note appuntamento',
          child: TextField(
            controller: _notes,
            minLines: 6,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: 'Aggiungi note o dettagli aggiuntivi...',
              alignLabelWithHint: true,
              filled: true,
              fillColor: palette.inputBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: palette.accent, width: 1.2),
              ),
            ),
          ),
        );
        final formContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            summaryCard,
            if (_inlineErrorMessage != null) ...[
              const SizedBox(height: 12),
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
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
            const SizedBox(height: 14),
            if (isSingleColumnLayout)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  clientSection,
                  const SizedBox(height: 12),
                  serviceSection,
                  const SizedBox(height: 12),
                  scheduleSection,
                  const SizedBox(height: 12),
                  notesSection,
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        clientSection,
                        const SizedBox(height: 12),
                        scheduleSection,
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        serviceSection,
                        const SizedBox(height: 12),
                        notesSection,
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
          ],
        );
        final actionButtons = _buildActionButtons(
          context,
          statusItems,
          isFutureStart,
          isCompactWidth: isCompactWidth,
          isEditing: isEditing,
        );
        final mobileStatusSection = _buildDetailSectionCard(
          icon: Icons.flag_rounded,
          title: 'Stato appuntamento',
          child: _buildStatusField(statusItems, isFutureStart),
        );

        if (mobileStandalone) {
          final mobileActions = <Widget>[
            if (isEditing)
              PopupMenuButton<_AppointmentMobileAction>(
                tooltip: 'Azioni',
                onSelected: (value) {
                  switch (value) {
                    case _AppointmentMobileAction.copy:
                      _copy();
                      break;
                    case _AppointmentMobileAction.delete:
                      _confirmDelete();
                      break;
                  }
                },
                itemBuilder: (context) {
                  return [
                    const PopupMenuItem(
                      value: _AppointmentMobileAction.copy,
                      child: Text('Copia appuntamento'),
                    ),
                    if (widget.enableDelete && widget.initial != null)
                      const PopupMenuItem(
                        value: _AppointmentMobileAction.delete,
                        child: Text('Elimina appuntamento'),
                      ),
                  ];
                },
              ),
            TextButton(
              onPressed: _isDeleting ? null : _submit,
              child: const Text('Salva'),
            ),
          ];
          return AppMobileSheetPageScaffold(
            title: appointmentTitle,
            subtitle: bookingDateLabel,
            backgroundColor: palette.modalBg,
            actions: mobileActions,
            body: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  summaryCard,
                  if (_inlineErrorMessage != null) ...[
                    const SizedBox(height: 12),
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
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onErrorContainer,
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
                  mobileStatusSection,
                  const SizedBox(height: 12),
                  clientSection,
                  const SizedBox(height: 12),
                  serviceSection,
                  const SizedBox(height: 12),
                  scheduleSection,
                  const SizedBox(height: 12),
                  notesSection,
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        }

        if (isPhoneLayout) {
          final inlineActionButtons = Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.border)),
            ),
            child: actionButtons,
          );
          return ColoredBox(
            color: palette.modalBg,
            child: SizedBox.expand(
              child: Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    formContent,
                    const SizedBox(height: 16),
                    inlineActionButtons,
                  ],
                ),
              ),
            ),
          );
        }
        return SafeArea(
          top: false,
          child: Container(
            color: palette.modalBg,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [formContent],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: palette.border)),
                      ),
                      child: actionButtons,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    List<DropdownMenuItem<AppointmentStatus>> statusItems,
    bool isFutureStart, {
    required bool isCompactWidth,
    required bool isEditing,
  }) {
    final deleteEnabled = widget.enableDelete && widget.initial != null;
    final statusField = _buildStatusField(statusItems, isFutureStart);
    final primaryActionStyle = FilledButton.styleFrom(
      backgroundColor: _kFigmaGoldStrong,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
    final copyLabel = _copyJustCompleted ? 'Copiato!' : 'Copia';
    final copyIcon =
        _copyJustCompleted ? Icons.check_rounded : Icons.content_copy_rounded;
    final copyButton = FilledButton.icon(
      style: primaryActionStyle,
      onPressed: _isDeleting ? null : _copy,
      icon: Icon(copyIcon),
      label: Text(copyLabel),
    );
    final saveButton = FilledButton.icon(
      style: primaryActionStyle,
      onPressed: _isDeleting ? null : _submit,
      icon: const Icon(Icons.save_outlined),
      label: const Text('Salva'),
    );
    final footerActions = <Widget>[
      if (!isEditing)
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _notes,
          builder: (context, value, _) {
            return FilledButton.icon(
              style: primaryActionStyle,
              onPressed: _isDeleting ? null : _showNotesDialog,
              icon: const Icon(Icons.note_alt_rounded),
              label: const Text('Nota'),
            );
          },
        ),
      copyButton,
      saveButton,
    ];

    if (isCompactWidth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: statusField,
                ),
              ),
              if (deleteEnabled)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Elimina',
                    color: _kFigmaDanger,
                    onPressed: _isDeleting ? null : _confirmDelete,
                    icon:
                        _isDeleting
                            ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.delete_outline_rounded),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: footerActions,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child:
                deleteEnabled
                    ? TextButton.icon(
                      onPressed: _isDeleting ? null : _confirmDelete,
                      icon:
                          _isDeleting
                              ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.delete_outline_rounded),
                      label: Text(_isDeleting ? 'Eliminazione...' : 'Elimina'),
                      style: TextButton.styleFrom(
                        foregroundColor: _kFigmaDanger,
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ),
        Expanded(
          child: Center(child: SizedBox(width: 240, child: statusField)),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: footerActions,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusField(
    List<DropdownMenuItem<AppointmentStatus>> statusItems,
    bool isFutureStart,
  ) {
    final palette = _AppointmentFormPalette.fromTheme(Theme.of(context));
    return DropdownButtonFormField<AppointmentStatus>(
      initialValue: _status,
      decoration: InputDecoration(
        labelText: 'Stato',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(
          color: palette.accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
        filled: true,
        fillColor: palette.inputBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.accent, width: 1.2),
        ),
      ),
      isExpanded: true,
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
    );
  }

  Future<void> _showNotesDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return _NotesDialog(initialText: _notes.text);
      },
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _notes.text = result;
    });
  }

  Widget _buildDetailSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final palette = _AppointmentFormPalette.fromTheme(theme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shouldStackTrailing =
              trailing != null && constraints.maxWidth < 720;
          final titleRow = Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: palette.accentSectionBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: palette.accentOnSection),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (!shouldStackTrailing && trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(child: trailing),
              ],
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleRow,
              if (shouldStackTrailing) ...[
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: trailing),
              ],
              const SizedBox(height: 12),
              child,
            ],
          );
        },
      ),
    );
  }

  Widget _buildDurationBadge({required int durationMinutes}) {
    final theme = Theme.of(context);
    final palette = _AppointmentFormPalette.fromTheme(theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.accentSectionBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 16,
            color: palette.accentOnSection,
          ),
          const SizedBox(width: 4),
          Text(
            '$durationMinutes min',
            style: theme.textTheme.labelLarge?.copyWith(
              color: palette.accentOnSection,
              fontWeight: FontWeight.w700,
            ),
          ),
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
    final palette = _AppointmentFormPalette.fromTheme(theme);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: palette.packageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.accent.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: palette.accentStrong),
              const SizedBox(width: 8),
              Text(
                'Pacchetti disponibili',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: palette.accentStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
    required String startTimeLabel,
    required String endTimeLabel,
    required List<Service> baseServices,
  }) {
    final theme = Theme.of(context);
    final palette = _AppointmentFormPalette.fromTheme(theme);
    final adjustedServices = _applyDurationAdjustments(baseServices);
    final totalDuration = _sumServiceDurations(adjustedServices);
    final canDecreaseDuration = totalDuration > _minTotalDuration;
    final lastAdjustableIndex = adjustedServices.lastIndexWhere(
      (service) => service.totalDuration > Duration.zero,
    );
    final Service? decreaseTarget =
        lastAdjustableIndex == -1 ? null : baseServices[lastAdjustableIndex];
    final Service? increaseTarget =
        baseServices.isNotEmpty ? baseServices.last : null;
    final canDecreaseLastService =
        canDecreaseDuration && decreaseTarget != null;
    final canIncreaseLastService = increaseTarget != null;
    void adjustLastService(int delta) {
      if (delta == 0) return;
      final target = delta < 0 ? decreaseTarget : increaseTarget;
      if (target == null) return;
      _updateServiceDurationDelta(target.id, delta, baseServices);
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
            border: Border.all(color: palette.border),
            color: palette.inputBg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TimelineInfoBox(
                      label: 'ORA DI INIZIO',
                      value: startTimeLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimelineInfoBox(
                      label: 'ORA DI FINE',
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
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDurationAdjustButton(
                        icon: Icons.remove_rounded,
                        enabled: canDecreaseLastService,
                        onPressed:
                            () => adjustLastService(-_slotIntervalMinutes),
                      ),
                      const SizedBox(width: 4),
                      _buildDurationAdjustButton(
                        icon: Icons.add_rounded,
                        enabled: canIncreaseLastService,
                        onPressed:
                            () => adjustLastService(_slotIntervalMinutes),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: palette.accent.withValues(alpha: 0.9),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 18,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tocca per scegliere un altro slot disponibile',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.accent,
                          fontWeight: FontWeight.w600,
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

  Widget _buildDurationAdjustButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final palette = _AppointmentFormPalette.fromTheme(Theme.of(context));
    return Material(
      color: enabled ? palette.controlBg : palette.controlDisabledBg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 17,
            color:
                enabled
                    ? palette.textPrimary
                    : palette.textSecondary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceDurationAdjustmentPanel({
    required List<Service> baseServices,
    required List<Service> adjustedServices,
  }) {
    final palette = _AppointmentFormPalette.fromTheme(Theme.of(context));
    if (baseServices.isEmpty) {
      return const SizedBox.shrink();
    }
    final adjustedById = {
      for (final service in adjustedServices) service.id: service,
    };
    final totalDuration = _sumServiceDurations(adjustedServices);
    final canDecreaseOverall = totalDuration > _minTotalDuration;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: palette.inputBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: palette.border),
          child: ExpansionTile(
            collapsedTextColor: palette.textSecondary,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            leading: Icon(Icons.timeline, color: palette.accent),
            title: Text(
              'Regola durata servizi',
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              'Modifica ogni servizio di ±$_slotIntervalMinutes min',
              style: TextStyle(color: palette.textSecondary),
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
                        onPressed:
                            (adjustedById[baseServices[index].id]
                                                ?.totalDuration ??
                                            baseServices[index].totalDuration) >
                                        Duration.zero &&
                                    canDecreaseOverall
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
                        onPressed:
                            () => _updateServiceDurationDelta(
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
    final adjustment =
        _serviceDurationAdjustments[baseService.id] ?? Duration.zero;
    final adjustedTotal =
        adjustedService?.totalDuration ?? baseService.totalDuration;
    final adjustmentMinutes = adjustment.inMinutes;
    final adjustmentLabel =
        adjustmentMinutes == 0
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
    final selectedServices = _applyDurationAdjustments(baseSelectedServices);
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
        return DialogActionLayout(
          title: 'Orari disponibili',
          subtitle: _capitalize(dayFormat.format(day)),
          actions: const [],
          body: Wrap(
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
    final zoneCategoryIds =
        zoneCategories.map((data) => data.category.id).toSet();
    final zoneCategoryNames =
        zoneCategories
            .map((data) => data.category.name.trim().toLowerCase())
            .where((name) => name.isNotEmpty)
            .toSet();

    var query = '';
    var searchFieldVersion = 0;
    var workingSelection = List<String>.from(initialSelection);
    var selectedZoneCategoryId =
        zoneCategories.isNotEmpty ? zoneCategories.first.category.id : '';
    var activeTabIndex = 0;
    final result = await showAppModalSheet<List<String>>(
      context: context,
      includeCloseButton: false,
      builder: (context) {
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

            final listableServices =
                sortedServices.where((service) {
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
            final mediaQuery = MediaQuery.of(context);
            final modalMaxHeight =
                mediaQuery.size.height *
                (mediaQuery.size.width < 600 ? 0.9 : 0.82);
            final bodyMaxHeight =
                (modalMaxHeight - 190.0).clamp(240.0, 620.0).toDouble();
            const serviceSearchFieldHeight = kMinInteractiveDimension;
            const serviceSearchSpacing = 16.0;
            const emptyServiceStateHeight = 120.0;
            const minServiceTabHeight = 168.0;
            final serviceTabChromeHeight =
                serviceSearchFieldHeight + serviceSearchSpacing;
            final maxListViewportHeight =
                (bodyMaxHeight - serviceTabChromeHeight)
                    .clamp(emptyServiceStateHeight, bodyMaxHeight)
                    .toDouble();
            final estimatedListHeight =
                (categories.length * 36.0) + (filtered.length * 72.0);
            final listViewportHeight =
                (filtered.isEmpty
                        ? emptyServiceStateHeight
                        : estimatedListHeight)
                    .clamp(emptyServiceStateHeight, maxListViewportHeight)
                    .toDouble();
            final serviceTabHeight =
                (serviceTabChromeHeight + listViewportHeight)
                    .clamp(minServiceTabHeight, bodyMaxHeight)
                    .toDouble();
            final zoneTabHeight = bodyMaxHeight;
            final activeTabHeight =
                hasZoneTab && activeTabIndex == 1
                    ? zoneTabHeight
                    : serviceTabHeight;

            Widget buildServiceListTab() {
              return Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    key: ValueKey(searchFieldVersion),
                    initialValue: query,
                    decoration: InputDecoration(
                      labelText: 'Cerca servizio',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon:
                          query.isEmpty
                              ? null
                              : IconButton(
                                tooltip: 'Pulisci ricerca',
                                icon: const Icon(Icons.clear_rounded),
                                onPressed:
                                    () => setModalState(() {
                                      query = '';
                                      searchFieldVersion += 1;
                                    }),
                              ),
                    ),
                    onChanged: (value) => setModalState(() => query = value),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child:
                        filtered.isEmpty
                            ? Center(
                              child: Text(
                                'Nessun servizio trovato',
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                            : ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: const ClampingScrollPhysics(),
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
                                      final selected = workingSelection
                                          .contains(service.id);
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
                                        onChanged:
                                            (_) => toggleSelection(service.id),
                                        dense: true,
                                        title: Text(service.name),
                                        subtitle:
                                            subtitle != null
                                                ? Text(subtitle)
                                                : null,
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
                                                      .withValues(alpha: 0.6),
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
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: modalMaxHeight),
                child: DialogActionLayout(
                  title: 'Seleziona servizi',
                  subtitle:
                      selectedStaff == null
                          ? null
                          : 'Operatore: ${selectedStaff.fullName}',
                  trailing: TextButton(
                    onPressed:
                        workingSelection.isEmpty
                            ? null
                            : () => setModalState(
                              () => workingSelection = const [],
                            ),
                    child: const Text('Pulisci'),
                  ),
                  scrollBody: false,
                  bodyPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  body: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasZoneTab)
                          Material(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            child: TabBar(
                              onTap:
                                  (index) => setModalState(
                                    () => activeTabIndex = index,
                                  ),
                              labelColor: theme.colorScheme.primary,
                              indicatorColor: theme.colorScheme.primary,
                              unselectedLabelColor: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                              tabs: const [
                                Tab(text: 'Elenco servizi'),
                                Tab(text: 'Servizi a zona'),
                              ],
                            ),
                          ),
                        if (hasZoneTab) const SizedBox(height: 12),
                        Expanded(
                          child: SizedBox(
                            height: activeTabHeight,
                            child:
                                hasZoneTab
                                    ? TabBarView(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      children: [
                                        buildServiceListTab(),
                                        buildZoneTab(),
                                      ],
                                    )
                                    : buildServiceListTab(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  footer: Row(
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
                  actions: const [],
                ),
              ),
            );
          },
        );
      },
    );
    return result;
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
    _lastSavedClientId = appointment.clientId;
    final copied = appointment.copyWith(
      id: _uuid.v4(),
      status: AppointmentStatus.scheduled,
      notes: null,
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
      messenger.showAppSnackBar(
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
      messenger.showAppSnackBar(SnackBar(content: Text(message)));
      setState(() => _isDeleting = false);
    } on StateError catch (error) {
      if (!mounted) return;
      messenger.showAppSnackBar(SnackBar(content: Text(error.message)));
      setState(() => _isDeleting = false);
    } catch (error) {
      if (!mounted) return;
      messenger.showAppSnackBar(
        SnackBar(content: Text('Errore durante l\'eliminazione: $error')),
      );
      setState(() => _isDeleting = false);
    }
  }

  Future<Client?> _createClient() async {
    if (_salonId == null) {
      _showInlineError(
        'Seleziona un operatore per determinare il salone prima di creare un cliente',
      );
      return null;
    }

    final data = ref.read(appDataProvider);
    final salons = data.salons.isNotEmpty ? data.salons : widget.salons;
    final clients = data.clients.isNotEmpty ? data.clients : widget.clients;

    final newClient = await showAppModalSheet<Client>(
      context: context,
      includeCloseButton: false,
      desktopMaxWidth: 980,
      builder:
          (ctx) => ClientFormSheet(
            salons: salons,
            clients: clients,
            defaultSalonId: _salonId,
          ),
    );

    if (newClient == null) {
      return null;
    }
    if (!mounted) {
      return null;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showAppSnackBar(
      const SnackBar(
        content: Text('Cliente aggiunto. Salvataggio in corso...'),
      ),
    );
    final notifier = ref.read(appDataProvider.notifier);
    Future<void> persistClient() async {
      try {
        final saveResult = await notifier.upsertClient(newClient);
        if (!mounted) return;
        messenger.hideCurrentAppSnackBar();
        final warningMessage = saveResult.warningMessage?.trim();
        messenger.showAppSnackBar(
          SnackBar(
            content: Text(
              warningMessage?.isNotEmpty == true
                  ? warningMessage!
                  : 'Cliente salvato con successo.',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        messenger.hideCurrentAppSnackBar();
        messenger.showAppSnackBar(
          SnackBar(content: Text(formatClientSaveError(error))),
        );
      }
    }

    unawaited(persistClient());
    return newClient;
  }

  Future<void> _selectClient(List<Client> clients) async {
    FocusScope.of(context).unfocus();
    final selectedClient = await showClientSearchSheet(
      context: context,
      clients: clients,
      activeSalonId: _salonId,
      selectedClientId: _clientId,
      allowCreate: true,
      onCreateRequested: _createClient,
    );
    if (!mounted || selectedClient == null) {
      return;
    }
    _applyClientSelection(selectedClient);
  }

  bool _usesDesktopInlineClientSearch(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 1024;
  }

  Widget _buildClientSelectionBody(List<Client> clients) {
    return FormField<String>(
      key: _clientFieldKey,
      validator: (_) => _clientId == null ? 'Scegli un cliente' : null,
      builder: (state) {
        final selectedClient = widget.clients.firstWhereOrNull(
          (client) => client.id == _clientId,
        );
        if (_usesDesktopInlineClientSearch(context)) {
          return _buildDesktopClientSelection(
            clients: clients,
            selectedClient: selectedClient,
            errorText: state.errorText,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedClient == null)
              _buildEmptyClientState(
                errorText: state.errorText,
                clients: clients,
              )
            else
              _buildSelectedClientState(
                selectedClient,
                errorText: state.errorText,
                clients: clients,
              ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopClientSelection({
    required List<Client> clients,
    required Client? selectedClient,
    String? errorText,
  }) {
    final theme = Theme.of(context);
    final hasSelection = selectedClient != null;
    final clientNumberText = selectedClient?.clientNumber?.trim() ?? '';
    final clientField =
        hasSelection
            ? InputDecorator(
              decoration: InputDecoration(
                labelText: 'Cliente',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                errorText: errorText,
                isDense: true,
                filled: true,
                fillColor: _kFigmaInputBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kFigmaBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kFigmaGold, width: 1.2),
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
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: _kFigmaTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Apri scheda cliente',
                        icon: const Icon(Icons.open_in_new_rounded),
                        onPressed: () => _openClientDetails(selectedClient),
                      ),
                      IconButton(
                        tooltip: 'Note cliente',
                        icon: const Icon(Icons.sticky_note_2_outlined),
                        onPressed: () => _openClientNotes(selectedClient),
                      ),
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
                      child: Text(
                        selectedClient.phone.trim(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _kFigmaTextSecondary,
                        ),
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
                filled: true,
                fillColor: _kFigmaInputBg,
                suffixIcon:
                    _clientSearchController.text.isEmpty
                        ? const Icon(Icons.search_rounded, size: 20)
                        : IconButton(
                          tooltip: 'Pulisci ricerca',
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: _clearClientSearch,
                        ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kFigmaBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kFigmaGold, width: 1.2),
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
              decoration: InputDecoration(
                labelText: 'Numero cliente',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                isDense: true,
                filled: true,
                fillColor: _kFigmaInputBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kFigmaBorder),
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
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: _kFigmaTextPrimary,
                    ),
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
                filled: true,
                fillColor: _kFigmaInputBg,
                suffixIcon:
                    _clientNumberSearchController.text.isEmpty
                        ? const Icon(Icons.search_rounded, size: 20)
                        : IconButton(
                          tooltip: 'Pulisci ricerca',
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: _clearClientNumberSearch,
                        ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kFigmaBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kFigmaGold, width: 1.2),
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
        final fields =
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
            fields,
            if (!hasSelection) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final createdClient = await _createClient();
                  if (!mounted || createdClient == null) {
                    return;
                  }
                  _applyClientSelection(createdClient);
                },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Nuovo cliente'),
              ),
              const SizedBox(height: 8),
              _buildDesktopClientSuggestions(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyClientState({
    required List<Client> clients,
    String? errorText,
  }) {
    final theme = Theme.of(context);
    final palette = _AppointmentFormPalette.fromTheme(theme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: palette.inputBg,
        borderRadius: BorderRadius.circular(14),
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
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Apri la ricerca dedicata per selezionare un cliente esistente oppure creane uno nuovo senza comprimere il form.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _selectClient(clients),
                icon: const Icon(Icons.person_search_rounded),
                label: const Text('Seleziona cliente'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final createdClient = await _createClient();
                  if (!mounted || createdClient == null) {
                    return;
                  }
                  _applyClientSelection(createdClient);
                },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Nuovo cliente'),
              ),
            ],
          ),
          if (errorText != null) ...[
            const SizedBox(height: 10),
            Text(
              errorText,
              style: theme.textTheme.bodySmall?.copyWith(color: palette.danger),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedClientState(
    Client selectedClient, {
    required List<Client> clients,
    String? errorText,
  }) {
    final theme = Theme.of(context);
    final palette = _AppointmentFormPalette.fromTheme(theme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: palette.inputBg,
        borderRadius: BorderRadius.circular(14),
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
                child: Text(_clientInitials(selectedClient)),
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
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (selectedClient.clientNumber != null &&
                            selectedClient.clientNumber!.isNotEmpty)
                          _buildClientInfoPill(
                            label: 'N° ${selectedClient.clientNumber}',
                          ),
                      ],
                    ),
                    if (selectedClient.phone.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          selectedClient.phone.trim(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    if (selectedClient.email != null &&
                        selectedClient.email!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          selectedClient.email!.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.textSecondary,
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
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _selectClient(clients),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Cambia'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openClientDetails(selectedClient),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Apri scheda'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openClientNotes(selectedClient),
                icon: const Icon(Icons.sticky_note_2_outlined),
                label: const Text('Note'),
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
              style: theme.textTheme.bodySmall?.copyWith(color: palette.danger),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClientInfoPill({required String label}) {
    final palette = _AppointmentFormPalette.fromTheme(Theme.of(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.accentSoftBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.accentStrong,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  String _clientInitials(Client client) {
    final trimmed = client.fullName.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  Widget _buildDesktopClientSuggestions() {
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
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    if (_clientSuggestions.isEmpty) {
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
          for (var i = 0; i < _clientSuggestions.length; i++) ...[
            _buildDesktopClientSuggestionTile(_clientSuggestions[i]),
            if (i != _clientSuggestions.length - 1)
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
      leading: CircleAvatar(child: Text(_clientInitials(client))),
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
    if (_clientId == null) {
      return;
    }
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
    if (_usesDesktopInlineClientSearch(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        FocusScope.of(context).requestFocus(_clientSearchFocusNode);
      });
    }
  }

  Future<void> _openClientDetails(Client client) async {
    FocusScope.of(context).unfocus();
    final isCompact = isCompactClientLayout(context);
    final payload = <String, Object?>{'clientId': client.id};
    final clientNumber = client.clientNumber;
    if (clientNumber != null && clientNumber.isNotEmpty) {
      payload['clientNumber'] = clientNumber;
    }
    if (!isCompact) {
      ref
          .read(adminDashboardIntentProvider.notifier)
          .state = AdminDashboardIntent(moduleId: 'clients', payload: payload);
    }
    final opened = await openClientDetailPage(
      context,
      clientId: client.id,
      popCurrent: true,
      compactOnly: true,
    );
    if (!mounted) {
      return;
    }
    if (!opened) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _openClientNotes(Client client) async {
    FocusScope.of(context).unfocus();
    await showAppModalSheet<void>(
      context: context,
      includeCloseButton: false,
      builder: (ctx) {
        return DialogActionLayout(
          title: 'Note cliente',
          body: ClientNotesSection(client: client),
          actions: const [],
        );
      },
    );
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
    _serviceDurationAdjustments.removeWhere(
      (key, _) => !expected.contains(key),
    );
    for (final id in serviceIds) {
      _serviceDurationAdjustments.putIfAbsent(id, () => Duration.zero);
    }
  }

  List<Service> _applyDurationAdjustments(List<Service> services) {
    return services
        .map((service) {
          final adjustment =
              _serviceDurationAdjustments[service.id] ?? Duration.zero;
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
    final currentTotal =
        baseService.duration + baseService.extraDuration + currentAdjustment;
    var deltaDuration = Duration(minutes: deltaMinutes);
    final candidateTotal = currentTotal + deltaDuration;
    if (candidateTotal < Duration.zero) {
      deltaDuration = Duration.zero - currentTotal;
    }
    if (deltaDuration == Duration.zero) {
      return;
    }
    final currentAdjustedServices = _applyDurationAdjustments(baseServices);
    final totalDurationBefore = _sumServiceDurations(currentAdjustedServices);
    if (deltaDuration.isNegative) {
      final allowableDecrease = totalDurationBefore - _minTotalDuration;
      if (allowableDecrease <= Duration.zero) {
        return;
      }
      final requestedDecrease = deltaDuration.abs();
      if (requestedDecrease > allowableDecrease) {
        deltaDuration = -allowableDecrease;
      }
      final adjustedCandidateTotal = currentTotal + deltaDuration;
      if (adjustedCandidateTotal < Duration.zero) {
        deltaDuration = Duration.zero - currentTotal;
      }
      if (deltaDuration == Duration.zero) {
        return;
      }
    }
    final nextAdjustment = currentAdjustment + deltaDuration;
    final newTotal =
        baseService.duration + baseService.extraDuration + nextAdjustment;
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
                  onPressed:
                      index > 0
                          ? () => _reorderService(index, index - 1)
                          : null,
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: theme.iconTheme.color?.withValues(
                      alpha: index > 0 ? 1 : 0.35,
                    ),
                  ),
                ),
                Chip(label: Text(selectedServices[index].name)),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  iconSize: 18,
                  tooltip: 'Sposta avanti',
                  onPressed:
                      index < selectedServices.length - 1
                          ? () => _reorderService(index, index + 1)
                          : null,
                  icon: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: theme.iconTheme.color?.withValues(
                      alpha: index < selectedServices.length - 1 ? 1 : 0.35,
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
    final palette = _AppointmentFormPalette.fromTheme(theme);
    return Container(
      decoration: BoxDecoration(
        color: palette.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  service.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (uncoveredQuantity > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: palette.dangerBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$uncoveredQuantity fuori pacchetto',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (packages.isEmpty)
            Text(
              'Nessun pacchetto compatibile.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
              ),
            )
          else
            Column(
              children: [
                for (final purchase in packages) ...[
                  _PackageSelectionCard(
                    title: purchase.displayName,
                    subtitle: _packageSubtitle(purchase, service.id),
                    selected: selectedPackageId == purchase.item.referenceId,
                    enabled:
                        purchase.remainingSessionsForService(service.id) > 0 ||
                        selectedPackageId == purchase.item.referenceId,
                    recommended:
                        suggestedPackageId == purchase.item.referenceId,
                    onTap:
                        purchase.remainingSessionsForService(service.id) > 0 ||
                                selectedPackageId == purchase.item.referenceId
                            ? () {
                              final packageId = purchase.item.referenceId;
                              final isSelected = selectedPackageId == packageId;
                              onSelect(isSelected ? null : packageId);
                            }
                            : null,
                  ),
                  if (purchase != packages.last) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }

  String _packageSubtitle(ClientPackagePurchase purchase, String serviceId) {
    final remaining = purchase.remainingSessionsForService(serviceId);
    final buffer = StringBuffer('$remaining sessioni disponibili');
    final expiration = purchase.expirationDate;
    if (expiration != null) {
      buffer
        ..write(' • Scade il ')
        ..write(DateFormat('dd/MM/yyyy').format(expiration));
    }
    return buffer.toString();
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
    final palette = _AppointmentFormPalette.fromTheme(theme);
    final borderColor =
        selected ? palette.accentStrong : palette.border.withValues(alpha: 0.9);
    final backgroundColor = selected ? palette.selectedItemBg : palette.inputBg;
    final foregroundColor =
        enabled
            ? palette.textPrimary
            : palette.textSecondary.withValues(alpha: 0.65);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 1.3 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foregroundColor,
                      ),
                    ),
                    if (recommended && !selected) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Suggerito',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.accentStrong,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        selected
                            ? palette.accentStrong
                            : palette.textSecondary.withValues(alpha: 0.45),
                    width: 2,
                  ),
                  color: selected ? palette.accentStrong : Colors.transparent,
                ),
                child:
                    selected
                        ? const Icon(Icons.circle, size: 8, color: Colors.white)
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineInfoBox extends StatelessWidget {
  const _TimelineInfoBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _AppointmentFormPalette.fromTheme(theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: palette.inputBg,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesDialog extends StatefulWidget {
  const _NotesDialog({required this.initialText});

  final String initialText;

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth =
        (MediaQuery.sizeOf(context).width - 48).clamp(280.0, 520.0).toDouble();

    return AlertDialog(
      title: const Text('Note'),
      content: SizedBox(
        width: dialogWidth,
        child: TextField(
          controller: _controller,
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
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Salva nota'),
        ),
      ],
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
