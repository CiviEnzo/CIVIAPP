import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:flutter/material.dart';

class SalonClientRegistrationSheet extends StatefulWidget {
  const SalonClientRegistrationSheet({super.key, required this.salon});

  final Salon salon;

  @override
  State<SalonClientRegistrationSheet> createState() =>
      _SalonClientRegistrationSheetState();
}

class _SalonClientRegistrationSheetState
    extends State<SalonClientRegistrationSheet> {
  late ClientRegistrationAccessMode _accessMode;
  late Set<ClientRegistrationExtraField> _extraFields;

  @override
  void initState() {
    super.initState();
    final initial = widget.salon.clientRegistration;
    _accessMode = initial.accessMode;
    _extraFields = initial.extraFields.toSet();
  }

  void _toggleExtra(ClientRegistrationExtraField field, bool enabled) {
    setState(() {
      if (enabled) {
        _extraFields.add(field);
      } else {
        _extraFields.remove(field);
      }
    });
  }

  void _submit() {
    final updated = widget.salon.copyWith(
      clientRegistration: ClientRegistrationSettings(
        accessMode: _accessMode,
        extraFields: _extraFields.toList(growable: false),
      ),
    );
    Navigator.of(context).pop(updated);
  }

  String _accessModeLabel(ClientRegistrationAccessMode mode) {
    switch (mode) {
      case ClientRegistrationAccessMode.open:
        return 'Accesso immediato (salone aperto)';
      case ClientRegistrationAccessMode.approval:
        return 'Solo previa approvazione';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extraOptions = <ClientRegistrationExtraField, String>{
      ClientRegistrationExtraField.address: 'Richiedi città di residenza',
      ClientRegistrationExtraField.profession: 'Richiedi professione',
      ClientRegistrationExtraField.referralSource:
          'Richiedi "Come ci ha conosciuto?"',
      ClientRegistrationExtraField.notes: 'Richiedi note aggiuntive',
      ClientRegistrationExtraField.gender: 'Richiedi sesso',
    };

    return DialogActionLayout(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registrazione clienti', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Configura come i clienti richiedono l\'accesso e quali dati sono obbligatori.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ClientRegistrationAccessMode>(
            value: _accessMode,
            decoration: const InputDecoration(labelText: 'Modalità di accesso'),
            items:
                ClientRegistrationAccessMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(_accessModeLabel(mode)),
                      ),
                    )
                    .toList(growable: false),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _accessMode = value);
            },
          ),
          const SizedBox(height: 16),
          Text('Campi aggiuntivi obbligatori', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          ...extraOptions.entries.map((entry) {
            final isSelected = _extraFields.contains(entry.key);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: isSelected,
              onChanged: (value) => _toggleExtra(entry.key, value ?? false),
              title: Text(entry.value),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Annulla'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salva')),
      ],
    );
  }
}

