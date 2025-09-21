import 'package:civiapp/app/providers.dart';
import 'package:civiapp/data/repositories/app_data_state.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/shift.dart';
import 'package:civiapp/domain/entities/staff_absence.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/presentation/shared/client_package_purchase.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class ClientBookingSheet extends ConsumerStatefulWidget {
  const ClientBookingSheet({
    super.key,
    required this.client,
    this.initialServiceId,
  });

  final Client client;
  final String? initialServiceId;

  static Future<Appointment?> show(
    BuildContext context, {
    required Client client,
    Service? preselectedService,
  }) {
    return showAppModalSheet<Appointment>(
      context: context,
      builder:
          (ctx) => ClientBookingSheet(
            client: client,
            initialServiceId: preselectedService?.id,
          ),
    );
  }

  @override
  ConsumerState<ClientBookingSheet> createState() => _ClientBookingSheetState();
}

class _ClientBookingSheetState extends ConsumerState<ClientBookingSheet> {
  static const _slotIntervalMinutes = 15;
  final _uuid = const Uuid();
  final DateFormat _dayLabel = DateFormat('EEE d MMM', 'it_IT');
  final DateFormat _timeLabel = DateFormat('HH:mm', 'it_IT');
  String? _selectedServiceId;
  String? _selectedStaffId;
  DateTime? _selectedDay;
  DateTime? _selectedSlotStart;
  bool _isSubmitting = false;
  bool _usePackageSession = false;
  String? _selectedPackageId;

  @override
  void initState() {
    super.initState();
    _selectedServiceId = widget.initialServiceId;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final services =
        data.services
            .where((service) => service.salonId == widget.client.salonId)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    if (services.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Nessun servizio disponibile per la prenotazione.'),
      );
    }

    final selectedService = services.firstWhere(
      (service) => service.id == _selectedServiceId,
      orElse: () => services.first,
    );
    if (_selectedServiceId == null ||
        selectedService.id != _selectedServiceId) {
      _selectedServiceId = selectedService.id;
    }

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

    final packagePurchases = resolveClientPackagePurchases(
      sales: data.sales,
      packages: data.packages,
      appointments: data.appointments,
      services: data.services,
      clientId: widget.client.id,
      salonId: widget.client.salonId,
    );

    final packagesForService =
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
          });

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
              '1. Scegli il servizio',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  services
                      .map(
                        (service) => ChoiceChip(
                          label: Text(service.name),
                          selected: service.id == _selectedServiceId,
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() {
                              _selectedServiceId = service.id;
                              _selectedStaffId = null;
                              _selectedDay = null;
                              _selectedSlotStart = null;
                            });
                          },
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 24),
            Text(
              '2. Scegli l\'operatore',
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
              '3. Scegli data e orario',
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
    final slotEnd = slotStart.add(service.duration);

    final appointments =
        data.appointments.where((existing) {
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

    setState(() => _isSubmitting = true);
    try {
      final appointment = Appointment(
        id: _uuid.v4(),
        salonId: widget.client.salonId,
        clientId: widget.client.id,
        staffId: staff.id,
        serviceId: service.id,
        start: slotStart,
        end: slotEnd,
        status: AppointmentStatus.scheduled,
        packageId: _usePackageSession ? _selectedPackageId : null,
      );
      await ref.read(appDataProvider.notifier).upsertAppointment(appointment);
      if (!mounted) return;
      Navigator.of(context).pop(appointment);
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
              (allowedRoles.isEmpty || allowedRoles.contains(member.role.name)),
        )
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
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
        data.appointments.where((appointment) {
          if (appointment.staffId != staffId) return false;
          if (appointment.status == AppointmentStatus.cancelled ||
              appointment.status == AppointmentStatus.noShow) {
            return false;
          }
          if (!appointment.end.isAfter(now)) {
            return false;
          }
          return true;
        }).toList();

    final busyAbsences =
        data.staffAbsences.where((absence) {
          if (absence.staffId != staffId) return false;
          if (!absence.end.isAfter(now)) return false;
          return true;
        }).toList();

    final serviceDuration = service.duration;
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
            slotStart = slotStart.add(Duration(minutes: _slotIntervalMinutes));
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
          slotStart = slotStart.add(Duration(minutes: _slotIntervalMinutes));
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

  DateTime _dayFrom(DateTime value) {
    return DateTime(value.year, value.month, value.day);
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
