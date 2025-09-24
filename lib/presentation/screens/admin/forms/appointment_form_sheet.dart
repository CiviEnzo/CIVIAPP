import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/availability/appointment_conflicts.dart';
import 'package:civiapp/domain/availability/equipment_availability.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/shared/client_package_purchase.dart';
import 'package:civiapp/presentation/screens/admin/forms/client_form_sheet.dart';
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
  final DateTime? suggestedStart;
  final DateTime? suggestedEnd;
  final String? suggestedStaffId;
  final bool enableDelete;

  @override
  ConsumerState<AppointmentFormSheet> createState() =>
      _AppointmentFormSheetState();
}

class _AppointmentFormSheetState extends ConsumerState<AppointmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late DateTime _start;
  late DateTime _end;
  String? _salonId;
  String? _clientId;
  String? _staffId;
  String? _serviceId;
  AppointmentStatus _status = AppointmentStatus.scheduled;
  late TextEditingController _notes;
  bool _usePackageSession = false;
  String? _selectedPackageId;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _clientId = initial?.clientId;
    _staffId = initial?.staffId ?? widget.suggestedStaffId;
    _serviceId = initial?.serviceId;
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
    final services = data.services.isNotEmpty ? data.services : widget.services;

    final filteredClients =
        clients
            .where((client) => _salonId == null || client.salonId == _salonId)
            .toList();
    final filteredServices =
        services
            .where((service) => _salonId == null || service.salonId == _salonId)
            .toList();
    final selectedService = services.firstWhereOrNull(
      (service) => service.id == _serviceId,
    );
    final filteredStaff =
        staffMembers.where((member) {
          if (_salonId != null && member.salonId != _salonId) {
            return false;
          }
          if (selectedService != null) {
            final allowedRoles = selectedService.staffRoles;
            if (allowedRoles.isNotEmpty &&
                !allowedRoles.contains(member.roleId)) {
              return false;
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

    if (selectedClient == null || selectedService == null) {
      if (_usePackageSession || _selectedPackageId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _usePackageSession = false;
            _selectedPackageId = null;
          });
        });
      }
    } else {
      final packagePurchases = resolveClientPackagePurchases(
        sales: data.sales,
        packages: data.packages,
        appointments: data.appointments,
        services: data.services,
        clientId: selectedClient.id,
        salonId: selectedClient.salonId,
      );
      packagesForService =
          packagePurchases
              .where(
                (purchase) =>
                    purchase.supportsService(selectedService.id) &&
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
            });

      eligiblePackages =
          packagesForService
              .where((purchase) => purchase.effectiveRemainingSessions > 0)
              .toList();

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

      dropdownPackages = List<ClientPackagePurchase>.from(eligiblePackages);
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

      if (!canEnablePackage && _usePackageSession) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _usePackageSession = false;
          });
        });
      }
    }

    final showPackageSection =
        selectedClient != null &&
        selectedService != null &&
        packagesForService.isNotEmpty;

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
              onChanged:
                  (value) => setState(() {
                    _salonId = value;
                    _clientId = null;
                    _staffId = null;
                    _serviceId = null;
                    _usePackageSession = false;
                    _selectedPackageId = null;
                  }),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _clientId,
                    decoration: const InputDecoration(labelText: 'Cliente'),
                    items:
                        filteredClients
                            .map(
                              (client) => DropdownMenuItem(
                                value: client.id,
                                child: Text(client.fullName),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() {
                          _clientId = value;
                          _usePackageSession = false;
                          _selectedPackageId = null;
                        }),
                    validator:
                        (value) => value == null ? 'Scegli un cliente' : null,
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
              onChanged: (value) => setState(() => _staffId = value),
              validator:
                  (value) => value == null ? 'Scegli un operatore' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _serviceId,
              decoration: const InputDecoration(labelText: 'Servizio'),
              items:
                  filteredServices
                      .map(
                        (service) => DropdownMenuItem(
                          value: service.id,
                          child: Text(service.name),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _serviceId = value;
                  _usePackageSession = false;
                  _selectedPackageId = null;
                  if (value != null) {
                    final service = filteredServices.firstWhereOrNull(
                      (srv) => srv.id == value,
                    );
                    if (service != null) {
                      _end = _start.add(service.duration);
                      final allowedRoles = service.staffRoles;
                      if (_staffId != null && allowedRoles.isNotEmpty) {
                        final staffMember = staffMembers.firstWhereOrNull(
                          (member) => member.id == _staffId,
                        );
                        if (staffMember == null ||
                            !allowedRoles.contains(staffMember.roleId)) {
                          _staffId = null;
                        }
                      }
                    }
                  }
                });
              },
              validator: (value) => value == null ? 'Scegli un servizio' : null,
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
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selectedDate == null) return;
    if (!mounted) return;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (selectedTime == null) return;
    if (!mounted) return;
    setState(() {
      _start = DateTime(
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
    final services = data.services.isNotEmpty ? data.services : widget.services;
    final staffMembers = data.staff.isNotEmpty ? data.staff : widget.staff;

    final service = services.firstWhereOrNull((item) => item.id == _serviceId);
    if (service == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Servizio non valido.')));
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

    final allowedRoles = service.staffRoles;
    if (allowedRoles.isNotEmpty && !allowedRoles.contains(staffMember.roleId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L\'operatore selezionato non può erogare il servizio scelto.',
          ),
        ),
      );
      return;
    }

    final appointment = Appointment(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      clientId: _clientId!,
      staffId: _staffId!,
      serviceId: _serviceId!,
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

    final salon = salons.firstWhereOrNull(
      (item) => item.id == appointment.salonId,
    );
    final equipmentCheck = EquipmentAvailabilityChecker.check(
      salon: salon,
      service: service,
      allServices: services,
      appointments: existingAppointments,
      start: appointment.start,
      end: appointment.end,
      excludeAppointmentId: appointment.id,
    );
    if (equipmentCheck.hasConflicts) {
      final equipmentLabel = equipmentCheck.blockingEquipment.join(', ');
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

    final salons =
        ref.read(appDataProvider).salons.isNotEmpty
            ? ref.read(appDataProvider).salons
            : widget.salons;

    final newClient = await showAppModalSheet<Client>(
      context: context,
      builder:
          (ctx) => ClientFormSheet(salons: salons, defaultSalonId: _salonId),
    );

    if (newClient != null) {
      await ref.read(appDataProvider.notifier).upsertClient(newClient);
      if (!mounted) return;
      setState(() {
        _clientId = newClient.id;
      });
    }
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
