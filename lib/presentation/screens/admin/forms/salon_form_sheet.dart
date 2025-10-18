import 'package:civiapp/domain/entities/loyalty_settings.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class SalonFormSheet extends StatefulWidget {
  const SalonFormSheet({super.key, this.initial});

  final Salon? initial;

  @override
  State<SalonFormSheet> createState() => _SalonFormSheetState();
}

class _SalonFormSheetState extends State<SalonFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _name;
  late TextEditingController _address;
  late TextEditingController _city;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _description;
  late TextEditingController _postalCode;
  late TextEditingController _bookingLink;
  late TextEditingController _googlePlaceId;
  late TextEditingController _latitude;
  late TextEditingController _longitude;
  late List<_SocialLinkFormData> _socialLinks;
  late List<_RoomFormData> _rooms;
  late List<_EquipmentFormData> _equipment;
  late List<_ClosureFormData> _closures;
  late List<_ScheduleEntry> _schedule;
  late SalonStatus _status;
  late bool _loyaltyEnabled;
  late TextEditingController _loyaltyEuroPerPoint;
  late TextEditingController _loyaltyPointValueEuro;
  late TextEditingController _loyaltyMaxPercent;
  late TextEditingController _loyaltyInitialBalance;
  late TextEditingController _loyaltyResetMonth;
  late TextEditingController _loyaltyResetDay;
  late TextEditingController _loyaltyTimezone;
  late bool _loyaltyAutoSuggest;
  late LoyaltyRoundingMode _loyaltyRounding;
  late ClientRegistrationAccessMode _registrationAccessMode;
  late Set<ClientRegistrationExtraField> _registrationExtraFields;
  static const int _minutesInDay = 24 * 60;
  static const int _defaultOpeningMinutes = 9 * 60;
  static const int _defaultClosingMinutes = 19 * 60;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _address = TextEditingController(text: initial?.address ?? '');
    _city = TextEditingController(text: initial?.city ?? '');
    _phone = TextEditingController(text: initial?.phone ?? '');
    _email = TextEditingController(text: initial?.email ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _postalCode = TextEditingController(text: initial?.postalCode ?? '');
    _bookingLink = TextEditingController(text: initial?.bookingLink ?? '');
    _googlePlaceId = TextEditingController(text: initial?.googlePlaceId ?? '');

    final latitudeValue = initial?.latitude;
    final longitudeValue = initial?.longitude;
    _latitude = TextEditingController(
      text: latitudeValue == null ? '' : latitudeValue.toStringAsFixed(6),
    );
    _longitude = TextEditingController(
      text: longitudeValue == null ? '' : longitudeValue.toStringAsFixed(6),
    );
    final socialLinksInitial = initial?.socialLinks ?? const <String, String>{};
    _socialLinks =
        socialLinksInitial.entries
            .map(
              (entry) => _SocialLinkFormData(
                id: _uuid.v4(),
                label: entry.key,
                url: entry.value,
              ),
            )
            .toList();
    if (_socialLinks.isEmpty) {
      _socialLinks = [_SocialLinkFormData(id: _uuid.v4())];
    }

    final roomList = initial?.rooms ?? const <SalonRoom>[];
    _rooms =
        roomList
            .map(
              (room) => _RoomFormData.fromRoom(
                room,
                servicesLabel: room.services.join(', '),
              ),
            )
            .toList();
    if (_rooms.isEmpty) {
      _rooms = [_RoomFormData(id: _uuid.v4())];
    }

    final equipmentList = initial?.equipment ?? const <SalonEquipment>[];
    _equipment = equipmentList.map(_EquipmentFormData.fromEquipment).toList();
    if (_equipment.isEmpty) {
      _equipment = [_EquipmentFormData(id: _uuid.v4())];
    }

    final closuresList = initial?.closures ?? const <SalonClosure>[];
    _closures = closuresList.map(_ClosureFormData.fromClosure).toList();

    _status = initial?.status ?? SalonStatus.active;

    final scheduleMap = {
      for (final entry in initial?.schedule ?? const <SalonDailySchedule>[])
        entry.weekday: entry,
    };
    _schedule = List<_ScheduleEntry>.generate(7, (index) {
      final weekday = DateTime.monday + index;
      final current = scheduleMap[weekday];
      if (current != null && current.isOpen) {
        return _ScheduleEntry(
          weekday: weekday,
          isOpen: true,
          open: _minutesToTimeOfDay(
            current.openMinuteOfDay ?? _defaultOpeningMinutes,
          ),
          close: _minutesToTimeOfDay(
            current.closeMinuteOfDay ?? _defaultClosingMinutes,
          ),
        );
      }
      return _ScheduleEntry(
        weekday: weekday,
        isOpen: false,
        open: const TimeOfDay(hour: 9, minute: 0),
        close: const TimeOfDay(hour: 19, minute: 0),
      );
    });

    final loyalty = initial?.loyaltySettings ?? const LoyaltySettings();
    _loyaltyEnabled = loyalty.enabled;
    _loyaltyRounding = loyalty.earning.rounding;
    _loyaltyAutoSuggest = loyalty.redemption.autoSuggest;
    _loyaltyEuroPerPoint = TextEditingController(
      text: loyalty.earning.euroPerPoint.toStringAsFixed(2),
    );
    _loyaltyPointValueEuro = TextEditingController(
      text: loyalty.redemption.pointValueEuro.toStringAsFixed(2),
    );
    _loyaltyMaxPercent = TextEditingController(
      text: (loyalty.redemption.maxPercent * 100).toStringAsFixed(1),
    );
    _loyaltyInitialBalance = TextEditingController(
      text: loyalty.initialBalance.toString(),
    );
    _loyaltyResetMonth = TextEditingController(
      text: loyalty.expiration.resetMonth.toString(),
    );
    _loyaltyResetDay = TextEditingController(
      text: loyalty.expiration.resetDay.toString(),
    );
    _loyaltyTimezone = TextEditingController(text: loyalty.expiration.timezone);
    final registration =
        initial?.clientRegistration ?? const ClientRegistrationSettings();
    _registrationAccessMode = registration.accessMode;
    _registrationExtraFields = registration.extraFields.toSet();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _phone.dispose();
    _email.dispose();
    _description.dispose();
    _postalCode.dispose();
    _bookingLink.dispose();
    _googlePlaceId.dispose();
    _latitude.dispose();
    _longitude.dispose();
    for (final social in _socialLinks) {
      social.dispose();
    }
    for (final room in _rooms) {
      room.dispose();
    }
    for (final equipment in _equipment) {
      equipment.dispose();
    }
    for (final closure in _closures) {
      closure.dispose();
    }
    _loyaltyEuroPerPoint.dispose();
    _loyaltyPointValueEuro.dispose();
    _loyaltyMaxPercent.dispose();
    _loyaltyInitialBalance.dispose();
    _loyaltyResetMonth.dispose();
    _loyaltyResetDay.dispose();
    _loyaltyTimezone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null ? 'Nuovo salone' : 'Modifica salone',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci il nome del salone'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Indirizzo'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Città'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Telefono'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _postalCode,
              decoration: const InputDecoration(labelText: 'CAP'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bookingLink,
              decoration: const InputDecoration(
                labelText: 'Link prenotazione esterna',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _googlePlaceId,
              decoration: const InputDecoration(
                labelText: 'Link recensioni',
                helperText:
                    'Incolla il link diretto alla pagina recensioni o l\'ID Google Place',
              ),
              keyboardType: TextInputType.url,
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitude,
                    decoration: const InputDecoration(labelText: 'Latitudine'),
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _longitude,
                    decoration: const InputDecoration(labelText: 'Longitudine'),
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SalonStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Stato del salone'),
              items:
                  SalonStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            const SizedBox(height: 12),
            _buildClientRegistrationSection(context),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Presenza online e social',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Column(
              children:
                  _socialLinks
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SocialLinkCard(
                            data: item,
                            onRemove:
                                _socialLinks.length <= 1
                                    ? null
                                    : () => _removeSocialLink(item),
                          ),
                        ),
                      )
                      .toList(),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addSocialLink,
                icon: const Icon(Icons.alternate_email_rounded),
                label: const Text('Aggiungi canale social'),
              ),
            ),
            const SizedBox(height: 24),
            _buildLoyaltyCard(context),
            const SizedBox(height: 24),
            Text(
              'Macchinari disponibili',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_equipment.isEmpty)
              Text(
                'Nessun macchinario configurato. Aggiungine uno per gestire disponibilità e competenze.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ..._equipment.map(
              (item) => _EquipmentCard(
                data: item,
                onStatusChanged:
                    (status) => _changeEquipmentStatus(item, status),
                onRemove:
                    _equipment.length <= 1
                        ? null
                        : () => _removeEquipment(item),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addEquipment,
                icon: const Icon(Icons.precision_manufacturing_rounded),
                label: const Text('Aggiungi macchinario'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Orari di apertura',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Column(
              children:
                  _schedule
                      .map(
                        (entry) => _ScheduleCard(
                          entry: entry,
                          onChanged:
                              (value) => _toggleScheduleEntry(entry, value),
                          onPickOpening:
                              () => _pickScheduleTime(entry, isOpening: true),
                          onPickClosing:
                              () => _pickScheduleTime(entry, isOpening: false),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Chiusure straordinarie',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_closures.isEmpty)
              Text(
                'Nessuna chiusura programmata. Aggiungi periodi di chiusura per aggiornare automaticamente le prenotazioni.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ..._closures.map(
              (closure) => _ClosureCard(
                data: closure,
                onPickRange: () => _pickClosureRange(closure),
                onRemove: () => _removeClosure(closure),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addClosure,
                icon: const Icon(Icons.event_busy_rounded),
                label: const Text('Aggiungi chiusura'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Cabine e stanze',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_rooms.isEmpty)
              Text(
                'Nessuna cabina configurata. Aggiungine una per iniziare.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ..._rooms.map(
              (room) => _RoomCard(
                data: room,
                onRemove: _rooms.length <= 1 ? null : () => _removeRoom(room),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addRoom,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Aggiungi cabina'),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Salva'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Programma fedeltà', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _loyaltyEnabled,
              title: const Text('Abilita raccolta punti per questo salone'),
              onChanged: (value) => setState(() => _loyaltyEnabled = value),
            ),
            const SizedBox(height: 12),
            IgnorePointer(
              ignoring: !_loyaltyEnabled,
              child: AnimatedOpacity(
                opacity: _loyaltyEnabled ? 1 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _loyaltyEuroPerPoint,
                            decoration: const InputDecoration(
                              labelText: '€ per punto',
                              helperText: 'Es. 10 significa 1 punto ogni 10€',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<LoyaltyRoundingMode>(
                            value: _loyaltyRounding,
                            decoration: const InputDecoration(
                              labelText: 'Arrotondamento',
                            ),
                            items:
                                LoyaltyRoundingMode.values
                                    .map(
                                      (mode) => DropdownMenuItem(
                                        value: mode,
                                        child: Text(
                                          _loyaltyRoundingLabel(mode),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _loyaltyRounding = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _loyaltyPointValueEuro,
                            decoration: const InputDecoration(
                              labelText: 'Valore punto (€)',
                              helperText: 'Conversione in sconto (es. 1 = 1€)',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _loyaltyMaxPercent,
                            decoration: const InputDecoration(
                              labelText: 'Max sconto (%)',
                              helperText: 'Percentuale massima per transazione',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Suggerisci automaticamente punti da usare',
                      ),
                      value: _loyaltyAutoSuggest,
                      onChanged:
                          (value) =>
                              setState(() => _loyaltyAutoSuggest = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _loyaltyInitialBalance,
                            decoration: const InputDecoration(
                              labelText: 'Saldo iniziale punti',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _loyaltyResetMonth,
                            decoration: const InputDecoration(
                              labelText: 'Mese reset (1-12)',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _loyaltyResetDay,
                            decoration: const InputDecoration(
                              labelText: 'Giorno reset (1-31)',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _loyaltyTimezone,
                      decoration: const InputDecoration(
                        labelText: 'Timezone',
                        helperText: 'Es. Europe/Rome',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _loyaltyRoundingLabel(LoyaltyRoundingMode mode) {
    switch (mode) {
      case LoyaltyRoundingMode.floor:
        return 'Per difetto';
      case LoyaltyRoundingMode.round:
        return 'Matematico';
      case LoyaltyRoundingMode.ceil:
        return 'Per eccesso';
    }
  }

  LoyaltySettings? _buildLoyaltySettings() {
    if (!_loyaltyEnabled) {
      return const LoyaltySettings(enabled: false);
    }

    double? parseDouble(String value) =>
        double.tryParse(value.replaceAll(',', '.').trim());

    int? parseInt(String value) => int.tryParse(value.trim());

    final euroPerPoint = parseDouble(_loyaltyEuroPerPoint.text);
    if (euroPerPoint == null || euroPerPoint <= 0) {
      _showError('Inserisci un valore valido per € per punto (>= 1).');
      return null;
    }

    final pointValueEuro = parseDouble(_loyaltyPointValueEuro.text);
    if (pointValueEuro == null || pointValueEuro <= 0) {
      _showError('Inserisci un valore valido per il valore del punto.');
      return null;
    }

    final maxPercentInput = parseDouble(_loyaltyMaxPercent.text);
    if (maxPercentInput == null ||
        maxPercentInput <= 0 ||
        maxPercentInput > 50) {
      _showError('Lo sconto massimo deve essere compreso tra 1% e 50%.');
      return null;
    }
    final maxPercent = maxPercentInput / 100;

    final initialBalance = parseInt(_loyaltyInitialBalance.text) ?? 0;
    if (initialBalance < 0) {
      _showError('Il saldo iniziale deve essere maggiore o uguale a zero.');
      return null;
    }

    final resetMonth = parseInt(_loyaltyResetMonth.text) ?? 1;
    if (resetMonth < 1 || resetMonth > 12) {
      _showError('Il mese di reset deve essere compreso tra 1 e 12.');
      return null;
    }

    final resetDay = parseInt(_loyaltyResetDay.text) ?? 1;
    if (resetDay < 1 || resetDay > 31) {
      _showError('Il giorno di reset deve essere compreso tra 1 e 31.');
      return null;
    }

    final timezone =
        _loyaltyTimezone.text.trim().isEmpty
            ? 'Europe/Rome'
            : _loyaltyTimezone.text.trim();

    return LoyaltySettings(
      enabled: true,
      earning: LoyaltyEarningRules(
        euroPerPoint: euroPerPoint,
        rounding: _loyaltyRounding,
      ),
      redemption: LoyaltyRedemptionRules(
        pointValueEuro: pointValueEuro,
        maxPercent: maxPercent,
        autoSuggest: _loyaltyAutoSuggest,
      ),
      initialBalance: initialBalance,
      expiration: LoyaltyExpirationRules(
        resetMonth: resetMonth,
        resetDay: resetDay,
        timezone: timezone,
      ),
      updatedAt: DateTime.now(),
    );
  }

  Widget _buildClientRegistrationSection(BuildContext context) {
    final theme = Theme.of(context);
    final modeItems = ClientRegistrationAccessMode.values
        .map(
          (mode) => DropdownMenuItem<ClientRegistrationAccessMode>(
            value: mode,
            child: Text(_accessModeLabel(mode)),
          ),
        )
        .toList(growable: false);
    final extraOptions = <ClientRegistrationExtraField, String>{
      ClientRegistrationExtraField.address: 'Richiedi città di residenza',
      ClientRegistrationExtraField.profession: 'Richiedi professione',
      ClientRegistrationExtraField.referralSource:
          'Richiedi "Come ci ha conosciuto?"',
      ClientRegistrationExtraField.notes: 'Richiedi note aggiuntive',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registrazione clienti', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              'Configura il comportamento della registrazione via app: puoi richiedere approvazione manuale e selezionare dati aggiuntivi obbligatori.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ClientRegistrationAccessMode>(
              value: _registrationAccessMode,
              decoration: const InputDecoration(
                labelText: 'Modalità di accesso',
              ),
              items: modeItems,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _registrationAccessMode = value);
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Campi aggiuntivi obbligatori',
              style: theme.textTheme.labelLarge,
            ),
            ...extraOptions.entries.map((entry) {
              final isSelected = _registrationExtraFields.contains(entry.key);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _registrationExtraFields.add(entry.key);
                    } else {
                      _registrationExtraFields.remove(entry.key);
                    }
                  });
                },
                title: Text(entry.value),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _accessModeLabel(ClientRegistrationAccessMode mode) {
    switch (mode) {
      case ClientRegistrationAccessMode.open:
        return 'Accesso immediato (salone aperto)';
      case ClientRegistrationAccessMode.approval:
        return 'Solo previa approvazione';
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final parsedRooms = <SalonRoom>[];
    for (final room in _rooms) {
      final name = room.name.text.trim();
      if (name.isEmpty) {
        _showError('Specifica il nome per ogni cabina.');
        return;
      }
      final capacityText = room.capacity.text.trim();
      final capacity = capacityText.isEmpty ? 1 : int.tryParse(capacityText);
      if (capacity == null || capacity <= 0) {
        _showError('La capienza deve essere un numero positivo.');
        return;
      }
      final services =
          room.services.text
              .split(',')
              .map((service) => service.trim())
              .where((service) => service.isNotEmpty)
              .toList();
      parsedRooms.add(
        SalonRoom(
          id: room.id,
          name: name,
          capacity: capacity,
          category:
              room.category.text.trim().isEmpty
                  ? null
                  : room.category.text.trim(),
          services: services,
        ),
      );
    }

    if (parsedRooms.isEmpty) {
      _showError('Aggiungi almeno una cabina al salone.');
      return;
    }

    final parsedEquipment = <SalonEquipment>[];
    for (final equipment in _equipment) {
      final name = equipment.name.text.trim();
      if (name.isEmpty) {
        _showError('Specifica il nome per ogni macchinario.');
        return;
      }
      final quantityText = equipment.quantity.text.trim();
      final quantity = quantityText.isEmpty ? 1 : int.tryParse(quantityText);
      if (quantity == null || quantity <= 0) {
        _showError(
          'La quantità di "${equipment.name.text}" deve essere un numero positivo.',
        );
        return;
      }
      parsedEquipment.add(
        SalonEquipment(
          id: equipment.id,
          name: name,
          quantity: quantity,
          status: equipment.status,
          notes:
              equipment.notes.text.trim().isEmpty
                  ? null
                  : equipment.notes.text.trim(),
        ),
      );
    }

    if (parsedEquipment.isEmpty) {
      _showError('Aggiungi almeno un macchinario al salone.');
      return;
    }

    final schedule = <SalonDailySchedule>[];
    for (final entry in _schedule) {
      final openMinutes = _timeOfDayToMinutes(entry.open);
      final closeMinutes = _timeOfDayToMinutes(entry.close);
      if (entry.isOpen && closeMinutes <= openMinutes) {
        _showError(
          'L\'orario di chiusura deve essere successivo a quello di apertura per ${_weekdayName(entry.weekday)}.',
        );
        return;
      }
      schedule.add(
        SalonDailySchedule(
          weekday: entry.weekday,
          isOpen: entry.isOpen,
          openMinuteOfDay: entry.isOpen ? openMinutes : null,
          closeMinuteOfDay: entry.isOpen ? closeMinutes : null,
        ),
      );
    }

    final parsedClosures = <SalonClosure>[];
    for (final closure in _closures) {
      if (closure.end.isBefore(closure.start)) {
        _showError('Le chiusure devono terminare dopo la data di inizio.');
        return;
      }
      parsedClosures.add(
        SalonClosure(
          id: closure.id,
          start: closure.start,
          end: closure.end,
          reason:
              closure.reason.text.trim().isEmpty
                  ? null
                  : closure.reason.text.trim(),
        ),
      );
    }

    double? latitude;
    final latitudeText = _latitude.text.trim().replaceAll(',', '.');
    if (latitudeText.isNotEmpty) {
      latitude = double.tryParse(latitudeText);
      if (latitude == null) {
        _showError('Inserisci una latitudine valida (es. 45.464203).');
        return;
      }
    }

    double? longitude;
    final longitudeText = _longitude.text.trim().replaceAll(',', '.');
    if (longitudeText.isNotEmpty) {
      longitude = double.tryParse(longitudeText);
      if (longitude == null) {
        _showError('Inserisci una longitudine valida (es. 9.189982).');
        return;
      }
    }

    final socialLinks = <String, String>{};
    for (final link in _socialLinks) {
      final label = link.label.text.trim();
      final url = link.url.text.trim();
      if (label.isEmpty && url.isEmpty) {
        continue;
      }
      if (label.isEmpty || url.isEmpty) {
        _showError('Completa nome e link per ogni canale social.');
        return;
      }
      if (socialLinks.containsKey(label)) {
        _showError('Hai inserito più volte il canale "$label".');
        return;
      }
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        _showError('Inserisci un URL valido per "$label".');
        return;
      }
      socialLinks[label] = url;
    }

    final loyaltySettings = _buildLoyaltySettings();
    if (loyaltySettings == null) {
      return;
    }

    final salonName = _name.text.trim();
    final salonId = widget.initial?.id ?? _generateSalonId(salonName);
    final dashboardSections =
        widget.initial?.dashboardSections ?? const SalonDashboardSections();

    final salon = Salon(
      id: salonId,
      name: _name.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      postalCode:
          _postalCode.text.trim().isEmpty ? null : _postalCode.text.trim(),
      bookingLink:
          _bookingLink.text.trim().isEmpty ? null : _bookingLink.text.trim(),
      googlePlaceId:
          _googlePlaceId.text.trim().isEmpty
              ? null
              : _googlePlaceId.text.trim(),
      latitude: latitude,
      longitude: longitude,
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      socialLinks: socialLinks,
      rooms: parsedRooms,
      equipment: parsedEquipment,
      closures: parsedClosures,
      schedule: schedule,
      status: _status,
      loyaltySettings: loyaltySettings,
      dashboardSections: dashboardSections,
      clientRegistration: ClientRegistrationSettings(
        accessMode: _registrationAccessMode,
        extraFields: _registrationExtraFields.toList(growable: false),
      ),
    );

    Navigator.of(context).pop(salon);
  }

  String _generateSalonId(String name) {
    var base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (base.isEmpty) {
      base = 'salon';
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${base}_$timestamp';
  }

  void _addRoom() {
    setState(() {
      _rooms.add(_RoomFormData(id: _uuid.v4()));
    });
  }

  void _removeRoom(_RoomFormData room) {
    setState(() {
      _rooms.remove(room);
    });
    room.dispose();
  }

  void _addEquipment() {
    setState(() {
      _equipment.add(_EquipmentFormData(id: _uuid.v4()));
    });
  }

  void _addSocialLink() {
    setState(() {
      _socialLinks.add(_SocialLinkFormData(id: _uuid.v4()));
    });
  }

  void _removeSocialLink(_SocialLinkFormData link) {
    setState(() {
      _socialLinks.remove(link);
    });
    link.dispose();
  }

  void _removeEquipment(_EquipmentFormData equipment) {
    setState(() {
      _equipment.remove(equipment);
    });
    equipment.dispose();
  }

  void _changeEquipmentStatus(
    _EquipmentFormData equipment,
    SalonEquipmentStatus status,
  ) {
    setState(() {
      equipment.status = status;
    });
  }

  void _addClosure() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    setState(() {
      _closures.add(_ClosureFormData(id: _uuid.v4(), start: start, end: start));
    });
  }

  void _removeClosure(_ClosureFormData closure) {
    setState(() {
      _closures.remove(closure);
    });
    closure.dispose();
  }

  Future<void> _pickClosureRange(_ClosureFormData closure) async {
    final initialRange = DateTimeRange(start: closure.start, end: closure.end);
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
      helpText: 'Seleziona periodo di chiusura',
      saveText: 'Conferma',
    );
    if (result == null) {
      return;
    }

    setState(() {
      closure
        ..start = DateTime(
          result.start.year,
          result.start.month,
          result.start.day,
        )
        ..end = DateTime(
          result.end.year,
          result.end.month,
          result.end.day,
          23,
          59,
          59,
        );
    });
  }

  void _toggleScheduleEntry(_ScheduleEntry entry, bool isOpen) {
    setState(() {
      entry.isOpen = isOpen;
      if (isOpen &&
          _timeOfDayToMinutes(entry.close) <= _timeOfDayToMinutes(entry.open)) {
        final nextMinutes = _clampMinutes(
          _timeOfDayToMinutes(entry.open) + 8 * 60,
        );
        entry.close = _minutesToTimeOfDay(nextMinutes);
      }
    });
  }

  Future<void> _pickScheduleTime(
    _ScheduleEntry entry, {
    required bool isOpening,
  }) async {
    final initial = isOpening ? entry.open : entry.close;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) {
      return;
    }

    if (!isOpening &&
        _timeOfDayToMinutes(picked) <= _timeOfDayToMinutes(entry.open)) {
      _showError(
        'L\'orario di chiusura deve essere successivo a quello di apertura.',
      );
      return;
    }

    setState(() {
      if (isOpening) {
        entry.open = picked;
        if (_timeOfDayToMinutes(entry.close) <=
            _timeOfDayToMinutes(entry.open)) {
          final nextMinutes = _clampMinutes(
            _timeOfDayToMinutes(entry.open) + 60,
          );
          entry.close = _minutesToTimeOfDay(nextMinutes);
        }
      } else {
        entry.close = picked;
      }
    });
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static TimeOfDay _minutesToTimeOfDay(int minutes) {
    final value = _clampMinutes(minutes);
    return TimeOfDay(hour: value ~/ 60, minute: value % 60);
  }

  static int _timeOfDayToMinutes(TimeOfDay time) =>
      time.hour * 60 + time.minute;

  static int _clampMinutes(int minutes) {
    if (minutes < 0) {
      return 0;
    }
    if (minutes >= _minutesInDay) {
      return _minutesInDay - 1;
    }
    return minutes;
  }
}

const List<String> _weekdayLabels = <String>[
  'Lunedì',
  'Martedì',
  'Mercoledì',
  'Giovedì',
  'Venerdì',
  'Sabato',
  'Domenica',
];

String _weekdayName(int weekday) {
  final index = (weekday - DateTime.monday) % 7;
  final normalized = index < 0 ? index + 7 : index;
  return _weekdayLabels[normalized];
}

class _ScheduleEntry {
  _ScheduleEntry({
    required this.weekday,
    required this.isOpen,
    required this.open,
    required this.close,
  });

  final int weekday;
  bool isOpen;
  TimeOfDay open;
  TimeOfDay close;
}

class _SocialLinkFormData {
  _SocialLinkFormData({required this.id, String? label, String? url})
    : label = TextEditingController(text: label ?? ''),
      url = TextEditingController(text: url ?? '');

  final String id;
  final TextEditingController label;
  final TextEditingController url;

  void dispose() {
    label.dispose();
    url.dispose();
  }
}

class _SocialLinkCard extends StatelessWidget {
  const _SocialLinkCard({required this.data, this.onRemove});

  final _SocialLinkFormData data;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: data.label,
                    decoration: const InputDecoration(
                      labelText: 'Nome canale',
                      hintText: 'Es. Instagram',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                if (onRemove != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Rimuovi canale',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.url,
              decoration: const InputDecoration(
                labelText: 'Link',
                hintText: 'https://',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomFormData {
  _RoomFormData({
    required this.id,
    String? name,
    int? capacity,
    String? category,
    String? servicesLabel,
  }) : name = TextEditingController(text: name ?? ''),
       capacity = TextEditingController(text: capacity?.toString() ?? '1'),
       category = TextEditingController(text: category ?? ''),
       services = TextEditingController(text: servicesLabel ?? '');

  factory _RoomFormData.fromRoom(
    SalonRoom room, {
    required String servicesLabel,
  }) {
    return _RoomFormData(
      id: room.id,
      name: room.name,
      capacity: room.capacity,
      category: room.category,
      servicesLabel: servicesLabel,
    );
  }

  final String id;
  final TextEditingController name;
  final TextEditingController capacity;
  final TextEditingController category;
  final TextEditingController services;

  void dispose() {
    name.dispose();
    capacity.dispose();
    category.dispose();
    services.dispose();
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.entry,
    required this.onChanged,
    required this.onPickOpening,
    required this.onPickClosing,
  });

  final _ScheduleEntry entry;
  final ValueChanged<bool> onChanged;
  final VoidCallback onPickOpening;
  final VoidCallback onPickClosing;

  @override
  Widget build(BuildContext context) {
    final timeFormatter = MaterialLocalizations.of(context);
    final openingLabel = timeFormatter.formatTimeOfDay(
      entry.open,
      alwaysUse24HourFormat: true,
    );
    final closingLabel = timeFormatter.formatTimeOfDay(
      entry.close,
      alwaysUse24HourFormat: true,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              value: entry.isOpen,
              onChanged: onChanged,
              title: Text(_weekdayName(entry.weekday)),
              subtitle: Text(
                entry.isOpen
                    ? 'Aperto $openingLabel - $closingLabel'
                    : 'Chiuso',
              ),
            ),
            if (entry.isOpen)
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPickOpening,
                        icon: const Icon(Icons.login_rounded),
                        label: Text('Apre alle $openingLabel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPickClosing,
                        icon: const Icon(Icons.logout_rounded),
                        label: Text('Chiude alle $closingLabel'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.data, required this.onRemove});

  final _RoomFormData data;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Cabina', style: theme.textTheme.titleSmall),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Rimuovi cabina',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            TextFormField(
              controller: data.name,
              decoration: const InputDecoration(labelText: 'Nome cabina'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.category,
              decoration: const InputDecoration(
                labelText: 'Categoria postazione',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.capacity,
              decoration: const InputDecoration(labelText: 'Capienza'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.services,
              decoration: const InputDecoration(
                labelText: 'Servizi offerti',
                helperText: 'Separa i servizi con una virgola',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _EquipmentFormData {
  _EquipmentFormData({
    required this.id,
    String? name,
    int? quantity,
    SalonEquipmentStatus? status,
    String? notes,
  }) : name = TextEditingController(text: name ?? ''),
       quantity = TextEditingController(text: quantity?.toString() ?? '1'),
       notes = TextEditingController(text: notes ?? ''),
       status = status ?? SalonEquipmentStatus.operational;

  factory _EquipmentFormData.fromEquipment(SalonEquipment equipment) {
    return _EquipmentFormData(
      id: equipment.id,
      name: equipment.name,
      quantity: equipment.quantity,
      status: equipment.status,
      notes: equipment.notes,
    );
  }

  final String id;
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController notes;
  SalonEquipmentStatus status;

  void dispose() {
    name.dispose();
    quantity.dispose();
    notes.dispose();
  }
}

class _ClosureFormData {
  _ClosureFormData({
    required this.id,
    required this.start,
    required this.end,
    String? reason,
  }) : reason = TextEditingController(text: reason ?? '');

  factory _ClosureFormData.fromClosure(SalonClosure closure) {
    return _ClosureFormData(
      id: closure.id,
      start: closure.start,
      end: closure.end,
      reason: closure.reason,
    );
  }

  final String id;
  DateTime start;
  DateTime end;
  final TextEditingController reason;

  void dispose() {
    reason.dispose();
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.data,
    required this.onStatusChanged,
    required this.onRemove,
  });

  final _EquipmentFormData data;
  final ValueChanged<SalonEquipmentStatus> onStatusChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Macchinario', style: theme.textTheme.titleSmall),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Rimuovi macchinario',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            TextFormField(
              controller: data.name,
              decoration: const InputDecoration(labelText: 'Nome macchinario'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SalonEquipmentStatus>(
              value: data.status,
              decoration: const InputDecoration(labelText: 'Stato operativo'),
              items:
                  SalonEquipmentStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  onStatusChanged(value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.quantity,
              decoration: const InputDecoration(
                labelText: 'Quantità disponibile',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.notes,
              decoration: const InputDecoration(
                labelText: 'Note o istruzioni',
                helperText:
                    'Informazioni visibili allo staff (manutenzione, uso, etc.)',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosureCard extends StatelessWidget {
  const _ClosureCard({
    required this.data,
    required this.onPickRange,
    required this.onRemove,
  });

  final _ClosureFormData data;
  final VoidCallback onPickRange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('dd/MM/yyyy');
    final startLabel = formatter.format(data.start);
    final endLabel = formatter.format(data.end);
    final rangeLabel =
        data.start.year == data.end.year &&
                data.start.month == data.end.month &&
                data.start.day == data.end.day
            ? startLabel
            : '$startLabel → $endLabel';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Periodo di chiusura', style: theme.textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  tooltip: 'Rimuovi chiusura',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: onPickRange,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(rangeLabel),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.reason,
              decoration: const InputDecoration(
                labelText: 'Motivo della chiusura',
                helperText:
                    'Facoltativo, aiuta a comunicare allo staff le ragioni.',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
