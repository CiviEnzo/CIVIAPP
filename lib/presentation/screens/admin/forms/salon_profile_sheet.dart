import 'package:civiapp/domain/entities/salon.dart';
import 'package:flutter/material.dart';

class SalonProfileSheet extends StatefulWidget {
  const SalonProfileSheet({super.key, required this.salon});

  final Salon salon;

  @override
  State<SalonProfileSheet> createState() => _SalonProfileSheetState();
}

class _SalonProfileSheetState extends State<SalonProfileSheet> {
  late TextEditingController _address;
  late TextEditingController _city;
  late TextEditingController _postalCode;
  late TextEditingController _googlePlaceId;
  late TextEditingController _latitude;
  late TextEditingController _longitude;
  late TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final salon = widget.salon;
    _address = TextEditingController(text: salon.address);
    _city = TextEditingController(text: salon.city);
    _postalCode = TextEditingController(text: salon.postalCode ?? '');
    _googlePlaceId = TextEditingController(text: salon.googlePlaceId ?? '');
    _latitude = TextEditingController(
      text: salon.latitude == null ? '' : salon.latitude!.toStringAsFixed(6),
    );
    _longitude = TextEditingController(
      text: salon.longitude == null ? '' : salon.longitude!.toStringAsFixed(6),
    );
    _description = TextEditingController(text: salon.description ?? '');
  }

  @override
  void dispose() {
    _address.dispose();
    _city.dispose();
    _postalCode.dispose();
    _googlePlaceId.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    double? latitude;
    if (_latitude.text.trim().isNotEmpty) {
      latitude = double.tryParse(_latitude.text.trim().replaceAll(',', '.'));
      if (latitude == null) {
        _showError('Inserisci una latitudine valida (es. 45.464203).');
        return;
      }
    }

    double? longitude;
    if (_longitude.text.trim().isNotEmpty) {
      longitude = double.tryParse(_longitude.text.trim().replaceAll(',', '.'));
      if (longitude == null) {
        _showError('Inserisci una longitudine valida (es. 9.189982).');
        return;
      }
    }

    final updated = widget.salon.copyWith(
      address: _address.text.trim(),
      city: _city.text.trim(),
      postalCode:
          _postalCode.text.trim().isEmpty ? null : _postalCode.text.trim(),
      googlePlaceId:
          _googlePlaceId.text.trim().isEmpty
              ? null
              : _googlePlaceId.text.trim(),
      latitude: latitude,
      longitude: longitude,
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
    );

    Navigator.of(context).pop(updated);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profilo salone', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Indirizzo',
                helperText: 'Via e numero civico',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Città'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _postalCode,
              decoration: const InputDecoration(labelText: 'CAP'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _googlePlaceId,
              decoration: const InputDecoration(
                labelText: 'Google Place ID',
                helperText: 'Utilizzato per recensioni e mappe',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
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
                  child: TextField(
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
            TextField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Descrizione',
                helperText: 'Testo mostrato nelle card pubbliche',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Annulla'),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _submit, child: const Text('Salva')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
