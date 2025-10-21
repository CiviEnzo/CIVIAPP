import 'dart:async';
import 'dart:typed_data';

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/last_minute_notification.dart';
import 'package:civiapp/domain/entities/last_minute_slot.dart';
import 'package:civiapp/domain/entities/reminder_settings.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class ExpressSlotSheetResult {
  const ExpressSlotSheetResult({required this.slot, this.notification});

  final LastMinuteSlot slot;
  final LastMinuteNotificationRequest? notification;
}

class ExpressSlotSheet extends ConsumerStatefulWidget {
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
    this.clients = const <Client>[],
    this.reminderSettings,
  });

  final String salonId;
  final DateTime initialStart;
  final DateTime initialEnd;
  final List<Service> services;
  final List<StaffMember> staff;
  final List<SalonRoom> rooms;
  final String? initialStaffId;
  final LastMinuteSlot? initialSlot;
  final List<Client> clients;
  final ReminderSettings? reminderSettings;

  @override
  ConsumerState<ExpressSlotSheet> createState() => _ExpressSlotSheetState();
}

class _ExpressSlotSheetState extends ConsumerState<ExpressSlotSheet> {
  static const int _maxImageBytes = 5 * 1024 * 1024;

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
  late final String _slotId;
  LastMinuteSlot? _editing;
  bool _sendNotification = false;
  LastMinuteNotificationAudience _notificationAudience =
      LastMinuteNotificationAudience.everyone;
  final Set<String> _selectedClientIds = <String>{};
  String? _imageUrl;
  String? _imageStoragePath;
  bool _isUploadingImage = false;
  String? _imageUploadError;
  final List<String> _pendingDeletePaths = <String>[];
  bool _didSubmit = false;

  @override
  void initState() {
    super.initState();
    _editing = widget.initialSlot;
    _slotId = _editing?.id ?? _uuid.v4();
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
    _imageUrl = _editing?.imageUrl;
    _imageStoragePath = _editing?.imageStoragePath;

    if (widget.initialSlot != null) {
      final slot = widget.initialSlot!;
      _labelController.text = slot.serviceName;
      _durationController.text = slot.duration.inMinutes.toString();
      _basePriceController.text = slot.basePrice.toStringAsFixed(2);
      _discountController.text = slot.discountPercentage.toString();
      _priceNowController.text = slot.priceNow.toStringAsFixed(2);
      _loyaltyController.text = slot.loyaltyPoints.toString();
      _seatsController.text = slot.availableSeats.toString();
      final lead =
          slot.effectiveWindowStart
              .difference(slot.start)
              .inMinutes
              .abs()
              .toString();
      final ext =
          slot.effectiveWindowEnd.difference(slot.start).inMinutes.toString();
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

    final settings = widget.reminderSettings;
    if (widget.initialSlot == null && settings != null) {
      switch (settings.lastMinuteNotificationAudience) {
        case LastMinuteNotificationAudience.none:
          _sendNotification = false;
          _notificationAudience = LastMinuteNotificationAudience.everyone;
          break;
        case LastMinuteNotificationAudience.everyone:
          _sendNotification = true;
          _notificationAudience = LastMinuteNotificationAudience.everyone;
          break;
        case LastMinuteNotificationAudience.ownerSelection:
          _sendNotification = true;
          _notificationAudience = LastMinuteNotificationAudience.ownerSelection;
          break;
      }
    } else {
      _sendNotification = false;
      _notificationAudience = LastMinuteNotificationAudience.everyone;
    }
  }

  @override
  void dispose() {
    if (!_didSubmit) {
      final currentPath = _imageStoragePath;
      final initialPath = _editing?.imageStoragePath;
      if (currentPath != null &&
          currentPath.isNotEmpty &&
          currentPath != initialPath) {
        final storage = ref.read(firebaseStorageServiceProvider);
        unawaited(storage.deleteFile(currentPath));
      }
    }
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
            _SlotImageField(
              imageUrl: _imageUrl,
              isUploading: _isUploadingImage,
              error: _imageUploadError,
              onPickImage: _pickSlotImage,
              onRemoveImage:
                  _imageUrl != null && !_isUploadingImage ? _removeSlotImage : null,
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
              _buildNotificationSection(context),
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

  Widget _buildNotificationSection(BuildContext context) {
    final theme = Theme.of(context);
    final hasClients = widget.clients.isNotEmpty;
    final selectedClients = widget.clients
        .where((client) => _selectedClientIds.contains(client.id))
        .sortedBy((client) => client.fullName.toLowerCase())
        .toList(growable: false);
    final hasSelection = selectedClients.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Invia notifica push ai clienti'),
          subtitle: const Text(
            'Avvisa i clienti quando pubblichi o modifichi lo slot last-minute.',
          ),
          value: _sendNotification,
          onChanged: (value) {
            setState(() {
              _sendNotification = value;
            });
          },
        ),
        if (_sendNotification) ...[
          DropdownButtonFormField<LastMinuteNotificationAudience>(
            value: _notificationAudience,
            decoration: const InputDecoration(labelText: 'Destinatari'),
            items: const [
              DropdownMenuItem<LastMinuteNotificationAudience>(
                value: LastMinuteNotificationAudience.everyone,
                child: Text('Tutti i clienti del salone'),
              ),
              DropdownMenuItem<LastMinuteNotificationAudience>(
                value: LastMinuteNotificationAudience.ownerSelection,
                child: Text('Scegli manualmente i destinatari'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _notificationAudience = value;
              });
              if (value == LastMinuteNotificationAudience.ownerSelection &&
                  hasClients &&
                  _selectedClientIds.isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _pickRecipients();
                  }
                });
              }
            },
          ),
          if (_notificationAudience ==
              LastMinuteNotificationAudience.ownerSelection) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: hasClients ? _pickRecipients : null,
              icon: const Icon(Icons.people_alt_outlined),
              label: Text(
                hasSelection
                    ? 'Modifica destinatari (${_selectedClientIds.length})'
                    : 'Scegli destinatari',
              ),
            ),
            const SizedBox(height: 8),
            if (!hasClients)
              Text(
                'Nessun cliente disponibile per questo salone.',
                style: theme.textTheme.bodySmall,
              )
            else if (!hasSelection)
              Text(
                'Seleziona almeno un cliente prima di inviare la notifica.',
                style: theme.textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final client in selectedClients.take(6))
                    Chip(label: Text(client.fullName)),
                  if (_selectedClientIds.length > 6)
                    Chip(label: Text('+${_selectedClientIds.length - 6}')),
                ],
              ),
          ],
        ],
      ],
    );
  }

  Future<void> _pickRecipients() async {
    final initialSelection = Set<String>.from(_selectedClientIds);
    final result = await showAppModalSheet<Set<String>>(
      context: context,
      builder: (sheetContext) {
        return _LastMinuteRecipientPicker(
          clients: widget.clients,
          initialSelection: initialSelection,
        );
      },
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _selectedClientIds
        ..clear()
        ..addAll(result);
    });
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

  Future<void> _pickSlotImage() async {
    setState(() {
      _imageUploadError = null;
    });
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
      withReadStream: true,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.first;
    if (file.size > _maxImageBytes) {
      final maxMb = (_maxImageBytes / (1024 * 1024)).toStringAsFixed(1);
      setState(() {
        _imageUploadError = 'L\'immagine supera il limite di $maxMb MB.';
      });
      return;
    }
    final bytes = await _resolveBytes(file);
    if (!mounted || bytes == null || bytes.isEmpty) {
      setState(() {
        _imageUploadError = 'Impossibile leggere il file selezionato.';
      });
      return;
    }
    setState(() {
      _isUploadingImage = true;
      _imageUploadError = null;
    });
    final storage = ref.read(firebaseStorageServiceProvider);
    final session = ref.read(sessionControllerProvider);
    final uploaderId = session.uid ?? 'unknown';
    final previousPath = _imageStoragePath;
    try {
      final upload = await storage.uploadLastMinuteSlotImage(
        salonId: widget.salonId,
        slotId: _slotId,
        data: bytes,
        fileName: file.name,
        uploaderId: uploaderId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _imageUrl = upload.downloadUrl;
        _imageStoragePath = upload.storagePath;
      });
      if (previousPath != null && previousPath.isNotEmpty) {
        _pendingDeletePaths.add(previousPath);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _imageUploadError = 'Impossibile caricare l\'immagine: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _removeSlotImage() {
    if (_imageStoragePath != null && _imageStoragePath!.isNotEmpty) {
      _pendingDeletePaths.add(_imageStoragePath!);
    }
    setState(() {
      _imageUrl = null;
      _imageStoragePath = null;
      _imageUploadError = null;
    });
  }

  Future<Uint8List?> _resolveBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes;
    }
    final stream = file.readStream;
    if (stream == null) {
      return null;
    }
    final completer = Completer<Uint8List>();
    final buffer = BytesBuilder(copy: false);
    stream.listen(
      buffer.add,
      onDone: () => completer.complete(buffer.toBytes()),
      onError: completer.completeError,
      cancelOnError: true,
    );
    return completer.future;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_sendNotification &&
        _notificationAudience ==
            LastMinuteNotificationAudience.ownerSelection &&
        _selectedClientIds.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Seleziona almeno un destinatario per la notifica.'),
          ),
        );
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

    _didSubmit = true;
    if (_pendingDeletePaths.isNotEmpty) {
      final storage = ref.read(firebaseStorageServiceProvider);
      final uniquePaths = _pendingDeletePaths.toSet();
      for (final path in uniquePaths) {
        if (path.isEmpty) continue;
        unawaited(storage.deleteFile(path));
      }
    }

    final slot = LastMinuteSlot(
      id: _slotId,
      salonId: widget.salonId,
      serviceId: _selectedServiceId,
      serviceName: _labelController.text.trim(),
      imageUrl: _imageUrl,
      imageStoragePath: _imageStoragePath,
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

    LastMinuteNotificationRequest? notification;
    if (_sendNotification) {
      final audience = _notificationAudience;
      final recipients =
          audience == LastMinuteNotificationAudience.ownerSelection
              ? _selectedClientIds.toList(growable: false)
              : const <String>[];
      notification = LastMinuteNotificationRequest(
        audience: audience,
        clientIds: recipients,
      );
    }

    Navigator.of(
      context,
    ).pop(ExpressSlotSheetResult(slot: slot, notification: notification));
  }
}

class _SlotImageField extends StatelessWidget {
  const _SlotImageField({
    required this.imageUrl,
    required this.isUploading,
    required this.error,
    required this.onPickImage,
    this.onRemoveImage,
  });

  final String? imageUrl;
  final bool isUploading;
  final String? error;
  final VoidCallback onPickImage;
  final VoidCallback? onRemoveImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Immagine last-minute',
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child:
                imageUrl != null
                    ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => Container(
                            color: scheme.surfaceVariant,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              size: 40,
                            ),
                          ),
                    )
                    : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.secondaryContainer,
                            scheme.primaryContainer,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        Icons.photo_outlined,
                        size: 48,
                        color: scheme.onSecondaryContainer.withOpacity(0.6),
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Suggerimento: carica un\'immagine orizzontale del trattamento.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: isUploading ? null : onPickImage,
              icon:
                  isUploading
                      ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.upload_rounded),
              label: Text(
                isUploading
                    ? 'Caricamento...'
                    : (imageUrl == null
                        ? 'Carica immagine'
                        : 'Sostituisci immagine'),
              ),
            ),
            if (imageUrl != null && onRemoveImage != null)
              OutlinedButton.icon(
                onPressed: isUploading ? null : onRemoveImage,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Rimuovi'),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

class _LastMinuteRecipientPicker extends StatefulWidget {
  const _LastMinuteRecipientPicker({
    required this.clients,
    required this.initialSelection,
  });

  final List<Client> clients;
  final Set<String> initialSelection;

  @override
  State<_LastMinuteRecipientPicker> createState() =>
      _LastMinuteRecipientPickerState();
}

class _LastMinuteRecipientPickerState
    extends State<_LastMinuteRecipientPicker> {
  late final TextEditingController _searchController;
  late final Set<String> _selection;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _selection = Set<String>.from(widget.initialSelection);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<Client> _filteredClients() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.clients;
    }
    final queryNoSpaces = query.replaceAll(RegExp(r'\s+'), '');
    return widget.clients
        .where((client) {
          final fullName = client.fullName.toLowerCase();
          if (fullName.contains(query)) {
            return true;
          }
          final number = client.clientNumber?.toLowerCase();
          if (number != null && number.contains(query)) {
            return true;
          }
          if (queryNoSpaces.isEmpty) {
            return false;
          }
          final phone = client.phone.replaceAll(RegExp(r'\s+'), '');
          return phone.contains(queryNoSpaces);
        })
        .toList(growable: false);
  }

  void _toggle(String clientId, bool shouldSelect) {
    setState(() {
      if (shouldSelect) {
        _selection.add(clientId);
      } else {
        _selection.remove(clientId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredClients();
    final hasClients = widget.clients.isNotEmpty;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 24),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seleziona destinatari', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Cerca per nome, numero cliente o telefono',
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    hasClients
                        ? ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final client = filtered[index];
                            final selected = _selection.contains(client.id);
                            return CheckboxListTile(
                              value: selected,
                              onChanged: (value) {
                                _toggle(client.id, value ?? false);
                              },
                              title: Text(client.fullName),
                              subtitle:
                                  client.clientNumber != null
                                      ? Text('Cliente #${client.clientNumber}')
                                      : null,
                            );
                          },
                        )
                        : Center(
                          child: Text(
                            'Non ci sono clienti associati al salone.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selection.length} selezionati',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _selection.isEmpty
                            ? null
                            : () {
                              setState(() => _selection.clear());
                            },
                    child: const Text('Pulisci'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(Set<String>.from(_selection));
                    },
                    child: const Text('Conferma'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
