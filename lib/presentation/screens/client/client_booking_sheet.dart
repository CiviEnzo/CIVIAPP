import 'package:civiapp/app/providers.dart';
import 'package:civiapp/data/repositories/app_data_state.dart';
import 'package:civiapp/domain/availability/appointment_conflicts.dart';
import 'package:civiapp/domain/availability/equipment_availability.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/client.dart';
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

class ClientBookingSheet extends ConsumerStatefulWidget {
  const ClientBookingSheet({
    super.key,
    required this.client,
    this.initialServiceId,
    this.initialAppointment,
  });

  final Client client;
  final String? initialServiceId;
  final Appointment? initialAppointment;

  static Future<Appointment?> show(
    BuildContext context, {
    required Client client,
    Service? preselectedService,
    Appointment? existingAppointment,
  }) {
    return showAppModalSheet<Appointment>(
      context: context,
      builder:
          (ctx) => ClientBookingSheet(
            client: client,
            initialServiceId: preselectedService?.id,
            initialAppointment: existingAppointment,
          ),
    );
  }

  @override
  ConsumerState<ClientBookingSheet> createState() => _ClientBookingSheetState();
}

class _ClientBookingSheetState extends ConsumerState<ClientBookingSheet> {
  static const _slotIntervalMinutes = 15;
  static const String _uncategorizedCategoryId = 'uncategorized';
  final _uuid = const Uuid();
  final DateFormat _dayLabel = DateFormat('EEE d MMM', 'it_IT');
  final DateFormat _timeLabel = DateFormat('HH:mm', 'it_IT');
  String? _selectedCategoryId;
  String? _selectedServiceId;
  String? _selectedStaffId;
  DateTime? _selectedDay;
  DateTime? _selectedSlotStart;
  bool _isSubmitting = false;
  bool _usePackageSession = false;
  String? _selectedPackageId;
  bool _packageSelectionManuallyChanged = false;

  @override
  void initState() {
    super.initState();
    final appointment = widget.initialAppointment;
    _selectedServiceId = widget.initialServiceId ?? appointment?.serviceId;
    _selectedStaffId = appointment?.staffId;
    if (appointment != null) {
      _selectedDay = _dayFrom(appointment.start);
      _selectedSlotStart = appointment.start;
      _usePackageSession = appointment.packageId != null;
      _selectedPackageId = appointment.packageId;
    }
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

    final resolvedSelection = _resolveSelection(bookingCategories);
    final effectiveCategoryId = resolvedSelection.categoryId;
    final effectiveServiceId = resolvedSelection.serviceId;

    if (effectiveCategoryId != _selectedCategoryId ||
        effectiveServiceId != _selectedServiceId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedCategoryId = effectiveCategoryId;
          _selectedServiceId = effectiveServiceId;
        });
      });
    }

    final currentCategoryId = effectiveCategoryId ?? _selectedCategoryId;
    final fallbackCategory =
        bookingCategories.isNotEmpty ? bookingCategories.first : null;
    final selectedCategory =
        bookingCategories.firstWhereOrNull(
          (item) => item.id == currentCategoryId,
        ) ??
        fallbackCategory;
    final visibleServices = selectedCategory?.services ?? const <Service>[];
    final selectedService =
        visibleServices.firstWhereOrNull(
          (service) => service.id == (effectiveServiceId ?? _selectedServiceId),
        ) ??
        (visibleServices.isNotEmpty ? visibleServices.first : services.first);

    final staff = _availableStaff(data: data, service: selectedService);
    if (staff.isNotEmpty &&
        _selectedStaffId != null &&
        staff.every((member) => member.id != _selectedStaffId)) {
      _selectedStaffId = staff.first.id;
      _resetSelectionAfterStaffChange();
    } else if (_selectedStaffId == null && staff.isNotEmpty) {
      _selectedStaffId = staff.first.id;
    }

    final availability =
        _selectedStaffId != null
            ? _computeAvailability(
              data: data,
              service: selectedService,
              staffId: _selectedStaffId!,
            )
            : const <DateTime, List<_AvailableSlot>>{};

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

    final packagesForService = _dedupePurchasesByReferenceId(
      packagePurchases
          .where(
            (purchase) =>
                purchase.isActive &&
                purchase.supportsService(selectedService.id) &&
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

    // Default to consuming a package session when one is available unless the
    // user explicitly opted out.
    if (packagesForService.isNotEmpty &&
        !_usePackageSession &&
        !_packageSelectionManuallyChanged) {
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
      if (packagesForService.isEmpty ||
          (availableIds.isNotEmpty &&
              !availableIds.contains(_selectedPackageId))) {
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

    ClientPackagePurchase? selectedPackage;
    for (final purchase in packagesForService) {
      if (purchase.item.referenceId == _selectedPackageId) {
        selectedPackage = purchase;
        break;
      }
    }
    selectedPackage ??=
        packagesForService.isNotEmpty ? packagesForService.first : null;

    String? packageSubtitle;
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

    final selectedDayKey =
        _selectedDay != null ? _dayFrom(_selectedDay!) : null;
    final slots =
        selectedDayKey != null
            ? availability[selectedDayKey] ?? const <_AvailableSlot>[]
            : const <_AvailableSlot>[];

    final selectedDayClosures =
        selectedDayKey == null
            ? const <SalonClosure>[]
            : _findOverlappingClosures(
              closures: salon?.closures ?? const <SalonClosure>[],
              start: selectedDayKey,
              end: selectedDayKey.add(const Duration(days: 1)),
            );

    if (_selectedSlotStart != null &&
        slots.every((slot) => slot.start != _selectedSlotStart)) {
      _selectedSlotStart = null;
    }

    final suggestions =
        selectedDayKey != null
            ? _nextAvailableSuggestions(
              availability: availability,
              selectedDay: selectedDayKey,
            )
            : const <_DaySuggestion>[];
    final hasAnyAvailability = availability.isNotEmpty;

    final bottomPadding = 16.0 + MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prenota un appuntamento',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              '1. Scegli la categoria',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  bookingCategories
                      .map(
                        (category) => ChoiceChip(
                          label: Text(category.label),
                          selected: category.id == currentCategoryId,
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() {
                              _selectedCategoryId = category.id;
                              final firstServiceId =
                                  category.services.isNotEmpty
                                      ? category.services.first.id
                                      : null;
                              _selectedServiceId = firstServiceId;
                              _selectedStaffId = null;
                              _selectedDay = null;
                              _selectedSlotStart = null;
                              _usePackageSession = false;
                              _selectedPackageId = null;
                              _packageSelectionManuallyChanged = false;
                            });
                          },
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 24),
            Text(
              '2. Scegli il servizio',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (visibleServices.isEmpty)
              const Text('Nessun servizio disponibile per questa categoria.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    visibleServices
                        .map(
                          (service) => ChoiceChip(
                            label: Text(service.name),
                            selected: service.id == selectedService.id,
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() {
                                _selectedServiceId = service.id;
                                _selectedStaffId = null;
                                _selectedDay = null;
                                _selectedSlotStart = null;
                                _usePackageSession = false;
                                _selectedPackageId = null;
                                _packageSelectionManuallyChanged = false;
                              });
                            },
                          ),
                        )
                        .toList(),
              ),
            const SizedBox(height: 24),
            Text(
              '3. Scegli l\'operatore',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (staff.isEmpty)
              const Text('Nessun operatore disponibile per questo servizio.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    staff
                        .map(
                          (member) => ChoiceChip(
                            label: Text(member.fullName),
                            selected: member.id == _selectedStaffId,
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() {
                                _selectedStaffId = member.id;
                                _selectedDay = null;
                                _selectedSlotStart = null;
                              });
                            },
                          ),
                        )
                        .toList(),
              ),
            const SizedBox(height: 24),
            if (packagesForService.isNotEmpty) ...[
              Text(
                'Sessioni pacchetto disponibili',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
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
                  });
                },
                title: const Text('Scala una sessione da un pacchetto'),
                subtitle:
                    packageSubtitle != null ? Text(packageSubtitle) : null,
              ),
              if (_usePackageSession && packagesForService.length > 1) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedPackageId,
                  decoration: const InputDecoration(
                    labelText: 'Seleziona il pacchetto da utilizzare',
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
                  onChanged:
                      (value) => setState(() {
                        _selectedPackageId = value;
                      }),
                ),
              ],
              const SizedBox(height: 24),
            ],
            Text(
              '4. Scegli data e orario',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_selectedStaffId == null)
              const Text('Seleziona un operatore per vedere le disponibilità.')
            else ...[
              OutlinedButton.icon(
                onPressed: () => _pickDay(context),
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _selectedDay != null
                      ? _capitalize(_dayLabel.format(_selectedDay!))
                      : 'Scegli una data',
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedDay == null)
                Text(
                  hasAnyAvailability
                      ? 'Seleziona una data per vedere le disponibilità.'
                      : 'Nessuna disponibilità nelle prossime settimane.',
                )
              else if (slots.isEmpty) ...[
                if (selectedDayClosures.isNotEmpty) ...[
                  ...selectedDayClosures.map(
                    (closure) => _buildClosureNotice(
                      context: context,
                      message: _describeClosure(closure),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Nessuna disponibilità per la data selezionata.'),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Disponibilità nei giorni successivi:'),
                  const SizedBox(height: 8),
                  ...suggestions.map((suggestion) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_capitalize(_dayLabel.format(suggestion.day))),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              suggestion.slots
                                  .map(
                                    (slot) => ChoiceChip(
                                      label: Text(
                                        _timeLabel.format(slot.start),
                                      ),
                                      selected:
                                          slot.start == _selectedSlotStart,
                                      onSelected: (selected) {
                                        if (!selected) return;
                                        setState(() {
                                          _selectedDay = suggestion.day;
                                          _selectedSlotStart = slot.start;
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }),
                ] else if (!hasAnyAvailability)
                  const Text('Nessuna disponibilità nelle prossime settimane.')
                else
                  const Text('Nessuno slot disponibile nei prossimi 3 giorni.'),
              ] else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      slots
                          .map(
                            (slot) => ChoiceChip(
                              label: Text(_timeLabel.format(slot.start)),
                              selected: slot.start == _selectedSlotStart,
                              onSelected: (selected) {
                                if (!selected) return;
                                setState(() {
                                  _selectedSlotStart = slot.start;
                                });
                              },
                            ),
                          )
                          .toList(),
                ),
            ],
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _canSubmit ? _confirmBooking : null,
                child:
                    _isSubmitting
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Conferma prenotazione'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit =>
      !_isSubmitting &&
      _selectedServiceId != null &&
      _selectedStaffId != null &&
      _selectedSlotStart != null &&
      (!_usePackageSession || _selectedPackageId != null);

  Future<void> _confirmBooking() async {
    if (!_canSubmit) {
      return;
    }
    final data = ref.read(appDataProvider);
    final service = data.services.firstWhere(
      (service) => service.id == _selectedServiceId,
    );
    final staff = data.staff.firstWhere(
      (member) => member.id == _selectedStaffId,
    );
    final slotStart = _selectedSlotStart!;
    final slotEnd = slotStart.add(service.totalDuration);
    final salon = data.salons.firstWhereOrNull(
      (item) => item.id == widget.client.salonId,
    );

    final editingAppointmentId = widget.initialAppointment?.id;
    final allAppointments = _visibleAppointments(
      data,
      excludeAppointmentId: editingAppointmentId,
    );
    final appointments =
        allAppointments.where((existing) {
          if (existing.staffId != staff.id) return false;
          if (existing.status == AppointmentStatus.cancelled ||
              existing.status == AppointmentStatus.noShow) {
            return false;
          }
          return existing.start.isBefore(slotEnd) &&
              existing.end.isAfter(slotStart);
        }).toList();

    if (appointments.isNotEmpty) {
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

    final equipmentCheck = EquipmentAvailabilityChecker.check(
      salon: salon,
      service: service,
      allServices: data.services,
      appointments: allAppointments,
      start: slotStart,
      end: slotEnd,
    );
    if (equipmentCheck.hasConflicts) {
      final equipmentLabel = equipmentCheck.blockingEquipment.join(', ');
      final message =
          equipmentLabel.isEmpty
              ? 'Macchinario non disponibile per questo orario.'
              : 'Macchinario non disponibile per questo orario: $equipmentLabel';
      _showError('$message. Scegli un altro orario.');
      return;
    }

    final hasClientConflict = hasClientBookingConflict(
      appointments: data.appointments,
      clientId: widget.client.id,
      start: slotStart,
      end: slotEnd,
      excludeAppointmentId: editingAppointmentId,
    );
    if (hasClientConflict) {
      _showError(
        'Hai già un appuntamento in questo orario. Scegli un altro slot.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final packageId = _usePackageSession ? _selectedPackageId : null;
      final existing = widget.initialAppointment;
      final appointment =
          existing?.copyWith(
            staffId: staff.id,
            serviceId: service.id,
            start: slotStart,
            end: slotEnd,
            packageId: packageId,
          ) ??
          Appointment(
            id: _uuid.v4(),
            salonId: widget.client.salonId,
            clientId: widget.client.id,
            staffId: staff.id,
            serviceId: service.id,
            start: slotStart,
            end: slotEnd,
            status: AppointmentStatus.scheduled,
            packageId: packageId,
          );
      await ref.read(appDataProvider.notifier).upsertAppointment(appointment);
      if (!mounted) return;
      Navigator.of(context).pop(appointment);
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

  Future<void> _pickDay(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _selectedDay ?? now;
    final firstDate = DateTime(now.year, now.month, now.day);
    final horizon = DateTime(
      now.year,
      now.month + 3,
      now.day,
    ).add(const Duration(days: 1));
    final lastDate = horizon.subtract(const Duration(days: 1));
    final adjustedInitial =
        initialDate.isBefore(firstDate)
            ? firstDate
            : initialDate.isAfter(lastDate)
            ? lastDate
            : initialDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: adjustedInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('it', 'IT'),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedDay = _dayFrom(picked);
      _selectedSlotStart = null;
    });
  }

  List<StaffMember> _availableStaff({
    required AppDataState data,
    required Service service,
  }) {
    final allowedRoles = service.staffRoles;
    return data.staff
        .where(
          (member) =>
              member.salonId == widget.client.salonId &&
              member.isActive &&
              (allowedRoles.isEmpty ||
                  member.roleIds.any(
                    (roleId) => allowedRoles.contains(roleId),
                  )),
        )
        .toList()
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

  _BookingSelection _resolveSelection(List<_BookingCategory> categories) {
    if (categories.isEmpty) {
      return const _BookingSelection();
    }

    _BookingCategory? category = categories.firstWhereOrNull(
      (item) => item.id == _selectedCategoryId,
    );
    category ??= categories.firstWhereOrNull(
      (item) =>
          item.services.any((service) => service.id == _selectedServiceId),
    );
    category ??= categories.first;

    Service? service = category.services.firstWhereOrNull(
      (item) => item.id == _selectedServiceId,
    );
    service ??= category.services.isNotEmpty ? category.services.first : null;

    return _BookingSelection(categoryId: category.id, serviceId: service?.id);
  }

  Map<DateTime, List<_AvailableSlot>> _computeAvailability({
    required AppDataState data,
    required Service service,
    required String staffId,
  }) {
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
    final allAppointments = _visibleAppointments(
      data,
      excludeAppointmentId: editingAppointmentId,
    );
    final equipmentAvailability = _EquipmentAvailability.resolve(
      salon: salon,
      service: service,
      allServices: data.services,
      appointments: allAppointments,
      now: now,
      horizon: horizon,
    );
    if (!equipmentAvailability.canOfferService) {
      return const <DateTime, List<_AvailableSlot>>{};
    }
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

    final serviceDuration = service.totalDuration;
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
          final slotEnd = slotStart.add(serviceDuration);
          if (slotEnd.isAfter(cappedWindowEnd)) {
            break;
          }
          if (slotStart.isBefore(now)) {
            slotStart = slotStart.add(slotStep);
            continue;
          }
          if (!equipmentAvailability.isSlotAvailable(
            start: slotStart,
            end: slotEnd,
          )) {
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
            _AvailableSlot(start: slotStart, end: slotEnd, shiftId: shift.id),
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

  void _resetSelectionAfterStaffChange() {
    _selectedDay = null;
    _selectedSlotStart = null;
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

class _BookingSelection {
  const _BookingSelection({this.categoryId, this.serviceId});

  final String? categoryId;
  final String? serviceId;
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

class _EquipmentAvailability {
  const _EquipmentAvailability._({
    required this.requiredEquipmentIds,
    required Map<String, _EquipmentInventory> inventory,
  }) : _inventory = inventory;

  final List<String> requiredEquipmentIds;
  final Map<String, _EquipmentInventory> _inventory;

  static _EquipmentAvailability resolve({
    required Salon? salon,
    required Service service,
    required List<Service> allServices,
    required List<Appointment> appointments,
    required DateTime now,
    required DateTime horizon,
  }) {
    final requiredIds = List<String>.unmodifiable(service.requiredEquipmentIds);
    if (requiredIds.isEmpty) {
      return _EquipmentAvailability._(
        requiredEquipmentIds: requiredIds,
        inventory: const <String, _EquipmentInventory>{},
      );
    }
    if (salon == null) {
      return _EquipmentAvailability._(
        requiredEquipmentIds: requiredIds,
        inventory: const <String, _EquipmentInventory>{},
      );
    }

    final equipmentById = {
      for (final equipment in salon.equipment) equipment.id: equipment,
    };
    final servicesById = {for (final item in allServices) item.id: item};

    final busyByEquipment = <String, List<_TimeRange>>{};
    for (final appointment in appointments) {
      if (appointment.salonId != salon.id) continue;
      if (!appointment.end.isAfter(now)) continue;
      if (!appointment.start.isBefore(horizon)) continue;
      if (appointment.status == AppointmentStatus.cancelled ||
          appointment.status == AppointmentStatus.noShow) {
        continue;
      }

      final appointmentService = servicesById[appointment.serviceId];
      if (appointmentService == null ||
          appointmentService.requiredEquipmentIds.isEmpty) {
        continue;
      }

      final range = _TimeRange(start: appointment.start, end: appointment.end);
      for (final equipmentId in appointmentService.requiredEquipmentIds) {
        final entries = busyByEquipment.putIfAbsent(equipmentId, () => []);
        entries.add(range);
      }
    }

    for (final entries in busyByEquipment.values) {
      entries.sort((a, b) => a.start.compareTo(b.start));
    }

    final inventory = <String, _EquipmentInventory>{};
    for (final equipmentId in requiredIds) {
      final equipment = equipmentById[equipmentId];
      final capacity = _effectiveCapacity(equipment);
      final busySlots = List<_TimeRange>.unmodifiable(
        busyByEquipment[equipmentId] ?? const <_TimeRange>[],
      );
      inventory[equipmentId] = _EquipmentInventory(
        capacity: capacity,
        busySlots: busySlots,
      );
    }

    return _EquipmentAvailability._(
      requiredEquipmentIds: requiredIds,
      inventory: inventory,
    );
  }

  bool get canOfferService {
    if (requiredEquipmentIds.isEmpty) {
      return true;
    }
    for (final equipmentId in requiredEquipmentIds) {
      final inventory = _inventory[equipmentId];
      if (inventory == null || inventory.capacity <= 0) {
        return false;
      }
    }
    return true;
  }

  bool isSlotAvailable({required DateTime start, required DateTime end}) {
    if (requiredEquipmentIds.isEmpty) {
      return true;
    }
    final slotRange = _TimeRange(start: start, end: end);
    for (final equipmentId in requiredEquipmentIds) {
      final inventory = _inventory[equipmentId];
      if (inventory == null || inventory.capacity <= 0) {
        return false;
      }
      var overlaps = 0;
      for (final busy in inventory.busySlots) {
        if (!busy.overlaps(slotRange)) {
          continue;
        }
        overlaps += 1;
        if (overlaps >= inventory.capacity) {
          return false;
        }
      }
    }
    return true;
  }

  static int _effectiveCapacity(SalonEquipment? equipment) {
    if (equipment == null) {
      return 0;
    }
    if (equipment.quantity <= 0) {
      return 0;
    }
    if (equipment.status != SalonEquipmentStatus.operational) {
      return 0;
    }
    return equipment.quantity;
  }
}

class _EquipmentInventory {
  const _EquipmentInventory({required this.capacity, required this.busySlots});

  final int capacity;
  final List<_TimeRange> busySlots;
}
