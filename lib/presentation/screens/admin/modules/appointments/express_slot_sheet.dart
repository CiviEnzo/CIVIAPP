import 'package:civiapp/domain/entities/last_minute_slot.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ExpressSlotSheet extends StatefulWidget {
  const ExpressSlotSheet({
    super.key,
    required this.salonId,
    required this.initialStart,
    required this.initialEnd,
    required this.services,
    required this.staff,
    required this.rooms,
    this.initialStaffId,
    this.initialSlot,
  });

  final String salonId;
  final DateTime initialStart;
  final DateTime initialEnd;
  final List<Service> services;
  final List<StaffMember> staff;
  final List<SalonRoom> rooms;
  final String? initialStaffId;
  final LastMinuteSlot? initialSlot;

  @override
  State<ExpressSlotSheet> createState() => _ExpressSlotSheetState();
}

class _ExpressSlotSheetState extends State<ExpressSlotSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late final TextEditingController _labelController;
  late final TextEditingController _durationController;
  late final TextEditingController _basePriceController;
  late final TextEditingController _discountController;
  late final TextEditingController _priceNowController;
  late final TextEditingController _loyaltyController;
  late final TextEditingController _seatsController;
  late final TextEditingController _windowLeadController;
  late final TextEditingController _windowExtendController;

  String? _selectedServiceId;
  String? _selectedStaffId;
  String? _selectedRoomId;
  LastMinuteSlot? _editing;

  @override
  void initState() {
    super.initState();
    _editing = widget.initialSlot;
    final durationMinutes = widget.initialEnd
        .difference(widget.initialStart)
        .inMinutes
        .clamp(5, 360);
    _durationController = TextEditingController(
      text: durationMinutes.toString(),
    );
    _basePriceController = TextEditingController();
    _discountController = TextEditingController(text: '20');
    _priceNowController = TextEditingController();
    _loyaltyController = TextEditingController(text: '0');
    _seatsController = TextEditingController(text: '1');
    _windowLeadController = TextEditingController(text: '60');
    _windowExtendController = TextEditingController(text: '0');
    _labelController = TextEditingController();

    if (widget.initialSlot != null) {
      final slot = widget.initialSlot!;
      _labelController.text = slot.serviceName;
      _durationController.text = slot.duration.inMinutes.toString();
      _basePriceController.text = slot.basePrice.toStringAsFixed(2);
      _discountController.text = slot.discountPercentage.toString();
      _priceNowController.text = slot.priceNow.toStringAsFixed(2);
      _loyaltyController.text = slot.loyaltyPoints.toString();
      _seatsController.text = slot.availableSeats.toString();
      final lead = slot.effectiveWindowStart
          .difference(slot.start)
          .inMinutes
          .abs()
          .toString();
      final ext = slot.effectiveWindowEnd
          .difference(slot.start)
          .inMinutes
          .toString();
      _windowLeadController.text = lead;
      _windowExtendController.text = ext;
      _selectedServiceId = slot.serviceId;
      _selectedStaffId = slot.operatorId;
      _selectedRoomId = slot.roomId;
    } else if (widget.services.isNotEmpty) {
      _selectedServiceId = widget.services.first.id;
      _applyServiceDefaults(widget.services.first);
    }
    if (widget.staff.isNotEmpty || widget.initialStaffId != null) {
      final matchingStaff = widget.staff.firstWhereOrNull(
        (member) => member.id == widget.initialStaffId,
      );
      _selectedStaffId =
          _selectedStaffId ??
          matchingStaff?.id ??
          (widget.staff.isNotEmpty ? widget.staff.first.id : null);
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _durationController.dispose();
    _basePriceController.dispose();
    _discountController.dispose();
    _priceNowController.dispose();
    _loyaltyController.dispose();
    _seatsController.dispose();
    _windowLeadController.dispose();
    _windowExtendController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final staff = widget.staff;
    final rooms = widget.rooms;

    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initialSlot == null
                    ? 'Crea slot express'
                    : 'Modifica slot express',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: _selectedServiceId,
                decoration: const InputDecoration(labelText: 'Servizio'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Senza servizio (inserisci un nome)'),
                  ),
                  ...services.map(
                    (service) => DropdownMenuItem<String?>(
                      value: service.id,
                      child: Text(service.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedServiceId = value;
                    if (value != null) {
                      final service = services.firstWhereOrNull(
                        (s) => s.id == value,
                      );
                      if (service != null) {
                        _applyServiceDefaults(service);
                      }
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Nome slot *',
                  helperText: 'Mostrato ai clienti nella sezione last-minute',
                ),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Inserisci un nome per lo slot'
                            : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Durata (min)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: _positiveIntValidator,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedStaffId,
                      decoration: const InputDecoration(
                        labelText: 'Operatore *',
                      ),
                      items:
                          staff
                              .map(
                                (member) => DropdownMenuItem<String>(
                                  value: member.id,
                                  child: Text(member.fullName),
                                ),
                              )
                              .toList(),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Seleziona un operatore'
                                  : null,
                      onChanged:
                          (value) => setState(() => _selectedStaffId = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _selectedRoomId,
                decoration: const InputDecoration(labelText: 'Cabina'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Nessuna cabina'),
                  ),
                  ...rooms.map(
                    (room) => DropdownMenuItem<String?>(
                      value: room.id,
                      child: Text(room.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedRoomId = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _basePriceController,
                      decoration: const InputDecoration(
                        labelText: 'Prezzo di listino €',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _positiveDoubleValidator,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _discountController,
                      decoration: const InputDecoration(labelText: 'Sconto %'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return null;
                        }
                        final parsed = double.tryParse(
                          value.replaceAll(',', '.'),
                        );
                        if (parsed == null || parsed < 0 || parsed > 100) {
                          return '0 - 100';
                        }
                        return null;
                      },
                      onChanged: (_) => _recalculatePriceNow(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceNowController,
                decoration: const InputDecoration(
                  labelText: 'Prezzo scontato € *',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _positiveDoubleValidator,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _loyaltyController,
                      decoration: const InputDecoration(
                        labelText: 'Punti fedeltà',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _seatsController,
                      decoration: const InputDecoration(
                        labelText: 'Posti disponibili',
                      ),
                      keyboardType: TextInputType.number,
                      validator: _positiveIntValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _windowLeadController,
                      decoration: const InputDecoration(
                        labelText: 'Anticipo visibilità (min)',
                        helperText:
                            'Quando mostrare lo slot prima dell\'inizio',
                      ),
                      keyboardType: TextInputType.number,
                      validator: _nonNegativeIntValidator,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _windowExtendController,
                      decoration: const InputDecoration(
                        labelText: 'Estensione visibilità (min)',
                        helperText:
                            'Quanto tempo dopo l\'inizio mantenerlo prenotabile',
                      ),
                      keyboardType: TextInputType.number,
                      validator: _nonNegativeIntValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annulla'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(
                      widget.initialSlot == null ? 'Crea slot' : 'Salva',
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

  void _applyServiceDefaults(Service service) {
    _labelController.text = service.name;
    _durationController.text = service.totalDuration.inMinutes.toString();
    _basePriceController.text = service.price.toStringAsFixed(2);
    _recalculatePriceNow();
  }

  void _recalculatePriceNow() {
    final base =
        double.tryParse(_basePriceController.text.replaceAll(',', '.')) ?? 0;
    final discount =
        double.tryParse(_discountController.text.replaceAll(',', '.')) ?? 0;
    final discounted = base * (1 - discount / 100);
    if (discounted > 0) {
      _priceNowController.text = discounted.toStringAsFixed(2);
    }
  }

  String? _positiveIntValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Obbligatorio';
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0) {
      return 'Inserisci un valore > 0';
    }
    return null;
  }

  String? _nonNegativeIntValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Obbligatorio';
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0) {
      return 'Inserisci un valore >= 0';
    }
    return null;
  }

  String? _positiveDoubleValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Obbligatorio';
    }
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      return 'Inserisci un valore valido';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final start = widget.initialSlot?.start ?? widget.initialStart;
    final durationMinutes = int.parse(_durationController.text).clamp(5, 600);
    final duration = Duration(minutes: durationMinutes);
    final basePrice = double.parse(
      _basePriceController.text.replaceAll(',', '.'),
    );
    final priceNow = double.parse(
      _priceNowController.text.replaceAll(',', '.'),
    );
    final discount =
        double.tryParse(_discountController.text.replaceAll(',', '.')) ?? 0.0;
    final loyaltyPoints = int.tryParse(_loyaltyController.text) ?? 0;
    final seats = int.tryParse(_seatsController.text) ?? 1;
    final windowLead = int.tryParse(_windowLeadController.text) ?? 60;
    final windowExtend = int.tryParse(_windowExtendController.text) ?? 0;
    final staffId = _selectedStaffId;
    if (staffId == null || staffId.isEmpty) {
      return;
    }

    final wasBooked = _editing?.isBooked ?? false;
    final preservedSeats = wasBooked ? _editing!.availableSeats : seats;

    final slot = LastMinuteSlot(
      id: _editing?.id ?? _uuid.v4(),
      salonId: widget.salonId,
      serviceId: _selectedServiceId,
      serviceName: _labelController.text.trim(),
      start: start,
      duration: duration,
      basePrice: basePrice,
      discountPercentage: discount,
      priceNow: priceNow,
      roomId: _selectedRoomId,
      roomName:
          widget.rooms
              .firstWhereOrNull((room) => room.id == _selectedRoomId)
              ?.name,
      operatorId: staffId,
      operatorName:
          widget.staff
              .firstWhereOrNull((member) => member.id == staffId)
              ?.fullName,
      availableSeats: preservedSeats,
      loyaltyPoints: loyaltyPoints,
      createdAt: _editing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      windowStart: start.subtract(Duration(minutes: windowLead.abs())),
      windowEnd: start.add(Duration(minutes: windowExtend.abs())),
      bookedClientId: wasBooked ? _editing!.bookedClientId : null,
      bookedClientName: wasBooked ? _editing!.bookedClientName : null,
    );

    Navigator.of(context).pop(slot);
  }
}
