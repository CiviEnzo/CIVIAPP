import 'package:civiapp/app/providers.dart';
import 'package:civiapp/data/repositories/app_data_state.dart';
import 'package:civiapp/domain/availability/appointment_conflicts.dart';
import 'package:civiapp/domain/availability/equipment_availability.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/shift.dart';
import 'package:civiapp/domain/entities/staff_absence.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/shared/client_package_purchase.dart';
import 'package:civiapp/presentation/screens/admin/forms/client_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/client_search_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class AppointmentFormSheet extends ConsumerStatefulWidget {
  const AppointmentFormSheet({
    super.key,
    required this.salons,
    required this.clients,
    required this.staff,
    required this.services,
    this.initial,
    this.defaultSalonId,
    this.defaultClientId,
    this.suggestedStart,
    this.suggestedEnd,
    this.suggestedStaffId,
    this.enableDelete = false,
  });

  final List<Salon> salons;
  final List<Client> clients;
  final List<StaffMember> staff;
  final List<Service> services;
  final Appointment? initial;
  final String? defaultSalonId;
  final String? defaultClientId;
  final DateTime? suggestedStart;
  final DateTime? suggestedEnd;
  final String? suggestedStaffId;
  final bool enableDelete;

  @override
  ConsumerState<AppointmentFormSheet> createState() =>
      _AppointmentFormSheetState();
}

class _AppointmentFormSheetState extends ConsumerState<AppointmentFormSheet> {
  static const _slotIntervalMinutes = 15;
  final _formKey = GlobalKey<FormState>();
  final _clientFieldKey = GlobalKey<FormFieldState<String>>();
  final _uuid = const Uuid();
  late DateTime _start;
  late DateTime _end;
  String? _salonId;
  String? _clientId;
  String? _staffId;
  late List<String> _serviceIds;
  AppointmentStatus _status = AppointmentStatus.scheduled;
  late TextEditingController _notes;
  bool _usePackageSession = false;
  String? _selectedPackageId;
  bool _packageSelectionManuallyChanged = false;
  bool _isDeleting = false;

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
    _selectedPackageId = initial?.packageId;
    _usePackageSession = _selectedPackageId != null;
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
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy HH:mm', 'it_IT');
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
          _usePackageSession = false;
          _selectedPackageId = null;
          _packageSelectionManuallyChanged = false;
        });
      });
    }
    final selectedServices =
        services.where((service) => _serviceIds.contains(service.id)).toList();
    final singleSelectedService =
        selectedServices.length == 1 ? selectedServices.first : null;
    final filteredStaff =
        staffMembers.where((member) {
          if (_salonId != null && member.salonId != _salonId) {
            return false;
          }
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

    var packagesForService = <ClientPackagePurchase>[];
    ClientPackagePurchase? selectedPackage;
    String? packageSubtitle;
    bool canEnablePackage = false;
    String? fallbackPackageId;
    var eligiblePackages = <ClientPackagePurchase>[];
    var dropdownPackages = <ClientPackagePurchase>[];

    final staffFieldValue =
        _staffId != null && filteredStaff.any((member) => member.id == _staffId)
            ? _staffId
            : null;

    final now = DateTime.now();
    final isFutureStart = _start.isAfter(now);
    final statusItems =
        AppointmentStatus.values.map((status) {
          final isDisabled =
              isFutureStart && status == AppointmentStatus.completed;
          final label =
              isDisabled
                  ? '${_statusLabel(status)} (non disponibile per appuntamenti futuri)'
                  : _statusLabel(status);
          return DropdownMenuItem<AppointmentStatus>(
            value: status,
            enabled: !isDisabled,
            child: Text(label),
          );
        }).toList();

    if (selectedClient == null || singleSelectedService == null) {
      if (_usePackageSession || _selectedPackageId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _usePackageSession = false;
            _selectedPackageId = null;
            _packageSelectionManuallyChanged = false;
          });
        });
      }
    } else {
      final packagePurchases = resolveClientPackagePurchases(
        sales: data.sales,
        packages: data.packages,
        appointments: data.appointments,
        services: allServices,
        clientId: selectedClient.id,
        salonId: selectedClient.salonId,
      );
      packagesForService = _dedupePurchasesByReferenceId(
        packagePurchases
            .where(
              (purchase) =>
                  purchase.supportsService(singleSelectedService.id) &&
                  (purchase.effectiveRemainingSessions > 0 ||
                      purchase.item.referenceId == _selectedPackageId),
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

      eligiblePackages = _dedupePurchasesByReferenceId(
        packagesForService
            .where((purchase) => purchase.effectiveRemainingSessions > 0)
            .toList(),
      );

      final assignedPackage =
          _selectedPackageId != null
              ? packagePurchases.firstWhereOrNull(
                (purchase) => purchase.item.referenceId == _selectedPackageId,
              )
              : null;
      if (assignedPackage != null &&
          packagesForService.every(
            (purchase) =>
                purchase.item.referenceId != assignedPackage.item.referenceId,
          )) {
        packagesForService.insert(0, assignedPackage);
      }

      fallbackPackageId =
          packagesForService
              .firstWhereOrNull(
                (purchase) => purchase.effectiveRemainingSessions > 0,
              )
              ?.item
              .referenceId ??
          (packagesForService.isNotEmpty
              ? packagesForService.first.item.referenceId
              : null);

      if (_usePackageSession) {
        final availableIds =
            packagesForService
                .map((purchase) => purchase.item.referenceId)
                .toSet();
        if (packagesForService.isEmpty ||
            !availableIds.contains(_selectedPackageId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              if (fallbackPackageId == null) {
                _usePackageSession = false;
                _selectedPackageId = null;
                _packageSelectionManuallyChanged = false;
              } else {
                _selectedPackageId = fallbackPackageId;
              }
            });
          });
        }
      }

      selectedPackage =
          packagesForService.firstWhereOrNull(
            (purchase) => purchase.item.referenceId == _selectedPackageId,
          ) ??
          (packagesForService.isNotEmpty ? packagesForService.first : null);

      dropdownPackages = _dedupePurchasesByReferenceId(
        List<ClientPackagePurchase>.from(eligiblePackages),
      );
      if (selectedPackage != null) {
        final activeSelection = selectedPackage;
        if (dropdownPackages.every(
          (purchase) =>
              purchase.item.referenceId != activeSelection.item.referenceId,
        )) {
          dropdownPackages.insert(0, activeSelection);
        }
      }

      if (packagesForService.isNotEmpty) {
        if (_usePackageSession) {
          final activePackage = selectedPackage;
          if (activePackage != null) {
            packageSubtitle =
                '${activePackage.displayName} • ${activePackage.effectiveRemainingSessions} sessioni disponibili';
          }
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
      }

      canEnablePackage = packagesForService.any(
        (purchase) => purchase.effectiveRemainingSessions > 0,
      );

      // Prefer consuming a package session by default when one is available
      // unless the operator explicitly disables it.
      if (canEnablePackage &&
          !_usePackageSession &&
          !_packageSelectionManuallyChanged) {
        final autoPackageId = fallbackPackageId;
        if (autoPackageId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _usePackageSession = true;
              _selectedPackageId = autoPackageId;
            });
          });
        }
      }

      if (!canEnablePackage && _usePackageSession) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _usePackageSession = false;
            _packageSelectionManuallyChanged = false;
          });
        });
      }
    }

    final showPackageSection =
        selectedClient != null &&
        singleSelectedService != null &&
        packagesForService.isNotEmpty;

    final closureConflicts =
        selectedSalon == null
            ? const <SalonClosure>[]
            : _findOverlappingClosures(
              closures: selectedSalon.closures,
              start: _start,
              end: _end,
            );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null
                  ? 'Nuovo appuntamento'
                  : 'Modifica appuntamento',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _salonId,
              decoration: const InputDecoration(labelText: 'Salone'),
              items:
                  salons
                      .map(
                        (salon) => DropdownMenuItem(
                          value: salon.id,
                          child: Text(salon.name),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _salonId = value;
                  _clientId = null;
                  _staffId = null;
                  _serviceIds = const [];
                  _usePackageSession = false;
                  _selectedPackageId = null;
                  _packageSelectionManuallyChanged = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _clientFieldKey.currentState?.didChange(_clientId);
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FormField<String>(
                    key: _clientFieldKey,
                    validator:
                        (_) => _clientId == null ? 'Scegli un cliente' : null,
                    builder: (state) {
                      final selectedClient = clients.firstWhereOrNull(
                        (client) => client.id == _clientId,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _selectClient(filteredClients),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Cliente',
                                errorText: state.errorText,
                                suffixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                ),
                              ),
                              isEmpty: selectedClient == null,
                              child: Text(
                                selectedClient?.fullName ?? 'Seleziona cliente',
                                style:
                                    selectedClient == null
                                        ? Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).hintColor,
                                        )
                                        : Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _createClient,
                  tooltip: 'Nuovo cliente',
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: staffFieldValue,
              decoration: const InputDecoration(labelText: 'Operatore'),
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
                setState(() {
                  _staffId = value;
                  if (value == null) {
                    return;
                  }
                  final staffMember = staffMembers.firstWhereOrNull(
                    (member) => member.id == value,
                  );
                  if (staffMember == null) {
                    _serviceIds = const [];
                    _usePackageSession = false;
                    _selectedPackageId = null;
                    _packageSelectionManuallyChanged = false;
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
                    _usePackageSession = false;
                    _selectedPackageId = null;
                    _packageSelectionManuallyChanged = false;
                  }
                });
              },
              validator:
                  (value) => value == null ? 'Scegli un operatore' : null,
            ),
            const SizedBox(height: 12),
            FormField<List<String>>(
              validator:
                  (_) =>
                      _serviceIds.isEmpty ? 'Scegli almeno un servizio' : null,
              builder: (state) {
                final theme = Theme.of(context);
                final selectedNames =
                    selectedServices.map((service) => service.name).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final selection = await _openServicePicker(
                          context,
                          services: filteredServices,
                          selectedStaff: staffMembers.firstWhereOrNull(
                            (member) => member.id == _staffId,
                          ),
                        );
                        if (selection != null) {
                          setState(() {
                            _serviceIds = selection;
                            _usePackageSession = false;
                            _selectedPackageId = null;
                            _packageSelectionManuallyChanged = false;
                            if (_serviceIds.isNotEmpty) {
                              final durations = services
                                  .where(
                                    (service) =>
                                        _serviceIds.contains(service.id),
                                  )
                                  .map((service) => service.totalDuration)
                                  .fold(
                                    Duration.zero,
                                    (acc, value) => acc + value,
                                  );
                              if (!durations.isNegative &&
                                  durations > Duration.zero) {
                                _end = _start.add(durations);
                              }
                            }
                          });
                          state.didChange(_serviceIds);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Servizi',
                          errorText: state.errorText,
                          suffixIcon: const Icon(Icons.segment_rounded),
                        ),
                        isEmpty: selectedNames.isEmpty,
                        child:
                            selectedNames.isEmpty
                                ? Text(
                                  'Seleziona uno o più servizi',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.hintColor,
                                  ),
                                )
                                : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      selectedServices
                                          .map(
                                            (service) =>
                                                Chip(label: Text(service.name)),
                                          )
                                          .toList(),
                                ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (showPackageSection) ...[
              Text(
                'Sessioni pacchetto disponibili',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _usePackageSession,
                onChanged:
                    canEnablePackage
                        ? (checked) {
                          setState(() {
                            _packageSelectionManuallyChanged = true;
                            _usePackageSession = checked ?? false;
                            if (_usePackageSession) {
                              final fallback =
                                  fallbackPackageId ??
                                  (eligiblePackages.isNotEmpty
                                      ? eligiblePackages.first.item.referenceId
                                      : null);
                              if (fallback == null) {
                                _usePackageSession = false;
                                _selectedPackageId = null;
                                _packageSelectionManuallyChanged = false;
                              } else {
                                _selectedPackageId = fallback;
                              }
                            } else {
                              _selectedPackageId = null;
                            }
                          });
                        }
                        : null,
                title: const Text('Scala una sessione da un pacchetto'),
                subtitle:
                    packageSubtitle != null ? Text(packageSubtitle) : null,
              ),
              if (_usePackageSession && dropdownPackages.length > 1) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedPackageId,
                  decoration: const InputDecoration(
                    labelText: 'Seleziona il pacchetto da utilizzare',
                  ),
                  items:
                      dropdownPackages
                          .map(
                            (purchase) => DropdownMenuItem(
                              value: purchase.item.referenceId,
                              child: Text(
                                '${purchase.displayName} • ${purchase.effectiveRemainingSessions} sessioni',
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) => setState(() {
                        _selectedPackageId = value;
                      }),
                ),
              ],
              const SizedBox(height: 12),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data e ora di inizio'),
              subtitle: Text(dateFormat.format(_start)),
              trailing: const Icon(Icons.calendar_today_rounded),
              onTap: _pickStart,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data e ora di fine'),
              subtitle: Text(dateFormat.format(_end)),
              trailing: const Icon(Icons.schedule_rounded),
              onTap: _pickEnd,
            ),
            if (closureConflicts.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...closureConflicts.map(
                (closure) => _buildClosureNotice(
                  context: context,
                  message: _describeClosure(closure),
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<AppointmentStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Stato'),
              items: statusItems,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                if (isFutureStart && value == AppointmentStatus.completed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Non puoi impostare lo stato "Completato" per un appuntamento futuro.',
                      ),
                    ),
                  );
                  return;
                }
                setState(() => _status = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Note'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.enableDelete && widget.initial != null) ...[
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
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const Spacer(),
                ] else
                  const Spacer(),
                FilledButton(
                  onPressed: _isDeleting ? null : _submit,
                  child: const Text('Salva'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart() async {
    if (_salonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona un salone prima di scegliere l\'orario.'),
        ),
      );
      return;
    }
    if (_staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona un operatore prima di scegliere l\'orario.'),
        ),
      );
      return;
    }
    if (_serviceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seleziona almeno un servizio prima di scegliere l\'orario.',
          ),
        ),
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
    final selectedServices =
        services.where((item) => _serviceIds.contains(item.id)).toList();
    if (staffMember == null || selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operatore o servizi non validi.')),
      );
      return;
    }
    final totalDuration = selectedServices.fold<Duration>(
      Duration.zero,
      (acc, service) => acc + service.totalDuration,
    );
    if (totalDuration <= Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Durata complessiva servizi non valida.')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nessuno slot disponibile per l\'operatore nella data selezionata.',
            ),
          ),
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
          for (final service in services) {
            final equipmentCheck = EquipmentAvailabilityChecker.check(
              salon: salon,
              service: service,
              allServices: allServices,
              appointments: allAppointments,
              start: slotStart,
              end: slotEnd,
              excludeAppointmentId: excludeAppointmentId,
            );
            if (equipmentCheck.hasConflicts) {
              blockingEquipment.addAll(equipmentCheck.blockingEquipment);
            }
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
    StaffMember? selectedStaff,
  }) async {
    if (services.isEmpty) {
      return const <String>[];
    }
    final initialSelection = List<String>.from(_serviceIds);
    final sortedServices = List<Service>.from(services)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final theme = Theme.of(context);

    final searchController = TextEditingController();
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        var query = '';
        var workingSelection = List<String>.from(initialSelection);
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

            final lowerQuery = query.trim().toLowerCase();
            final filtered =
                lowerQuery.isEmpty
                    ? sortedServices
                    : sortedServices
                        .where(
                          (service) =>
                              service.name.toLowerCase().contains(lowerQuery),
                        )
                        .toList();
            final grouped = groupBy<Service, String>(filtered, (service) {
              final label = service.category.trim();
              if (label.isNotEmpty) return label;
              return 'Altri servizi';
            });
            final categories =
                grouped.keys.toList()
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
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
                                      'Durata ${durationMinutes} min',
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
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_salonId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleziona un salone')));
      return;
    }

    if (_usePackageSession && _selectedPackageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona il pacchetto da utilizzare')),
      );
      return;
    }

    final data = ref.read(appDataProvider);
    final salons = data.salons.isNotEmpty ? data.salons : widget.salons;
    final allServices =
        data.services.isNotEmpty ? data.services : widget.services;
    final services = allServices;
    final staffMembers = data.staff.isNotEmpty ? data.staff : widget.staff;

    final selectedServices =
        services.where((item) => _serviceIds.contains(item.id)).toList();
    if (selectedServices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Servizi non validi.')));
      return;
    }

    final staffMember = staffMembers.firstWhereOrNull(
      (member) => member.id == _staffId,
    );
    if (staffMember == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Operatore non valido.')));
      return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'L\'operatore selezionato non può erogare "${incompatibleService.name}".',
          ),
        ),
      );
      return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Il salone è chiuso in questo orario. $firstConflict'),
        ),
      );
      return;
    }

    final appointment = Appointment(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      clientId: _clientId!,
      staffId: _staffId!,
      serviceIds: _serviceIds,
      start: _start,
      end: _end,
      status: _status,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      packageId: _usePackageSession ? _selectedPackageId : null,
      roomId: widget.initial?.roomId,
    );

    if (appointment.start.isAfter(DateTime.now()) &&
        appointment.status == AppointmentStatus.completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Non puoi impostare lo stato "Completato" per un appuntamento futuro.',
          ),
        ),
      );
      return;
    }

    final existingAppointments = data.appointments;
    final hasStaffConflict = hasStaffBookingConflict(
      appointments: existingAppointments,
      staffId: appointment.staffId,
      start: appointment.start,
      end: appointment.end,
      excludeAppointmentId: appointment.id,
    );
    if (hasStaffConflict) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile salvare: operatore già occupato in quel periodo',
          ),
        ),
      );
      return;
    }

    final hasClientConflict = hasClientBookingConflict(
      appointments: existingAppointments,
      clientId: appointment.clientId,
      start: appointment.start,
      end: appointment.end,
      excludeAppointmentId: appointment.id,
    );
    if (hasClientConflict) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile salvare: il cliente ha già un appuntamento in quel periodo',
          ),
        ),
      );
      return;
    }

    final blockingEquipment = <String>{};
    for (final service in selectedServices) {
      final equipmentCheck = EquipmentAvailabilityChecker.check(
        salon: selectedSalon,
        service: service,
        allServices: allServices,
        appointments: existingAppointments,
        start: appointment.start,
        end: appointment.end,
        excludeAppointmentId: appointment.id,
      );
      if (equipmentCheck.hasConflicts) {
        blockingEquipment.addAll(equipmentCheck.blockingEquipment);
      }
    }
    if (blockingEquipment.isNotEmpty) {
      final equipmentLabel = blockingEquipment.join(', ');
      final message =
          equipmentLabel.isEmpty
              ? 'Macchinario non disponibile per questo orario.'
              : 'Macchinario non disponibile per questo orario: $equipmentLabel.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$message Scegli un altro slot.')));
      return;
    }

    Navigator.of(context).pop(appointment);
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
      Navigator.of(context).pop();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona un salone prima di creare un cliente'),
        ),
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
      await ref.read(appDataProvider.notifier).upsertClient(newClient);
      if (!mounted) return;
      setState(() {
        _clientId = newClient.id;
        _usePackageSession = false;
        _selectedPackageId = null;
        _packageSelectionManuallyChanged = false;
      });
      _clientFieldKey.currentState?.didChange(newClient.id);
    }
  }

  Future<void> _selectClient(List<Client> clients) async {
    final selected = await showAppModalSheet<Client>(
      context: context,
      builder: (ctx) => ClientSearchSheet(clients: clients),
    );

    if (selected != null) {
      if (!mounted) return;
      setState(() {
        _clientId = selected.id;
        _usePackageSession = false;
        _selectedPackageId = null;
        _packageSelectionManuallyChanged = false;
      });
      _clientFieldKey.currentState?.didChange(selected.id);
    }
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

  String _statusLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return 'Programmato';
      case AppointmentStatus.confirmed:
        return 'Confermato';
      case AppointmentStatus.completed:
        return 'Completato';
      case AppointmentStatus.cancelled:
        return 'Annullato';
      case AppointmentStatus.noShow:
        return 'No show';
    }
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
