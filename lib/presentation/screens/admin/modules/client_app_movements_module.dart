import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_app_movement.dart';
import 'package:you_book/domain/entities/last_minute_slot.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/screens/admin/modules/client_detail_page.dart';

class ClientAppMovementsModule extends ConsumerStatefulWidget {
  const ClientAppMovementsModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<ClientAppMovementsModule> createState() =>
      _ClientAppMovementsModuleState();
}

class _ClientAppMovementsModuleState
    extends ConsumerState<ClientAppMovementsModule> {
  static final DateFormat _dateHeaderFormat = DateFormat(
    'EEEE d MMMM',
    'it_IT',
  );
  static final DateFormat _timeFormat = DateFormat('HH:mm', 'it_IT');
  static final DateFormat _dateTimeChipFormat = DateFormat(
    'dd/MM HH:mm',
    'it_IT',
  );
  static final NumberFormat _currencyFormat = NumberFormat.simpleCurrency(
    locale: 'it_IT',
  );

  late DateTimeRange _range;
  late Set<ClientAppMovementType> _selectedTypes;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final rangeEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final rangeStart = rangeEnd.subtract(const Duration(days: 29));
    _range = DateTimeRange(start: rangeStart, end: rangeEnd);
    _selectedTypes = Set<ClientAppMovementType>.from(
      ClientAppMovementType.values,
    );
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void didUpdateWidget(covariant ClientAppMovementsModule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.salonId != oldWidget.salonId) {
      // No additional state to reset yet, but retain hook for future use.
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final entries = _buildEntries(data);
    final rangeFiltered = entries.where(_isWithinSelectedRange).toList();

    final countsByType = <ClientAppMovementType, int>{
      for (final type in ClientAppMovementType.values) type: 0,
    };
    for (final entry in rangeFiltered) {
      countsByType.update(entry.type, (value) => value + 1);
    }

    final typeFiltered =
        rangeFiltered
            .where((entry) => _selectedTypes.contains(entry.type))
            .toList();
    final query = _searchController.text.trim().toLowerCase();
    final filtered =
        typeFiltered.where((entry) {
            if (query.isEmpty) {
              return true;
            }
            final haystack =
                <String>[
                  entry.title,
                  entry.subtitle ?? '',
                  entry.clientName ?? '',
                  ...entry.details.map((detail) => detail.label),
                ].join(' ').toLowerCase();
            return haystack.contains(query);
          }).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final grouped = groupBy<_MovementEntry, DateTime>(
      filtered,
      (entry) => DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      ),
    );
    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FiltersBar(
          range: _range,
          counts: countsByType,
          selectedTypes: _selectedTypes,
          onRangeChanged: _handleRangeChanged,
          onToggleType: _handleToggleType,
          searchController: _searchController,
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              filtered.isEmpty
                  ? _EmptyMovementsState(searchQuery: query, range: _range)
                  : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: sortedDays.length,
                    itemBuilder: (context, index) {
                      final day = sortedDays[index];
                      final entriesForDay = grouped[day]!;
                      return _DaySection(
                        day: day,
                        entries: entriesForDay,
                        onClientTap: _openClientFromMovement,
                        onAgendaTap: _openAgendaAt,
                      );
                    },
                  ),
        ),
      ],
    );
  }

  void _handleRangeChanged(DateTimeRange range) {
    setState(() {
      _range = DateTimeRange(
        start: DateTime(range.start.year, range.start.month, range.start.day),
        end: DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        ),
      );
    });
  }

  void _handleToggleType(ClientAppMovementType type, bool selected) {
    setState(() {
      if (selected) {
        _selectedTypes.add(type);
      } else {
        _selectedTypes.remove(type);
      }
      if (_selectedTypes.isEmpty) {
        _selectedTypes = Set<ClientAppMovementType>.from(
          ClientAppMovementType.values,
        );
      }
    });
  }

  bool _isWithinSelectedRange(_MovementEntry entry) {
    final timestamp = entry.timestamp;
    return !timestamp.isBefore(_range.start) && !timestamp.isAfter(_range.end);
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

  String? _resolvePaymentLabel({
    PaymentMethod? method,
    required Map<String, dynamic>? metadata,
  }) {
    bool hasStripe(dynamic value) {
      if (value == null) {
        return false;
      }
      if (value is String) {
        return value.toLowerCase().contains('stripe');
      }
      if (value is Iterable) {
        for (final entry in value) {
          if (hasStripe(entry)) {
            return true;
          }
        }
        return false;
      }
      if (value is Map) {
        for (final entry in value.entries) {
          if (hasStripe(entry.value)) {
            return true;
          }
        }
      }
      return false;
    }

    if (hasStripe(metadata)) {
      return 'Stripe';
    }

    return method != null ? _paymentMethodLabel(method) : null;
  }

  List<_MovementEntry> _buildEntries(AppDataState data) {
    final salonFilter = widget.salonId?.trim();
    final applicableSalonId =
        salonFilter != null && salonFilter.isNotEmpty ? salonFilter : null;

    final clientsById = {for (final client in data.clients) client.id: client};
    final staffById = {for (final staff in data.staff) staff.id: staff};
    final servicesById = {
      for (final service in data.services) service.id: service,
    };
    final appointmentsById = {
      for (final appointment in data.appointments) appointment.id: appointment,
    };
    final salesById = {for (final sale in data.sales) sale.id: sale};
    final lastMinuteById = {
      for (final slot in data.lastMinuteSlots) slot.id: slot,
    };

    final recordedMovements =
        data.clientAppMovements.where((movement) {
            final matchesSalon =
                applicableSalonId == null ||
                movement.salonId == applicableSalonId;
            return matchesSalon && _isClientAppMovement(movement);
          }).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final entries = <_MovementEntry>[];

    for (final movement in recordedMovements) {
      final entry = _entryFromRecordedMovement(
        movement,
        clientsById,
        staffById,
        servicesById,
        appointmentsById,
        salesById,
        lastMinuteById,
      );
      if (entry != null) {
        entries.add(entry);
      }
    }

    return entries;
  }

  Future<void> _openClientFromMovement(String clientId) async {
    final isCompact = isCompactClientLayout(context);
    final data = ref.read(appDataProvider);
    final client = data.clients.firstWhereOrNull((item) => item.id == clientId);
    final payload = <String, Object?>{'clientId': clientId};
    final clientNumber = client?.clientNumber?.trim();
    if (clientNumber != null && clientNumber.isNotEmpty) {
      payload['clientNumber'] = clientNumber;
    }
    if (!isCompact) {
      ref
          .read(adminDashboardIntentProvider.notifier)
          .state = AdminDashboardIntent(moduleId: 'clients', payload: payload);
    }
    await openClientDetailPage(
      context,
      clientId: clientId,
      initialTabIndex: 0,
      compactOnly: true,
    );
  }

  void _openAgendaAt(DateTime dateTime) {
    ref
        .read(adminDashboardIntentProvider.notifier)
        .state = AdminDashboardIntent(
      moduleId: 'appointments',
      payload: <String, Object?>{'focusDateTime': dateTime.toIso8601String()},
    );
  }

  _MovementEntry? _entryFromRecordedMovement(
    ClientAppMovement movement,
    Map<String, Client> clientsById,
    Map<String, StaffMember> staffById,
    Map<String, Service> servicesById,
    Map<String, Appointment> appointmentsById,
    Map<String, Sale> salesById,
    Map<String, LastMinuteSlot> lastMinuteById,
  ) {
    final client = clientsById[movement.clientId];
    final clientName = client?.fullName.trim();
    final baseTitle =
        movement.label?.trim().isNotEmpty == true
            ? movement.label!.trim()
            : null;
    switch (movement.type) {
      case ClientAppMovementType.registration:
        return _MovementEntry(
          id: movement.id,
          type: movement.type,
          timestamp: movement.timestamp,
          title: _movementTitle(
            movement.type,
            clientName: clientName,
            baseTitle: baseTitle,
          ),
          subtitle:
              movement.description ??
              '${client?.fullName ?? 'Cliente'} ha completato la registrazione.',
          clientId: movement.clientId,
          clientName: client?.fullName,
          details: [
            if (movement.channel != null && movement.channel!.isNotEmpty)
              _MovementDetail(
                icon: Icons.devices_rounded,
                label: 'Canale: ${movement.channel}',
              ),
          ],
        );
      case ClientAppMovementType.appointmentCreated:
      case ClientAppMovementType.appointmentUpdated:
      case ClientAppMovementType.appointmentCancelled:
        final appointment = appointmentsById[movement.appointmentId ?? ''];
        final summary =
            appointment == null
                ? (movement.description ??
                    'Appuntamento ${movement.type == ClientAppMovementType.appointmentCancelled ? 'annullato' : 'aggiornato'}.')
                : _formatAppointmentSummary(
                  appointment,
                  clientsById,
                  servicesById,
                  staffById,
                );
        final details = <_MovementDetail>[];
        final newServiceNames = _resolveServiceNames(
          appointment: appointment,
          servicesById: servicesById,
          metadata: movement.metadata,
          useUpdatedServices: true,
        );
        final previousServiceNames = _resolveServiceNames(
          appointment: appointment,
          servicesById: servicesById,
          metadata: movement.metadata,
          useUpdatedServices: false,
        );
        final bool servicesChanged =
            movement.type == ClientAppMovementType.appointmentUpdated &&
            newServiceNames.isNotEmpty &&
            previousServiceNames.isNotEmpty &&
            !const SetEquality<String>().equals(
              newServiceNames.toSet(),
              previousServiceNames.toSet(),
            );
        final serviceLabel = _buildServiceDetailLabel(
          currentServices: newServiceNames,
          previousServices: previousServiceNames,
          showChange: servicesChanged,
        );
        if (serviceLabel != null) {
          details.add(
            _MovementDetail(
              icon: Icons.design_services_rounded,
              label: serviceLabel,
            ),
          );
        }
        final previousStatus = _statusLabel(
          movement.metadata['previousStatus'] ?? movement.metadata['oldStatus'],
        );
        final nextStatus = _statusLabel(
          movement.metadata['newStatus'] ?? movement.metadata['status'],
        );
        if (previousStatus != null &&
            nextStatus != null &&
            previousStatus != nextStatus) {
          details.add(
            _MovementDetail(
              icon: Icons.flag_rounded,
              label: '$previousStatus → $nextStatus',
            ),
          );
        }

        final previousStart = _parseDateTime(
          movement.metadata['previousStart'] ??
              movement.metadata['oldStart'] ??
              movement.metadata['fromStart'],
        );
        final nextStart =
            _parseDateTime(
              movement.metadata['newStart'] ?? movement.metadata['start'],
            ) ??
            appointment?.start;
        if (nextStart != null) {
          details.insert(
            0,
            _MovementDetail(
              icon: Icons.event_rounded,
              label: 'Data: ${_dateTimeChipFormat.format(nextStart)}',
              agendaTarget: nextStart,
            ),
          );
        }
        if (appointment?.bookingChannel != null &&
            appointment!.bookingChannel!.isNotEmpty) {
          details.add(
            _MovementDetail(
              icon: Icons.link_rounded,
              label: 'Canale: ${appointment.bookingChannel}',
            ),
          );
        }
        if (appointment != null) {
          final staff = staffById[appointment.staffId];
          final staffName = staff?.displayName.trim();
          if (staffName != null && staffName.isNotEmpty) {
            details.add(
              _MovementDetail(
                icon: Icons.badge_rounded,
                label: 'Staff: $staffName',
              ),
            );
          }
        }
        if (previousStart != null &&
            nextStart != null &&
            !previousStart.isAtSameMomentAs(nextStart)) {
          details.add(
            _MovementDetail(
              icon: Icons.access_time_rounded,
              label:
                  '${_dateTimeChipFormat.format(previousStart)} → ${_dateTimeChipFormat.format(nextStart)}',
            ),
          );
        }

        final previousEnd = _parseDateTime(
          movement.metadata['previousEnd'] ??
              movement.metadata['oldEnd'] ??
              movement.metadata['fromEnd'],
        );
        final nextEnd =
            _parseDateTime(
              movement.metadata['newEnd'] ?? movement.metadata['end'],
            ) ??
            appointment?.end;
        if (movement.type != ClientAppMovementType.appointmentUpdated &&
            previousEnd != null &&
            nextEnd != null &&
            !previousEnd.isAtSameMomentAs(nextEnd)) {
          details.add(
            _MovementDetail(
              icon: Icons.timelapse_rounded,
              label:
                  '${_dateTimeChipFormat.format(previousEnd)} → ${_dateTimeChipFormat.format(nextEnd)}',
            ),
          );
        }

        final cancelReason =
            movement.metadata['reason'] ?? movement.metadata['cancelReason'];
        if (movement.type == ClientAppMovementType.appointmentCancelled &&
            cancelReason is String &&
            cancelReason.trim().isNotEmpty) {
          final trimmedReason = cancelReason.trim();
          details.add(
            _MovementDetail(
              icon: Icons.feedback_rounded,
              label: 'Motivazione: $trimmedReason',
            ),
          );
        }
        return _MovementEntry(
          id: movement.id,
          type: movement.type,
          timestamp: movement.timestamp,
          title: _movementTitle(
            movement.type,
            clientName: clientName,
            baseTitle: baseTitle,
          ),
          subtitle:
              movement.type == ClientAppMovementType.appointmentCreated &&
                      appointment != null
                  ? null
                  : summary,
          clientId: movement.clientId,
          clientName: client?.fullName,
          details: details,
        );
      case ClientAppMovementType.purchase:
        final sale = salesById[movement.saleId ?? ''];
        final total =
            sale?.total ?? (movement.metadata['amount'] as num?)?.toDouble();
        final details = <_MovementDetail>[];
        if (total != null) {
          details.add(
            _MovementDetail(
              icon: Icons.euro_rounded,
              label: 'Totale ${_currencyFormat.format(total)}',
            ),
          );
        }
        final purchasedItems = _resolvePurchaseItemLabels(
          sale,
          movement.metadata,
        );
        final purchaseItemsLabel = _buildPurchaseItemsLabel(purchasedItems);
        if (purchaseItemsLabel != null) {
          details.add(
            _MovementDetail(
              icon: Icons.shopping_bag_rounded,
              label: purchaseItemsLabel,
            ),
          );
        }
        var paymentLabel = _resolvePaymentLabel(
          method: sale?.paymentMethod,
          metadata: movement.metadata,
        );
        if (paymentLabel == null && sale != null) {
          paymentLabel = _resolvePaymentLabel(
            method: sale.paymentMethod,
            metadata: sale.metadata,
          );
        }
        if (paymentLabel != null && paymentLabel.isNotEmpty) {
          details.add(
            _MovementDetail(
              icon: Icons.credit_card_rounded,
              label: 'Metodo: $paymentLabel',
            ),
          );
        }
        return _MovementEntry(
          id: movement.id,
          type: movement.type,
          timestamp: movement.timestamp,
          title: _movementTitle(
            movement.type,
            clientName: clientName,
            baseTitle: baseTitle,
          ),
          subtitle:
              movement.description ??
              '${client?.fullName ?? 'Cliente'} ha finalizzato un pagamento.',
          clientId: movement.clientId,
          clientName: client?.fullName,
          details: details,
        );
      case ClientAppMovementType.reviewClick:
        return _MovementEntry(
          id: movement.id,
          type: movement.type,
          timestamp: movement.timestamp,
          title: _movementTitle(
            movement.type,
            clientName: clientName,
            baseTitle: baseTitle,
          ),
          subtitle:
              movement.description ??
              '${client?.fullName ?? 'Cliente'} ha aperto la pagina recensioni.',
          clientId: movement.clientId,
          clientName: client?.fullName,
          details: const [],
        );
      case ClientAppMovementType.lastMinutePurchase:
        final slot = lastMinuteById[movement.lastMinuteSlotId ?? ''];
        final sale = salesById[movement.saleId ?? ''];
        final details = <_MovementDetail>[];
        final price = movement.metadata['price'] as num? ?? slot?.priceNow;
        if (price != null) {
          details.add(
            _MovementDetail(
              icon: Icons.flash_on_rounded,
              label: '€ ${_currencyFormat.format(price)}',
            ),
          );
        }
        if (slot?.serviceName != null) {
          details.add(
            _MovementDetail(icon: Icons.spa_rounded, label: slot!.serviceName),
          );
        }
        var paymentLabel = _resolvePaymentLabel(
          method: sale?.paymentMethod,
          metadata: movement.metadata,
        );
        if (paymentLabel == null && sale != null) {
          paymentLabel = _resolvePaymentLabel(
            method: sale.paymentMethod,
            metadata: sale.metadata,
          );
        }
        if (paymentLabel != null && paymentLabel.isNotEmpty) {
          details.add(
            _MovementDetail(
              icon: Icons.credit_card_rounded,
              label: 'Metodo: $paymentLabel',
            ),
          );
        }
        return _MovementEntry(
          id: movement.id,
          type: movement.type,
          timestamp: movement.timestamp,
          title: _movementTitle(
            movement.type,
            clientName: clientName,
            baseTitle: baseTitle,
          ),
          subtitle:
              movement.description ??
              '${client?.fullName ?? 'Cliente'} ha prenotato un\'offerta last minute.',
          clientId: movement.clientId,
          clientName: client?.fullName,
          details: details,
        );
    }
  }

  String _movementSignature(
    ClientAppMovementType type, {
    required String clientId,
    String? appointmentId,
    String? saleId,
    String? lastMinuteSlotId,
  }) {
    return '${type.name}::$clientId::${appointmentId ?? ''}::${saleId ?? ''}::${lastMinuteSlotId ?? ''}';
  }

  List<String> _resolveServiceNames({
    Appointment? appointment,
    required Map<String, Service> servicesById,
    required Map<String, dynamic> metadata,
    required bool useUpdatedServices,
  }) {
    final dynamic rawIds =
        useUpdatedServices
            ? (metadata['newServices'] ?? metadata['serviceIds'])
            : (metadata['previousServices'] ?? metadata['oldServices']);
    final ids = _extractServiceIdList(rawIds);
    if (ids.isEmpty) {
      if (useUpdatedServices && appointment != null) {
        return _mapServiceIdsToNames(appointment.serviceIds, servicesById);
      }
      return const <String>[];
    }
    return _mapServiceIdsToNames(ids, servicesById);
  }

  List<String> _extractServiceIdList(dynamic raw) {
    if (raw is Iterable) {
      return raw
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) {
        return <String>[trimmed];
      }
    }
    return const <String>[];
  }

  List<String> _mapServiceIdsToNames(
    Iterable<String> ids,
    Map<String, Service> servicesById,
  ) {
    final seen = <String>{};
    final names = <String>[];
    for (final id in ids) {
      final serviceName = servicesById[id]?.name;
      if (serviceName == null) {
        continue;
      }
      final trimmed = serviceName.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      names.add(trimmed);
    }
    return names;
  }

  String? _buildServiceDetailLabel({
    required List<String> currentServices,
    required List<String> previousServices,
    required bool showChange,
  }) {
    if (showChange &&
        currentServices.isNotEmpty &&
        previousServices.isNotEmpty) {
      return 'Servizi: ${previousServices.join(', ')} → ${currentServices.join(', ')}';
    }
    final resolved =
        currentServices.isNotEmpty ? currentServices : previousServices;
    if (resolved.isEmpty) {
      return null;
    }
    final prefix = resolved.length == 1 ? 'Servizio' : 'Servizi';
    return '$prefix: ${resolved.join(', ')}';
  }

  List<String> _resolvePurchaseItemLabels(
    Sale? sale,
    Map<String, dynamic> metadata,
  ) {
    final labels = <String>[];
    if (sale != null) {
      for (final item in sale.items) {
        final description = item.description.trim();
        if (description.isEmpty) {
          continue;
        }
        final label =
            item.quantity == 1
                ? description
                : '$description x${_formatQuantityLabel(item.quantity)}';
        labels.add(label);
      }
    }

    if (labels.isEmpty) {
      final rawItems = metadata['items'];
      if (rawItems is Iterable) {
        for (final raw in rawItems) {
          if (raw is! Map) {
            continue;
          }
          final dynamic nameValue = raw['name'] ?? raw['description'];
          if (nameValue is! String) {
            continue;
          }
          final trimmedName = nameValue.trim();
          if (trimmedName.isEmpty) {
            continue;
          }
          final dynamic quantityValue = raw['quantity'];
          if (quantityValue is num && quantityValue != 1) {
            labels.add('$trimmedName x${_formatQuantityLabel(quantityValue)}');
          } else {
            labels.add(trimmedName);
          }
        }
      }
    }

    if (labels.isEmpty) {
      final quoteTitle = metadata['quoteTitle'];
      if (quoteTitle is String) {
        final trimmedTitle = quoteTitle.trim();
        if (trimmedTitle.isNotEmpty) {
          labels.add(trimmedTitle);
        }
      } else {
        final quoteNumber = metadata['quoteNumber'];
        if (quoteNumber is String) {
          final trimmedNumber = quoteNumber.trim();
          if (trimmedNumber.isNotEmpty) {
            labels.add('Preventivo #$trimmedNumber');
          }
        }
      }
    }

    final seen = <String>{};
    return labels.where((label) => seen.add(label)).toList();
  }

  String? _buildPurchaseItemsLabel(List<String> items) {
    if (items.isEmpty) {
      return null;
    }
    final prefix = items.length == 1 ? 'Articolo' : 'Articoli';
    return '$prefix: ${items.join(', ')}';
  }

  String _formatQuantityLabel(num quantity) {
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    }
    final formatted = quantity.toStringAsFixed(2);
    return formatted
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatAppointmentSummary(
    Appointment appointment,
    Map<String, Client> clientsById,
    Map<String, Service> servicesById,
    Map<String, StaffMember> staffById,
  ) {
    final serviceNames =
        appointment.serviceAllocations
            .map((allocation) => servicesById[allocation.serviceId]?.name)
            .whereNotNull()
            .toList();
    final staff = staffById[appointment.staffId];
    final client = clientsById[appointment.clientId];
    final buffer = StringBuffer();
    buffer.write(_timeFormat.format(appointment.start));
    buffer.write(' • ');
    if (serviceNames.isNotEmpty) {
      buffer.write(serviceNames.join(', '));
    } else {
      buffer.write('Appuntamento');
    }
    if (staff != null) {
      buffer.write(' con ${staff.displayName}');
    }
    if (client != null) {
      buffer.write(' per ${client.fullName}');
    }
    return buffer.toString();
  }

  String _defaultAppointmentTitle(ClientAppMovementType type) {
    switch (type) {
      case ClientAppMovementType.appointmentCreated:
        return 'Appuntamento creato';
      case ClientAppMovementType.appointmentUpdated:
        return 'Appuntamento aggiornato';
      case ClientAppMovementType.appointmentCancelled:
        return 'Appuntamento annullato';
      default:
        return 'Appuntamento';
    }
  }

  String _movementTitle(
    ClientAppMovementType type, {
    required String? clientName,
    String? baseTitle,
  }) {
    if (clientName == null || clientName.isEmpty) {
      return baseTitle ?? _defaultMovementTitle(type);
    }
    return switch (type) {
      ClientAppMovementType.registration =>
        '$clientName ha completato la registrazione',
      ClientAppMovementType.appointmentCreated =>
        '$clientName ha creato un appuntamento',
      ClientAppMovementType.appointmentUpdated =>
        '$clientName ha aggiornato un appuntamento',
      ClientAppMovementType.appointmentCancelled =>
        '$clientName ha annullato un appuntamento',
      ClientAppMovementType.purchase => '$clientName ha effettuato un acquisto',
      ClientAppMovementType.reviewClick =>
        '$clientName ha aperto le recensioni',
      ClientAppMovementType.lastMinutePurchase =>
        '$clientName ha acquistato un last minute',
    };
  }

  String _defaultMovementTitle(ClientAppMovementType type) {
    switch (type) {
      case ClientAppMovementType.registration:
        return 'Nuova registrazione';
      case ClientAppMovementType.appointmentCreated:
      case ClientAppMovementType.appointmentUpdated:
      case ClientAppMovementType.appointmentCancelled:
        return _defaultAppointmentTitle(type);
      case ClientAppMovementType.purchase:
        return 'Acquisto completato';
      case ClientAppMovementType.reviewClick:
        return 'Recensioni aperte';
      case ClientAppMovementType.lastMinutePurchase:
        return 'Last minute acquistato';
    }
  }

  String _paymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Contanti';
      case PaymentMethod.pos:
        return 'POS';
      case PaymentMethod.transfer:
        return 'Bonifico';
      case PaymentMethod.giftCard:
        return 'Gift card';
      case PaymentMethod.posticipated:
        return 'Posticipato';
    }
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.entries,
    this.onClientTap,
    this.onAgendaTap,
  });

  final DateTime day;
  final List<_MovementEntry> entries;
  final Future<void> Function(String clientId)? onClientTap;
  final void Function(DateTime dateTime)? onAgendaTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _ClientAppMovementsModuleState._dateHeaderFormat.format(
      day,
    );
    final sorted =
        entries.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              dateLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...sorted.map(
            (entry) => _MovementCard(
              entry: entry,
              onClientTap: onClientTap,
              onAgendaTap: onAgendaTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({
    required this.entry,
    this.onClientTap,
    this.onAgendaTap,
  });

  final _MovementEntry entry;
  final Future<void> Function(String clientId)? onClientTap;
  final void Function(DateTime dateTime)? onAgendaTap;

  Widget _buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final clientId = entry.clientId;
    final clientName = entry.clientName?.trim();
    if (clientId == null ||
        clientName == null ||
        clientName.isEmpty ||
        onClientTap == null ||
        !entry.title.startsWith(clientName)) {
      return Text(entry.title, style: titleStyle);
    }
    final suffix = entry.title.substring(clientName.length);
    final linkColor = theme.colorScheme.primary;
    return Text.rich(
      TextSpan(
        style: titleStyle,
        children: [
          TextSpan(
            text: clientName,
            style: titleStyle?.copyWith(
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
            ),
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () {
                    final future = onClientTap?.call(clientId);
                    if (future != null) {
                      unawaited(future);
                    }
                  },
          ),
          TextSpan(text: suffix),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconForType(entry.type);
    final color = _colorForType(entry.type, theme);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withOpacity(0.12),
                  foregroundColor: color,
                  child: Icon(icon, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitle(context),
                      if (entry.subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          entry.subtitle!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (entry.details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    entry.details
                        .map(
                          (detail) =>
                              detail.agendaTarget != null && onAgendaTap != null
                                  ? ActionChip(
                                    avatar: Icon(detail.icon, size: 16),
                                    label: Text(detail.label),
                                    labelStyle: theme.textTheme.labelLarge
                                        ?.copyWith(
                                          decoration: TextDecoration.underline,
                                        ),
                                    onPressed: () {
                                      onAgendaTap?.call(detail.agendaTarget!);
                                    },
                                  )
                                  : Chip(
                                    avatar: Icon(detail.icon, size: 16),
                                    label: Text(detail.label),
                                  ),
                        )
                        .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _iconForType(ClientAppMovementType type) {
    switch (type) {
      case ClientAppMovementType.registration:
        return Icons.person_add_alt_rounded;
      case ClientAppMovementType.appointmentCreated:
        return Icons.event_available_rounded;
      case ClientAppMovementType.appointmentUpdated:
        return Icons.event_repeat_rounded;
      case ClientAppMovementType.appointmentCancelled:
        return Icons.event_busy_rounded;
      case ClientAppMovementType.purchase:
        return Icons.receipt_long_rounded;
      case ClientAppMovementType.reviewClick:
        return Icons.reviews_rounded;
      case ClientAppMovementType.lastMinutePurchase:
        return Icons.flash_on_rounded;
    }
  }

  static Color _colorForType(ClientAppMovementType type, ThemeData theme) {
    final scheme = theme.colorScheme;
    switch (type) {
      case ClientAppMovementType.registration:
        return scheme.primary;
      case ClientAppMovementType.appointmentCreated:
        return scheme.tertiary;
      case ClientAppMovementType.appointmentUpdated:
        return scheme.secondary;
      case ClientAppMovementType.appointmentCancelled:
        return scheme.error;
      case ClientAppMovementType.purchase:
        return scheme.primaryContainer;
      case ClientAppMovementType.reviewClick:
        return scheme.secondaryContainer;
      case ClientAppMovementType.lastMinutePurchase:
        return scheme.surfaceTint;
    }
  }
}

class _MovementEntry {
  const _MovementEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.title,
    this.subtitle,
    this.clientId,
    this.clientName,
    this.details = const <_MovementDetail>[],
  });

  final String id;
  final ClientAppMovementType type;
  final DateTime timestamp;
  final String title;
  final String? subtitle;
  final String? clientId;
  final String? clientName;
  final List<_MovementDetail> details;
}

class _MovementDetail {
  const _MovementDetail({
    required this.icon,
    required this.label,
    this.agendaTarget,
  });

  final IconData icon;
  final String label;
  final DateTime? agendaTarget;
}

class _FiltersBar extends StatefulWidget {
  const _FiltersBar({
    required this.range,
    required this.counts,
    required this.selectedTypes,
    required this.onRangeChanged,
    required this.onToggleType,
    required this.searchController,
  });

  final DateTimeRange range;
  final Map<ClientAppMovementType, int> counts;
  final Set<ClientAppMovementType> selectedTypes;
  final void Function(DateTimeRange) onRangeChanged;
  final void Function(ClientAppMovementType, bool) onToggleType;
  final TextEditingController searchController;

  @override
  State<_FiltersBar> createState() => _FiltersBarState();
}

class _FiltersBarState extends State<_FiltersBar> {
  final ScrollController _typesScrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _typesScrollController.addListener(_updateArrowState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrowState());
  }

  @override
  void didUpdateWidget(covariant _FiltersBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrowState());
  }

  @override
  void dispose() {
    _typesScrollController.removeListener(_updateArrowState);
    _typesScrollController.dispose();
    super.dispose();
  }

  void _updateArrowState() {
    if (!_typesScrollController.hasClients || !mounted) return;
    final position = _typesScrollController.position;
    final canLeft = position.pixels > 0.5;
    final canRight = position.pixels < (position.maxScrollExtent - 0.5);
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  Future<void> _scrollTypesBy(double delta) async {
    if (!_typesScrollController.hasClients) return;
    final position = _typesScrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await _typesScrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: widget.range.start,
      end: widget.range.end,
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
      locale: const Locale('it'),
      saveText: 'Applica',
    );
    if (picked != null) {
      widget.onRangeChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rangeLabel =
        '${DateFormat('dd/MM/yy').format(widget.range.start)} → ${DateFormat('dd/MM/yy').format(widget.range.end)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
                onPressed: () => _pickRange(context),
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(rangeLabel),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon:
                        widget.searchController.text.isEmpty
                            ? null
                            : IconButton(
                              onPressed: widget.searchController.clear,
                              icon: const Icon(Icons.clear_rounded),
                            ),
                    hintText: 'Cerca per cliente o descrizione',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Scorri filtri a sinistra',
                onPressed: _canScrollLeft ? () => _scrollTypesBy(-220) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _typesScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        ClientAppMovementType.values.map((type) {
                          final isSelected = widget.selectedTypes.contains(
                            type,
                          );
                          final count = widget.counts[type] ?? 0;
                          final label =
                              count > 0 ? '${type.label} ($count)' : type.label;
                          final scheme = Theme.of(context).colorScheme;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: isSelected,
                              backgroundColor: scheme.surfaceContainerHighest,
                              selectedColor: scheme.secondary,
                              checkmarkColor: scheme.onSecondary,
                              labelStyle: TextStyle(
                                color:
                                    isSelected
                                        ? scheme.onSecondary
                                        : scheme.onSurface,
                              ),
                              label: Text(label),
                              onSelected:
                                  (value) => widget.onToggleType(type, value),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Scorri filtri a destra',
                onPressed: _canScrollRight ? () => _scrollTypesBy(220) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Divider(
            height: 24,
            thickness: 1,
            color: theme.colorScheme.surfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _EmptyMovementsState extends StatelessWidget {
  const _EmptyMovementsState({required this.searchQuery, required this.range});

  final String searchQuery;
  final DateTimeRange range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle =
        searchQuery.isEmpty
            ? 'Non ci sono movimenti registrati nel periodo selezionato.'
            : 'Nessun risultato per "$searchQuery" nel periodo selezionato.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timeline_rounded,
              size: 48,
              color: theme.colorScheme.surfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Nessun movimento disponibile',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    // Assume milliseconds since epoch.
    if (value == 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(trimmed).toLocal();
    } catch (_) {
      return null;
    }
  }
  if (value is Map && value['seconds'] is int) {
    final seconds = value['seconds'] as int;
    final nanoseconds = value['nanoseconds'] as int? ?? 0;
    final microseconds = seconds * 1000000 + (nanoseconds / 1000).round();
    return DateTime.fromMicrosecondsSinceEpoch(
      microseconds,
      isUtc: true,
    ).toLocal();
  }
  return null;
}

String? _statusLabel(dynamic value) {
  if (value == null) {
    return null;
  }
  final normalized = value.toString().trim();
  if (normalized.isEmpty) {
    return null;
  }
  switch (normalized) {
    case 'scheduled':
      return 'Programmato';
    case 'completed':
      return 'Completato';
    case 'cancelled':
      return 'Annullato';
    case 'noShow':
      return 'No show';
    default:
      return normalized;
  }
}
