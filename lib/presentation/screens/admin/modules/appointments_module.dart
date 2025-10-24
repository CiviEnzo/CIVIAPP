import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/availability/appointment_conflicts.dart';
import 'package:you_book/domain/availability/equipment_availability.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/appointment_day_checklist.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/last_minute_notification.dart';
import 'package:you_book/domain/entities/last_minute_slot.dart';
import 'package:you_book/domain/entities/payment_ticket.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/appointment_clipboard.dart';
import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/domain/entities/staff_absence.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/appointment_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/appointment_calendar_view.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/appointment_anomaly.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/express_slot_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

enum _AppointmentDisplayMode { calendar, list }

enum _WeekLayoutMode { detailed, compact, operators }

enum _SlotAction { appointment, express, copyFromClipboard }

class AppointmentsModule extends ConsumerStatefulWidget {
  const AppointmentsModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<AppointmentsModule> createState() => _AppointmentsModuleState();
}

const List<MapEntry<int, String>> _weekdayOptions = <MapEntry<int, String>>[
  MapEntry(DateTime.monday, 'Lunedì'),
  MapEntry(DateTime.tuesday, 'Martedì'),
  MapEntry(DateTime.wednesday, 'Mercoledì'),
  MapEntry(DateTime.thursday, 'Giovedì'),
  MapEntry(DateTime.friday, 'Venerdì'),
  MapEntry(DateTime.saturday, 'Sabato'),
  MapEntry(DateTime.sunday, 'Domenica'),
];

class _AppointmentsModuleState extends ConsumerState<AppointmentsModule> {
  static final _dayLabel = DateFormat('EEEE dd MMMM yyyy', 'it_IT');
  static final _weekStartLabel = DateFormat('dd MMM', 'it_IT');
  static final _timeLabel = DateFormat('HH:mm', 'it_IT');
  static const Uuid _uuid = Uuid();
  static const List<ButtonSegment<_AppointmentDisplayMode>> _modeSegments =
      <ButtonSegment<_AppointmentDisplayMode>>[
        const ButtonSegment(
          value: _AppointmentDisplayMode.calendar,
          label: const Text('Calendario'),
          icon: const Icon(Icons.calendar_month_rounded),
        ),
        const ButtonSegment(
          value: _AppointmentDisplayMode.list,
          label: const Text('Lista'),
          icon: const Icon(Icons.view_list_rounded),
        ),
      ];
  static const List<ButtonSegment<AppointmentCalendarScope>> _scopeSegments =
      <ButtonSegment<AppointmentCalendarScope>>[
        const ButtonSegment(
          value: AppointmentCalendarScope.day,
          label: const Text('Giorno'),
          icon: const Icon(Icons.calendar_view_day_rounded),
        ),
        const ButtonSegment(
          value: AppointmentCalendarScope.week,
          label: const Text('Settimana'),
          icon: const Icon(Icons.view_week_rounded),
        ),
      ];
  static const List<ButtonSegment<_WeekLayoutMode>> _weekLayoutSegments =
      <ButtonSegment<_WeekLayoutMode>>[
        const ButtonSegment(
          value: _WeekLayoutMode.detailed,
          label: const Text('Dettaglio'),
          icon: const Icon(Icons.view_week_rounded),
        ),
        const ButtonSegment(
          value: _WeekLayoutMode.compact,
          label: const Text('Compatto'),
          icon: const Icon(Icons.grid_view_rounded),
        ),
        const ButtonSegment(
          value: _WeekLayoutMode.operators,
          label: const Text('Operatori'),
          icon: const Icon(Icons.table_chart_rounded),
        ),
      ];
  static const List<ButtonSegment<int>> _slotDurationSegments =
      <ButtonSegment<int>>[
        const ButtonSegment<int>(value: 15, label: const Text('15 min')),
        const ButtonSegment<int>(value: 30, label: const Text('30 min')),
        const ButtonSegment<int>(value: 60, label: const Text('60 min')),
      ];

  _AppointmentDisplayMode _mode = _AppointmentDisplayMode.calendar;
  AppointmentCalendarScope _scope = AppointmentCalendarScope.week;
  late DateTime _anchorDate;
  Set<String> _selectedStaffIds = <String>{};
  bool _isRescheduling = false;
  int _calendarSlotMinutes = 15;
  bool _checklistEditingEnabled = true;
  _WeekLayoutMode _weekLayoutMode = _WeekLayoutMode.detailed;
  final Set<int> _visibleWeekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  };

  String? get _effectiveSalonId {
    final explicit = widget.salonId?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final sessionSalon = ref.read(currentSalonIdProvider);
    if (sessionSalon != null && sessionSalon.isNotEmpty) {
      return sessionSalon;
    }
    return null;
  }

  AppointmentWeekLayoutMode get _effectiveWeekLayout {
    switch (_weekLayoutMode) {
      case _WeekLayoutMode.compact:
        return AppointmentWeekLayoutMode.compact;
      case _WeekLayoutMode.operators:
        return AppointmentWeekLayoutMode.operatorBoard;
      case _WeekLayoutMode.detailed:
      default:
        return AppointmentWeekLayoutMode.detailed;
    }
  }

  Set<String> _clientsWithOutstandingPayments({
    required Iterable<Appointment> appointments,
    required Iterable<Sale> sales,
    required Iterable<PaymentTicket> tickets,
  }) {
    final clientIds =
        appointments.map((appointment) => appointment.clientId).toSet();
    if (clientIds.isEmpty) {
      return const <String>{};
    }

    final salesByClient = <String, List<Sale>>{};
    for (final sale in sales) {
      if (!clientIds.contains(sale.clientId)) {
        continue;
      }
      salesByClient.putIfAbsent(sale.clientId, () => <Sale>[]).add(sale);
    }

    final openTicketsByClient = <String, List<PaymentTicket>>{};
    for (final ticket in tickets) {
      if (!clientIds.contains(ticket.clientId)) {
        continue;
      }
      if (ticket.status != PaymentTicketStatus.open) {
        continue;
      }
      openTicketsByClient
          .putIfAbsent(ticket.clientId, () => <PaymentTicket>[])
          .add(ticket);
    }

    final result = <String>{};
    for (final clientId in clientIds) {
      final clientSales = salesByClient[clientId] ?? const <Sale>[];
      final clientTickets =
          openTicketsByClient[clientId] ?? const <PaymentTicket>[];
      if (_hasOutstandingPaymentsForClient(
        sales: clientSales,
        openTickets: clientTickets,
      )) {
        result.add(clientId);
      }
    }
    return result;
  }

  bool _hasOutstandingPaymentsForClient({
    required Iterable<Sale> sales,
    required Iterable<PaymentTicket> openTickets,
  }) {
    if (openTickets.isNotEmpty) {
      return true;
    }
    for (final sale in sales) {
      final hasSaleOutstanding =
          sale.paymentStatus == SalePaymentStatus.deposit &&
          sale.outstandingAmount > 0.009;
      if (hasSaleOutstanding) {
        return true;
      }
      for (final item in sale.items) {
        final hasOutstandingPackage =
            item.referenceType == SaleReferenceType.package &&
            (item.amount - item.depositAmount) > 0.009;
        final packageMarkedAsDeposit =
            item.packagePaymentStatus == PackagePaymentStatus.deposit;
        if (hasOutstandingPackage || packageMarkedAsDeposit) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchorDate = DateTime(now.year, now.month, now.day);
  }

  String _staffFilterLabel(List<StaffMember> staff, Set<String> selectedIds) {
    if (staff.isEmpty || selectedIds.isEmpty) {
      return 'Operatori: Tutti';
    }
    final selectedMembers = staff
        .where((member) => selectedIds.contains(member.id))
        .toList(growable: false);
    if (selectedMembers.isEmpty) {
      return 'Operatori: Tutti';
    }
    if (selectedMembers.length == 1) {
      return 'Operatori: ${selectedMembers.first.fullName}';
    }
    final firstNames = selectedMembers
        .take(2)
        .map((member) => _firstName(member.fullName))
        .toList(growable: false);
    if (selectedMembers.length == 2) {
      return 'Operatori: ${firstNames[0]}, ${firstNames[1]}';
    }
    final remaining = selectedMembers.length - 2;
    return 'Operatori: ${firstNames[0]}, ${firstNames[1]} +$remaining';
  }

  String _firstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) {
      return fullName;
    }
    final parts = trimmed.split(RegExp(r'\\s+'));
    return parts.isEmpty ? fullName : parts.first;
  }

  Future<void> _openStaffFilterSheet(
    List<StaffMember> staff,
    Set<String> selectedStaffIds,
  ) async {
    if (staff.isEmpty) {
      return;
    }
    var selection = Set<String>.from(
      selectedStaffIds.where((id) => staff.any((member) => member.id == id)),
    );
    final result = await showAppModalSheet<Set<String>>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final mediaQuery = MediaQuery.of(context);
        final maxHeight = mediaQuery.size.height * 0.7;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final visibleItems = staff.length < 6 ? staff.length : 6;
            final listHeight = visibleItems == 0 ? 0.0 : visibleItems * 56.0;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: mediaQuery.viewInsets.bottom + 12,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Filtra operatori',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      CheckboxListTile(
                        value: selection.isEmpty,
                        onChanged: (value) {
                          setModalState(() {
                            if (value == true) {
                              selection.clear();
                            } else {
                              selection =
                                  staff.map((member) => member.id).toSet();
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Tutto lo staff'),
                      ),
                      if (staff.isNotEmpty) const Divider(height: 1),
                      if (staff.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Nessun operatore disponibile'),
                        )
                      else
                        SizedBox(
                          height: listHeight,
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: staff.length,
                            separatorBuilder:
                                (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final member = staff[index];
                              final isSelected = selection.contains(member.id);
                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  setModalState(() {
                                    if (value == true) {
                                      selection.add(member.id);
                                    } else {
                                      selection.remove(member.id);
                                    }
                                  });
                                },
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(member.fullName),
                              );
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  selection.clear();
                                });
                              },
                              child: const Text('Reimposta'),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Annulla'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed:
                                  () => Navigator.of(
                                    context,
                                  ).pop(Set<String>.from(selection)),
                              child: const Text('Applica'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null) {
      final sanitizedResult =
          result.where((id) => staff.any((member) => member.id == id)).toSet();
      final normalized =
          sanitizedResult.length == staff.length ? <String>{} : sanitizedResult;
      setState(() => _selectedStaffIds = normalized);
    }
  }

  String _staffSelectionKey(Set<String> ids) {
    if (ids.isEmpty) {
      return 'all';
    }
    final sorted = ids.toList()..sort();
    return sorted.join('-');
  }

  AppointmentDayChecklist? _findChecklistById(
    List<AppointmentDayChecklist> source,
    String checklistId,
  ) {
    if (checklistId.isEmpty) {
      return null;
    }
    return source.firstWhereOrNull((item) => item.id == checklistId);
  }

  AppointmentDayChecklist? _findChecklistForDay(
    List<AppointmentDayChecklist> source,
    String salonId,
    DateTime day,
  ) {
    return source.firstWhereOrNull(
      (item) => item.salonId == salonId && DateUtils.isSameDay(item.date, day),
    );
  }

  Future<void> _openAgendaVisionDialog(
    BuildContext context, {
    required List<StaffMember> staff,
  }) async {
    const compactDensity = VisualDensity(horizontal: -2, vertical: -2);
    final segmentedStyle = ButtonStyle(
      visualDensity: compactDensity,
      padding: const MaterialStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      minimumSize: const MaterialStatePropertyAll(Size(0, 38)),
    );
    final outlinedButtonStyle = OutlinedButton.styleFrom(
      visualDensity: compactDensity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      minimumSize: const Size(0, 40),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  final staffLabel =
                      staff.isEmpty
                          ? null
                          : _staffFilterLabel(staff, _selectedStaffIds);
                  final rangeStart = _rangeStart(_anchorDate, _scope);
                  final rangeEnd = _rangeEnd(rangeStart, _scope);
                  final rangeLabel = _buildRangeLabel(
                    rangeStart,
                    rangeEnd,
                    _scope,
                  );
                  final currentView =
                      _mode == _AppointmentDisplayMode.calendar
                          ? 'Calendario'
                          : 'Lista';

                  void refresh() {
                    if (!mounted) return;
                    setDialogState(() {});
                  }

                  final showInlineStaffSelection =
                      staff.isNotEmpty && staff.length < 10;
                  final showStaffFilterButton =
                      staff.length >= 10 && staffLabel != null;

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Visione agenda',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Chiudi',
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        Text(
                          '$currentView - $rangeLabel',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<_AppointmentDisplayMode>(
                          style: segmentedStyle,
                          segments: _modeSegments,
                          selected: {_mode},
                          onSelectionChanged: (selection) {
                            final newMode = selection.first;
                            setState(() => _mode = newMode);
                            refresh();
                          },
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<AppointmentCalendarScope>(
                          style: segmentedStyle,
                          segments: _scopeSegments,
                          selected: {_scope},
                          onSelectionChanged: (selection) {
                            final newScope = selection.first;
                            _updateScope(newScope);
                            refresh();
                          },
                        ),
                        if (_mode == _AppointmentDisplayMode.calendar) ...[
                          const SizedBox(height: 12),
                          SegmentedButton<int>(
                            style: segmentedStyle,
                            segments: _slotDurationSegments,
                            selected: {_calendarSlotMinutes},
                            onSelectionChanged: (selection) {
                              final minutes = selection.first;
                              setState(() => _calendarSlotMinutes = minutes);
                              refresh();
                            },
                          ),
                        ],
                        if (_mode == _AppointmentDisplayMode.calendar &&
                            _scope == AppointmentCalendarScope.week) ...[
                          const SizedBox(height: 12),
                          SegmentedButton<_WeekLayoutMode>(
                            style: segmentedStyle,
                            segments: _weekLayoutSegments,
                            selected: {_weekLayoutMode},
                            onSelectionChanged: (selection) {
                              final newLayout = selection.first;
                              setState(() => _weekLayoutMode = newLayout);
                              refresh();
                            },
                          ),
                        ],
                        if (showInlineStaffSelection) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Filtra operatori',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                label: const Text('Tutti'),
                                selected: _selectedStaffIds.isEmpty,
                                onSelected: (_) {
                                  setState(
                                    () => _selectedStaffIds = <String>{},
                                  );
                                  refresh();
                                },
                              ),
                              for (final member in staff)
                                FilterChip(
                                  label: Text(member.fullName),
                                  selected: _selectedStaffIds.contains(
                                    member.id,
                                  ),
                                  onSelected: (isSelected) {
                                    setState(() {
                                      final updated = Set<String>.from(
                                        _selectedStaffIds,
                                      );
                                      if (isSelected) {
                                        updated.add(member.id);
                                      } else {
                                        updated.remove(member.id);
                                      }
                                      if (updated.length == staff.length) {
                                        _selectedStaffIds = <String>{};
                                      } else {
                                        _selectedStaffIds = updated;
                                      }
                                    });
                                    refresh();
                                  },
                                ),
                            ],
                          ),
                        ] else if (showStaffFilterButton) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            style: outlinedButtonStyle,
                            onPressed: () async {
                              await _openStaffFilterSheet(
                                staff,
                                _selectedStaffIds,
                              );
                              if (!mounted) return;
                              refresh();
                            },
                            icon: const Icon(Icons.people_alt_rounded),
                            label: Text(staffLabel!),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  int _nextChecklistPosition(AppointmentDayChecklist? checklist) {
    if (checklist == null || checklist.items.isEmpty) {
      return 0;
    }
    var maxPosition = checklist.items.first.position;
    for (final item in checklist.items.skip(1)) {
      if (item.position > maxPosition) {
        maxPosition = item.position;
      }
    }
    return maxPosition + 1;
  }

  void _handleChecklistError(Object error, StackTrace stackTrace) {
    debugPrint(
      '[Checklist] Handler invoked -> errorType=${error.runtimeType} error=$error',
    );
    debugPrintStack(stackTrace: stackTrace);
    final currentUser = ref.read(appDataProvider.notifier).currentUser;
    if (currentUser != null) {
      debugPrint(
        '[Checklist] Current user -> uid=${currentUser.uid} role=${currentUser.role?.name} '
        'salonIds=${currentUser.salonIds}',
      );
    } else {
      debugPrint('[Checklist] Current user -> null');
    }
    final firebaseError = error is FirebaseException ? error : null;
    if (firebaseError != null) {
      debugPrint(
        '[Checklist] FirebaseException code=${firebaseError.code} plugin=${firebaseError.plugin} '
        'message=${firebaseError.message}',
      );
    }
    if (firebaseError?.code == 'permission-denied') {
      if (_checklistEditingEnabled && mounted) {
        setState(() => _checklistEditingEnabled = false);
      } else {
        _checklistEditingEnabled = false;
      }
      _showChecklistMessage(
        'Non hai i permessi necessari per modificare la checklist.',
      );
      return;
    }

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'AppointmentsModule',
        context: ErrorDescription(
          'Aggiornamento checklist calendario appuntamenti',
        ),
      ),
    );
    _showChecklistMessage('Impossibile aggiornare la checklist. Riprova.');
  }

  void _showChecklistMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addChecklistItem(DateTime day, String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final salonId = _effectiveSalonId;
    if (salonId == null || salonId.isEmpty) {
      _showChecklistMessage('Seleziona un salone per usare la checklist.');
      return;
    }
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final state = ref.read(appDataProvider);
    final existing = _findChecklistForDay(
      state.appointmentDayChecklists,
      salonId,
      normalizedDay,
    );
    final now = DateTime.now();
    final position = _nextChecklistPosition(existing);
    final newItem = AppointmentChecklistItem(
      id: _uuid.v4(),
      label: trimmed,
      position: position,
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
    );
    final isNewChecklist = existing == null;
    final checklist =
        isNewChecklist
            ? AppointmentDayChecklist(
              id: _uuid.v4(),
              salonId: salonId,
              date: normalizedDay,
              items: <AppointmentChecklistItem>[newItem],
              createdAt: now,
              updatedAt: now,
            )
            : existing.copyWith(
              items: <AppointmentChecklistItem>[...existing.items, newItem],
              updatedAt: now,
            );
    debugPrint(
      '[Checklist] Insert request -> salonId=$salonId day=${normalizedDay.toIso8601String()} '
      'checklistId=${checklist.id} newChecklist=$isNewChecklist itemId=${newItem.id} label="$trimmed"',
    );
    debugPrint(
      '[Checklist] Debug -> salonId length=${salonId.length} chars, ascii=${salonId.codeUnits}',
    );
    try {
      await ref
          .read(appDataProvider.notifier)
          .upsertAppointmentDayChecklist(checklist);
      debugPrint(
        '[Checklist] Insert success -> checklistId=${checklist.id} itemId=${newItem.id}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[Checklist] Insert failed -> checklistId=${checklist.id} itemId=${newItem.id} '
        'errorType=${error.runtimeType} error=$error',
      );
      _handleChecklistError(error, stackTrace);
    }
  }

  Future<void> _toggleChecklistItem(
    String checklistId,
    String itemId,
    bool isCompleted,
  ) async {
    if (checklistId.isEmpty || itemId.isEmpty) {
      return;
    }
    final state = ref.read(appDataProvider);
    final checklist = _findChecklistById(
      state.appointmentDayChecklists,
      checklistId,
    );
    if (checklist == null) {
      return;
    }
    var changed = false;
    final now = DateTime.now();
    final updatedItems = checklist.items
        .map((item) {
          if (item.id != itemId) {
            return item;
          }
          if (item.isCompleted == isCompleted) {
            return item;
          }
          changed = true;
          return item.copyWith(isCompleted: isCompleted, updatedAt: now);
        })
        .toList(growable: false);
    if (!changed) {
      return;
    }
    final updatedChecklist = checklist.copyWith(
      items: updatedItems,
      updatedAt: now,
    );
    try {
      await ref
          .read(appDataProvider.notifier)
          .upsertAppointmentDayChecklist(updatedChecklist);
    } catch (error, stackTrace) {
      _handleChecklistError(error, stackTrace);
    }
  }

  Future<void> _renameChecklistItem(
    String checklistId,
    String itemId,
    String label,
  ) async {
    if (checklistId.isEmpty || itemId.isEmpty) {
      return;
    }
    final trimmed = label.trim();
    final state = ref.read(appDataProvider);
    final checklist = _findChecklistById(
      state.appointmentDayChecklists,
      checklistId,
    );
    if (checklist == null) {
      return;
    }
    if (trimmed.isEmpty) {
      await _deleteChecklistItem(checklistId, itemId);
      return;
    }
    var changed = false;
    final now = DateTime.now();
    final updatedItems = checklist.items
        .map((item) {
          if (item.id != itemId) {
            return item;
          }
          if (item.label == trimmed) {
            return item;
          }
          changed = true;
          return item.copyWith(label: trimmed, updatedAt: now);
        })
        .toList(growable: false);
    if (!changed) {
      return;
    }
    final updatedChecklist = checklist.copyWith(
      items: updatedItems,
      updatedAt: now,
    );
    try {
      await ref
          .read(appDataProvider.notifier)
          .upsertAppointmentDayChecklist(updatedChecklist);
    } catch (error, stackTrace) {
      _handleChecklistError(error, stackTrace);
    }
  }

  Future<void> _deleteChecklistItem(String checklistId, String itemId) async {
    if (checklistId.isEmpty || itemId.isEmpty) {
      return;
    }
    final store = ref.read(appDataProvider.notifier);
    final state = ref.read(appDataProvider);
    final checklist = _findChecklistById(
      state.appointmentDayChecklists,
      checklistId,
    );
    if (checklist == null) {
      return;
    }
    final remaining = checklist.items
        .where((item) => item.id != itemId)
        .toList(growable: false);
    if (remaining.length == checklist.items.length) {
      return;
    }
    if (remaining.isEmpty) {
      try {
        await store.deleteAppointmentDayChecklist(checklist.id);
      } catch (error, stackTrace) {
        _handleChecklistError(error, stackTrace);
      }
      return;
    }
    final normalizedItems = <AppointmentChecklistItem>[];
    for (var index = 0; index < remaining.length; index++) {
      final current = remaining[index];
      if (current.position == index) {
        normalizedItems.add(current);
      } else {
        normalizedItems.add(current.copyWith(position: index));
      }
    }
    final updatedChecklist = checklist.copyWith(
      items: normalizedItems,
      updatedAt: DateTime.now(),
    );
    try {
      await store.upsertAppointmentDayChecklist(updatedChecklist);
    } catch (error, stackTrace) {
      _handleChecklistError(error, stackTrace);
    }
  }

  Map<DateTime, AppointmentDayChecklist> _dayChecklistsInRange({
    required Iterable<AppointmentDayChecklist> source,
    required String? salonId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final result = <DateTime, AppointmentDayChecklist>{};
    final lowerBound = DateTime(
      rangeStart.year,
      rangeStart.month,
      rangeStart.day,
    );
    final upperBound = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    for (final checklist in source) {
      if (salonId != null && checklist.salonId != salonId) {
        continue;
      }
      final day = DateTime(
        checklist.date.year,
        checklist.date.month,
        checklist.date.day,
      );
      if (day.isBefore(lowerBound) || !day.isBefore(upperBound)) {
        continue;
      }
      final existing = result[day];
      if (existing == null) {
        result[day] = checklist;
        continue;
      }
      final existingTimestamp = existing.updatedAt ?? existing.createdAt;
      final candidateTimestamp = checklist.updatedAt ?? checklist.createdAt;
      if (existingTimestamp == null && candidateTimestamp == null) {
        continue;
      }
      if (existingTimestamp == null && candidateTimestamp != null) {
        result[day] = checklist;
        continue;
      }
      if (existingTimestamp != null && candidateTimestamp != null) {
        if (candidateTimestamp.isAfter(existingTimestamp)) {
          result[day] = checklist;
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final salons = data.salons;
    final salonsById = {for (final salon in salons) salon.id: salon};
    final clients = data.clients;
    final staffMembers =
        data.staff
            .where(
              (member) =>
                  widget.salonId == null || member.salonId == widget.salonId,
            )
            .sortedByDisplayOrder();
    final services = data.services;
    final selectedSalon =
        widget.salonId != null
            ? salons.firstWhereOrNull((salon) => salon.id == widget.salonId)
            : null;
    final effectiveSalonId = _effectiveSalonId;

    final sanitizedSelectedIds =
        _selectedStaffIds
            .where((id) => staffMembers.any((member) => member.id == id))
            .toSet();
    if (sanitizedSelectedIds.length != _selectedStaffIds.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedStaffIds = sanitizedSelectedIds);
      });
    }

    final selectedStaffIds = sanitizedSelectedIds;
    final visibleStaff =
        selectedStaffIds.isEmpty
            ? staffMembers
            : staffMembers
                .where((member) => selectedStaffIds.contains(member.id))
                .toList(growable: false);
    final staffIds =
        selectedStaffIds.isEmpty ? <String>{} : selectedStaffIds.toSet();

    final now = DateTime.now();
    final relevantAppointments = data.appointments
        .where(
          (appointment) =>
              widget.salonId == null || appointment.salonId == widget.salonId,
        )
        .sortedBy((appointment) => appointment.start);
    final relevantShifts =
        data.shifts
            .where(
              (shift) =>
                  widget.salonId == null || shift.salonId == widget.salonId,
            )
            .toList();
    final relevantAbsencesAll =
        data.staffAbsences
            .where(
              (absence) =>
                  widget.salonId == null || absence.salonId == widget.salonId,
            )
            .toList();

    final rangeStart = _rangeStart(_anchorDate, _scope);
    final rangeEnd = _rangeEnd(rangeStart, _scope);
    final dayChecklists = Map<DateTime, AppointmentDayChecklist>.unmodifiable(
      _dayChecklistsInRange(
        source: data.appointmentDayChecklists,
        salonId: effectiveSalonId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );

    final anomalies = _detectAppointmentAnomalies(
      appointments: relevantAppointments,
      shifts: relevantShifts,
      absences: relevantAbsencesAll,
      now: now,
    );

    final Map<String, String> lockedAppointmentReasons = {};
    for (final appointment in relevantAppointments) {
      final reason = _modificationRestrictionReason(appointment, now);
      if (reason != null) {
        lockedAppointmentReasons[appointment.id] = reason;
      }
    }

    final attentionAppointments =
        relevantAppointments.where((appointment) {
          final matchesStaff =
              staffIds.isEmpty || staffIds.contains(appointment.staffId);
          if (!matchesStaff) {
            return false;
          }
          final hasAnomalies = anomalies.containsKey(appointment.id);
          final isCancelled = appointment.status == AppointmentStatus.cancelled;
          return hasAnomalies || isCancelled;
        }).toList();

    final allSalonAppointments = relevantAppointments
        .where(
          (appointment) => _dateRangesOverlap(
            appointment.start,
            appointment.end,
            rangeStart,
            rangeEnd,
          ),
        )
        .sortedBy((appointment) => appointment.start);
    final appointments = allSalonAppointments
        .where(
          (appointment) =>
              staffIds.isEmpty || staffIds.contains(appointment.staffId),
        )
        .where(
          (appointment) => _dateRangesOverlap(
            appointment.start,
            appointment.end,
            rangeStart,
            rangeEnd,
          ),
        )
        .sortedBy((appointment) => appointment.start);
    final filteredAppointments =
        appointments
            .where(
              (appointment) => _isWeekdayVisible(appointment.start.weekday),
            )
            .toList();
    final clientsWithOutstandingPayments = _clientsWithOutstandingPayments(
      appointments: filteredAppointments,
      sales: data.sales,
      tickets: data.paymentTickets,
    );

    final List<Shift> shifts = relevantShifts
        .where((shift) => staffIds.isEmpty || staffIds.contains(shift.staffId))
        .where(
          (shift) =>
              _dateRangesOverlap(shift.start, shift.end, rangeStart, rangeEnd),
        )
        .sortedBy((shift) => shift.start);
    final filteredShifts =
        shifts
            .where((shift) => _isWeekdayVisible(shift.start.weekday))
            .toList();
    final List<StaffAbsence> absences = relevantAbsencesAll
        .where(
          (absence) => staffIds.isEmpty || staffIds.contains(absence.staffId),
        )
        .where(
          (absence) => _dateRangesOverlap(
            absence.start,
            absence.end,
            rangeStart,
            rangeEnd,
          ),
        )
        .sortedBy((absence) => absence.start);
    final filteredAbsences =
        absences
            .where((absence) => _isWeekdayVisible(absence.start.weekday))
            .toList();

    // Build placeholders for active last-minute slots to flag conflicts visually
    final nowReference = DateTime.now();
    final rawLastMinuteSlots = data.lastMinuteSlots;
    final expressPlaceholders = rawLastMinuteSlots
        .where((slot) {
          if (widget.salonId != null && slot.salonId != widget.salonId) {
            return false;
          }
          // We only display active/future slots with a specific operator
          if (!slot.isAvailable || slot.operatorId == null) {
            return false;
          }
          if (!slot.end.isAfter(nowReference)) {
            return false;
          }
          // Restrict to the currently visible date range for performance
          final slotStart = slot.start;
          final slotEnd = slot.end;
          return _dateRangesOverlap(slotStart, slotEnd, rangeStart, rangeEnd);
        })
        .map(
          (slot) => Appointment(
            id: 'last-minute-${slot.id}',
            salonId: slot.salonId,
            clientId: 'last-minute-${slot.id}',
            staffId: slot.operatorId!,
            serviceIds:
                slot.serviceId != null && slot.serviceId!.isNotEmpty
                    ? <String>[slot.serviceId!]
                    : const <String>[],
            start: slot.start,
            end: slot.end,
            status: AppointmentStatus.scheduled,
            roomId: slot.roomId,
            notes: 'Slot last-minute disponibile',
            lastMinuteSlotId: slot.id,
          ),
        )
        .sortedBy((a) => a.start)
        .toList(growable: false);

    // Augment all-appointments with placeholders for conflict checks and drag behavior
    final allAppointmentsWithPlaceholders = <Appointment>[
      ...allSalonAppointments,
      ...expressPlaceholders,
    ];

    // Keep the source slots for overlay interaction (edit/delete)
    final lastMinuteSlotsInRange = rawLastMinuteSlots
        .where((slot) {
          if (widget.salonId != null && slot.salonId != widget.salonId) {
            return false;
          }
          if (slot.operatorId == null) {
            return false;
          }
          if (!slot.end.isAfter(nowReference)) {
            return false;
          }
          return _dateRangesOverlap(slot.start, slot.end, rangeStart, rangeEnd);
        })
        .toList(growable: false);

    final roomsById = _buildRoomsIndex(salons, widget.salonId);
    final rangeLabel = _buildRangeLabel(rangeStart, rangeEnd, _scope);
    final staffSelectionKey = _staffSelectionKey(selectedStaffIds);
    final theme = Theme.of(context);
    final moduleBackground = theme.colorScheme.surfaceContainerLowest;

    return ColoredBox(
      color: moduleBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildToolbar(
              context,
              salons: salons,
              clients: clients,
              staff: staffMembers,
              services: services,
              rangeLabel: rangeLabel,
              selectedSalon: selectedSalon,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child:
                  _mode == _AppointmentDisplayMode.calendar
                      ? AppointmentCalendarView(
                        key: ValueKey(
                          'calendar-${_scope.name}-${_weekLayoutMode.name}-$staffSelectionKey-${rangeStart.toIso8601String()}',
                        ),
                        anchorDate: rangeStart,
                        scope: _scope,
                        weekLayout:
                            _scope == AppointmentCalendarScope.week
                                ? _effectiveWeekLayout
                                : AppointmentWeekLayoutMode.detailed,
                        appointments: filteredAppointments,
                        allAppointments: allAppointmentsWithPlaceholders,
                        lastMinutePlaceholders: expressPlaceholders,
                        lastMinuteSlots: lastMinuteSlotsInRange,
                        staff: visibleStaff,
                        clients: clients,
                        clientsWithOutstandingPayments:
                            clientsWithOutstandingPayments,
                        services: services,
                        serviceCategories: data.serviceCategories,
                        shifts: filteredShifts,
                        absences: filteredAbsences,
                        roles: data.staffRoles,
                        schedule: selectedSalon?.schedule,
                        roomsById: roomsById,
                        salonsById: salonsById,
                        visibleWeekdays: _visibleWeekdays,
                        lockedAppointmentReasons: lockedAppointmentReasons,
                        anomalies: anomalies,
                        statusColor:
                            (status) => _colorForStatus(context, status),
                        dayChecklists: dayChecklists,
                        onTapLastMinuteSlot:
                            (slot) => _onTapLastMinuteSlot(
                              context,
                              slot,
                              salons: salons,
                              staff: staffMembers,
                              services: services,
                            ),
                        onReschedule:
                            _isRescheduling ? (_) async {} : _onReschedule,
                        onEdit:
                            (appointment) => _handleEditAppointment(
                              context,
                              appointment,
                              salons: salons,
                              clients: clients,
                              staff: staffMembers,
                              services: services,
                            ),
                        onCreate:
                            (selection) => _onSlotSelected(
                              context,
                              selection,
                              salons,
                              clients,
                              staffMembers,
                              services,
                            ),
                        slotMinutes: _calendarSlotMinutes,
                        onAddChecklistItem:
                            _checklistEditingEnabled ? _addChecklistItem : null,
                        onToggleChecklistItem:
                            _checklistEditingEnabled
                                ? _toggleChecklistItem
                                : null,
                        onRenameChecklistItem:
                            _checklistEditingEnabled
                                ? _renameChecklistItem
                                : null,
                        onDeleteChecklistItem:
                            _checklistEditingEnabled
                                ? _deleteChecklistItem
                                : null,
                      )
                      : _ListAppointmentsView(
                        key: ValueKey(
                          'list-${_scope.name}-$staffSelectionKey-${rangeStart.toIso8601String()}',
                        ),
                        appointments: filteredAppointments,
                        lastMinutePlaceholders: expressPlaceholders,
                        data: data,
                        rangeStart: rangeStart,
                        rangeEnd: rangeEnd,
                        lockedReasons: lockedAppointmentReasons,
                        anomalies: anomalies,
                        attentionAppointments: attentionAppointments,
                        onEdit:
                            (appointment) => _handleEditAppointment(
                              context,
                              appointment,
                              salons: salons,
                              clients: clients,
                              staff: staffMembers,
                              services: services,
                            ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context, {
    required List<Salon> salons,
    required List<Client> clients,
    required List<StaffMember> staff,
    required List<Service> services,
    required String rangeLabel,
    Salon? selectedSalon,
  }) {
    const compactDensity = VisualDensity(horizontal: -2, vertical: -2);
    final tonalButtonStyle = FilledButton.styleFrom(
      visualDensity: compactDensity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      minimumSize: const Size(0, 40),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final visionButton = FilledButton.tonalIcon(
          style: tonalButtonStyle,
          onPressed: () => _openAgendaVisionDialog(context, staff: staff),
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Visione agenda'),
        );
        final todayButton = FilledButton.tonal(
          style: tonalButtonStyle,
          onPressed: _goToToday,
          child: const Text('Oggi'),
        );
        final goToDateButton = FilledButton.tonalIcon(
          style: tonalButtonStyle,
          onPressed: () => _pickDate(),
          icon: const Icon(Icons.event_available_rounded),
          label: const Text('Vai a data'),
        );
        final rangeNavigator = _RangeNavigator(
          label: rangeLabel,
          onPrevious: () => _shiftAnchor(-1),
          onNext: () => _shiftAnchor(1),
        );
        final centerControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            todayButton,
            const SizedBox(width: 12),
            rangeNavigator,
            const SizedBox(width: 12),
            goToDateButton,
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              visionButton,
              const SizedBox(height: 12),
              Center(child: centerControls),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            visionButton,
            const SizedBox(width: 16),
            Expanded(
              child: Align(alignment: Alignment.center, child: centerControls),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) {
      setState(() {
        if (_scope == AppointmentCalendarScope.week) {
          _anchorDate = _startOfWeek(picked);
        } else {
          final desired = DateTime(picked.year, picked.month, picked.day);
          _anchorDate =
              _isWeekdayVisible(desired.weekday)
                  ? desired
                  : _findNextVisibleDay(desired, 1);
        }
      });
    }
  }

  void _updateScope(AppointmentCalendarScope scope) {
    if (scope == _scope) {
      return;
    }
    setState(() {
      _scope = scope;
      if (_scope == AppointmentCalendarScope.week) {
        _anchorDate = _startOfWeek(_anchorDate);
      } else {
        _anchorDate = _findNextVisibleDay(_anchorDate, 1);
      }
    });
  }

  void _shiftAnchor(int direction) {
    final deltaDays = _scope == AppointmentCalendarScope.day ? 1 : 7;
    setState(() {
      if (_scope == AppointmentCalendarScope.day) {
        var candidate = _anchorDate.add(Duration(days: direction));
        candidate = _findNextVisibleDay(candidate, direction);
        _anchorDate = candidate;
      } else {
        _anchorDate = _anchorDate.add(Duration(days: deltaDays * direction));
      }
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      final today = DateTime(now.year, now.month, now.day);
      _anchorDate =
          _scope == AppointmentCalendarScope.week
              ? _startOfWeek(today)
              : _findNextVisibleDay(today, 1);
    });
  }

  Future<void> _openWeekdayFilter(
    BuildContext context,
    Salon? selectedSalon,
  ) async {
    final allowedDays =
        selectedSalon == null || selectedSalon.schedule.isEmpty
            ? null
            : selectedSalon.schedule
                .where((entry) => entry.isOpen)
                .map((entry) => entry.weekday)
                .toSet();

    var options = _weekdayOptions;
    if (allowedDays != null && allowedDays.isNotEmpty) {
      final filtered =
          _weekdayOptions
              .where((option) => allowedDays.contains(option.key))
              .toList();
      if (filtered.isNotEmpty) {
        options = filtered;
      }
    }

    final tempSelection = Set<int>.from(
      _visibleWeekdays.where(
        (day) => allowedDays == null || allowedDays.contains(day),
      ),
    );
    if (tempSelection.isEmpty) {
      tempSelection.add(options.first.key);
    }

    final ferialiKeys =
        options
            .where(
              (entry) =>
                  entry.key != DateTime.saturday &&
                  entry.key != DateTime.sunday,
            )
            .map((entry) => entry.key)
            .toList();

    final result = await showAppModalSheet<Set<int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Giorni visibili',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (allowedDays != null && allowedDays.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sono disponibili solo i giorni in cui il salone è aperto.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  ...options.map((option) {
                    final selected = tempSelection.contains(option.key);
                    return CheckboxListTile(
                      value: selected,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(option.value),
                      onChanged: (value) {
                        if (value == true) {
                          setModalState(() => tempSelection.add(option.key));
                        } else if (tempSelection.length > 1) {
                          setModalState(() => tempSelection.remove(option.key));
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed:
                            () => setModalState(() {
                              tempSelection
                                ..clear()
                                ..addAll(options.map((entry) => entry.key));
                            }),
                        child: const Text('Seleziona tutti'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed:
                            ferialiKeys.isEmpty
                                ? null
                                : () => setModalState(() {
                                  tempSelection
                                    ..clear()
                                    ..addAll(ferialiKeys);
                                }),
                        child: const Text('Solo feriali'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annulla'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed:
                            tempSelection.isEmpty
                                ? null
                                : () => Navigator.pop(
                                  context,
                                  Set<int>.from(tempSelection),
                                ),
                        child: const Text('Applica'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _visibleWeekdays
          ..clear()
          ..addAll(result);
        _ensureAnchorVisible();
      });
    }
  }

  bool _isWeekdayVisible(int weekday) => _visibleWeekdays.contains(weekday);

  DateTime _findNextVisibleDay(DateTime start, int direction) {
    var candidate = DateTime(start.year, start.month, start.day);
    for (var i = 0; i < 7; i++) {
      if (_isWeekdayVisible(candidate.weekday)) {
        return candidate;
      }
      candidate = candidate.add(Duration(days: direction >= 0 ? 1 : -1));
    }
    return DateTime(start.year, start.month, start.day);
  }

  void _ensureAnchorVisible() {
    if (_scope == AppointmentCalendarScope.day &&
        !_isWeekdayVisible(_anchorDate.weekday)) {
      _anchorDate = _findNextVisibleDay(_anchorDate, 1);
    }
  }

  void _onSlotSelected(
    BuildContext context,
    AppointmentSlotSelection selection,
    List<Salon> salons,
    List<Client> clients,
    List<StaffMember> staff,
    List<Service> services,
  ) async {
    final staffMember = staff.firstWhereOrNull(
      (member) => member.id == selection.staffId,
    );
    final defaultSalonId =
        staffMember?.salonId ??
        widget.salonId ??
        (salons.isNotEmpty ? salons.first.id : null);

    final clipboard = ref.read(appointmentClipboardProvider);

    final slotAction = await showAppModalSheet<_SlotAction>(
      context: context,
      builder: (modalContext) {
        final tiles = <Widget>[
          ListTile(
            leading: const Icon(Icons.event_available_rounded),
            title: const Text('Crea appuntamento standard'),
            onTap:
                () => Navigator.of(modalContext).pop(_SlotAction.appointment),
          ),
        ];
        if (clipboard != null) {
          final title = _clipboardActionTitle(clipboard, clients: clients);
          final subtitle = _clipboardActionSubtitle(
            clipboard,
            services: services,
          );
          tiles.add(
            ListTile(
              leading: const Icon(Icons.content_paste_go_rounded),
              title: Text(title),
              subtitle: subtitle != null ? Text(subtitle) : null,
              onTap:
                  () => Navigator.of(
                    modalContext,
                  ).pop(_SlotAction.copyFromClipboard),
            ),
          );
        }
        tiles.add(
          ListTile(
            leading: const Icon(Icons.flash_on_rounded),
            title: const Text('Crea slot express last-minute'),
            onTap: () => Navigator.of(modalContext).pop(_SlotAction.express),
          ),
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [...tiles, const SizedBox(height: 12)],
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    if (slotAction == null) {
      return;
    }

    if (slotAction == _SlotAction.appointment) {
      _openAppointmentForm(
        context,
        salons: salons,
        clients: clients,
        staff: staff,
        services: services,
        initialStart: selection.start,
        initialEnd: selection.end,
        initialStaffId: staffMember?.id,
        initialSalonId: defaultSalonId,
      );
      return;
    }

    if (slotAction == _SlotAction.copyFromClipboard) {
      await _createAppointmentFromClipboard(
        context,
        selection: selection,
        salons: salons,
        clients: clients,
        staff: staff,
        services: services,
      );
      return;
    }

    await _openExpressSlotSheet(
      context,
      selection: selection,
      salons: salons,
      staff: staff,
      services: services,
      defaultSalonId: defaultSalonId,
    );
  }

  String _clipboardActionTitle(
    AppointmentClipboard clipboard, {
    required List<Client> clients,
  }) {
    final client = clients.firstWhereOrNull(
      (item) => item.id == clipboard.appointment.clientId,
    );
    final name = client?.fullName.trim();
    if (name == null || name.isEmpty) {
      return 'Copia appuntamento';
    }
    return 'Copia appuntamento $name';
  }

  String? _clipboardActionSubtitle(
    AppointmentClipboard clipboard, {
    required List<Service> services,
  }) {
    final serviceNames = clipboard.appointment.serviceIds
        .map((id) => services.firstWhereOrNull((service) => service.id == id))
        .whereType<Service>()
        .map((service) => service.name)
        .toList(growable: false);
    final parts = <String>[];
    if (serviceNames.isNotEmpty) {
      parts.add(serviceNames.join(', '));
    }
    final minutes = clipboard.appointment.duration.inMinutes;
    if (minutes > 0) {
      parts.add('$minutes min');
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' • ');
  }

  Future<void> _createAppointmentFromClipboard(
    BuildContext context, {
    required AppointmentSlotSelection selection,
    required List<Salon> salons,
    required List<Client> clients,
    required List<StaffMember> staff,
    required List<Service> services,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final clipboard = ref.read(appointmentClipboardProvider);
    if (clipboard == null) {
      return;
    }
    final template = clipboard.appointment;
    final staffMember = staff.firstWhereOrNull(
      (member) => member.id == selection.staffId,
    );
    final appointmentServices = template.serviceIds
        .map((id) => services.firstWhereOrNull((service) => service.id == id))
        .whereType<Service>()
        .toList(growable: false);
    if (staffMember == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile copiare l\'appuntamento: operatore non valido.',
          ),
        ),
      );
      return;
    }
    final incompatibleService = appointmentServices.firstWhereOrNull((service) {
      if (service.staffRoles.isEmpty) {
        return false;
      }
      return !staffMember.roleIds.any(service.staffRoles.contains);
    });
    if (incompatibleService != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'L\'operatore selezionato non può erogare '
            '"${incompatibleService.name}".',
          ),
        ),
      );
      return;
    }
    final duration = template.duration;
    if (duration <= Duration.zero) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Durata appuntamento non valida.')),
      );
      return;
    }
    final computedEnd = selection.start.add(duration);
    final data = ref.read(appDataProvider);
    final nowReference = DateTime.now();
    final expressPlaceholders =
        data.lastMinuteSlots
            .where((slot) {
              if (slot.salonId != staffMember.salonId) {
                return false;
              }
              if (slot.operatorId != staffMember.id) {
                return false;
              }
              if (!slot.isAvailable) {
                return false;
              }
              if (!slot.end.isAfter(nowReference)) {
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
    final combinedAppointments = <Appointment>[
      ...data.appointments,
      ...expressPlaceholders,
    ];
    final hasInsufficientSpace = hasStaffBookingConflict(
      appointments: combinedAppointments,
      staffId: staffMember.id,
      start: selection.start,
      end: computedEnd,
    );
    if (hasInsufficientSpace) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'La durata del trattamento supera lo slot selezionato. '
            'Scegli uno slot più lungo.',
          ),
        ),
      );
      return;
    }
    final staffSalonId = staffMember.salonId.trim();
    final salonId = staffSalonId.isNotEmpty ? staffSalonId : template.salonId;
    final appointment = template.copyWith(
      id: _uuid.v4(),
      salonId: salonId,
      staffId: selection.staffId,
      start: selection.start,
      end: computedEnd,
    );
    final saved = await _validateAndSaveAppointment(
      context,
      ref,
      appointment,
      services,
      salons,
    );
    if (!saved || !mounted) {
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Appuntamento copiato sullo slot selezionato.'),
      ),
    );
  }

  void _handleEditAppointment(
    BuildContext context,
    Appointment appointment, {
    required List<Salon> salons,
    required List<Client> clients,
    required List<StaffMember> staff,
    required List<Service> services,
  }) {
    final now = DateTime.now();
    final restriction = _modificationRestrictionReason(appointment, now);
    if (restriction != null) {
      _showAppointmentDetails(
        context,
        appointment,
        salons: salons,
        clients: clients,
        staff: staff,
        services: services,
        infoMessage: restriction,
      );
      return;
    }
    _openAppointmentForm(
      context,
      salons: salons,
      clients: clients,
      staff: staff,
      services: services,
      existing: appointment,
    );
  }

  Future<void> _onTapLastMinuteSlot(
    BuildContext context,
    LastMinuteSlot slot, {
    required List<Salon> salons,
    required List<StaffMember> staff,
    required List<Service> services,
  }) async {
    final action = await showAppModalSheet<String>(
      context: context,
      builder: (modalContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Modifica slot last-minute'),
                onTap: () => Navigator.of(modalContext).pop('edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Elimina slot last-minute'),
                onTap: () => Navigator.of(modalContext).pop('delete'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'delete') {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final when = DateFormat(
            'dd/MM/yyyy HH:mm',
            'it_IT',
          ).format(slot.start);
          return AlertDialog(
            title: const Text('Rimuovi slot last-minute'),
            content: Text('Vuoi rimuovere lo slot last-minute delle $when?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Rimuovi'),
              ),
            ],
          );
        },
      );
      if (shouldDelete == true) {
        await ref.read(appDataProvider.notifier).deleteLastMinuteSlot(slot.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Slot last-minute rimosso.')),
        );
      }
      return;
    }

    // Edit flow
    final salon = salons.firstWhereOrNull((s) => s.id == slot.salonId);
    final servicesForSalon = services
        .where((service) => service.salonId == slot.salonId && service.isActive)
        .sortedBy((service) => service.name.toLowerCase());
    final staffForSalon =
        staff
            .where(
              (member) => member.salonId == slot.salonId && member.isActive,
            )
            .sortedByDisplayOrder();
    final rooms = salon?.rooms ?? const <SalonRoom>[];
    final data = ref.read(appDataProvider);
    final reminderSettings = data.reminderSettings.firstWhereOrNull(
      (settings) => settings.salonId == slot.salonId,
    );
    final clientsForSalon = data.clients
        .where((client) => client.salonId == slot.salonId)
        .sortedBy((client) => client.fullName.toLowerCase())
        .toList(growable: false);

    final result = await showAppModalSheet<ExpressSlotSheetResult>(
      context: context,
      builder: (sheetContext) {
        return ExpressSlotSheet(
          salonId: slot.salonId,
          initialStart: slot.start,
          initialEnd: slot.end,
          services: servicesForSalon,
          staff: staffForSalon,
          rooms: rooms,
          initialStaffId: slot.operatorId,
          initialSlot: slot,
          clients: clientsForSalon,
          reminderSettings: reminderSettings,
        );
      },
    );
    if (result == null) {
      return;
    }
    final updated = result.slot;
    final notification = result.notification;
    try {
      await ref.read(appDataProvider.notifier).upsertLastMinuteSlot(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot last-minute aggiornato.')),
      );
      if (notification != null && mounted) {
        await _dispatchLastMinuteNotification(
          context: context,
          slot: updated,
          notification: notification,
        );
      }
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _dispatchLastMinuteNotification({
    required BuildContext context,
    required LastMinuteSlot slot,
    required LastMinuteNotificationRequest notification,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(appDataProvider.notifier)
          .sendLastMinuteNotification(slot: slot, request: notification);
      if (!mounted) {
        return;
      }
      final buffer =
          StringBuffer()
            ..write('Notifica slot inviata: ')
            ..write('${result.successCount} ok');
      if (result.failureCount > 0) {
        buffer.write(', ${result.failureCount} errori');
      }
      if (result.skippedCount > 0) {
        buffer.write(', ${result.skippedCount} esclusi');
      }
      messenger.showSnackBar(SnackBar(content: Text(buffer.toString())));
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }
      final message =
          error.message ?? 'Invio notifica non riuscito: ${error.code}';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Invio notifica non riuscito: $error')),
      );
    }
  }

  Future<void> _openExpressSlotSheet(
    BuildContext context, {
    required AppointmentSlotSelection selection,
    required List<Salon> salons,
    required List<StaffMember> staff,
    required List<Service> services,
    required String? defaultSalonId,
  }) async {
    final resolvedSalonId =
        defaultSalonId ??
        widget.salonId ??
        (salons.isNotEmpty ? salons.first.id : null);
    if (resolvedSalonId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona un salone per creare slot last-minute.'),
        ),
      );
      return;
    }

    final salon = salons.firstWhereOrNull(
      (element) => element.id == resolvedSalonId,
    );
    final data = ref.read(appDataProvider);
    final reminderSettings = data.reminderSettings.firstWhereOrNull(
      (settings) => settings.salonId == resolvedSalonId,
    );
    final clientsForSalon = data.clients
        .where((client) => client.salonId == resolvedSalonId)
        .sortedBy((client) => client.fullName.toLowerCase())
        .toList(growable: false);
    final servicesForSalon = services
        .where(
          (service) => service.salonId == resolvedSalonId && service.isActive,
        )
        .sortedBy((service) => service.name.toLowerCase());
    final staffForSalon =
        staff
            .where(
              (member) => member.salonId == resolvedSalonId && member.isActive,
            )
            .sortedByDisplayOrder();
    final rooms = salon?.rooms ?? const <SalonRoom>[];

    final result = await showAppModalSheet<ExpressSlotSheetResult>(
      context: context,
      builder: (sheetContext) {
        return ExpressSlotSheet(
          salonId: resolvedSalonId,
          initialStart: selection.start,
          initialEnd: selection.end,
          services: servicesForSalon,
          staff: staffForSalon,
          rooms: rooms,
          initialStaffId: selection.staffId,
          clients: clientsForSalon,
          reminderSettings: reminderSettings,
        );
      },
    );

    if (result == null) {
      return;
    }
    final slot = result.slot;
    final notification = result.notification;

    try {
      await ref.read(appDataProvider.notifier).upsertLastMinuteSlot(slot);
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) {
      return;
    }
    final featureEnabled = salon?.featureFlags.clientLastMinute ?? false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          featureEnabled
              ? 'Slot last-minute creato.'
              : 'Slot creato. Attiva il flag “clientLastMinute” per renderlo visibile ai clienti.',
        ),
      ),
    );
    if (notification != null && mounted) {
      await _dispatchLastMinuteNotification(
        context: context,
        slot: slot,
        notification: notification,
      );
    }
  }

  Future<void> _onReschedule(AppointmentRescheduleRequest request) async {
    final appointment = request.appointment;
    final newStaffId = request.newStaffId ?? appointment.staffId;
    final newRoomId = request.newRoomId ?? appointment.roomId;
    final messenger = ScaffoldMessenger.of(context);
    if (!mounted || _isRescheduling) {
      return;
    }
    final now = DateTime.now();
    final restriction = _modificationRestrictionReason(appointment, now);
    if (restriction != null) {
      final data = ref.read(appDataProvider);
      _showAppointmentDetails(
        context,
        appointment,
        salons: data.salons,
        clients: data.clients,
        staff: data.staff,
        services: data.services,
        infoMessage: restriction,
      );
      return;
    }
    if (appointment.start == request.newStart &&
        appointment.end == request.newEnd &&
        appointment.staffId == newStaffId &&
        appointment.roomId == newRoomId) {
      return;
    }
    setState(() => _isRescheduling = true);
    final updated = appointment.copyWith(
      staffId: newStaffId,
      start: request.newStart,
      end: request.newEnd,
      roomId: newRoomId,
    );

    final data = ref.read(appDataProvider);
    final existingAppointments = data.appointments;
    final nowReference = DateTime.now();
    final expressPlaceholders =
        data.lastMinuteSlots
            .where((slot) {
              if (slot.salonId != updated.salonId) {
                return false;
              }
              if (slot.operatorId != updated.staffId) {
                return false;
              }
              if (!slot.isAvailable) {
                return false;
              }
              if (!slot.end.isAfter(nowReference)) {
                return false;
              }
              return true;
            })
            .map(
              (slot) => Appointment(
                id: 'last-minute-${slot.id}',
                salonId: slot.salonId,
                clientId: 'last-minute-${slot.id}',
                staffId: slot.operatorId ?? updated.staffId,
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
    final combinedAppointments = <Appointment>[
      ...existingAppointments,
      ...expressPlaceholders,
    ];
    final hasStaffConflict = hasStaffBookingConflict(
      appointments: combinedAppointments,
      staffId: updated.staffId,
      start: updated.start,
      end: updated.end,
      excludeAppointmentId: updated.id,
    );
    if (hasStaffConflict) {
      if (mounted) {
        setState(() => _isRescheduling = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Impossibile spostare: operatore già occupato in quel periodo',
            ),
          ),
        );
      }
      return;
    }
    final hasClientConflict = hasClientBookingConflict(
      appointments: existingAppointments,
      clientId: updated.clientId,
      start: updated.start,
      end: updated.end,
      excludeAppointmentId: updated.id,
    );
    if (hasClientConflict) {
      if (mounted) {
        setState(() => _isRescheduling = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Impossibile spostare: il cliente ha già un appuntamento in quel periodo',
            ),
          ),
        );
      }
      return;
    }
    final allServices = data.services;
    final allSalons = data.salons;
    final service = allServices.firstWhereOrNull(
      (item) => item.id == updated.serviceId,
    );
    if (service == null) {
      if (mounted) {
        setState(() => _isRescheduling = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('Servizio non valido.')),
        );
      }
      return;
    }
    final salon = allSalons.firstWhereOrNull(
      (item) => item.id == updated.salonId,
    );
    final equipmentCheck = EquipmentAvailabilityChecker.check(
      salon: salon,
      service: service,
      allServices: allServices,
      appointments: combinedAppointments,
      start: updated.start,
      end: updated.end,
      excludeAppointmentId: updated.id,
    );
    if (equipmentCheck.hasConflicts) {
      if (mounted) {
        final equipmentLabel = equipmentCheck.blockingEquipment.join(', ');
        final message =
            equipmentLabel.isEmpty
                ? 'Macchinario non disponibile per questo orario.'
                : 'Macchinario non disponibile per questo orario: $equipmentLabel.';
        setState(() => _isRescheduling = false);
        messenger.showSnackBar(
          SnackBar(content: Text('$message Scegli un altro slot.')),
        );
      }
      return;
    }
    try {
      await ref.read(appDataProvider.notifier).upsertAppointment(updated);
      if (!mounted) {
        return;
      }
      final label = DateFormat(
        'dd MMM HH:mm',
        'it_IT',
      ).format(request.newStart);
      messenger.showSnackBar(
        SnackBar(content: Text('Appuntamento spostato a $label.')),
      );
    } on StateError catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Errore durante lo spostamento: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRescheduling = false);
      }
    }
  }

  Future<void> _showAppointmentDetails(
    BuildContext context,
    Appointment appointment, {
    required List<Salon> salons,
    required List<Client> clients,
    required List<StaffMember> staff,
    required List<Service> services,
    String? infoMessage,
  }) {
    final client = clients.firstWhereOrNull(
      (item) => item.id == appointment.clientId,
    );
    final staffMember = staff.firstWhereOrNull(
      (item) => item.id == appointment.staffId,
    );
    final appointmentServices =
        appointment.serviceIds
            .map((id) => services.firstWhereOrNull((item) => item.id == id))
            .whereType<Service>()
            .toList();
    final salon = salons.firstWhereOrNull(
      (item) => item.id == appointment.salonId,
    );
    final dateLabel = DateFormat(
      'EEEE dd MMMM yyyy HH:mm',
      'it_IT',
    ).format(appointment.start);
    final endLabel = DateFormat(
      'EEEE dd MMMM yyyy HH:mm',
      'it_IT',
    ).format(appointment.end);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final body = <Widget>[
          _buildAppointmentDetailRow('Cliente', client?.fullName ?? 'Cliente'),
          _buildAppointmentDetailRow(
            'Servizi',
            appointmentServices.isNotEmpty
                ? appointmentServices.map((service) => service.name).join(' + ')
                : 'Servizio',
          ),
          _buildAppointmentDetailRow(
            'Operatore',
            staffMember?.fullName ?? 'Staff',
          ),
          if (salon != null) _buildAppointmentDetailRow('Salone', salon.name),
          _buildAppointmentDetailRow('Inizio', dateLabel),
          _buildAppointmentDetailRow('Fine', endLabel),
          _buildAppointmentDetailRow('Stato', _statusLabel(appointment.status)),
          if (appointment.notes != null && appointment.notes!.isNotEmpty)
            _buildAppointmentDetailRow('Note', appointment.notes!),
        ];

        return AlertDialog(
          title: const Text('Dettagli appuntamento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (infoMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(infoMessage, style: theme.textTheme.bodyMedium),
                  ),
                ],
                ...body,
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Chiudi'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppointmentDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
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

  void _openAppointmentForm(
    BuildContext context, {
    required List<Salon> salons,
    required List<Client> clients,
    required List<StaffMember> staff,
    required List<Service> services,
    Appointment? existing,
    DateTime? initialStart,
    DateTime? initialEnd,
    String? initialStaffId,
    String? initialSalonId,
  }) {
    _openForm(
      context,
      ref,
      salons: salons,
      clients: clients,
      staff: staff,
      services: services,
      defaultSalonId: initialSalonId ?? widget.salonId,
      existing: existing,
      initialStart: initialStart,
      initialEnd: initialEnd,
      initialStaffId: initialStaffId,
    );
  }

  static Map<String, String> _buildRoomsIndex(
    List<Salon> salons,
    String? salonFilter,
  ) {
    final index = <String, String>{};
    for (final salon in salons) {
      if (salonFilter != null && salon.id != salonFilter) {
        continue;
      }
      for (final room in salon.rooms) {
        index[room.id] = room.name;
      }
    }
    return index;
  }

  DateTime _rangeStart(DateTime anchor, AppointmentCalendarScope scope) {
    if (scope == AppointmentCalendarScope.day) {
      final date = DateTime(anchor.year, anchor.month, anchor.day);
      return _isWeekdayVisible(date.weekday)
          ? date
          : _findNextVisibleDay(date, 1);
    }
    return _startOfWeek(anchor);
  }

  static DateTime _rangeEnd(DateTime start, AppointmentCalendarScope scope) {
    return scope == AppointmentCalendarScope.day
        ? start.add(const Duration(days: 1))
        : start.add(const Duration(days: 7));
  }

  static String _buildRangeLabel(
    DateTime start,
    DateTime end,
    AppointmentCalendarScope scope,
  ) {
    if (scope == AppointmentCalendarScope.day) {
      return _dayLabel.format(start);
    }
    final endInclusive = end.subtract(const Duration(days: 1));
    final startLabel = _weekStartLabel.format(start);
    final endLabel = _weekStartLabel.format(endInclusive);
    return 'Settimana $startLabel → $endLabel';
  }

  static bool _dateRangesOverlap(
    DateTime start,
    DateTime end,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return start.isBefore(rangeEnd) && end.isAfter(rangeStart);
  }

  static DateTime _startOfWeek(DateTime date) {
    final base = DateTime(date.year, date.month, date.day);
    final weekday = base.weekday; // Monday = 1
    return base.subtract(Duration(days: weekday - DateTime.monday));
  }

  Map<String, Set<AppointmentAnomalyType>> _detectAppointmentAnomalies({
    required List<Appointment> appointments,
    required List<Shift> shifts,
    required List<StaffAbsence> absences,
    required DateTime now,
  }) {
    if (appointments.isEmpty) {
      return <String, Set<AppointmentAnomalyType>>{};
    }

    final shiftsByStaff = groupBy<Shift, String>(
      shifts,
      (shift) => shift.staffId,
    );
    final absencesByStaff = groupBy<StaffAbsence, String>(
      absences,
      (absence) => absence.staffId,
    );

    final Map<String, Set<AppointmentAnomalyType>> result = {};

    for (final appointment in appointments) {
      final isLocked = _modificationRestrictionReason(appointment, now) != null;
      if (isLocked) {
        continue;
      }
      final issues = <AppointmentAnomalyType>{};

      final staffShifts = shiftsByStaff[appointment.staffId] ?? const [];
      final coveringShift = staffShifts.firstWhereOrNull(
        (shift) =>
            !shift.start.isAfter(appointment.start) &&
            !shift.end.isBefore(appointment.end),
      );
      if (coveringShift == null) {
        issues.add(AppointmentAnomalyType.noShift);
      } else if (_overlapsBreak(appointment, coveringShift)) {
        issues
          ..add(AppointmentAnomalyType.breakOverlap)
          ..add(AppointmentAnomalyType.noShift);
      }

      final staffAbsences = absencesByStaff[appointment.staffId] ?? const [];
      final hasAbsenceOverlap = staffAbsences.any(
        (absence) => _rangesOverlap(
          appointment.start,
          appointment.end,
          absence.start,
          absence.end,
        ),
      );
      if (hasAbsenceOverlap) {
        issues
          ..add(AppointmentAnomalyType.absenceOverlap)
          ..add(AppointmentAnomalyType.noShift);
      }

      final hasOutdatedStatus =
          appointment.end.isBefore(now) &&
          appointment.status == AppointmentStatus.scheduled;
      if (hasOutdatedStatus) {
        issues.add(AppointmentAnomalyType.outdatedStatus);
      }

      if (issues.isNotEmpty) {
        result[appointment.id] = issues;
      }
    }

    return result;
  }

  static bool _overlapsBreak(Appointment appointment, Shift shift) {
    final breakStart = shift.breakStart;
    final breakEnd = shift.breakEnd;
    if (breakStart == null || breakEnd == null) {
      return false;
    }
    return _rangesOverlap(
      appointment.start,
      appointment.end,
      breakStart,
      breakEnd,
    );
  }

  static bool _rangesOverlap(
    DateTime start,
    DateTime end,
    DateTime otherStart,
    DateTime otherEnd,
  ) {
    return _dateRangesOverlap(start, end, otherStart, otherEnd);
  }

  String? _modificationRestrictionReason(
    Appointment appointment,
    DateTime now,
  ) {
    final today = DateUtils.dateOnly(now);
    final appointmentDay = DateUtils.dateOnly(appointment.start);
    if (!appointmentDay.isBefore(today)) {
      return null;
    }
    switch (appointment.status) {
      case AppointmentStatus.completed:
        return 'Appuntamento completato: non è possibile modificarlo.';
      case AppointmentStatus.cancelled:
        return null;
      case AppointmentStatus.noShow:
        return 'Appuntamento segnato come no show: non è possibile modificarlo.';
      case AppointmentStatus.scheduled:
        return null;
    }
  }

  Color _colorForStatus(BuildContext context, AppointmentStatus status) {
    final scheme = Theme.of(context).colorScheme;
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
}

class _RangeNavigator extends StatelessWidget {
  const _RangeNavigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Periodo precedente',
              onPressed: onPrevious,
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.onPrimaryContainer.withOpacity(
                  0.08,
                ),
                foregroundColor: colorScheme.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(40, 40),
                visualDensity: const VisualDensity(
                  horizontal: -1,
                  vertical: -1,
                ),
              ),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            const SizedBox(width: 20),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 20),
            IconButton(
              tooltip: 'Periodo successivo',
              onPressed: onNext,
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.onPrimaryContainer.withOpacity(
                  0.08,
                ),
                foregroundColor: colorScheme.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(40, 40),
                visualDensity: const VisualDensity(
                  horizontal: -1,
                  vertical: -1,
                ),
              ),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListAppointmentsView extends StatelessWidget {
  const _ListAppointmentsView({
    super.key,
    required this.appointments,
    required this.lastMinutePlaceholders,
    required this.data,
    required this.rangeStart,
    required this.rangeEnd,
    required this.lockedReasons,
    required this.anomalies,
    required this.attentionAppointments,
    required this.onEdit,
  });

  final List<Appointment> appointments;
  final List<Appointment> lastMinutePlaceholders;
  final AppDataState data;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final Map<String, String> lockedReasons;
  final Map<String, Set<AppointmentAnomalyType>> anomalies;
  final List<Appointment> attentionAppointments;
  final ValueChanged<Appointment> onEdit;

  @override
  Widget build(BuildContext context) {
    final combined = <Appointment>[...appointments];
    final placeholderIds = <String>{};
    for (final placeholder in lastMinutePlaceholders) {
      placeholderIds.add(placeholder.id);
      combined.add(placeholder);
    }
    combined.sort((a, b) => a.start.compareTo(b.start));

    if (combined.isEmpty && attentionAppointments.isEmpty) {
      return const Center(
        child: Text('Nessun appuntamento pianificato per questo periodo.'),
      );
    }

    final grouped = groupBy<Appointment, DateTime>(
      combined,
      (appointment) => DateUtils.dateOnly(appointment.start),
    );
    final orderedDates = grouped.keys.toList()..sort((a, b) => a.compareTo(b));
    final dateFormat = DateFormat('EEEE dd MMMM', 'it_IT');
    final items = <Widget>[];
    if (attentionAppointments.isNotEmpty) {
      items.add(
        _AttentionAppointmentsCard(
          appointments: attentionAppointments,
          data: data,
          anomalies: anomalies,
          lockedReasons: lockedReasons,
          onEdit: onEdit,
        ),
      );
    }

    items.addAll(
      orderedDates.map((day) {
        final entries = grouped[day] ?? const <Appointment>[];
        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            initiallyExpanded: DateUtils.isSameDay(day, DateTime.now()),
            title: Text(
              dateFormat.format(day),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            children:
                entries.map((appointment) {
                  final isPlaceholder = placeholderIds.contains(appointment.id);
                  final issues =
                      anomalies[appointment.id] ??
                      const <AppointmentAnomalyType>{};
                  final hasIssues = issues.isNotEmpty;
                  final isCancelled =
                      appointment.status == AppointmentStatus.cancelled;
                  final List<AppointmentAnomalyType> issueSummary =
                      hasIssues
                          ? (issues.toList()
                            ..sort((a, b) => a.index.compareTo(b.index)))
                          : const <AppointmentAnomalyType>[];
                  final attentionReasons = <String>[];
                  if (isCancelled) {
                    attentionReasons.add('Appuntamento annullato');
                  }
                  if (hasIssues) {
                    attentionReasons.addAll(
                      issueSummary.map((issue) => issue.label),
                    );
                  }
                  final attentionLine =
                      attentionReasons.isNotEmpty
                          ? 'Attenzione: ${attentionReasons.join(', ')}'
                          : null;
                  final subtitleLines = <String>[
                    _buildSubtitle(appointment, data),
                  ];
                  if (attentionLine != null) {
                    subtitleLines.add(attentionLine);
                  }
                  final lockReason = lockedReasons[appointment.id];
                  if (lockReason != null) {
                    subtitleLines.add(lockReason);
                  }
                  final theme = Theme.of(context);
                  final needsAttention = hasIssues || isCancelled;
                  final iconData =
                      needsAttention
                          ? hasIssues
                              ? AppointmentAnomalyType.noShift.icon
                              : Icons.cancel_rounded
                          : lockReason != null
                          ? Icons.lock_rounded
                          : isPlaceholder
                          ? Icons.flash_on_rounded
                          : Icons.spa_rounded;
                  final iconColor =
                      needsAttention
                          ? hasIssues
                              ? theme.colorScheme.error
                              : theme.colorScheme.outlineVariant
                          : lockReason != null
                          ? theme.colorScheme.outline
                          : isPlaceholder
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Icon(iconData, color: iconColor),
                    title: Text(
                      _buildTitle(
                        appointment,
                        data,
                        isPlaceholder: isPlaceholder,
                      ),
                    ),
                    subtitle: Text(
                      _buildSubtitle(
                        appointment,
                        data,
                        isPlaceholder: isPlaceholder,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_AppointmentsModuleState._timeLabel.format(appointment.start)} - ${_AppointmentsModuleState._timeLabel.format(appointment.end)}',
                        ),
                        const SizedBox(height: 4),
                        _StatusPill(status: appointment.status),
                      ],
                    ),
                    onTap: isPlaceholder ? null : () => onEdit(appointment),
                    enabled: !isPlaceholder,
                  );
                }).toList(),
          ),
        );
      }),
    );

    return ListView(padding: const EdgeInsets.all(16), children: items);
  }

  static String _buildTitle(
    Appointment appointment,
    AppDataState data, {
    bool isPlaceholder = false,
  }) {
    final client =
        data.clients
            .firstWhereOrNull((client) => client.id == appointment.clientId)
            ?.fullName ??
        (isPlaceholder ? 'Slot last-minute' : 'Cliente');
    final services =
        appointment.serviceIds
            .map(
              (id) =>
                  data.services.firstWhereOrNull((service) => service.id == id),
            )
            .whereType<Service>()
            .map((service) => service.name)
            .toList();
    final serviceLabel =
        services.isNotEmpty ? services.join(' + ') : 'Servizio';
    return '$client • $serviceLabel';
  }

  static String _buildSubtitle(
    Appointment appointment,
    AppDataState data, {
    bool isPlaceholder = false,
  }) {
    final staff =
        data.staff
            .firstWhereOrNull((member) => member.id == appointment.staffId)
            ?.fullName ??
        'Staff';
    final room =
        data.salons
            .firstWhereOrNull((salon) => salon.id == appointment.salonId)
            ?.rooms
            .firstWhereOrNull((room) => room.id == appointment.roomId)
            ?.name;
    final buffer = StringBuffer(staff);
    if (room != null) {
      buffer.write(' · $room');
    }
    if (isPlaceholder) {
      buffer.write(' · Disponibile ora');
    }
    if (appointment.notes != null && appointment.notes!.isNotEmpty) {
      buffer.write('\n${appointment.notes}');
    }
    return buffer.toString();
  }
}

class _AttentionAppointmentsCard extends StatelessWidget {
  const _AttentionAppointmentsCard({
    required this.appointments,
    required this.data,
    required this.anomalies,
    required this.lockedReasons,
    required this.onEdit,
  });

  final List<Appointment> appointments;
  final AppDataState data;
  final Map<String, Set<AppointmentAnomalyType>> anomalies;
  final Map<String, String> lockedReasons;
  final ValueChanged<Appointment> onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted =
        appointments.toList()..sort((a, b) => a.start.compareTo(b.start));
    final attentionTiles =
        ListTile.divideTiles(
          context: context,
          tiles: sorted.map((appointment) {
            final issues =
                anomalies[appointment.id] ?? const <AppointmentAnomalyType>{};
            final issueList =
                issues.toList()..sort((a, b) => a.index.compareTo(b.index));
            final issueDescriptions =
                issueList.map((issue) => issue.description).toList();
            if (appointment.status == AppointmentStatus.cancelled) {
              issueDescriptions.insert(0, 'Appuntamento annullato');
            }
            final isCancelled =
                appointment.status == AppointmentStatus.cancelled;
            final leadingIcon =
                isCancelled
                    ? Icons.cancel_rounded
                    : AppointmentAnomalyType.noShift.icon;
            final leadingColor =
                isCancelled
                    ? theme.colorScheme.outlineVariant
                    : theme.colorScheme.error;
            final dateLabel = DateFormat(
              'dd MMM yyyy',
              'it_IT',
            ).format(appointment.start);
            final timeLabel =
                '${_AppointmentsModuleState._timeLabel.format(appointment.start)} - ${_AppointmentsModuleState._timeLabel.format(appointment.end)}';
            final subtitleLines =
                <String>[
                  _ListAppointmentsView._buildSubtitle(appointment, data),
                  ...issueDescriptions,
                  if (lockedReasons.containsKey(appointment.id))
                    lockedReasons[appointment.id]!,
                ].where((line) => line.trim().isNotEmpty).toList();
            final subtitleText = subtitleLines.join('\n');
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              leading: Icon(leadingIcon, color: leadingColor),
              title: Text(_ListAppointmentsView._buildTitle(appointment, data)),
              subtitle: Text(subtitleText),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(dateLabel),
                  const SizedBox(height: 4),
                  Text(timeLabel),
                ],
              ),
              onTap: () => onEdit(appointment),
            );
          }),
        ).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  AppointmentAnomalyType.noShift.icon,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Appuntamenti da gestire (${sorted.length})',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          if (attentionTiles.isNotEmpty) const Divider(height: 1),
          ...attentionTiles,
        ],
      ),
    );
  }
}

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  required List<Salon> salons,
  required List<Client> clients,
  required List<StaffMember> staff,
  required List<Service> services,
  String? defaultSalonId,
  Appointment? existing,
  DateTime? initialStart,
  DateTime? initialEnd,
  String? initialStaffId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (salons.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Crea un salone prima di pianificare appuntamenti.'),
      ),
    );
    return;
  }
  final result = await showAppModalSheet<AppointmentFormResult>(
    context: context,
    builder:
        (ctx) => AppointmentFormSheet(
          salons: salons,
          clients: clients,
          staff: staff,
          services: services,
          defaultSalonId: defaultSalonId,
          initial: existing,
          suggestedStart: initialStart,
          suggestedEnd: initialEnd,
          suggestedStaffId: initialStaffId,
          enableDelete: existing != null,
        ),
  );
  if (result == null) {
    return;
  }
  if (result.action == AppointmentFormAction.copy) {
    ref
        .read(appointmentClipboardProvider.notifier)
        .state = AppointmentClipboard(
      appointment: result.appointment,
      copiedAt: DateTime.now(),
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Appuntamento copiato. Seleziona uno slot libero.'),
      ),
    );
    return;
  }
  if (result.action == AppointmentFormAction.delete) {
    return;
  }
  await _validateAndSaveAppointment(
    context,
    ref,
    result.appointment,
    services,
    salons,
  );
}

Future<bool> _validateAndSaveAppointment(
  BuildContext context,
  WidgetRef ref,
  Appointment appointment,
  List<Service> fallbackServices,
  List<Salon> fallbackSalons,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final data = ref.read(appDataProvider);
  final existingAppointments = data.appointments;
  final allServices =
      data.services.isNotEmpty ? data.services : fallbackServices;
  final allSalons = data.salons.isNotEmpty ? data.salons : fallbackSalons;
  final nowReference = DateTime.now();
  final expressPlaceholders =
      data.lastMinuteSlots
          .where((slot) {
            if (slot.salonId != appointment.salonId) {
              return false;
            }
            if (slot.operatorId != appointment.staffId) {
              return false;
            }
            if (!slot.isAvailable) {
              return false;
            }
            if (!slot.end.isAfter(nowReference)) {
              return false;
            }
            return true;
          })
          .map(
            (slot) => Appointment(
              id: 'last-minute-${slot.id}',
              salonId: slot.salonId,
              clientId: 'last-minute-${slot.id}',
              staffId: slot.operatorId ?? appointment.staffId,
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
  final combinedAppointments = <Appointment>[
    ...existingAppointments,
    ...expressPlaceholders,
  ];
  final hasStaffConflict = hasStaffBookingConflict(
    appointments: combinedAppointments,
    staffId: appointment.staffId,
    start: appointment.start,
    end: appointment.end,
    excludeAppointmentId: appointment.id,
  );
  if (hasStaffConflict) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Impossibile salvare: operatore già occupato in quel periodo',
        ),
      ),
    );
    return false;
  }
  final hasClientConflict = hasClientBookingConflict(
    appointments: existingAppointments,
    clientId: appointment.clientId,
    start: appointment.start,
    end: appointment.end,
    excludeAppointmentId: appointment.id,
  );
  if (hasClientConflict) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Impossibile salvare: il cliente ha già un appuntamento in quel periodo',
        ),
      ),
    );
    return false;
  }
  final appointmentServices = appointment.serviceIds
      .map((id) => allServices.firstWhereOrNull((service) => service.id == id))
      .whereType<Service>()
      .toList(growable: false);
  if (appointmentServices.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Servizio non valido.')),
    );
    return false;
  }
  final salon = allSalons.firstWhereOrNull(
    (item) => item.id == appointment.salonId,
  );
  final blockingEquipment = <String>{};
  for (final service in appointmentServices) {
    final equipmentCheck = EquipmentAvailabilityChecker.check(
      salon: salon,
      service: service,
      allServices: allServices,
      appointments: combinedAppointments,
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
    messenger.showSnackBar(
      SnackBar(content: Text('$message Scegli un altro slot.')),
    );
    return false;
  }
  try {
    await ref.read(appDataProvider.notifier).upsertAppointment(appointment);
    return true;
  } on StateError catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return false;
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('Errore durante il salvataggio: $error')),
    );
    return false;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color background;
    Color foreground;
    String label;
    switch (status) {
      case AppointmentStatus.scheduled:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        label = 'Programmato';
        break;
      case AppointmentStatus.completed:
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        label = 'Completato';
        break;
      case AppointmentStatus.cancelled:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        label = 'Annullato';
        break;
      case AppointmentStatus.noShow:
        background = scheme.error.withValues(alpha: 0.15);
        foreground = scheme.error;
        label = 'No-show';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
